#!/usr/bin/env python
#
# import_ldap_user.py: import a user to a DC/OS cluster from the LDAP server configured in it.
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Import a user from an LDAP directory into DC/OS based on its username. 
# Username is received as the first command-line parameter.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/ldap/post_ldap_importuser
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/ldap/post_ldap_config_test

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
  print( '** ERROR: Configuration not found. Please run ./run.sh first' )
  sys.exit(1)  

#check command-line arguments and use the first one only as the username
if len(sys.argv) >= 1:
  sys.stdout.write( '** INFO: Importing User: {} \r'.format( sys.argv[1] ) )
  sys.stdout.flush() 
  username = sys.argv[1]
else:
  raise ValueError('Wrong syntax. First argument must be the groupname to be imported.')

#Test the LDAP connection
#/ldap/config/test
sys.stdout.write( '** INFO: Testing LDAP connection... \r' )
sys.stdout.flush() 
#build the request
api_endpoint = '/acs/api/v1/ldap/config'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
'Content-type': 'application/json',
'Authorization': 'token='+config['TOKEN'],
}
#send the request to TEST the LDAP connection
try:
  request = requests.post(
    url,
    headers = headers
  )
  request.raise_for_status()
  #show progress after request
  sys.stdout.write( '** INFO: TEST LDAP config: {:>20} \r'.format( request.status_code ) )
  sys.stdout.flush() 
except requests.exceptions.HTTPError as error:
  print ('** ERROR: TEST LDAP config: {}'.format( error ) )

#TODO: exit if TEST LDAP Error?

#If successful, POST the request to import the user
#/ldap/importuser
#build the request
api_endpoint = '/acs/api/v1/ldap/importuser'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
'Content-type': 'application/json',
'Authorization': 'token='+config['TOKEN'],
}
data = '{ "username": '+username+' }'
#send the request to IMPORT the USER
try:
  request = requests.post(
    url,
    headers = headers,
    data = json.dumps( data )
  )
  request.raise_for_status()
  #show progress after request
  sys.stdout.write( '** INFO: IMPORT LDAP User: {} {:>20} \r'.format( username, request.status_code ) )
  sys.stdout.flush() 
except requests.exceptions.HTTPError as error:
  print ('** ERROR: IMPORT LDAP User: {}: {}'.format( username, error ) ) 


sys.stdout.write('\n** INFO: IMPORT LDAP User:                         Done.\n')
