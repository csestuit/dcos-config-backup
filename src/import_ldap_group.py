#!/usr/bin/env python
#
# import_ldap_group.py: import a group to a DC/OS cluster from the LDAP server configured in it.
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Import a group from an LDAP directory into DC/OS based on its groupname. 
# Groupname is received as the first command-line parameter.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/ldap/post_ldap_importgroup
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
  sys.stdout.write( '** ERROR: Configuration not found. Please run ./run.sh first' )
  sys.exit(1)  

#check command-line arguments and use the first one only as the groupname
if len(sys.argv) >= 1:
  sys.stdout.write( '** INFO: Importing Group: {} \r'.format( sys.argv[1] ) )
  sys.stdout.flush() 
  groupname = sys.argv[1]
else:
  raise ValueError('Wrong syntax. First argument must be the groupname to be imported.')

#Test the LDAP connection
#/ldap/config/test
sys.stdout.write( '** INFO: Testing LDAP connection... \r' )
sys.stdout.flush() 
#build the request
api_endpoint = '/acs/api/v1/ldap/config/test'
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
  sys.stdout.write( '** INFO: TEST LDAP connection: {:>20} \r'.format( request.status_code ) )
  sys.stdout.flush() 
except requests.exceptions.HTTPError as error:
  print ('** ERROR: TEST LDAP connection: {}'.format( error ) )

#TODO: exit if TEST LDAP Error?

#If successful, POST the request to import the group
#/ldap/importgroup
#build the request
api_endpoint = '/acs/api/v1/ldap/importgroup'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
'Content-type': 'application/json',
'Authorization': 'token='+config['TOKEN'],
}
data = '{ "groupname": '+groupname+' }'
#send the request to IMPORT the GROUP
try:
  request = requests.post(
    url,
    headers = headers,
    data = json.dumps( data )
  )
  request.raise_for_status()
  #show progress after request
  sys.stdout.write( '** INFO: IMPORT LDAP Group: {} {:>20} \r'.format( groupname, request.status_code ) )
  sys.stdout.flush() 
except requests.exceptions.HTTPError as error:
  print ('** ERROR: IMPORT LDAP Group: {}: {}'.format( groupname, error ) ) 


sys.stdout.write('\n** INFO: IMPORT LDAP Group:                         Done.\n')
