#!/bin/bash
# Post a set of users to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_users.sh" script.

#variables should be exported with launch.sh
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

#read groups from file
echo "** Loading Users"
cat $USERS_FILE > USERS

#length of the array, -1 as it starts in zero / ordinal
LENGTH=i`$(cat USERS | jq '.array | length') - 1`

#loop through the list of users
echo "** Posting Users to cluster"
for i in {0..$LENGTH}
do
	#extract each field
	THIS_USER=$(echo $USERS | jq ".array[i]")
	UID=$(echo $THIS_USER | jq ".uid")
	URL=$(echo $THIS_USER | jq ".url")
	DESCRIPTION=$(echo $THIS_USER | jq ".description")
	IS_REMOTE=$(echo $THIS_USER | jq ".is_remote")
	IS_SERVICE=$(echo $THIS_USER | jq ".is_service")
	PUBLIC_KEY=$(echo $THIS_USER | jq ".public_key")

	#post user to cluster
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d '{"description": "'"$DESCRIPTION"'",\
"password": "'"$DEFAULT_USER_PASSWORD"'",\
"public_key": "'"$PUBLIC_KEY"'",\
"password": "'"$DEFAULT_PASSWORD"'",\
"secret": "'"$DEFAULT_USER_SECRET"'",\
}' \
-X PUT \
http://$DCOS_URL/acs/api/v1/users/uid )

	#report result
	echo "\nResult of creating User: "$UID" was "$RESPONSE
done

echo "\nDone."
