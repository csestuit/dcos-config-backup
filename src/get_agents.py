#!/usr/bin/env python3
#
# get_agents.py: retrieve and save the agent state from a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get the agent state from a DC/OS cluster. Save to file and provide a list of
# the Total, Active and Inactive agents.

#reference:
#http://mesos.apache.org/documentation/latest/endpoints/master/slaves/

import sys
import os
import requests
import json
import helpers			#helper functions in separate module helpers.py
from time import sleep

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
config_file = os.getcwd()+'/.config.json'
config = helpers.get_config( config_file )				#returns config as a dictionary
if len( config ) == 0:
	sys.stdout.write( '** ERROR: Configuration not found. Please run ./run.sh first\n' )
	sys.exit(1)	

#Get list of AGENTS with their state from DC/OS. 
#This will be later used as index to get all user-to-group memberships
api_endpoint = '/mesos/slaves'
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
	sys.stdout.write( '** INFO: GET Agents: {0} \n'.format( request.status_code ) )
	sys.stdout.flush()
except requests.exceptions.HTTPError as error:
	print ('** ERROR: GET Agents: {} \n'.format( error ) ) 

#2xx HTTP status code is success
if str(request.status_code)[0] == '2':
	
	#save to AGENTS file
	agents_file = open( config['AGENTS_FILE'], 'w' )
	agents_file.write( request.text )			#write to file in same raw JSON as obtained from DC/OS
	agents_file.close()

	#Create a list of agents
	agents_dict = json.loads( request.text )
	agents_list = agents_dict['slaves']

	#Display Agents - Total
	print( "TOTAL agents: 				{0}".format( len( agents_list ) ) )
	print("="*42)
	#Display Agents - Active
	active_agents = [ agent for agent in agents_list if agent['active'] ]
	print( "ACTIVE agents: 				{0}".format( len( active_agents ) ) )
	print("="*42)
	for index, agent in ( enumerate( active_agents ) ):
		if agent['reserved_resources']: 
			agent_role="*Public*" 
		else: 
			agent_role="Private "#resources are first reserved for the node's main role
		print ( "{0} Agent #{1}: {2:48}".format( agent_role, index, agent['hostname'] ) )
	#Display Agents - Inactive
	inactive_agents = [ agent for agent in agents_list if not agent['active'] ]
	print("="*42)
	print("INACTIVE agents: 			{0}".format( len( inactive_agents ) ) )
	print("="*42)
	for index, agent in ( enumerate( inactive_agents ) ):
		print ( "Agent #{0}: {1}".format( index, agent['hostname'] ) )
	sleep(2)

else:
	print ('** ERROR: GET Agents: {} \n'.format( error ) ) 	

sys.stdout.write( '\n** INFO: GET Agents: 							Done. \n' )





