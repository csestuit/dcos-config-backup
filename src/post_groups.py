#!/usr/bin/env python
#
# post_groups.py: load from file and restore groups to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of groups to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
#"get_groups.py" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/put_groups_gid

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
if not ( os.path.isfile( config['GROUPS_FILE'] ) ):
	sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Users before POSTing them.')
	sys.exit(1)

#open the GROUPS file and load the LIST of groups from JSON
groups_file = open( config['GROUPS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
groups = json.loads( groups_file.read() )
groups_file.close()

#loop through the list of groups and
#PUT /groups/{gid}
for index, group in ( enumerate( groups['array'] ) ): 

	gid = group['gid']
	#build the request
	api_endpoint = '/acs/api/v1/groups/'+gid
	url = 'http://'+config['DCOS_IP']+api_endpoint
	headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN'],
	}
	data = {
	'description': group['description'],
	}
	#send the request to PUT the new USER
	try:
		request = requests.put(
		url,
	 	data = json.dumps( data ),
	 	headers = headers
		)
		request.raise_for_status()
		#show progress after request
		sys.stdout.write( '** INFO: PUT Group: {} {} : {:>20}'.format( index, gid, request.status_code ) ) 
		sys.stdout.flush()
	except requests.exceptions.HTTPError as error:
		print ('** ERROR: PUT Group: {} {} : {}'.format( index, gid, error ) ) 

#loop through the list of groups_users and add users to groups
#PUT /groups/{gid}/users/{uid}

#check that there's a GROUPS_USERS file created (buffer loaded)
if not ( os.path.isfile( config['GROUPS_USERS_FILE'] ) ):
	sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET User-to-Group memberships before POSTing it.')
	sys.exit(1)

#open the GROUPS file and load the LIST of groups from JSON
groups_users_file = open( config['GROUPS_USERS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
groups_users = json.loads( groups_users_file.read() )
groups_users_file.close()

for index, group_user in ( enumerate( groups_users['array'] ) ): 
	#PUT /groups/{gid}/users/{uid}
	gid = group_user['gid']	

	#array of users for this group_users
	for index2, user in ( enumerate( group_user['users'] ) ): 

		uid = user['user']['uid']
		#build the request
		api_endpoint = '/acs/api/v1/groups/'+gid+'/users/'+uid
		url = 'http://'+config['DCOS_IP']+api_endpoint
		headers = {
		'Content-type': 'application/json',
		'Authorization': 'token='+config['TOKEN'],
		}
		#send the request to PUT the new USER
		try:
			request = requests.put(
			url,
			headers = headers
			)
			request.raise_for_status()
			#show progress after request
			sys.stdout.write( '** INFO: PUT Group: {} {} User: {} : {:>20} \r'.format( index, gid, uid, request.status_code ) )
			sys.stdout.flush() 
		except requests.exceptions.HTTPError as error:
			print ('** ERROR: PUT Group: {} {} User: {} : {}'.format( index, gid, uid, error ) ) 

sys.stdout.write('\n** PUT Groups Users: Done.\n')

