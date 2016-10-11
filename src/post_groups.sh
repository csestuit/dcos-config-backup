#!/bin/bash
#
# post_groups.sh: load from file and restore groups to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
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

  DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
  GROUPS_FILE=$( cat $CONFIG_FILE | jq -r '.GROUPS_FILE' )
  GROUPS_USERS_FILE=$( cat $CONFIG_FILE | jq -r '.GROUPS_USERS_FILE' )
  TOKEN=$( cat $CONFIG_FILE | jq -r '.TOKEN' )

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#loop through the list of groups
#PUT  /groups/{gid}
jq -r '.array|keys[]' $GROUPS_FILE | while read key; do

	#extract fields from file
	GROUP=$( jq ".array[$key]" $GROUPS_FILE )
 	_GID=$( echo $GROUP | jq -r ".gid" )
	URL=$( echo $GROUP | jq -r ".url" )
	DESCRIPTION=$( echo $GROUP | jq -r ".description" )
	#build request body
	BODY="{"\"description"\": "\"$DESCRIPTION"\"}"
	#post group to cluster
	RESPONSE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/groups/$_GID )
	#report result
	if [ -n "$RESPONSE" ]; then
 		echo -e "** DEBUG: ${RED}ERROR${NC} in creating GROUP: "$key": "$_GID" was :"
		echo -e $RESPONSE| jq
	fi

done

#loop through the list of groups_users and add users to groups
#PUT /groups/{gid}/users/{uid}
jq -r '.array|keys[]' $GROUPS_USERS_FILE | while read key; do

	#extract fields from file
	MEMBERSHIP=$( jq ".array[$key]" $GROUPS_USERS_FILE )
    _GID=$( echo $MEMBERSHIP | jq -r ".gid" )
	_USER=$( echo $MEMBERSHIP | jq -r ".user" )
	_UID=$( echo $_USER | jq -r ".uid" )
	#post group to cluster
	RESPONSE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/groups/$_GID/users/$_UID )

	if [ -n "$RESPONSE" ]; then
 		echo -e "** DEBUG: ${RED}ERROR${NC} in creating GROUP: "$key": "$_GID" was :"
		echo -e $RESPONSE| jq
	fi

done

echo "Done."

