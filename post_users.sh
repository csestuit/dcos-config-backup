#!/bin/bash
# Post a set of users to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_users.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/put_users_uid

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')

#loop through the list of users
jq -r '.array|keys[]' $USERS_FILE | while read key; do

	echo -e "*** Loading USER "$key" ..."	
	#extract fields from file
	USER=$(jq ".array[$key]" $USERS_FILE)
    _UID=$(echo $USER | jq -r ".uid")
	echo -e "*** user "$key" is: "$_UID
    URL=$(echo $USER | jq -r ".url")
    DESCRIPTION=$(echo $USER | jq -r ".description")
    IS_REMOTE=$(echo $USER | jq -r ".is_remote")
    IS_SERVICE=$(echo $USER | jq -r ".is_service")
    PUBLIC_KEY=$(echo $USER | jq -r ".public_key")

	#build request body
	BODY="{
"\"password"\": "\"$DEFAULT_USER_PASSWORD"\",\
"\"description"\": "\"$DESCRIPTION"\"\
}"
	echo "Raw request body: "$BODY

	#post user to cluster
	echo -e "*** Posting USER "key": "$_UID" ..."
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/users/$_UID )
	sleep 1

	#report result
 	echo "ERROR in creating USER: "$_UID" was :"
	echo $RESPONSE| jq

done

echo "Done."
