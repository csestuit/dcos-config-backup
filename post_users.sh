#!/bin/bash
# Post a set of users to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_users.sh" script.

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')

#read groups from file
echo "** Loading Users"

#length of the array, -1 as it starts in zero / ordinal
LENGTH=$(($(echo $USERS | jq '.array | length')-1))

#loop through the list of users
echo "** Posting Users to cluster"

jq -r '.array|keys[]' $USERS_FILE | while read key; do

	echo -e "*** Posting user "$key" ..."	
	#extract fields from file
	USER=$(jq ".array[$key]" $USERS_FILE)
 	echo "this user: "$USER
        _UID=$(echo $USER | jq -r ".uid")
	echo -e "*** user "$key" is: "$_UID
        URL=$(echo $USER | jq -r ".url")
	echo "this URL: "$URL
        DESCRIPTION=$(echo $USER | jq -r ".description")
        IS_REMOTE=$(echo $USER | jq -r ".is_remote")
        IS_SERVICE=$(echo $USER | jq -r ".is_service")
        PUBLIC_KEY=$(echo $USER | jq -r ".public_key")
sleep 1
	#build request body
	BODY="{
"\"password"\": "\"$DEFAULT_USER_PASSWORD"\",\
"\"description"\": "\"$DESCRIPTION"\"\
}"
	echo "Raw request body: "$BODY

#post user to cluster
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/users/$_UID )

	#report result
 	echo "Result of creating User: "$_UID" was "$(echo $RESPONSE| jq)

done

echo "\nDone."
