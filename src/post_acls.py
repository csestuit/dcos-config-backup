#!/usr/bin/env python3
#
# post_acls.py: load from file and restore ACLs to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of ACLs to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_acls.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action


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
if not ( os.path.isfile( config['ACLS_FILE'] ) ):
	sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET ACLs before POSTing them.')
	sys.exit(1)

#open the ACLS file and load the LIST of ACLs from JSON
acls_file = open( config['ACLS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
acls = json.loads( acls_file.read() )
acls_file.close()

#loop through the list of ACL Rules and create the ACLS in the system
#PUT /acls/{rid}
for index, acl in ( enumerate( acls['array'] ) ): 

	rid = helpers.escape( acl['rid'] )
	#build the request
	api_endpoint = '/acs/api/v1/acls/'+rid
	url = 'http://'+config['DCOS_IP']+api_endpoint
	headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN'],
	}
	data = {
	'description': acl['description'],
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
		sys.stdout.write( '** INFO: PUT ACL: {} : {}: {:>20} \r'.format( index, rid, request.status_code ) ) 
		sys.stdout.flush()
	except requests.exceptions.HTTPError as error:
		print ('** ERROR: PUT ACL: {}: {}'.format( rid, error ) ) 


#loop through the list of ACL permission rules and create the ACLS in the system
#/acls/{rid}/groups/{gid}/{action}
#/acls/{rid}/users/{uid}/{action}

#check that there's a ACLS_PERMISSIONS file created (buffer loaded)
if not ( os.path.isfile( config['ACLS_PERMISSIONS_FILE'] ) ):
	sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET ACL-Permission information before POSTing it.')
	sys.exit(1)

#open the ACLS file and load the LIST of acls from JSON
acls_permissions_file = open( config['ACLS_PERMISSIONS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
acls_permissions = json.loads( acls_permissions_file.read() )
acls_permissions_file.close()

for index, acl_permission in ( enumerate( acls_permissions['array'] ) ): 
	
	if 'rid' in acl_permission:
		rid = helpers.escape( acl_permission['rid']	)

		#test if this acl_permission has users
		if 'users' in acl_permission:
			#array of users for this acl_permission
			for index2, user in ( enumerate( acl_permission['users'] ) ): 
			#PUT  /acls/{rid}/users/{uid}/{action}
				if 'uid' in user:
					uid = user['uid']
					#array of actions for this user_acl_permission
					for index3, action in ( enumerate( user['actions'] ) ): 

						if 'name' in action:
							name = action['name']
							#build the request
							api_endpoint = '/acs/api/v1/acls/'+helpers.escape( rid )+'/users/'+uid+'/'+name
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
								sys.stdout.write( '** INFO: PUT Action: {} : {} User: {} ACL: {} : {:>20} \r'.format(index2,  name, uid, rid, request.status_code ) ) 
								sys.stdout.flush()
							except requests.exceptions.HTTPError as error:
								print ('** ERROR: PUT Action: {} : {} User: {} ACL: {} : {}\n'.format( index2, name, uid, rid, error ) ) 

	if 'groups' in acl_permission:
		#array of groups for this acl_permission
		for index2, group in ( enumerate( acl_permission['groups'] ) ): 
		#PUT  /acls/{rid}/groups/{gid}/{action}
			if 'gid' in group:
				gid = helpers.escape( group['gid'] )
				#array of actions for this group_acl_permission
				for index3, action in ( enumerate( group['actions'] ) ): 

					if 'name' in action:
						name = helpers.escape( action['name'] )
						#build the request
						api_endpoint = '/acs/api/v1/acls/'+helpers.escape( rid )+'/groups/'+gid+'/'+name
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
							sys.stdout.write( '** INFO: PUT Action: {} : {} Group: {} ACL: {} : {:>20} \r'.format( index2, name, gid, rid, request.status_code ) )
							sys.stdout.flush() 
						except requests.exceptions.HTTPError as error:
							print ('** ERROR: PUT Action: {} : {} Group: {} ACL: {} : {}\n'.format( index2, name, gid, rid, error ) ) 
	
sys.stdout.write('\n** INFO: PUT ACLs: 							Done.\n')


