#!/bin/bash
#
# post_groups.sh: load from file and restore groups to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com]
#
# Post a set of groups to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
#"get_groups.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/put_groups_gid

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then
  DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
  USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
  PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
  DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
  DEFAULT_USER_SECRET=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_SECRET')
  WORKING_DIR=$(cat $CONFIG_FILE | jq -r '.WORKING_DIR')
  CONFIG_FILE=$(cat $CONFIG_FILE | jq -r '.CONFIG_FILE')
  USERS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_FILE')
  ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
  GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
  TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')
else
  echo "** ERROR: Configuration not found. Please run ./run.sh first"
fi

#loop through the list of groups
jq -r '.array|keys[]' $GROUPS_FILE | while read key; do

	echo -e "*** Loading GROUP "$key" ..."	
	#extract fields from file
	GROUP=$(jq ".array[$key]" $GROUPS_FILE)
    	_GID=$(echo $GROUP | jq -r ".gid")
	echo -e "*** GROUP "$key" is: "$_GID
    	URL=$(echo $GROUP | jq -r ".url")
    	DESCRIPTION=$(echo $GROUP | jq -r ".description")

	#build request body
	BODY="{
"\"description"\": "\"$DESCRIPTION"\"\
}"
	echo "Raw request body: "$BODY

	#post group to cluster
	echo -e "*** Posting GROUP "key": "$_GID" ..."
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/groups/$_GID )
	sleep 1

	#report result
 	echo "ERROR in creating GROUP: "$_GID" was :"
	echo $RESPONSE| jq

done

echo "Done."

