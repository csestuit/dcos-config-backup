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

#load environment variables
source ./env.sh

function load_configuration {
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

else
	echo "ERROR: Configuration not found."
fi
}

#install dependencies

JQ="jq"

if [ ! $JQ ]; then 

	read -p "** JQ is not available but it's required. Please install $JQ for your system, then re-run this application"
	exit 1

fi

load_configuration

while true; do
	$CLS
	echo -e ""
	echo -e "** Current parameters:"
	echo -e ""
	echo -e "*************************                 ****************"
	echo -e "1) DC/OS IP or DNS name:                  "${RED}$DCOS_IP${NC}
	echo -e "*************************                 ****************"
	echo -e "2) DC/OS username:                        "${RED}$USERNAME${NC}
	echo -e "3) DC/OS password:                        "${RED}$PASSWORD${NC}
	echo -e "4) Default password for restored users:   "${RED}$DEFAULT_USER_PASSWORD${NC}
	echo -e ""
	echo -e "Information is stored in:		"${RED}$DATA_DIR${NC}

	echo ""
	
	read -p "** Are these parameters correct?: (y/n): " REPLY

		case $REPLY in
			
			[yY]) echo ""
				echo "** Proceeding."
				break
				;;
			
			[nN]) read -p "** Enter number of parameter to modify [1-4]: " PARAMETER

				case $PARAMETER in

					[1]) read -p "Enter new value for DC/OS IP or DNS name: " DCOS_IP
					;;
					[2]) read -p "Enter new value for DC/OS username: " USERNAME
					;;
					[3]) read -p "Enter new value for DC/OS password: " PASSWORD
					;;
					*) read -p "** Invalid input. Please choose an option [1-4]"
					;;

				esac
				;;
			*) read -p "** Invalid input. Please choose [y] or [n]"
			read -p "Press ENTER to continue"
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
"\"GROUPS_USERS_FILE"\": "\"$GROUPS_USERS_FILE"\",  \
"\"ACLS_FILE"\": "\"$ACLS_FILE"\",  \
"\"ACLS_PERMISSIONS_FILE"\": "\"$ACLS_PERMISSIONS_FILE"\",  \
"\"ACLS_PERMISSIONS_ACTIONS_FILE"\": "\"$ACLS_PERMISSIONS_ACTIONS_FILE"\",  \
"\"TOKEN"\": "\"$TOKEN"\"  \
} \
"

#save config to file for future use
echo $CONFIG > $CONFIG_FILE
echo "** DEBUG: Current configuration: "
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
export GROUPS_USERS_FILE=$GROUPS_USERS_FILE
export ACLS_FILE=$ACLS_FILE
export ACLS_PERMISSIONS_FILE=$ACLS_PERMISSIONS_FILE
export ACLS_PERMISSIONS_ACTIONS_FILE=$ACLS_PERMISSIONS_ACTIONS_FILE
export TOKEN=$TOKEN

read -p "Press ENTER to continue"

while true; do
	$CLS
	echo -e ""
	echo -e "** DC/OS Config Backup and Restore Utility:"
	echo -e "*****************************************************************"
	echo -e "** Operations to retrieve configuration from a running cluster:"
	echo -e "**"
	echo -e "1) Get users from DC/OS to buffer:                  		"$GET_USERS_OK
	echo -e "2) Get groups from DC/OS to buffer:	                        "$GET_GROUPS_OK
	echo -e "3) Get ACLs from DC/OS to buffer:				"$GET_ACLS_OK
	echo -e "4) Get ACL Permissions from DC/OS to buffer:   			"$GET_ACLS_PERMISSIONS_OK
	echo -e "5) Get ACL Permission Actions from DC/OS to buffer:		"$GET_ACLS_PERMISSIONS_ACTIONS_OK
	echo -e "*****************************************************************"
	echo -e "** Operations to restore backed up configuration to a running cluster:"
	echo -e "**"
	echo -e "6) Restore users to DC/OS from buffer:                  	"$POST_USERS_OK
	echo -e "7) Restore groups to DC/OS from buffer:	                    	"$POST_GROUPS_OK
	echo -e "8) Restore ACLs to DC/OS from buffer:	                        "$POST_ACLS_OK
	echo -e "9) Restore ACL Permissions to DC/OS from buffer:   		"$POST_ACLS_PERMISSIONS_OK
	echo -e "10) Restore ACL Permission Actions to DC/OS from buffer:     	"$POST_ACLS_PERMISSIONS_ACTIONS_OK
	echo -e "*****************************************************************"
	echo -e "** Operations to check out currently buffered configuration:"
	echo -e "**"
	echo -e "u) Check users currently in buffer.                  		"
	echo -e "g) Check groups currently in buffer.	                    	"
	echo -e "a) Check ACLs currently in buffer.	                        "
	echo -e "p) Check ACL Permissions currently in buffer.   			"
	echo -e "c) Check ACL Permission Actions currently in buffer.     	"
	echo -e ""
	echo -e "*****************************************************************"
	echo -e "** Operations to save/load configurations to/from disk:"
	echo -e "**"
	echo -e "d) List configurations currently available on disk "
	echo -e "s) Save current buffer status to disk                  		"
	echo -e "l) Load a configurtion from disk                  	"
	echo -e "*****************************************************************"
	echo -e "** DEBUG operations:"
	echo -e "**"
	echo -e "z) Restore EXAMPLE configuration for test.              		"
	echo -e "${RED}X${NC}) Exit this application"
	echo ""
	
	read -p "** Enter command: " PARAMETER

		case $PARAMETER in

			[1]) read -rp "About to back up the list of Users in cluster [ "$DCOS_IP" ] to [ "$USERS_FILE" ] . Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_USERS
						read -p "Press ENTER to continue..."
						GET_USERS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancel."
						sleep 1
						;;
					*) read -p "** Invalid input. Please choose [y] or [n]"
						;;
				esac
			;;	
			[2]) read -p "About to back up the list of Groups in cluster [ "$DCOS_IP" ] to [ "$GROUPS_FILE" ] and Memberships to "\
