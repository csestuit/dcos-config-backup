#!/usr/bin/env python3
#
# post_jobs.py: load from file and restore Metronome jobs to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of jobs to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_jobs" script.

#reference:
#https://dcos.github.io/metronome/docs/generated/api.html

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

#check that there's a JOBS file created (buffer loaded)
if not ( os.path.isfile( config['JOBS_FILE'] ) ):
  sys.stdout.write('** ERROR: Buffer is empty. Please LOAD or GET Jobs before POSTing them.')
  sys.exit(1)

#open the Jobs file and load the LIST of Jobs from JSON
jobs_file = open( config['JOBS_FILE'], 'r' )
#load entire text file and convert to JSON - dictionary
jobs = json.loads( jobs_file.read() )
jobs_file.close()

#loop through the list of users and
#PUT /users/{uid}
for index, job in ( enumerate( jobs['array'] ) ): 

  id = job['id']

  #build the request
  api_endpoint = '/metronome/v1/jobs/'+id
  url = 'http://'+config['DCOS_IP']+api_endpoint
  headers = {
  'Content-type': 'application/json',
  'Authorization': 'token='+config['TOKEN'],
  }
  data = job
  #send the request to PUT the new USER
  try:
    request = requests.put(
      url,
      headers = headers,
      data = json.dumps( data )
    )
    request.raise_for_status()
    #show progress after request
    sys.stdout.write( '** INFO: PUT Job: {} : {:>20} \r'.format( index, request.status_code ) )
    sys.stdout.flush() 
  except (
    requests.exceptions.ConnectionError ,\
    requests.exceptions.Timeout ,\
    requests.exceptions.TooManyRedirects ,\
    requests.exceptions.RequestException ,\
    ConnectionRefusedError
    ) as error:
    print ('** ERROR: PUT Job: {}: {}'.format( id, error ) ) 


sys.stdout.write('\n** INFO: PUT Jobs:                         Done.\n')
