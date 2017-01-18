#!/usr/bin/env python3
#
# post_users.py: load from file and restore users to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of users to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_users" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/put_users_uid

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
if not ( os.path.isfile( config['USERS_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Users before POSTing them.')
  sys.exit(1)

#open the users file and load the LIST of Users from JSON
users_file = open( config['USERS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
users = json.loads( users_file.read() )
users_file.close()

#loop through the list of users and
#PUT /users/{uid}
for index, user in ( enumerate( users['array'] ) ): 

  uid = user['uid']

  #build the request
  api_endpoint = '/acs/api/v1/users/'+uid
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
  'Content-type': 'application/json',
  'Authorization': 'token='+config['TOKEN'],
  }
  data = {
  'description': user['description'],
  'password': config['DEFAULT_USER_PASSWORD']
  }
  #send the request to PUT the new USER
  try:
    request = requests.put(
      url,
      headers = headers,
      data = json.dumps( data )
    )
    request.raise_for_status()
    #show progress after request
    sys.stdout.write( '** INFO: PUT User: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except requests.exceptions.HTTPError as error:
    print ('** ERROR: PUT User: {}: {}'.format( uid, error ) ) 


sys.stdout.write('\n** INFO: PUT Users:                         Done.\n')
