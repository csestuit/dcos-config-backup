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

def escape ( a_string ) :
	"""
	Escape characters that create issues for URLs
	"""
	escaped = a_string.replace("/", "%252F")

	return escaped

def walk_and_print( item, name ):
	"""
	Walks a recursive tree-like structure for items printing them.
	Structure is assumed to have children under 'groups' and name under 'id'
	Receives the tree item and an 'id' as a name to identify each node.
	"""
	if item['groups']:
		for i in item['groups']:
			walk_and_print( i, name )
	else:
		print( "{0}: {1}".format( name, item['id'] ) )

	return True

def remove_apps_from_service_group( service_group ):
	"""
	Walks a (potentially recursive tree-like structure of) service group in a dict that potentially include apps.
	Removes all apps from the definition. Returns the same dictionary without the apps.
	"""

	for index,group in enumerate( service_group['groups'] ):
		if isinstance( group, list):
			remove_apps_from_service_group( group )
	else:
		print("\n\n**DEBUG: I'm about to remove apps from : \n {0}".format(service_group))
		#service_group['apps'] = []
		del service_group['apps']
		print("\n\n**DEBUG: There you go, this guy has no apps : \n {0}".format(service_group))
		return service_group

	
