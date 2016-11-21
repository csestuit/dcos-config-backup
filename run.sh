#!/bin/bash

# run.sh: get or post IAM configuration from a DC/OS cluster
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

set -o errexit -o nounset -o pipefail

#load environment variables
source ./env.sh

##################################################################################
# helper functions
##################################################################################

function print_help {
#print help/usage message
echo 'usage: ./run.sh [option] [DCOS_IP] [configuration_name]'
echo 'options:'
echo '-g, --get   Gets a full configuration from the DC/OS cluster running in "DCOS_IP", and saves it under "configuration_name"'
echo '-p, --post  Loads a full configuration stored under "configuration_name" and posts it to the DC/OS cluster running in "DCOS_IP"'
}

function get_token {
#get token from cluster
TOKEN=$( curl \
-s \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST \
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token' )
echo -e "** INFO: DC/OS token obtained: "$TOKEN
}

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
	USERS_GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_GROUPS_FILE')
	GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
	GROUPS_USERS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_USERS_FILE')
	ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
	ACLS_PERMISSIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE')

else
	$CLS
	echo -e "** ${BLUE}WARNING${NC}: Configuration not found. "
	echo -e "** This is normal if this is the first time this program is run in this system."
	echo -e "** Generating a new configuration."
	read -p "** Press ENTER to continue."
fi
}

function show_configuration {
#show the currently running configuration
#TODO: reformat
	echo "** DEBUG: Current configuration: "
	cat $CONFIG_FILE | jq
}

