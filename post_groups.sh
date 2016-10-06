#!/bin/bash
# Post a set of groups to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_groups.sh" script.

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

#read groups from file
echo "** Loading Groups"
cat $GROUPS_FILE > GROUPS

#length of the array, -1 as it starts in zero / ordinal
LENGTH=i`$(cat GROUPS | jq '.array | length') - 1`

#loop through the array of groups
echo "** Posting Groups to cluster"
for i in {0..$LENGTH}
do
	THIS_GROUP=$(echo $GROUPS | jq ".array[i]")
	GID=$(echo $THIS_GROUP | jq ".gid")
	URL=$(echo $THIS_GROUP | jq ".url")
	DESCRIPTION=$(echo $THIS_GROUP | jq ".description")

	#post each group to cluster
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d '{"description": "'"$DESCRIPTION"'"}' \
-X PUT \
http://$DCOS_URL/acs/api/v1/groups/GID )

	#report result
	echo "\nResult of creating User: "$UID" was "$RESPONSE
done

echo "\nDone."

