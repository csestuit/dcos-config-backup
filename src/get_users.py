#!/usr/bin/env python3
#
# get_users.py: retrieve and save configured users on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of users configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_users" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/get_users

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
	sys.stdout.write( '** ERROR: Configuration not found. Please run ./run.sh first\n' )
	sys.exit(1)	

#Get list of USERS from DC/OS. 
#This will be later used as index to get all user-to-group memberships
api_endpoint = '/acs/api/v1/users'
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
	#show progress after request
	sys.stdout.write( '** INFO: GET User: {0} \r'.format( request.status_code ) )
	sys.stdout.flush()
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print ('** ERROR: GET User: {} \n'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':
	
	users = request.text				#raw text form requests, comes in JSON form from DC/OS

	#save to USERS file
	users_file = open( config['USERS_FILE'], 'w' )
	users_file.write( users )			#write to file in same raw JSON as obtained from DC/OS
	users_file.close()					

	#Load list of USERS from the USERS file, loop through them, 
	#get for each user its memberships from the DC/OS cluster
	# and store all users and their memberships in a dictionary blob. 

	#create a dictionary object that will hold all user-to-group memberships
	users_groups = { 'array' : [] }

	#change the list of users loaded from file (or DC/OS) to JSON dictionary
	users_json = json.loads( users )

	for index, user in ( enumerate( users_json['array'] ) ):

		#1.7 clusters dont have service accounts so this field may not exist
		#add it with a false value for transitioning.
		if not 'is_service' in user:
			user['is_service'] = 'false'
		
		#append this user as a dictionary to the list
		#ONLY if it's not remote
		if user['is_remote'] == 'false':
			users_groups['array'].append(
			{
				'uid' : 		user['uid'],
				'url' : 		user['url'],
				'description' : user['description'],
				'is_remote' : 	user['is_remote'],
				'is_service' : 	user['is_service'],
				#'public_key':	user['public_key'],
				#group memberships is a list, with each member being a dictionary
				'groups' : 		[]				#initialize groups LIST for this user
			}
			)
		#get groups for this user from DC/OS
		api_endpoint = '/acs/api/v1/users/'+user['uid']+'/groups'
		url = 'http://'+config['DCOS_IP']+api_endpoint
		try:
			request = requests.get(
				url,
				headers=headers,
				)
			#show progress after request
			sys.stdout.write( '** INFO: GET User Group {}: {}: {}\r'.format( index, user['uid'], request.status_code ) )
			sys.stdout.flush()
		except (
		    requests.exceptions.ConnectionError ,\
		    requests.exceptions.Timeout ,\
		    requests.exceptions.TooManyRedirects ,\
		    requests.exceptions.RequestException ,\
		    ConnectionRefusedError
		    ) as error:
			print ('** ERROR: GET User Group {}: {}: {} \n'.format( index, user['uid'], error ) ) 

		if str(request.status_code)[0] == '2':		
			memberships = request.json() 	#get memberships from the JSON
			#no need to decode the JSON as I can get 
			#memberships is another list, store as an
			for index2, membership in ( enumerate( memberships['array'] ) ):

				#get each group membership for this user
				users_groups['array'][index]['groups'].append( 
				{
					'membershipurl' :		membership['membershipurl'],
					'group' : {
						'gid' : 			membership['group']['gid'],
						'url' : 			membership['group']['url'],
						'description' : 	membership['group']['description']
					}
				}
				)

	#done.

	#write dictionary as a JSON object to file
	users_groups_json = json.dumps( users_groups ) 		#convert to JSON
	users_groups_file = open( config['USERS_GROUPS_FILE'], 'w' )
	users_groups_file.write( users_groups_json )		#write to file in raw JSON
	users_groups_file.close()									#flush

sys.stdout.write( '\n** INFO: GET Users: 							Done. \n' )





