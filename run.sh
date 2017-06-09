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
echo 'This script allows to perform several operations on a DC/OS cluster. If ran without options, it will offer an interactive menu to perform them.'
echo ''
echo 'usage: ./run.sh [options]'
echo ''
echo 'Options:'
echo
echo '-h, --help 						  - Print this help message.'
echo '-l, --login [DCOS_IP] [username] [password] 		  - Logs into a cluster and obtains an authentication token.'
echo '-g, --get   [configuration_name] 			  - Gets a full configuration from the DC/OS cluster, and saves it under "configuration_name".'
echo '-p, --post  [configuration_name] 			  - Loads a full configuration stored under "configuration_name" and posts it to the DC/OS cluster.'
echo '-n, --nodes						  - Checks the health and status of the agents in the DC/OS cluster.'
echo '-m, --masters	[number_of_masters]		- Checks the health and status of the masters and the general DC/OS cluster status.'
echo ''
}

#test connectivity with the test cluster, exit if unreachable
function test_connectivity {
if [ -z "$DCOS_IP" ]; then
	echo "**ERROR: DCOS_IP is not defined"
	exit 1
fi
#make sure the cluster is available to ping
if ping -q -c 1 -W 1 $DCOS_IP >/dev/null; then
  echo "** Connectivity with cluster is working."
else
  echo "** Connectivity with cluster is not working (ICMP is not reachable). Aborting."
  exit 1
fi

}

#get token from cluster
function get_token {

# test_connectivity #this fails when ICMP is blocked which is a usual security measure
#get token
TOKEN=$( curl \
-s \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST \
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token' )

#if the token is empty, assume wrong credentials or DC/OS is unavailable. Exit
if [ $TOKEN == "null" ]; then

	echo -e "** ${RED}ERROR${NC}: Unable to authenticate to DC/OS cluster."
	echo -e "** Either the provided credentials are wrong, or the DC/OS cluster at [ "${RED}$DCOS_IP${NC}" ] is unavailable."
	exit 1

else

	#if we were able to get a token that means the cluster is up and credentials are ok
	echo -e "** OK."
	echo -e "** ${BLUE}INFO${NC}: Login successful to DC/OS at [ "${RED}$DCOS_IP${NC}" ]"
	sleep 1
	if [[ $# -ne 0 ]]; then #interactive mode
		read -p "** Press ENTER to continue."
	fi
	#update configuration with token
	save_configuration
fi
}

function load_configuration {
#read configuration if it exists
#config is stored directly on JSON format
if [ -f $CONFIG_FILE ]; then

	DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
	USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
	PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
	TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')
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
	SERVICE_GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.SERVICE_GROUPS_FILE')
	SERVICE_GROUPS_MOM_FILE=$(cat $CONFIG_FILE | jq -r '.SERVICE_GROUPS_MOM_FILE')
	APPS_FILE=$(cat $CONFIG_FILE | jq -r '.APPS_FILE')
	APPS_MOM_FILE=$(cat $CONFIG_FILE | jq -r '.APPS_MOM_FILE')	

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
	echo "** INFO: Current configuration: "
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
"\"AGENTS_FILE"\": "\"$AGENTS_FILE"\",  \
"\"SERVICE_GROUPS_FILE"\": "\"$SERVICE_GROUPS_FILE"\",  \
"\"SERVICE_GROUPS_MOM_FILE"\": "\"$SERVICE_GROUPS_MOM_FILE"\",  \
"\"APPS_FILE"\": "\"$APPS_FILE"\",  \
"\"APPS_MOM_FILE"\": "\"$APPS_MOM_FILE"\",  \
"\"TOKEN"\": "\"$TOKEN"\"  \
} \
"
	#save config to file for future use
	echo $CONFIG > $CONFIG_FILE
	chmod 0700 $CONFIG_FILE
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
		mkdir -p $BACKUP_DIR/$ID/
		if [ -f $USERS_FILE ]; then
			cp $USERS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Users not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $USERS_GROUPS_FILE ]; then
			cp $USERS_GROUPS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Users/Groups not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $GROUPS_FILE ]; then
			cp $GROUPS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Groups not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $GROUPS_USERS_FILE ]; then
			cp $GROUPS_USERS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Groups/Users not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $ACLS_FILE ]; then
			cp $ACLS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: ACLs not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $ACLS_PERMISSIONS_FILE ]; then
			cp $ACLS_PERMISSIONS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: ACLs/Permissions not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $SERVICE_GROUPS_FILE ]; then
			cp $SERVICE_GROUPS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Service Groups not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $SERVICE_GROUPS_MOM_FILE ]; then
			cp $SERVICE_GROUPS_MOM_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: MoM Service Groups not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $APPS_FILE ]; then
			cp $APPS_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: Apps not retrieved before save. Please GET or LOAD and save again."
		fi
		if [ -f $APPS_MOM_FILE ]; then
			cp $APPS_MOM_FILE $BACKUP_DIR/$ID/
		else
			echo -e "**ERROR: save configuration: MoM Apps not retrieved before save. Please GET or LOAD and save again."
		fi


		#cp $CONFIG_FILE $BACKUP_DIR/$ID/
		chmod -R 0700 $BACKUP_DIR/$ID/
		echo -e "** Configuration saved to disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
		return 0
	fi

}

