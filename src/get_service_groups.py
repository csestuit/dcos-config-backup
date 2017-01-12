#!/usr/bin/env python
#
# get_service_groups.py: retrieve and save configured service groups on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of service groups configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_service_groups.py" script.

#reference:
#https://mesosphere.github.io/marathon/docs/rest-api.html

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

#Get list of SERVICE_GROUPS from DC/OS. 
#This will be later used as index to get all user-to-group memberships
api_endpoint = '/marathon/v2/groups'
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
	sys.stdout.write( '** INFO: GET Service Groups: {:>20} \r'.format( request.status_code ) ) 
	sys.stdout.flush()
except requests.exceptions.HTTPError as error:
	print ('** GET Service Groups failed with ERROR: {}\n'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':

	service_groups = request.text	#raw text form requests, in JSON from DC/OS
	service_groups_json = json.loads( service_groups )

	#save to SERVICE_GROUPS file
	service_groups_file = open( config['SERVICE_GROUPS_FILE'], 'w' )
	service_groups_file.write( json.dumps( service_groups_json ) )			#write to file in same raw JSON as obtained from DC/OS
	service_groups_file.close()					

	#change the list of service groups loaded from file (or DC/OS) to JSON dictionary
	helpers.walk_and_print( service_groups_json, "Service Group" )

	#done.

sys.stdout.write( '\n** INFO: GET Service Groups:							Done.\n' )

