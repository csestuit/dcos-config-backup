#!/usr/bin/env python3
#
# post_service_groups.py: load from file and restore service groups to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of service groups to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_service_groups" script.

#reference:
#https://mesosphere.github.io/marathon/docs/rest-api.html
#https://mesosphere.github.io/marathon/docs/generated/api.html#v2_apps__app_id__get

import sys
import os
import requests
import json
import helpers      #helper functions in separate module helpers.py
from time import sleep


#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
config_file = os.getcwd()+'/.config.json'
config = helpers.get_config( config_file )        #returns config as a dictionary
if len( config ) == 0:
  sys.stdout.write( '** ERROR: Configuration not found. Please run ./run.sh first' )
  sys.exit(1)  

#check that there's a SERVICE_GROUPS file created (buffer loaded)
if not ( os.path.isfile( config['SERVICE_GROUPS_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Service Groups before POSTing them.')
  sys.exit(1)

#open the service groups file and load the LIST of Service Groups from JSON
service_groups_file = open( config['SERVICE_GROUPS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
root_service_group = json.loads( service_groups_file.read() )
service_groups_file.close()

#***** Service groups ******
#'/' is a service group itself but it does not need to be posted.
#Need to POST the groups under it (one level) that don't exist yet.
#https://mesosphere.github.io/marathon/docs/rest-api.html#post-v2-groups

for index, service_group in enumerate( root_service_group['groups'] ):   #don't post `/` but only his 'groups'
  helpers.format_service_group( service_group )
  #build the request
  api_endpoint = '/marathon/v2/groups'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
    'Content-type': 'application/json',
    'Authorization': 'token='+config['TOKEN']
  }

  #send the request to PUT the new Service Group
  try:
    request = requests.post(
      url,
      headers = headers,
      data = json.dumps( service_group )
    )
    request.raise_for_status()
    #show progress after request
    sys.stdout.write( '** INFO: POST Service Group: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
    print ('** ERROR: POST Service Group: {0} {1}: {2}'.format( index, service_group['id'], request.text ) ) 

#***** Apps ******
#check that there's an APPS file created (buffer loaded)
if not ( os.path.isfile( config['APPS_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Apps before POSTing them.')
  sys.exit(1)

#open the apps file and load the LIST of Apps from JSON
apps_file = open( config['APPS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
apps = json.loads( apps_file.read() )
apps_file.close()

#Post apps
for index, app in enumerate( apps['apps'] ): 
  helpers.format_app( app )
  #build the request
  api_endpoint = '/marathon/v2/apps'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
    'Content-type': 'application/json',
    'Authorization': 'token='+config['TOKEN']
  }
  #send the request to PUT the new Service Group
  try:
    request = requests.post(
      url,
      headers = headers,
      data = json.dumps( app )
    )
    request.raise_for_status()
    #show progress after request
    sys.stdout.write( '** INFO: POST App: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
    print ('** ERROR: POST App: {0} {1}: {2}'.format( index, app['id'], request.text ) ) 

#***** Marathon-on-Marathon service groups ******

#open the service groups mom file and load the dict of SGs_MOM from JSON
service_groups_mom_file = open( config['SERVICE_GROUPS_MOM_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
service_groups_mom = json.loads( service_groups_mom_file.read() )
service_groups_mom_file.close()

#***For each Marathon-on-Marathon instance on file***
#***Launch it, inside the appropriate service group
for service_group_mom in service_groups_mom['mom_groups']:
  #reformat app to remove superfluous fields: 'version', tasksHealhty, etc.
  helpers.format_app( service_group_mom['app']  )
  #build the request
  api_endpoint = '/marathon/v2/apps'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
    'Content-type': 'application/json',
    'Authorization': 'token='+config['TOKEN'],
  }

  try:
    request = requests.post(
      url,
      headers = headers,
      data = json.dumps( service_group_mom['app'] )
    )
    request.raise_for_status()
    sys.stdout.write( '** INFO: POST MoM Instance: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
    print ('** ERROR: POST MoM Instance: {0} {1}: {2}'.format( index, service_group_mom['DCOS_SERVICE_NAME'], request.text ) ) 

#**** wait until all MoM instances are running so that we can post groups and apps to them ****
while True:
  #Get the list of Marathon apps on the system, store in dictionary
  api_endpoint = '/marathon/v2/apps'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
    'Content-type': 'application/json',
    'Authorization': 'token='+config['TOKEN'],
  }
  try:
    request = requests.get(
      url,
      headers=headers,
		  verify=False
      )
    request.raise_for_status()
    sys.stdout.write( '** INFO: GET Apps looking for MoM instances: {:>20} \r'.format( request.status_code ) ) 
    sys.stdout.flush()
  except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
    print ('**ERROR: GET Apps failed with: {}\n'.format( error ) )

  #2xx HTTP status code is success
  if str(request.status_code)[0] == '2':

    running_marathons = {"marathons":[]} #list of dictionaries with the app definition for each MoM instance
    running_apps = request.text #raw text form requests, in JSON from DC/OS
    running_apps_dict = json.loads( running_apps )
    for index,running_app in enumerate( running_apps_dict['apps'] ):
      if 'DCOS_PACKAGE_NAME' in running_app['labels']:
        if running_app['labels']['DCOS_PACKAGE_NAME']=='marathon':
          running_marathons['marathons'].append( running_app )
  else:
    print('**ERROR: GET Apps failed with: {}'.format( request.text ) )
    
  healthy_marathons = [ loaded_marathon for loaded_marathon in running_marathons['marathons'] if loaded_marathon['tasksHealthy']>0 ]
  print('** INFO: Detected {0} healthy MoM instances. Waiting until all {1} MoM instances are running.'.format( \
    len( healthy_marathons ), len( service_groups_mom['mom_groups'] ) ), end='\r' )
  if len( healthy_marathons ) == len ( service_groups_mom['mom_groups'] ): #ALL MARATHONS ARE RUNNING
    break
  sleep(10)

#FOR EACH MARATHON-ON MARATHON INSTANCE ON FILE
#Post all service groups as loaded at the beginning, now that those MoM instances are running.
#Then, post the apps.

#sleep 10 seconds for Marathons to REALLY come up
print('** INFO: All MoM instances are up! Waiting a grace period for them to start...')
sleep(10)

for index, mom in enumerate( service_groups_mom['mom_groups'] ):
  
  for index2,mom_groups in enumerate( mom['groups']['groups'] ): #skip "/" group -- go straight to children.
  
    #format the groups in the marathon instance to remove offending fields
    helpers.format_service_group( mom_groups )
    #build the request
    service_name = mom['DCOS_SERVICE_NAME']
    api_endpoint = '/v2/groups'
    url = 'http://'+config['DCOS_IP']+'/service/'+service_name+api_endpoint
    headers = {
      'Content-type': 'application/json',
      'Authorization': 'token='+config['TOKEN'],
    }
    try:
      request = requests.post(
        url,
        headers = headers, 
        data = json.dumps( mom_groups )
      )
      request.raise_for_status()
      #show progress after request
      sys.stdout.write( '** INFO: POST MoM Service Groups : {} : {:>20} \r'.format( index, request.status_code ) )
      sys.stdout.flush() 
    except (
      requests.exceptions.ConnectionError ,\
      requests.exceptions.Timeout ,\
      requests.exceptions.TooManyRedirects ,\
      requests.exceptions.RequestException ,\
      ConnectionRefusedError
      ) as error:
      print ('** ERROR: POST Mom Service Groups: {0} {1}: {2}'.format( index, mom['DCOS_SERVICE_NAME'], request.text ) ) 

#*---- APPS -----*
#Load MoM apps to post them along with the MoM service groups
apps_mom_file = open( config['APPS_MOM_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
apps_mom = json.loads( apps_mom_file.read() )
apps_mom_file.close()

for index,mom in enumerate( apps_mom['mom_apps'] ):

  for index2, mom_app in enumerate( mom['apps']['apps'] ):

    helpers.format_app( mom_app )
    service_name = mom['DCOS_SERVICE_NAME']
    api_endpoint = '/v2/apps'
    url = 'http://'+config['DCOS_IP']+'/service/'+service_name+api_endpoint
    headers = {
      'Content-type': 'application/json',
      'Authorization': 'token='+config['TOKEN'],
    }
    try:
      request = requests.post(
        url,
        headers = headers, 
        data = json.dumps( mom_app )
      )
      request.raise_for_status()
      #show progress after request
      sys.stdout.write( '** INFO: POST MoM App : {} : {:>20} \r'.format( index, request.status_code ) )
      sys.stdout.flush() 
    except (
      requests.exceptions.ConnectionError ,\
      requests.exceptions.Timeout ,\
      requests.exceptions.TooManyRedirects ,\
      requests.exceptions.RequestException ,\
      ConnectionRefusedError
    ) as error:
      print ('** ERROR: POST Mom App: {0} {1}: {2}'.format( index, mom['DCOS_SERVICE_NAME'], request.text ) ) 

sys.stdout.write('\n** INFO: PUT Service Groups and Apps:                         Done.\n')
