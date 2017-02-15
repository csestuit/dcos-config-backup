#!/usr/bin/env python3
# get_acls.py: retrieve and save configured ACLs on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of ACLs configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_acls.py" script.

#reference: 
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/get_acls

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

#Get list of ACLs from DC/OS. 
#This will be later used as index to get all ACL-to-user/group relations
api_endpoint = '/acs/api/v1/acls'
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
	sys.stdout.write( '** INFO: GET ACLs: {}\r'.format( request.status_code ) )
	sys.stdout.flush() 
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print ('** ERROR: GET ACLs: {}'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':
	acls = request.text	#raw text form requests, in JSON from DC/OS

	#save to ACLs file
	acls_file = open( config['ACLS_FILE'], 'w' )
	acls_file.write( acls )			#write to file in same raw JSON as obtained from DC/OS
	acls_file.close()					
	#change the list of acls loaded from file (or DC/OS) to JSON dictionary
	acls_json = json.loads( acls )

	#create a dictionary object that will hold all group-to-user memberships
	acls_permissions = { 'array' : [] }

	#loop through the list of ACLs received and get the permissions
	# /acls/{rid}/permissions
	for index, acl in ( enumerate( acls_json['array'] ) ):
		
		#append this acl as a dictionary to the list 
		acls_permissions['array'].append(
		{
			'rid' : 		helpers.escape( acl['rid'] ),
			'url' : 		acl['url'],
			'description' : acl['description'],
			'users' : 		[],				#initialize users LIST for this acl
			'groups':		[]				#initialize groups LIST for this acl
		}
		)

		#get permissions for this ACL from DC/OS
		#GET acls/[rid]/permissions
		api_endpoint = '/acs/api/v1/acls/'+helpers.escape( acl['rid'] )+'/permissions'
		url = 'http://'+config['DCOS_IP']+api_endpoint
		try:
			request = requests.get(
				url,
				headers=headers,
				)
			request.raise_for_status()
			sys.stdout.write( '** INFO: GET ACL Permissions: {} {:>20} \r'.format( index, request.status_code ) )
			sys.stdout.flush()
		except (
		    requests.exceptions.ConnectionError ,\
		    requests.exceptions.Timeout ,\
		    requests.exceptions.TooManyRedirects ,\
		    requests.exceptions.RequestException ,\
		    ConnectionRefusedError
		    ) as error:
			print ('** ERROR: GET ACL Permission: {} {}\n'.format( index, error ) )

		if str(request.status_code)[0] == '2':
			permissions = request.json() 	#get memberships from the JSON

			#Loop through the list of user permissions and get their associated actions
			for index2, user in ( enumerate( permissions['users'] ) ):
				#get each user that is a member of this acl and append to ['users']
				acls_permissions['array'][index]['users'].append( user )
				#Loop through the list of actions for this user and get the action value
				for index3, action in ( enumerate ( user['actions'] ) ):
					#get action from DC/OS
					#GET /acls/{rid}/users/{uid}/{action}
					api_endpoint = '/acs/api/v1/acls/'+helpers.escape( acl['rid'] )+'/users/'+user['uid']+'/'+action['name']
					url = 'http://'+config['DCOS_IP']+api_endpoint
					try:
						request = requests.get(
							url,
							headers=headers,
							)
						request.raise_for_status()
						sys.stdout.write( '** INFO: GET ACL Permission User Actions: {} : {:>20} \r'.format( index3, request.status_code ) )
						sys.stdout.flush()
					except (
					    requests.exceptions.ConnectionError ,\
					    requests.exceptions.Timeout ,\
					    requests.exceptions.TooManyRedirects ,\
					    requests.exceptions.RequestException ,\
					    ConnectionRefusedError
					    ) as error:
						print ('** ERROR: GET ACL Permission User Actions: {}\n'.format( error ) )
					
					if str(request.status_code)[0] == '2':
						action_value = request.json()
						#add the value as another field of the action alongside name and url
						acls_permissions['array'][index]['users'][index2]['actions'][index3]['value'] = action_value	

			#Repeat loop with groups to get all groups and actions
			for index2, group in ( enumerate( permissions['groups'] ) ):
				#get each user that is a member of this acl and append to ['users']
				acls_permissions['array'][index]['groups'].append( group )
				#Loop through the list of actions for this user and get the action value
				for index3, action in ( enumerate ( group['actions'] ) ):
					#get action from DC/OS
					#GET /acls/{rid}/users/{uid}/{action}
					api_endpoint = '/acs/api/v1/acls/'+helpers.escape( acl['rid'] )+'/groups/'+group['gid']+'/'+action['name']
					url = 'http://'+config['DCOS_IP']+api_endpoint
					try:
						request = requests.get(
							url,
							headers=headers,
							)
						request.raise_for_status()
						sys.stdout.write( '** INFO: GET ACL Permission Group Actions: {} : {:>20} \r'.format( index3, request.status_code ) )
						sys.stdout.flush()
					except (
					    requests.exceptions.ConnectionError ,\
					    requests.exceptions.Timeout ,\
					    requests.exceptions.TooManyRedirects ,\
					    requests.exceptions.RequestException ,\
					    ConnectionRefusedError
					    ) as error: 
						print ('** ERROR: GET ACL Permission Group Actions: {} {} \n'.format( index3, error ) )
					
					if str(request.status_code)[0] == '2':	
						action_value = request.json()
						#add the value as another field of the action alongside name and url
						acls_permissions['array'][index]['groups'][index2]['actions'][index3]['value'] = action_value	


	#write dictionary as a JSON object to file
	acls_permissions_json = json.dumps( acls_permissions ) 		#convert to JSON
	acls_permissions_file = open( config['ACLS_PERMISSIONS_FILE'], 'w' )
	acls_permissions_file.write( acls_permissions_json )		#write to file in raw JSON
	acls_permissions_file.close()		

#debug
sys.stdout.write( '\n** INFO: GET ACLs: 								Done.\n' )