function load_iam_configuration(){
	#load from disk a configuration saved previously
	#receives the name of config to load as first parameter
	#TODO: check that it actually exists

	if [ -z "$1" ]; then
		echo "** ERROR: load_iam_configuration: no parameter received"
		return 1
	elif [ -d $BACKUP_DIR/"$1" ]; then
		ID="$1"
		cp $BACKUP_DIR/$ID/$( basename $USERS_FILE )  $USERS_FILE
		cp $BACKUP_DIR/$ID/$( basename $USERS_GROUPS_FILE ) $USERS_GROUPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $GROUPS_FILE ) $GROUPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $GROUPS_USERS_FILE )	$GROUPS_USERS_FILE
		cp $BACKUP_DIR/$ID/$( basename $ACLS_FILE ) $ACLS_FILE
		cp $BACKUP_DIR/$ID/$( basename $ACLS_PERMISSIONS_FILE ) $ACLS_PERMISSIONS_FILE
		cp $BACKUP_DIR/$ID/$( basename $SERVICE_GROUPS_FILE ) $SERVICE_GROUPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $SERVICE_GROUPS_MOM_FILE ) $SERVICE_GROUPS_MOM_FILE
		cp $BACKUP_DIR/$ID/$( basename $APPS_FILE ) $APPS_FILE
		cp $BACKUP_DIR/$ID/$( basename $APPS_MOM_FILE ) $APPS_MOM_FILE
		echo -e "** Configuration loaded from disk with name [ "${BLUE}$ID${NC}" ] at [ "${RED}$BACKUP_DIR/$ID${NC}" ]"
		return 0
	else
		echo "** ERROR: configuration [ "${RED} $1 ${NC}" ] not found."
		return 1
	fi
}

function printf_new() {
#for passwords not visible, print a string N times
 str=$1
 num=$2
 v=$(printf "%-${num}s" "$str")
 echo "${v// /*}"
}

function delete_token(){
#delete the authentication token on exit interactive mode.
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
"\"AGENTS_FILE"\": "\"$AGENTS_FILE"\",  \
"\"SERVICE_GROUPS_FILE"\": "\"$SERVICE_GROUPS_FILE"\",  \
"\"SERVICE_GROUPS_MOM_FILE"\": "\"$SERVICE_GROUPS_MOM_FILE"\",  \
"\"APPS_FILE"\": "\"$APPS_FILE"\",  \
"\"APPS_MOM_FILE"\": "\"$APPS_MOM_FILE"\",  \
"\"TOKEN"\": "\""\"  \
} \
"
	#save config to file for future use
	echo $CONFIG > $CONFIG_FILE
	chmod 0700 $CONFIG_FILE
	show_configuration
}

