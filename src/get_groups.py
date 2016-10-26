#!/usr/bin/env python
#
# get_groups.py: retrieve and save configured groups on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of groups configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_groups.py" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/get_groups_gid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/get_groups_gid_users

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
	print( '** ERROR: Configuration not found. Please run ./run.sh first' )
	sys.exit(1)	

#Get list of GROUPS from DC/OS. 
#This will be later used as index to get all user-to-group memberships
api_endpoint = '/acs/api/v1/groups'
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
	print( '** GET Groups STATUS: {}'.format( request.status_code ) ) 
except requests.exceptions.HTTPError as error:
	print ('** GET Groups failed with ERROR: {}'.format( error ) ) 

groups = request.text	#raw text form requests, in JSON from DC/OS

#save to GROUPS file
groups_file = open( config['GROUPS_FILE'], 'w' )
groups_file.write( groups )			#write to file in same raw JSON as obtained from DC/OS
groups_file.close()					

#change the list of groups loaded from file (or DC/OS) to JSON dictionary
groups_json = json.loads( groups )
#create a dictionary object that will hold all group-to-user memberships
groups_users = { 'array' : [] }


for index, group in ( enumerate( groups_json['array'] ) ):
	
	#append this group as a dictionary to the list 
	groups_users['array'].append(
	{
		'gid' : 		group['gid'],
		'url' : 		group['url'],
		'description' : group['description'],
		'users' : 		[],				#initialize users LIST for this group
		'permissions':	[]				#initialize permissions LIST for this group
	}
	)

	#get users for this group from DC/OS
	#GET groups/[gid]/users
	api_endpoint = '/acs/api/v1/groups/'+group['gid']+'/users'
	url = 'http://'+config['DCOS_IP']+api_endpoint
	try:
		request = requests.get(
			url,
			headers=headers,
			)
		request.raise_for_status()
		print( '** GET Group/Users Membership STATUS: {}'.format( request.status_code ) )
	except requests.exceptions.HTTPError as error:
		print ('** GET Group/Users failed with ERROR: {}'.format( error ) ) 
	memberships = request.json() 	#get memberships from the JSON
	for index2, membership in ( enumerate( memberships['array'] ) ):
		#get each user that is a member of this group and append
		groups_users['array'][index]['users'].append( membership )

	#get permissions for this group from DC/OS
	#GET groups/[gid]/permissions
	api_endpoint = '/acs/api/v1/groups/'+group['gid']+'/permissions'
	url = 'http://'+config['DCOS_IP']+api_endpoint
	try:
		request = requests.get(
			url,
			headers=headers,
			)
		request.raise_for_status()
		print( '** GET Group/Permissions STATUS: {}'.format( request.status_code ) )	
	except requests.exceptions.HTTPError as error:
		print ('** GET Group/Users failed with ERROR: {}'.format( error ) ) 
	permissions = request.json() 	#get memberships from the JSON	
	for index2, permission in ( enumerate( memberships['array'] ) ):
		#get each group membership for this user
		groups_users['array'][index]['permissions'].append( permission )

#done.

#write dictionary as a JSON object to file
groups_users_json = json.dumps( groups_users ) 		#convert to JSON
groups_users_file = open( config['GROUPS_USERS_FILE'], 'w' )
groups_users_file.write( groups_users_json )		#write to file in raw JSON
groups_users_file.close()									#flush

print( '** GET Groups: Done.' )

