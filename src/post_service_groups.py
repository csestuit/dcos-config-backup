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

#check that there's a USERS file created (buffer loaded)
if not ( os.path.isfile( config['SERVICE_GROUPS_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Service Groups before POSTing them.')
  sys.exit(1)

#open the service groups file and load the LIST of Users from JSON
service_groups_file = open( config['SERVICE_GROUPS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
root_service_group = json.loads( service_groups_file.read() )
service_groups_file.close()

#'/' is a service group itself but it can't be posted directly (it exists).
#Need to POST the groups under it (one level) that don't exist yet.
#https://mesosphere.github.io/marathon/docs/rest-api.html#post-v2-groups

for index, service_group in enumerate( root_service_group['groups'] ):   #don't post `/` but only his 'groups'
  helpers.format_service_group( service_group )
  #service_group = helpers.single_to_double_quotes( json.dumps( service_group ) ) 
  #build the request
  api_endpoint = '/marathon/v2/groups'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
    'Content-type': 'application/json',
    'Authorization': 'token='+config['TOKEN']
  }
  #service_group=json.loads(service_group)
  #del service_group['apps']
  #service_group=json.dumps(service_group)
  #send the request to PUT the new Service Group
  try:
    request = requests.post(
      url,
      headers = headers,
      data = json.dumps(service_group)
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

#***** Marathon-on-Marathon service groups ******

#open the service groups mom file and load the dict of SGs_MOM from JSON
service_groups_mom_file = open( config['SERVICE_GROUPS_MOM_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
service_groups_mom = json.loads( service_groups_mom_file.read() )
service_groups_mom_file.close()
#add 'health' field for checking while MoMs are booting - intialize as unhealthy
for service_group_mom in service_groups_mom['mom_groups']:
  service_group_mom['health']=1   #0 is healthy, anything else is unhealthy. This initiallizes as unhealthy until detected otherwise

#***For each Marathon-on-Marathon instance on file***
#***Launch it, inside the appropriate service group
for service_group_mom in service_groups_mom['mom_groups']:
  #reformat app to remove superfluous fields: 'version', tasksHealhty, etc.
  helpers.format_app( service_group_mom['app']  )
  #build the request
  api_endpoint = '/marathon/v2/apps' #endpoint to launch an app
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
    #show progress after request
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

#****wait until all instances are running****
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
    )
  request.raise_for_status()
  sys.stdout.write( '** INFO: GET Apps: {:>20} \r'.format( request.status_code ) ) 
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

  marathons = {"marathons":[]} #list of dictionaries with the app definition for each MoM instance
  apps = request.text #raw text form requests, in JSON from DC/OS
  apps_dict = json.loads( apps )
  for index,app in enumerate( apps_dict['apps'] ):
    if 'DCOS_PACKAGE_NAME' in app['labels']:
      if app['labels']['DCOS_PACKAGE_NAME']=='marathon':
        marathons['marathons'].append( app )
else:
  print('**ERROR: GET Apps failed with: {}'.format( request.text ) )

#wait until all those are in RUNNING state
while True:
  #For "each entry" on MoM-service_groups, get status and count the number of running_marathons
  for index,loaded_marathon in enumerate( marathons['marathons'] ):
    #Get status of each app with 
    #/v2/apps/{app_id} ['tasksHealthy']
    #print('**DEBUG: loaded_marathon is: \n {0}'.format(loaded_marathon))
    app_id=loaded_marathon['id']
    api_endpoint = '/marathon/v2/apps/'+app_id
    url = 'http://'+config['DCOS_IP']+api_endpoint
    headers = {
      'Content-type': 'application/json',
      'Authorization': 'token='+config['TOKEN'],
    }
    try:
      response = requests.get(
        url,
        headers=headers,
        )
      request.raise_for_status()
      sys.stdout.write( '** INFO: GET App for MoM: {:>20} \r'.format( request.status_code ) ) 
      sys.stdout.flush()
    except (
      requests.exceptions.ConnectionError ,\
      requests.exceptions.Timeout ,\
      requests.exceptions.TooManyRedirects ,\
      requests.exceptions.RequestException ,\
      ConnectionRefusedError
      ) as error:
      print ('**ERROR: GET App for MoM failed with: {}\n'.format( error ) )

    #get the response
    launching_marathon=response.json()
    #print('** DEBUG: launching marathon is: \n {0}'.format( json.dumps( launching_marathon ) ) )
    if launching_marathon['app']['tasksHealthy'] > 0:
        print('**DEBUG: DETECTED HEALTHY LAUNCHING-MARATHON!!!!')
        loaded_marathon['health']=0     #0 is healthy, anything else is unhealthy


  running_marathons = [ loaded_marathon for loaded_marathon in marathons['marathons'] if loaded_marathon['health']==0 ]
  print('** INFO: Detected {0} running Marathon instances. Waiting until all {1} Marathon instances are running.'.format( \
    len( running_marathons ), len( service_groups_mom['mom_groups'] ) ) )
  if len( running_marathons ) == len ( service_groups_mom['mom_groups'] ): #ALL MARATHONS ARE RUNNING
    break
  sleep(2)

#FOR EACH MARATHON-ON MARATHON INSTANCE ON FILE
#Post all service groups as loaded at the beginning, now that those MoM instances are running
for index, marathon in enumerate( service_groups_mom['mom_groups'] ):
  #format the groups in the marathon instance to remove offending fields
  helpers.format_service_group( marathon['groups'] )
  #build the request
  service_name=marathon['DCOS_SERVICE_NAME']
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
      data = json.dumps( marathon['groups'] )
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
    print ('** ERROR: POST Mom Service Groups: {0} {1}: {2}'.format( index, marathon['DCOS_SERVICE_NAME'], request.text ) ) 


sys.stdout.write('\n** INFO: PUT Service Groups:                         Done.\n')