$GROUPS_USERS_FILE" . Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_GROUPS
						read -p "Press ENTER to continue..."
						GET_GROUPS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancel."
						sleep 1
						;;
					*) read -p "** Invalid input. Please choose [y] or [n]"
						;;

				esac
			;;	
			[3]) read -p "About to back up the list of ACLs in cluster [ "$DCOS_IP" ] to [ "$ACLS_FILE" ] . Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_USERS
						read -p "Press ENTER to continue..."
						GET_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancel."
						sleep 1
						;;
					*) read -p "** Invalid input. Please choose [y] or [n]"
						;;
				esac
			;;	
			[4]) read -p "TBD"
			;;
			[5]) read -p "TBD"
			;; 
			[6]) read -p "TBD"
			;;
			[7]) read -p "TBD"
			;;
			[8]) read -p "TBD"
			;;
			[9]) read -p "TBD"
			;;
			[10]) read -p "TBD"
			;;
			[uU]) echo -e "Stored User information on file [ "$USERS_FILE" ] is:"
				cat $USERS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[gG]) echo -e "Stored Group information on file [ "$GROUPS_FILE" ] is:"
				cat $GROUPS_FILE | jq '.array'
				echo -e "Stored Group user membership information on file [ "$GROUPS_USERS_FILE" ] is:"
				cat $GROUPS_USERS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[aA]) echo -e "Stored ACL information on file [ "$ACLS_FILE" ] is:"
				cat $ACLS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[pP]) echo -e "Stored ACL Permission information on file [ "$ACLS_PERMISSIONS_FILE" ] is:"
				cat $ACLS_PERMISSIONS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[cC]) echo -e "Stored ACL Permission Action information on file [ "$ACLS_PERMISSIONS_ACTIONS_FILE" ] is:"
				cat $ACLS_PERMISSIONS_ACTIONS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[dD]) echo -e "Currently available configurations:"
				ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}' 
				read -p "Press ENTER to continue"
			;;
			[sS]) read -p "Please enter a name to save under (NOTE: If that name exists, it will be OVERWRITTEN): "ID
				#TODO: check if it exists and fail if it does
				mkdir -p $BACKUP_DIR/$ID/
				cp $USERS_FILE $BACKUP_DIR/$ID/
				cp $GROUPS_FILE $BACKUP_DIR/$ID/				
				cp $GROUPS_USERS_FILE $BACKUP_DIR/$ID/	
				cp $ACLS_FILE $BACKUP_DIR/$ID/	
				cp $ACLS_PERMISSIONS_FILE $BACKUP_DIR/$ID/	
				cp $ACLS_PERMISSIONS_ACTIONS_FILE $BACKUP_DIR/$ID/
				cp $CONFIG_FILE $BACKUP_DIR/$ID/				
				read -p "Press ENTER to continue"
			;;
			[lL]) ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
				read -p "Please enter the name of a saved buffered to load. NOTE: Currently running buffer will be overwritten. " ID
				#TODO: check that it actually exists
				cp $BACKUP_DIR/$ID/$USERS_FILE $USERS_FILE
				cp $BACKUP_DIR/$ID/$GROUPS_FILE $GROUPS_FILE				
				cp $BACKUP_DIR/$ID/$GROUPS_USERS_FILE	$GROUPS_USERS_FILE 
				cp $BACKUP_DIR/$ID/$ACLS_FILE $ACLS_FILE 
				cp $BACKUP_DIR/$ID/$ACLS_PERMISSIONS_FILE $ACLS_PERMISSIONS_FILE
				cp $BACKUP_DIR/$ID/$ACLS_PERMISSIONS_ACTIONS_FILE $ACLS_PERMISSIONS_ACTIONS_FILE
				load_configuration
			;;

			[xX]) read -p "About to restore the example configuration stored in [ "$EXAMPLE_CONFIG" ] Press ENTER to proceed. "
				cp $EXAMPLE_CONFIG/$USERS_FILE $USERS_FILE
				cp $EXAMPLE_CONFIG/$GROUPS_FILE $GROUPS_FILE				
				cp $EXAMPLE_CONFIG/$GROUPS_USERS_FILE	$GROUPS_USERS_FILE 
				cp $EXAMPLE_CONFIG/$ACLS_FILE $ACLS_FILE 
				cp $EXAMPLE_CONFIG/$ACLS_PERMISSIONS_FILE $ACLS_PERMISSIONS_FILE
				cp $EXAMPLE_CONFIG/$ACLS_PERMISSIONS_ACTIONS_FILE $ACLS_PERMISSIONS_ACTIONS_FILE
				load_configuration

				exit 0
			;;					          			
			[xX]) echo -e "${BLUE}Goodbye.${NC}"
				exit 0
			;;
			*) echo "** Invalid input. Please choose a valid option"
			;;

		esac


done
echo "** Ready."
