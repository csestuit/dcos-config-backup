#!/bin/bash

# run.sh: interactively receive and store the configuration for backup/restore
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# This set of scripts allows to backup and restore several configurations from
# a running DC/OS Cluster. It uses the DC/OS REST API as Documented here:
# https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/
#
# A $PWD/DATA directory is created to store all information backed up from the cluster
# All files in this DATA directory are encoded in raw JSON. The restore scripts read
# these files, extract the relevant fields and post them back to the clister

# This first "run.sh" script initializes the cluster, interactively reads the 
# configuration and saves it in JSON format to a fixed, well known location in $PWD
# hidden  under .config.json

#Default values
DCOS_IP=127.0.0.1
USERNAME=bootstrapuser
PASSWORD=deleteme
DEFAULT_USER_PASSWORD=deleteme
DEFAULT_USER_SECRET=secret
WORKING_DIR=$PWD
DATA_DIR=$WORKING_DIR"/DATA"
#config file is stored hidden in current directory, fixed location
CONFIG_FILE=$PWD"/.config.json"
#not exposed but saved
USERS_FILE=$DATA_DIR/users.json
GROUPS_FILE=$DATA_DIR/groups.json
GROUPS_USERS_FILE=$DATA_DIR/groups_users.json
ACLS_FILE=$DATA_DIR/acls.json
ACLS_PERMISSIONS_FILE=$DATA_DIR/acls_permissions.json
ACLS_PERMISSIONS_ACTIONS_FILE=$DATA_DIR/acls_permissions_actions.json


#install dependencies
#TODO: add OS detection - this would work on YUM based systems only
if [ ! $( yum list installed $JQ >/dev/null 2>&1; ) ] then 

	read -p "** JQ is not available but it's required, would you like to install it? (y/n)" REPLY
	case $REPLY in
		[yY]) echo ""
					echo "** Installing EPEL-release (required for JQ)"
					sudo yum install -y epel-release 
					echo "** Installing JQ"	  
					sudo yum install -y jq
					;;
		[nN]) echo "**" $JQ "is required. Exiting."
					exit 1
					;;

	esac

fi

#read configuration if it exists
#config is stored directly on JSON format
if [ -f $CONFIG_FILE ]; then

	DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
	USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
	PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
	DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
	DEFAULT_USER_SECRET=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_SECRET')
	WORKING_DIR=$(cat $CONFIG_FILE | jq -r '.WORKING_DIR')
	CONFIG_FILE=$(cat $CONFIG_FILE | jq -r '.CONFIG_FILE')
	USERS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_FILE')
	GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
	ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
	ACLS_PERMISSIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE')
	ACLS_PERMISSIONS_ACTIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_ACTIONS_FILE')

fi

while true; do

	echo ""
	echo "** Current parameters:"
	echo ""
	echo "*************************                 ****************"
	echo "1) DC/OS IP or DNS name:                  "$DCOS_IP
	echo "*************************                 ****************"
	echo "2) DC/OS username:                        "$USERNAME
	echo "3) DC/OS password:                        "$PASSWORD
	echo "4) Default password for restored users:   "$DEFAULT_USER_PASSWORD
	echo "5) Default secret for restored users:     "$DEFAULT_USER_SECRET
	echo "6) Base working dir:                      "$WORKING_DIR
	echo "[INFO] Data dir in working dir (fixed):   "$DATA_DIR

	echo ""
	
	read -p "** Are these parameters correct?: (y/n): " REPLY

		case $REPLY in
			
		[yY]) echo ""
					echo "** Proceeding."
					break
					;;
			
		[nN]) read -p "** Enter number of parameter to modify [1-6]: " PARAMETER

					case $PARAMETER in

						[1]) read -p "Enter new value for DC/OS IP or DNS name: " DCOS_IP
						;;
						[2]) read -p "Enter new value for DC/OS username: " USERNAME
						;;
						[3]) read -p "Enter new value for DC/OS password: " PASSWORD
						;;
						[4]) read -p "Enter new value for Default Password for restored users: " DEFAULT_USER_PASSWORD
						;;
						[5]) read -p "Enter new value for Default Secret for restored users: " DEFAULT_USER_SECRET
						;; 
						[6]) read -p "Enter new value for Base Working Dir: " WORKING_DIR
						;;     			
						*) echo "** Invalid input. Please choose an option [1-6]"
						;;

					esac
					;;
		*) echo "** Invalid input. Please choose [y] or [n]"
		;;
	
	esac

done

#get token from cluster
TOKEN=$( curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST \
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token' )

#create working dir
mkdir -p $WORKING_DIR

#save configuration to config file in working dir
CONFIG="\
{ \
"\"DCOS_IP"\": "\"$DCOS_IP"\",   \
"\"USERNAME"\": "\"$USERNAME"\", \
"\"PASSWORD"\": "\"$PASSWORD"\", \
"\"DEFAULT_USER_PASSWORD"\": "\"$DEFAULT_USER_PASSWORD"\", \
"\"DEFAULT_USER_SECRET"\": "\"$DEFAULT_USER_SECRET"\", \
"\"WORKING_DIR"\": "\"$WORKING_DIR"\", \
"\"CONFIG_FILE"\": "\"$CONFIG_FILE"\",  \
"\"USERS_FILE"\": "\"$USERS_FILE"\",  \
"\"GROUPS_FILE"\": "\"$GROUPS_FILE"\",  \
"\"ACLS_FILE"\": "\"$ACLS_FILE"\",  \
"\"ACLS_PERMISSIONS_FILE"\": "\"$ACLS_PERMISSIONS_FILE"\",  \
"\"ACLS_PERMISSIONS_ACTIONS_FILE"\": "\"$ACLS_PERMISSIONS_ACTIONS_FILE"\",  \
"\"TOKEN"\": "\"$TOKEN"\"  \
} \
"

#save config to file for future use
echo $CONFIG > $CONFIG_FILE
echo "** Current configuration: "
cat $CONFIG_FILE | jq

#DEBUG: export them all for CLI debug
echo "** Exporting env variables"
export DCOS_IP=$DCOS_IP
export USERNAME=$USERNAME
export PASSWORD=$PASSWORD
export DEFAULT_USER_SECRET=$DEFAULT_USER_SECRET
export DEFAULT_USER_PASSWORD=$DEFAULT_USER_PASSWORD
export WORKING_DIR=$WORKING_DIR
export CONFIG_FILE=$CONFIG_FILE
export USERS_FILE=$USERS_FILE
export GROUPS_FILE=$GROUPS_FILE
export ACLS_FILE=$ACLS_FILE
export ACLS_PERMISSIONS_FILE=$ACLS_PERMISSIONS_FILE
export ACLS_PERMISSIONS_ACTIONS_FILE=$ACLS_PERMISSIONS_ACTIONS_FILE
export TOKEN=$TOKEN


echo "** Ready."
