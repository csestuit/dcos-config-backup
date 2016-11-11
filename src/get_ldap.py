#!/usr/bin/env python
#
# get_ldap.py: retrieve and save LDAP configuration from a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get LDAP information from a DC/OS cluster and write it
# to a file in raw JSON format for backup and restore purposes.
# It can be restored into a cluster with the accompanying 
# "post_ldap" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/ldap/get_ldap_config

import sys
import os
import requests
import json
import helpers			#helper functions in separate module helpers.py


#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
config_file = os.getcwd()+'/.config.json'
config = helpers.get_config( config_file )				#returns config as a dictionary
if len( config ) == 0:
	sys.stdout.write( '** ERROR: Configuration not found. Please run ./run.sh first' )
	sys.exit(1)	

#Get LDAP information from DC/OS. 
api_endpoint = '/acs/api/v1/ldap/config'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN'],
}
request = requests.get(
	url,
	headers=headers,
	)
#show progress after request
sys.stdout.write( '** INFO: GET LDAP: {0} \r'.format( request.status_code ) )
sys.stdout.flush()
ldap = request.text				#raw text form requests, comes in JSON form from DC/OS

#save to LDAP file
ldap_file = open( config['LDAP_FILE'], 'w' )
ldap_file.write( ldap )			#write to file in same raw JSON as obtained from DC/OS
ldap_file.close()					

sys.stdout.write( '\n** INFO: GET LDAP: 							Done. \n' )