function check_token_and_load_config() {
#check whether the configuration file includes a token
#used when running in non-interactive mode,
#to detect whether the call was done immediately after a login.
TOKEN=$(cat $CONFIG_FILE | jq -r ".TOKEN")
if [ -n "${TOKEN:-}" ]; then
	load_configuration
else
	echo "** DEBUG: Config is not set. Credentials required as parameters."
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


#non-interactive mode -- if any arguments are passed
####################################################
if [[ $# -ne 0 ]]; then

	OPTION="$1"

	if [ "$OPTION" == "-h" ] || [ "$OPTION" == "--help" ]; then
			print_help
			echo -e "** Configurations currently available on disk:"
			echo -e "${BLUE}"
			ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
			echo -e "${NC}"
			exit 0
	fi

	#CHANGED -- check configuration exists, exit otherwise
	#EDIT: non-interactive mode takes DCOS_IP and DCOS_TOKEN as environment variables
	#if [ ! -f $CONFIG_FILE ] &&  [ "$OPTION" != "-l" ] && [ "$OPTION" != "--login"  ]; then
  	#	echo "** ERROR: Configuration not found. Please log in first."
  	#	exit 1
	#fi

	#get token from configuration file if it exists. If it does, load config.
	if [ -f $CONFIG_FILE ]; then
		check_token_and_load_config
	fi

	#Allow to logging in with username and password to set token, like in 
	#./run.sh -l|--login $DCOS_IP $USERNAME $PASSWORD
	if [ "$OPTION" == "-l" ] || [ "$OPTION" == "--login" ]; then
		if [[ $# -ne 4 ]]; then 
			print_help
			echo -e "** ERROR: -l takes exactly three arguments [DCOS_IP] [USERNAME] [PASSWORD]."
			exit 1
		fi
		TOKEN="null"
		DCOS_IP="$2"
		USERNAME="$3"
		PASSWORD="$4"
		get_token
		save_configuration	#update username, password, token, DCOS_IP
		exit 0				#exit without deleting token
	elif [ -z "${TOKEN:-}" ]; then
		echo -e "** ERROR: TOKEN is not set. Please set and re-run"
		exit 1 
	else 
		echo -e "** INFO: TOKEN set to '$TOKEN'"
		save_configuration 	#update token in case is passed as environment variable 
	fi

	if [ -z "$DCOS_IP" ]; then 
		echo -e "** ERROR: DCOS_IP is not set. Please LOGIN or set/export and re-run"
		exit 1 
	else 
		echo -e "** INFO: DCOS_IP set to '$DCOS_IP'"
	fi

	load_configuration 		#in case we did set login information with --login

	#create buffer dir
	mkdir -p $DATA_DIR

	case $OPTION in
	    -g|--get)
			if [[ $# -ne 2 ]]; then 
				print_help
				echo -e "** ERROR: -g takes exactly one argument [configuration name]."
				exit 1
			fi
			CONFIG_NAME="$2"
			echo -e "** GET from ${RED}$DCOS_IP${NC} into ${RED}$CONFIG_NAME${NC}: Proceeding..."
			python3 $GET_USERS
			python3 $GET_GROUPS
			python3 $GET_ACLS
			python3 $GET_SERVICE_GROUPS
			save_iam_configuration $CONFIG_NAME
			list_iam_configurations
	    	shift # past argument
	    	;;
	    -p|--post)
		if [[ $# -ne 2 ]]; then 
			print_help
			echo -e "** ERROR: -p takes exactly one argument [configuration name]."
			exit 1
		fi
		CONFIG_NAME="$2"
		echo -e "** PUT from ${RED}$CONFIG_NAME${NC} into ${RED}$DCOS_IP${NC}: Proceeding..."
	    	get_token
	    	load_iam_configuration $CONFIG_NAME
	    	python3 $POST_USERS
	    	python3 $POST_GROUPS
	    	python3 $POST_ACLS
	    	python3 $POST_SERVICE_GROUPS
	    	shift # past argument
	    	;;
	    -n|--nodes)
			if [[ $# -ne 1 ]]; then  #less than 1 parameters is not valid. Just show status and configurations available.
				print_help
				echo -e "** ERROR: -n takes exactly zero arguments."
				exit 1
			fi
			echo -e "** CHECK AGENT health from ${RED}$DCOS_IP${NC}: Proceeding..."
	    	python3 $GET_AGENTS
	    	shift # past argument
	    	;;
	    -m|--masters)
			if [[ $# -ne 2 ]]; then  #less than 1 parameters is not valid. Just show status and configurations available.
				print_help
				echo -e "** ERROR: -m takes exactly one argument [expected_number_of_masters]."
				exit 1
			fi
			NUM_MASTERS="$2"
			echo -e "** CHECK MASTER and system health from ${RED}$DCOS_IP${NC}: Proceeding..."
	    	python3 $GET_MASTERS $NUM_MASTERS
	    	shift # past argument
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
	#delete_token on exit interactive mode that is not -l
	#ALL ACTIONS NEED TO BE PRECEDED BY LOGIN FIRST
	delete_token
	exit 0
fi

#interactive mode -- if no arguments are passed
####################################################

#initialize variables from non-interactive
DCOS_IP=127.0.0.1
TOKEN=""

save_configuration

load_configuration

delete_local_buffer

while true; do
	$CLS
	echo ""
	echo -e "*****************************************************************"
	echo -e "***** ${RED}Mesosphere DC/OS${NC} - Config Backup and Restore Utility ******"
	echo -e "*****************************************************************"
	echo -e "** Current configuration:"
	echo -e "*****************************************************************"
	echo -e "${BLUE}1${NC}) DC/OS IP or DNS name:                  "${RED}$DCOS_IP${NC}
	echo -e "*****************************************************************"
	echo -e "${BLUE}2${NC}) DC/OS username:                        "${RED}$USERNAME${NC}
	echo -e "${BLUE}3${NC}) DC/OS password:                        "${RED} $(printf_new '_' ${#PASSWORD}) ${NC}
	echo -e "${BLUE}4${NC}) Default password for restored users:   "${RED} $(printf_new '_' ${#DEFAULT_USER_PASSWORD} ) ${NC}
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
					[3]) echo -n "Enter new value for DC/OS password: "; read -s PASSWORD; echo
					;;
					[4]) echo -n "Enter new default password for restored users: "; read -s DEFAULT_USER_PASSWORD; echo
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

#get and validate token from cluster
get_token

#create buffer dir
mkdir -p $DATA_DIR

#save configuration to config file in working dir
#save_configuration

while true; do

	$CLS
	echo -e ""
	echo -e "*****************************************************************"
	echo -e "***** ${RED}Mesosphere DC/OS${NC} - Config Backup and Restore Utility ******"
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
	echo -e "${BLUE}M${NC}) Get Service Groups from DC/OS to local buffer:		"$GET_SERVICE_GROUPS_OK
	echo -e "${BLUE}G${NC}) Full GET from DC/OS to local buffer (1+2+3+M):		"$GET_FULL_OK
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}POST${NC} current local buffer to DC/OS:"
	echo -e "**"
	echo -e "${BLUE}4${NC}) Restore users to DC/OS from local buffer:			"$POST_USERS_OK
	echo -e "${BLUE}5${NC}) Restore groups and memberships to DC/OS from local buffer:	"$POST_GROUPS_OK
	echo -e "${BLUE}6${NC}) Restore ACLs and Permissions to DC/OS from local buffer:	"$POST_ACLS_OK
	echo -e "${BLUE}N${NC}) Restore Service Groups to DC/OS from local buffer:		"$POST_SERVICE_GROUPS_OK
	echo -e "${BLUE}P${NC}) Full POST to DC/OS from local buffer (4+5+6+N):		"$POST_FULL_OK
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}VERIFY${NC} current local buffer and configuration:"
	echo -e "**"
	echo -e "${BLUE}7${NC}) Check users currently in local buffer."
	echo -e "${BLUE}8${NC}) Check groups and memberships currently in local buffer."
	echo -e "${BLUE}9${NC}) Check ACLs and permissions currently in local buffer."
	echo -e "${BLUE}o${NC}) Check Service Groups currently in local buffer."
	echo -e "${BLUE}0${NC}) Check this program's current configuration."
	echo -e "*****************************************************************"
	echo -e "** ${BLUE}CHECK${NC} cluster status:"
	echo -e "**"
	echo -e "${BLUE}A${NC}) Check the cluster's agents current status."
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
						python3 $GET_USERS
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
						python3 $GET_GROUPS
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
						python3 $GET_ACLS
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

			[mM]) echo -e "** About to get the list of Service Groups in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to buffer [ "${RED}$SERVICE_GROUPS_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python3 $GET_SERVICE_GROUPS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						GET_SERVICE_GROUPS_OK=$PASS
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
				echo -e "** to buffers: "
				echo -e "** [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$USERS_GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** [ "${RED}$ACLS_PERMISSIONS_FILE${NC}" ]"
				echo -e "** [ "${RED}$SERVICE_GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$SERVICE_GROUPS_MOM_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python3 $GET_USERS
						python3 $GET_GROUPS
						python3 $GET_ACLS
						python3 $GET_SERVICE_GROUPS
						read -p "** Press ENTER to continue"
						#TODO: validate result
						GET_FULL_OK=$PASS
						GET_USERS_OK=$PASS
						GET_GROUPS_OK=$PASS
						GET_ACLS_OK=$PASS
						GET_SERVICE_GROUPS_OK=$PASS
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
						python3 $POST_USERS
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
						python3 $POST_GROUPS
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
						python3 $POST_ACLS
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

			[nN]) echo -e "** About to restore the list of Service Groups in buffer [ "${RED}$SERVICE_GROUPS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python3 $POST_SERVICE_GROUPS
						read -p "** Press ENTER to continue..."
						#TODO: validate result
						POST_SERVICE_GROUPS_OK=$PASS
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
				echo -e "** [ "${RED}$SERVICE_GROUPS_FILE${NC}" ]"
				echo -e "** [ "${RED}$SERVICE_GROUPS_MOM_FILE${NC}" ]"
				read -p "** Confirm? (y/n): " $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						python3 $POST_USERS
						python3 $POST_GROUPS
						python3 $POST_ACLS
						python3 $POST_SERVICE_GROUPS
						read -p "** Press ENTER to continue"
						#TODO: validate result
						POST_FULL_OK=$PASS
						POST_USERS_OK=$PASS
						POST_GROUPS_OK=$PASS
						POST_ACLS_OK=$PASS
						POST_SERVICE_GROUPS_OK=$PASS
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

			[oO]) if [ -f $SERVICE_GROUPS_FILE ]; then
					echo -e "** Stored Service Group information on buffer [ "${RED}$SERVICE_GROUPS_FILE${NC}" ] is:"
					cat $SERVICE_GROUPS_FILE | jq '.' | grep '"id"'
					if [ -f $SERVICE_GROUPS_MOM_FILE ]; then
						echo -e "** Stored Service Group for MoM information on buffer [ "${RED}$SERVICE_GROUPS_MOM_FILE${NC}" ] is:"
						cat $SERVICE_GROUPS_MOM_FILE | jq '.'
					fi
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

			[aA]) echo ""
						echo "** Proceeding."
						python3 $GET_AGENTS
						read -p "** Press ENTER to continue"
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

delete_token #so that it's generated again on launch but doesn't interfere with non-interactive mode.

echo "** Ready."
