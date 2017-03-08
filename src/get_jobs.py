#!/usr/bin/env python3
#
# get_jobs.py: retrieve and save configured Metronome jobs on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of jobs configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_jobs" script.

#reference:
#https://dcos.github.io/metronome/docs/generated/api.html

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

#Get list of JOBS from DC/OS. 
api_endpoint = '/metronome/v1/jobs'
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
	sys.stdout.write( '** INFO: GET Jobs: {0} \r'.format( request.status_code ) )
	sys.stdout.flush()
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print ('** ERROR: GET Jobs: {} \n'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':
	
	jobs = request.text				#raw text form requests, comes in JSON form from DC/OS

	#save to USERS file
	jobs_file = open( config['JOBS_FILE'], 'w' )
	jobs_file.write( jobs )			#write to file in same raw JSON as obtained from DC/OS
	jobs_file.close()					

	#Load list of USERS from the USERS file, loop through them, 
	#get for each user its memberships from the DC/OS cluster
	# and store all users and their memberships in a dictionary blob. 

	#create a dictionary object that will hold all user-to-group memberships
	users_groups = { 'array' : [] }

	#change the list of users loaded from file (or DC/OS) to JSON dictionary
	users_json = json.loads( users )
	#done.

sys.stdout.write( '\n** INFO: GET Jobs: 							Done. \n' )





