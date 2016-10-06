#!/bin/bash
# Interactively get and export the required parameters

#Default values
DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme
DEFAULT_USER_PASSWORD=deleteme
DEFAULT_USER_SECRET=secret
WORKING_DIR="~/DATA"

#not exposed
USERS_FILE=$WORKING_DIR/users.json
ACLS_FILE=$WORKING_DIR/acls.json
PORTS_FILE=$WORKING_DIR/ports.json

while true; do
	echo ""
	echo "** Current parameters:"
	echo ""
	echo "**************************          ****************"
	echo "1) DC/OS IP or DNS name:                  "$DCOS_URL
	echo "**************************          ****************"
	echo "2) DC/OS username:                     "$USERNAME
	echo "3) DC/OS password:                     "$PASSWORD
	echo "4) Default password for restored users:     "$DEFAULT_USER_PASSWORD
	echo "5) Default secret for restored users:    	 "$DEFAULT_USER_SECRET
	echo "6) Working directory:                  "$WORKING_DIR
	echo ""
  read -p "** Are these parameters correct?: (y/n): " REPLY
  case $REPLY in
    [yY]) echo ""
          echo "** Proceeding."
          break
          ;;
    [nN]) read -p "** Enter number of parameter to modify [1-6]" PARAMETER
          #FIXME: add section to ask which parameter to change and read it from input
          case $PARAMETER in
          	[1]) read -p "Enter new value for DC/OS IP or DNS name:" DCOS_URL
          	     break 1
		     ;;
          	[2]) read -p "Enter new value for DC/OS username:" USERNAME
          	     break 1
		     ;;
          	[3]) read -p "Enter new value for DC/OS password:" PASSWORD
          	     break 1
		     ;;
          	[4]) read -p "Enter new value for Default Password for restored users:" DEFAULT_USER_PASSWORD
          	     break 1
		     ;;
          	[5]) read -p "Enter new value for Default Secret for restored users::" DEFAULT_USER_SECRET
          	     break 1
		     ;;
           	[6]) read -p "Enter new value for Working Directory:" WORKING_DIR
          	     break 1
		     ;;
      		  *) echo "** Invalid input. Please choose an option [1-6]"
       		     ;;
	  esac
	;;
    *) echo "** Invalid input. Please choose [y] or [n]"
       ;;
  esac
done

mkdir -p WORKING_DIR

echo "Ready."
