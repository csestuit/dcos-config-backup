#!/bin/bash
# Post a set of groups to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_groups.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/put_groups_gid

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')

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

