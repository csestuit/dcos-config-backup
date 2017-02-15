#!/usr/bin/env python3
#
# get_masters.py: retrieve the master state and general health report from a DC/OS cluster
#
# Receives a parameter as CLI argument (argv[1]) indicating the expected number of masters in the cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#

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

#check we've been called with a number of masters as a parameter
NUM_MASTERS=int(sys.argv[1])

#CHECK #1
#check from zookeeper the number of servers and leaders matches what is expected.
EXHIBITOR_STATUS_URL = 'http://'+config['DCOS_IP']+':8181/exhibitor/v1/cluster/status'
print('**INFO: Expected cluster size: {}'.format( NUM_MASTERS ))
#get the actual cluster size from zookeeper
try:
	response = requests.get(EXHIBITOR_STATUS_URL)
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print('**ERROR: Could not connect to exhibitor: {}'.format( error ))
	sys.exit(1)
if str(response.status_code)[0] != '2':
	print('**ERROR: Could not get exhibitor status: {}, Status code: {}'.format( EXHIBITOR_STATUS_URL, response.status_code ) )
	sys.exit(1)
data = response.json()
#parseable output
exhibitor_status={'exhibitor_status': data }
print("\n\n**OUTPUT:\n{0}".format( json.dumps(exhibitor_status) ))
#count the number of serving nodes and leaders
serving = 0
leaders = 0
for node in data:
	if node['isLeader']:
		leaders += 1
	if node['description'] == 'serving':
		serving += 1

if serving != NUM_MASTERS or leaders != 1:
		print('**ERROR: Expected {0} servers and 1 leader, got {1} servers and {2} leaders. Exiting.'.format( NUM_MASTERS, serving, leaders ) )
		sys.exit(1)
else:
		print('**INFO: server/leader check OK: {0} servers and {1} leader.'.format( serving, leaders ) )
sleep(2)

#CHECK #2
#https://docs.mesosphere.com/1.8/administration/installing/cloud/aws/upgrading/
#METRICS: "registrar" has the metric/registrar/log recovered with a value of 1
#http://<dcos_master_private_ip>:5050/metrics/snapshot
api_endpoint=':5050/metrics/snapshot'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN']
}
try:
	response = requests.get(
		url,
		headers=headers,
		)
	#show progress after request
	print( '**INFO: GET Metrics: {0} \n'.format( response.status_code ) )
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print ('**ERROR: GET Metrics: {} \n'.format( response.text ) )

if str(response.status_code)[0] == '2':	#2xx HTTP status code is success
	#parseable output
	data=response.json()
	metrics={'metrics': data }
	print("\n\n**OUTPUT:\n{0}".format(json.dumps(metrics)))

	#TODO: print relevant metrics and make sure that registrar/log/recovered is there and =1
	if 'registrar/log/recovered' in data:
		if data['registrar/log/recovered'] == 1.0:
			print('**INFO: Log Recovered check OK')
		else:
			print('**ERROR: Log NOT recovered. Value is {0}'.format( data['registrar/log/recovered'] ) )
	else:
		print('**ERROR: Registrar Log not found in response' )
else:
	print ('**ERROR: GET Health: {} \n'.format( response.text ) ) 	
sleep(2)

#CHECK #3
#Get health report of the system and make sure EVERYTHING is Healthy. 
#Display where it's Unhealthy otherwise.
api_endpoint = '/system/health/v1/report'
url = 'http://'+config['DCOS_IP']+api_endpoint
headers = {
	'Content-type': 'application/json',
	'Authorization': 'token='+config['TOKEN'],
}
try:
	response = requests.get(
		url,
		headers=headers,
		)
	#show progress after request
	print( '**INFO: GET Health Report: {0} \n'.format( response.status_code ) )
except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
	print ('**ERROR: GET Health Report: {} \n'.format( response.text ) ) 

if str(response.status_code)[0] == '2':	#2xx HTTP status code is success
	#parseable output
	data=response.json()
	health_report={'health_report': data}
	print("\n\n**OUTPUT:\n{0}".format( json.dumps( health_report ) ) )	
	#print relevant parameters from health
	for unit in data['Units']:
		print('Name: {0:48}			State: {1}'.format( \
			data['Units'][unit]['UnitName'], data['Units'][unit]['Health'] ) )
		if data['Units'][unit]['Health']: #not 0 means unhealthy, print all children
			for node in unit['Nodes']:
				print('Name: {0:48}			IP: {1}		State: {2}'.format( \
					data['Units:'][unit]['UnitName'], response_dict['Units'][unit][node]['IP'], \
					data['Units'][unit][node]['Health'] ) )
else:
	print ('**ERROR: GET Health: {} \n'.format( response.text ) ) 	


sys.stdout.write( '\n** INFO: GET Masters: 							Done. \n' )





