#!/bin/bash
# Get a set of users configured in a running DC/OS cluster, and save
#them to a file in raw JSON format for backup and restore purposes.
#These can be restored into a cluster with the accompanying 
#"post_users.sh" script.

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

USERS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_URL/acs/api/v1/users)

touch $USERS_FILE
echo $USERS > $USERS_FILE

echo "\nUSERS: " $(echo $USERS | jq)
echo "\nDone."
