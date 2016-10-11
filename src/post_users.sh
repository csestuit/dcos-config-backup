#!/bin/bash
#
# post_users.sh: load from file and restore users to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of users to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_users.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/put_users_uid

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

  DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
  DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
  USERS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_FILE')
  TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#loop through the list of users and
#PUT /users/{uid}
jq -r '.array|keys[]' $USERS_FILE | while read key; do

	#extract fields from file
	USER=$( jq ".array[$key]" $USERS_FILE )
  	_UID=$( echo $USER | jq -r ".uid" )
  	URL=$( echo $USER | jq -r ".url" )
  	DESCRIPTION=$( echo $USER | jq -r ".description" )
  	IS_REMOTE=$( echo $USER | jq -r ".is_remote" )
  	IS_SERVICE=$( echo $USER | jq -r ".is_service" )
  	PUBLIC_KEY=$( echo $USER | jq -r ".public_key" )
	#build request body
	BODY="{ \
"\"password"\": "\"$DEFAULT_USER_PASSWORD"\",\
"\"description"\": "\"$DESCRIPTION"\"\
}"
	#post user to cluster
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/users/$_UID )
	#report result
 	if [ ! RESPONSE == "" ; then]
 		echo "** DEBUG: ERROR in creating USER: "$_UID" was :"
		echo $RESPONSE| jq
	fi

done

echo "Done."