function delete_local_buffer {
#erase the current local buffer to start clean
	echo "** Erasing local buffer ..."
	if [ "$(ls -A $DATA_DIR)" ]; then
		rm $DATA_DIR/*
	fi
}

function save_configuration {
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
"\"USERS_GROUPS_FILE"\": "\"$USERS_GROUPS_FILE"\",  \
"\"GROUPS_FILE"\": "\"$GROUPS_FILE"\",  \
"\"GROUPS_USERS_FILE"\": "\"$GROUPS_USERS_FILE"\",  \
"\"ACLS_FILE"\": "\"$ACLS_FILE"\",  \
"\"ACLS_PERMISSIONS_FILE"\": "\"$ACLS_PERMISSIONS_FILE"\",  \
"\"TOKEN"\": "\"$TOKEN"\"  \
} \
"
#save config to file for future use
echo $CONFIG > $CONFIG_FILE
show_configuration
}

function delete_local_buffer {
#erase the current local buffer to start clean
	echo "** Erasing local buffer ..."
	if [ "$(ls -A $DATA_DIR)" ]; then
		rm $DATA_DIR/*
	fi
}

function list_iam_configurations {
#list the configurations currenctly available on disk
	echo -e "** Configurations currently available on disk:"
	echo -e "${BLUE}"
	ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
	echo -e "${NC}"
}

function save_iam_configuration(){
#save the configuration received from cluster to disk
#receives the name to save under as first parameter

	if [ -z "$1" ]; then
		echo "** ERROR: save_iam_configuration: no parameter received"
		return 1
	else
		ID="$1"
		#TODO: check if it exists and fail if it does
		mkdir -p $BACKUP_DIR/$ID/
		cp $USERS_FILE $BACKUP_DIR/$ID/
		cp $USERS_GROUPS_FILE $BACKUP_DIR/$ID/
		cp $GROUPS_FILE $BACKUP_DIR/$ID/
		cp $GROUPS_USERS_FILE $BACKUP_DIR/$ID/
		cp $ACLS_FILE $BACKUP_DIR/$ID/
		cp $ACLS_PERMISSIONS_FILE $BACKUP_DIR/$ID/
		cp $CONFIG_FILE $BACKUP_DIR/$ID/
		echo -e "** Configuration saved to disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
		return 0
	fi

}

function load_iam_configuration(){
	#load from disk a configuration saved previously
	#receives the name of config to load as first parameter
	#TODO: check that it actually exists

	if [ -z "$1" ]; then
		echo  "** ERROR: load_iam_configuration: no parameter received"
		return 1
	else
		ID="$1"
		cp $BACKUP_DIR/$ID/$( basename $USERS_FILE )  $USERS_FILE
		cp $BACKUP_DIR/$ID/$( basename $USERS_GROUPS_FILE ) $USERS_GROUPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $GROUPS_FILE ) $GROUPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $GROUPS_USERS_FILE )	$GROUPS_USERS_FILE
		cp $BACKUP_DIR/$ID/$( basename $ACLS_FILE ) $ACLS_FILE
		cp $BACKUP_DIR/$ID/$( basename $ACLS_PERMISSIONS_FILE ) $ACLS_PERMISSIONS_FILE
		echo -e "** Configuration saved to disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
		return 0
	fi
}

##################################################################################
# main()
##################################################################################


#install dependencies
JQ="jq"
if [ ! $JQ ]; then

	read -p "** ${RED}ERROR${NC} JQ is not available but it's required. Please install $JQ in your system, then re-run this application"
	exit 1

fi

load_configuration

delete_local_buffer

#non-interactive mode -- if any arguments are passed
####################################################
if [[ $# -ne 0 ]]; then

	if [[ $# -ne 3 ]]; then
		print_help
		echo -e "** Configurations currently available on disk:"
		echo -e "${BLUE}"
		ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
		echo -e "${NC}"
		exit 1
	fi

	#TODO check configuration exists, exit otherwise
	if [ ! -f $CONFIG_FILE ]; then

  		echo "** ERROR: Configuration not found. Please run ./run.sh to create it interactively first."

	fi
	
	load_configuration

	get_token

	OPTION="$1"
	DCOS_IP="$2"
	CONFIG_NAME="$3"

	save_configuration	#update DCOS_IP

	#create buffer dir
	mkdir -p $DATA_DIR

	case $OPTION in
	    -g|--get)
		echo -e "** GET from ${RED}$DCOS_IP${NC} into ${RED}$CONFIG_NAME${NC}: Proceeding..."
		python $GET_USERS
		python $GET_GROUPS
		python $GET_ACLS
		save_iam_configuration $CONFIG_NAME
		list_iam_configurations
	    shift # past argument
	    exit 0
	    ;;
	    -p|--post)
		echo -e "** PUT from ${RED}$CONFIG_NAME${NC} into ${RED}$DCOS_IP${NC}: Proceeding..."
	    get_token
	    load_iam_configuration $CONFIG_NAME
	    python $POST_USERS
	    python $POST_GROUPS
	    python $POST_ACLS
	    shift # past argument
	    exit 0
	    ;;
	    *)
		echo "** ERROR: Unknown command-line option."
	    print_help
	    exit 1	            # unknown option
	    ;;
	esac
	shift # past argument or value
	echo '** INFO: 		Done.'
	delete_local_buffer
	exit 0
fi

#interactive mode -- if any arguments are passed
####################################################
while true; do
	$CLS
	echo ""
	echo -e "*****************************************************************"
	echo -e "*** ${RED}Mesosphere DC/OS${NC} - IAM Config Backup and Restore Utility ****"
	echo -e "*****************************************************************"
	echo -e "** Current configuration:"
	echo -e "*****************************************************************"
	echo -e "${BLUE}1${NC}) DC/OS IP or DNS name:                  "${RED}$DCOS_IP${NC}
	echo -e "*****************************************************************"
	echo -e "${BLUE}2${NC}) DC/OS username:                        "${RED}$USERNAME${NC}
	echo -e "${BLUE}3${NC}) DC/OS password:                        "${RED}$PASSWORD${NC}
	echo -e "${BLUE}4${NC}) Default password for restored users:   "${RED}$DEFAULT_USER_PASSWORD${NC}
	echo -e "*****************************************************************"
	echo -e "${BLUE}INFO${NC}: Local buffer location:		  "${RED}$DATA_DIR${NC}
	echo -e "*****************************************************************"
	echo ""

	read -p "** Are these parameters correct?: (y/n): " REPLY

		case $REPLY in

			[yY]) echo ""
				echo "** Proceeding."
				break
				;;

			[nN]) read -p "** Enter parameter to modify [1-4]: " PARAMETER

				case $PARAMETER in

					[1]) read -p "Enter new value for DC/OS IP or DNS name: " DCOS_IP
					;;
					[2]) read -p "Enter new value for DC/OS username: " USERNAME
					;;
					[3]) read -p "Enter new value for DC/OS password: " PASSWORD
					;;
					[4]) read -p "Enter new default password for restored users: " DEFAULT_USER_PASSWORD
					;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input. Please choose a valid option"
						read -p "Press ENTER to continue"
					;;

				esac
				;;
			*) echo -e "** ${RED}ERROR${NC}: Invalid input. Please choose [y] or [n]"
			read -p "Press ENTER to continue"
			;;

		esac

done

#get token from cluster
get_token

#if the token is empty, assume wrong credentials or DC/OS is unavailable
if [ $TOKEN == "null" ]; then

	echo -e "** ${RED}ERROR${NC}: Unable to authenticate to DC/OS cluster."
	echo -e "** Either the provided credentials are wrong, or the DC/OS cluster at [ "${RED}$DCOS_IP${NC}" ] is unavailable."
	read -p "Please check your configuration and try again. Press ENTER to exit."
	exit 1

fi

#if we were able to get a token that means the cluster is up and credentials are ok
echo -e "** OK."
echo -e "** ${BLUE}INFO${NC}: Login successful to DC/OS at [ "${RED}$DCOS_IP${NC}" ]"
read -p "** Press ENTER to continue."

#create buffer dir
mkdir -p $DATA_DIR

#save configuration to config file in working dir
save_configuration

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
export USERS_GROUPS_FILE=$USERS_GROUPS_FILE
export GROUPS_FILE=$GROUPS_FILE
export GROUPS_USERS_FILE=$GROUPS_USERS_FILE
export ACLS_FILE=$ACLS_FILE
export ACLS_PERMISSIONS_FILE=$ACLS_PERMISSIONS_FILE
export TOKEN=$TOKEN

while true; do

	$CLS
	echo -e ""
	echo -e "*****************************************************************"
	echo -e "*** ${RED}Mesosphere DC/OS${NC} / IAM Config Backup and Restore Utility ****"
	echo -e "*****************************************************************"
	echo -e "** Available commands:"
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}LOAD/SAVE${NC} configurations to/from disk into local buffer:"
	echo -e "**"
	echo -e "${BLUE}d${NC}) List configurations currently available on disk."
	echo -e "${BLUE}l${NC}) Load a configuration from disk into local buffer."
	echo -e "${BLUE}s${NC}) Save current local buffer status to disk."
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}GET${NC} configuration from a running DC/OS into local buffer:"
	echo -e "**"
	echo -e "${BLUE}1${NC}) Get users from DC/OS to local buffer:			"$GET_USERS_OK
	echo -e "${BLUE}2${NC}) Get groups and memberships from DC/OS to local buffer:	"$GET_GROUPS_OK
	echo -e "${BLUE}3${NC}) Get ACLs and permissions from DC/OS to local buffer:		"$GET_ACLS_OK
	echo -e "${BLUE}G${NC}) Full GET from DC/OS to local buffer (1+2+3):			"$GET_FULL_OK
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}POST${NC} current local buffer to DC/OS:"
	echo -e "**"
	echo -e "${BLUE}4${NC}) Restore users to DC/OS from local buffer:			"$POST_USERS_OK
	echo -e "${BLUE}5${NC}) Restore groups and memberships to DC/OS from local buffer:	"$POST_GROUPS_OK
	echo -e "${BLUE}6${NC}) Restore ACLs and Permissions to DC/OS from local buffer:	"$POST_ACLS_OK
	echo -e "${BLUE}P${NC}) Full POST to DC/OS from local buffer (4+5+6):		"$POST_FULL_OK
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}VERIFY${NC} current local buffer and configuration:"
	echo -e "**"
	echo -e "${BLUE}7${NC}) Check users currently in local buffer."
	echo -e "${BLUE}8${NC}) Check groups and memberships currently in local buffer."
	echo -e "${BLUE}9${NC}) Check ACLs and permissions currently in local buffer."
	echo -e "${BLUE}0${NC}) Check this program's current configuration."
	echo -e ""
	echo -e "*****************************************************************"
	echo -e "${BLUE}x${NC}) Exit this application and delete local buffer."
	echo ""

	read -p "** Enter command: " PARAMETER

		case $PARAMETER in

			[dD]) echo -e "** Currently available configurations:"
				list_iam_configurations
				read -p "** Press ENTER to continue"
			;;

			[lL]) echo -e "${BLUE}"
				ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
				echo -e "${NC}"
				echo -e "${BLUE}WARNING${NC}: Current local buffer will be OVERWRITTEN"
				ID=""
				while [[ -z "$ID" ]]; do
					read -p "** Please enter the name of a saved configuration to load to buffer: " ID
				done
				#TODO: check that it actually exists
				load_iam_configuration $ID
				load_configuration
				echo -e "** Configuration loaded from disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
				read -p "press ENTER to continue..."
			;;

			[sS]) echo -e "** Currently available configurations:"
				echo -e "${BLUE}"
				ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
				echo -e "${NC}"
				echo -e "${BLUE}WARNING${NC}: If a configuration under this name exists, it will be OVERWRITTEN)"
				ID=""
				while [[ -z "$ID" ]]; do
					read -p "** Please enter a name to save buffer under: " ID
				done
				#TODO: check if it exists and fail if it does
				save_iam_configuration $ID
				echo -e "** Configuration saved to disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
				read -p "** Press ENTER to continue"
			;;


			[1]) echo -e "** About to get the list of Users in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$USERS_FILE${NC}" ]"
				read -p "Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $GET_USERS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						GET_USERS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[2]) echo -e "** About to get the list of Groups in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$GROUPS_FILE${NC}" ]"
				echo -e "** About to get the list of User/Group memberships in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $GET_GROUPS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						GET_GROUPS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) read -p "** ${RED}ERROR${NC}: Invalid input. Please choose [y] or [n]"
						;;

				esac
			;;

			[3]) echo -e "** About to get the list of ACLs in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to buffer [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** About to get the list of ACL Permissions Rules in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to buffer [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $GET_ACLS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						GET_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[gG]) echo -e "** About to GET the FULL configuration in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e" ** to buffers: "
				echo -e "** [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$USERS_GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $GET_USERS
						python $GET_GROUPS
						python $GET_ACLS
						read -p "** Press ENTER to continue"
						#TODO: validate result
						GET_FULL_OK=$PASS
						GET_USERS_OK=$PASS
						GET_GROUPS_OK=$PASS
						GET_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[4]) echo -e "** About to restore the list of Users in local buffer [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $POST_USERS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						POST_USERS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[5]) echo -e "** About to restore the list of Groups in buffer [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** and the list of User/Group permissions in buffer [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $POST_GROUPS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						POST_GROUPS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;

			[6]) echo -e "** About to restore the list of ACLs in buffer [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** and the list of ACL permission rules in buffer [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $POST_ACLS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						POST_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[pP]) echo -e "** About to POST the FULL configuration to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** from buffers: "
				echo -e "** [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$USERS_GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python $POST_USERS
						python $POST_GROUPS
						python $POST_ACLS
						read -p "** Press ENTER to continue"
						#TODO: validate result
						POST_FULL_OK=$PASS
						POST_USERS_OK=$PASS
						POST_GROUPS_OK=$PASS
						POST_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "** Please choose [y] or [n]"
						;;
				esac
			;;

			[7]) if [ -f $USERS_FILE ]; then
					echo -e "** Stored Users information on buffer [ "${RED}$USERS_FILE${NC}" ] is:"
					cat $USERS_FILE | jq '.array'
					read -p "Press ENTER to continue"
				else
					echo -e "** ${RED}ERROR${NC}: Current buffer is empty."
					read -p "** Press ENTER to continue"
				fi
			;;

			[8])  if [ -f $GROUPS_FILE ]; then
					echo -e "** Stored Groups information on buffer [ "${RED}$GROUPS_FILE${NC}" ] is:"
					cat $GROUPS_FILE | jq '.array'
					echo -e "** Stored Group/User memberships information on file [ "${RED}$GROUPS_USERS_FILE${NC}" ] is:"
					cat $GROUPS_USERS_FILE | jq '.array'
					read -p "Press ENTER to continue"
				else
					echo -e "** ${RED}ERROR${NC}: Current buffer is empty."
					read -p "** Press ENTER to continue"
				fi
			;;

			[9]) if [ -f $ACLS_FILE ]; then
					echo -e "** Stored ACLs information on buffer [ "${RED}$ACLS_FILE${NC}" ] is:"
					cat $ACLS_FILE | jq '.array'
					echo -e "** Stored ACL Permission association information on file [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ] is:"
					cat $ACLS_PERMISSIONS_FILE | jq '.array'
					read -p "Press ENTER to continue"
				else
					echo -e "** ${RED}ERROR${NC}: Current buffer is empty."
					read -p "** Press ENTER to continue"
				fi
			;;

			[0]) if [ -f $CONFIG_FILE ]; then
					echo -e "** Configuration currently in buffer [ "${RED}$CONFIG_FILE${NC}" ] is:"
					show_configuration
					read -p "** Press ENTER to continue"
				else
					echo -e "** ${RED}ERROR${NC}: Current configuration is empty."
					read -p "** Press ENTER to continue"
				fi

			;;

			[xX]) echo -e "** ${BLUE}WARNING${NC}: Please remember to save the local buffer to disk before exiting."
				echo -e "** Otherwise the changes will be ${RED}DELETED${NC}."
				read -p "** Are you sure you want to exit? (y/n) : " REPLY
				if [ $REPLY == "y" ]; then
					delete_local_buffer
					echo -e "** ${BLUE}Goodbye.${NC}"
					exit 0
				else
					read -p "** Exit cancelled. Press ENTER to continue."
				fi
			;;

			*) echo -e "** ${RED}ERROR${NC}: Invalid input."
				read -p "** Please choose a valid option. "
			;;

		esac

done
echo "** Ready."
