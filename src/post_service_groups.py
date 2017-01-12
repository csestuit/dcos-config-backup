#!/usr/bin/env python
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

import sys
import os
import requests
import json
import helpers      #helper functions in separate module helpers.py

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
service_groups = json.loads( service_groups_file.read() )
service_groups_file.close()

#loop through the list of service groups and post them to the cluster.
for index, group in ( enumerate( service_groups['groups'] ) ): 

  #build the request
  api_endpoint = '/marathon/v2/groups'
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
  'Content-type': 'application/json',
  'Authorization': 'token='+config['TOKEN'],
  }
  data = group
  #send the request to PUT the new Service Group
  try:
    request = requests.put(
      url,
      headers = headers,
      data = json.dumps( data )
    )
    request.raise_for_status()
    #show progress after request
    sys.stdout.write( '** INFO: PUT Service Group: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except requests.exceptions.HTTPError as error:
    print ('** ERROR: PUT Service Group: {}: {}'.format( uid, error ) ) 


sys.stdout.write('\n** INFO: PUT Service Groups:                         Done.\n')
