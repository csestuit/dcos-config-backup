#!/usr/bin/env python
#
# post_ldap.py: load from file and restore LDAP configuration to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post LDAP configuration to a running DC/OS cluster, read from a file 
# where it's stored in raw JSON format as received from the accompanying
# "get_ldap" script.

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

#check that there's an LDAP file created (buffer loaded)
if not ( os.path.isfile( config['LDAP_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Users before POSTing them.')
  sys.exit(1)

#open the LDAP file and load the configuration from JSON
ldap_file = open( config['LDAP_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
ldap = json.loads( ldap_file.read() )
ldap_file.close()

#build the request
api_endpoint = '/acs/api/v1/ldap/config'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
'Content-type': 'application/json',
'Authorization': 'token='+config['TOKEN'],
}
data = ldap
#send the request to PUT the new USER
try:
  request = requests.put(
    url,
    headers = headers,
    data = json.dumps( data )
  )
  request.raise_for_status()
  #show progress after request
  sys.stdout.write( '** INFO: PUT LDAP: {:>20} \r'.format( request.status_code ) )
  sys.stdout.flush() 
except requests.exceptions.HTTPError as error:
  print ('** ERROR: PUT LDAP: {}: {}'.format( uid, error ) ) 


sys.stdout.write('\n** INFO: PUT LDAP:                         Done.\n')
