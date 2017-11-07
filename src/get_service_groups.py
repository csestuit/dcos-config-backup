#!/usr/bin/env python3
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
#Regular Marathon: "Services" tab
#################################

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
		verify=False
		)
	request.raise_for_status()
	sys.stdout.write( '** INFO: GET Service Groups: {:>20} \r'.format( request.status_code ) ) 
	sys.stdout.flush()
except (
	requests.exceptions.ConnectionError ,\
	requests.exceptions.Timeout ,\
	requests.exceptions.TooManyRedirects ,\
	requests.exceptions.RequestException ,\
	ConnectionRefusedError
	) as error:
	print ('**ERROR: GET Service Groups failed with: {}'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':

	service_groups = request.text	#raw text form requests, in JSON from DC/OS
	service_groups_json = json.loads( service_groups )

	#save to SERVICE_GROUPS file
	service_groups_file = open( config['SERVICE_GROUPS_FILE'], 'w' )
	service_groups_file.write( json.dumps( service_groups_json ) )			#write to file in same raw JSON as obtained from DC/OS
	service_groups_file.close()					

	#change the list of service groups loaded from file (or DC/OS) to JSON dictionary
	helpers.walk_and_print( service_groups_json, 'Service Group', 'groups' )

else:
	print('**ERROR: GET Service Groups failed with: {}'.format( request.text ) ) 

#Marathon-on-Marathon and Apps
##############################

#get all apps from DC/OS
api_endpoint = '/marathon/v2/apps'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN'],
}
try:
	request = requests.get(
		url,
		headers=headers,
		verify=False
		)
	request.raise_for_status()
	sys.stdout.write( '** INFO: GET Apps: {:>20} \r'.format( request.status_code ) ) 
	sys.stdout.flush()
except (
	requests.exceptions.ConnectionError ,\
	requests.exceptions.Timeout ,\
	requests.exceptions.TooManyRedirects ,\
	requests.exceptions.RequestException ,\
	ConnectionRefusedError
	) as error:
	print ('**ERROR: GET Apps failed with: {}\n'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':

	#save all apps from DC/OS
	apps_file = open( config['APPS_FILE'], 'w' )
	apps_file.write( request.text )
	apps_file.close()	

	marathons = {'marathons':[]}	#marathons: list of MoM instances 
	apps_store = {'apps':[]}		#apps_store: list of all apps 
	apps = request.text				#raw text form requests, in JSON from DC/OS
	apps_dict = json.loads( apps )
	for index,app in enumerate( apps_dict['apps'] ):
		apps_store['apps'].append( app )   
		if 'DCOS_PACKAGE_NAME' in app['labels']:
			if app['labels']['DCOS_PACKAGE_NAME']=='marathon':
				marathons['marathons'].append( app )

	#Get the group of each marathon
	api_endpoint = '/v2/groups'		#to form /service/$SERVICE_NAME/v2/groups
	api_endpoint_apps = '/v2/apps'	#to form /service/$SERVICE_NAME/v2/apps
	mom_groups = {'mom_groups':[]}	#A list of all MoM instances, each with its service groups
	mom_apps = {'mom_apps':[]} 			#A list of all MoM instances, each with its apps.

	#Go through the marathons, connect to them and repeat the above
	for marathon in marathons['marathons']:
		#get their service name
		service_name = marathon['labels']['DCOS_SERVICE_NAME']

		#Get the *****GROUPS***** for that MoM instance
		url='http://'+config['DCOS_IP']+'/service/'+service_name+api_endpoint
		#connect to that MoM instance
		headers = {
			'Content-type': 'application/json',
			'Authorization': 'token='+config['TOKEN'],
		}
		try:
			response = requests.get(
				url,
				headers=headers,
				verify=False
				)
			request.raise_for_status()
			sys.stdout.write( '** INFO: GET MoM Service Groups: {:>20} \r'.format( request.status_code ) ) 
			sys.stdout.flush()
		except (
			requests.exceptions.ConnectionError ,\
			requests.exceptions.Timeout ,\
			requests.exceptions.TooManyRedirects ,\
			requests.exceptions.RequestException ,\
			ConnectionRefusedError
			) as error:
			print ('**ERROR: GET MoM Service Groups failed with: {}'.format( error ) ) 

		if str(response.status_code)[0] == '2':

			service_groups = response.text	#raw text form requests, in JSON from DC/OS
			service_groups_json = json.loads( service_groups )
			#create a new entry for this MoM instances holding its name, definition and groups.
			entry = { 'DCOS_SERVICE_NAME': service_name,
					'app' : marathon,        #save the entire JSON so that we can post it later easily
											#'App' is saved as received -- upon posting, the offending fields are removed
					'groups': service_groups_json
					}
			mom_groups['mom_groups'].append( entry )

		else:
			print('**ERROR: GET MoM Service Groups failed with: {}'.format( response.text ) ) 

		#Get the *****APPS***** of that MoM instance
		url='http://'+config['DCOS_IP']+'/service/'+service_name+api_endpoint_apps
		#connect to that MoM instance
		headers = {
			'Content-type': 'application/json',
			'Authorization': 'token='+config['TOKEN'],
		}
		try:
			response = requests.get(
				url,
				headers=headers,
				verify=False
				)
			request.raise_for_status()
			sys.stdout.write( '** INFO: GET MoM Apps: {:>20} \r'.format( request.status_code ) ) 
			sys.stdout.flush()
		except (
			requests.exceptions.ConnectionError ,\
			requests.exceptions.Timeout ,\
			requests.exceptions.TooManyRedirects ,\
			requests.exceptions.RequestException ,\
			ConnectionRefusedError
			) as error:
			print ('**ERROR: GET MoM Apps failed with: {}'.format( error ) ) 

		if str(response.status_code)[0] == '2':

			running_mom_apps = response.text	#raw text form requests, in JSON from DC/OS:
			running_mom_apps_json = json.loads( running_mom_apps )
			#create a new entry for this MoM instances holding its name, definition and Apps.
			entry = { 'DCOS_SERVICE_NAME': service_name,
					'app' : marathon,        #save the entire JSON so that we can post it later easily
											#'App' is saved as received -- upon posting, the offending fields are removed
					'apps': running_mom_apps_json
					}
			mom_apps['mom_apps'].append( entry )
		else:
			print('**ERROR: GET MoM Apps failed with: {}'.format( response.text ) ) 

	#save to SERVICE_GROUPS_MOM file
	service_groups_file = open( config['SERVICE_GROUPS_MOM_FILE'], 'w' ) 		#append
	service_groups_file.write( json.dumps( mom_groups ) )			#write to file in same raw JSON as obtained from DC/OS
	service_groups_file.close()

	#save to APPS_MOM file
	apps_mom_file = open( config['APPS_MOM_FILE'], 'w' )
	apps_mom_file.write( json.dumps ( mom_apps ) )
	apps_mom_file.close()					

	#If there are any groups, walk them
	for service_group in mom_groups['mom_groups']:
		helpers.walk_and_print( service_group['groups'], 'Service Group '+service_name, 'groups' )

	#TODO: could also print the apps, but the walk_and_print function needs review
	#for app in mom_apps['apps']:
	#	helpers.walk_and_print( app, 'App '+service_name, 'apps' )

else:
	print('**ERROR: GET Apps failed with: {}'.format( request.text ) ) 

sys.stdout.write( '\n** INFO: GET Service Groups:							Done.\n' )

