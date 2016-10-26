#!/usr/bin/env python
#
# helpers.py: helper functions for other processes in the project to use
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Set of functions repeatedly used in other parts of this project. 
# Put on a separate module for clarity and readability.

import os
import json

# FUNCTION get_conf
def get_config ( config_path ) :
	"""
	Get the full program configuration from the file and returns a dictionary with 
	all its parameters. Program configuration is stored in raw JSON so we just need
	to load it and use standard `json` to parse it into a dictionary.
	"""

	config_file = open( config_path, 'r' )  	#open the config file for reading
	read_config = config_file.read()			#read the entire file into a dict with JSON format
	config_file.close()
	config = json.loads( read_config )			#parse read config as JSON into readable dictionary

	return config


