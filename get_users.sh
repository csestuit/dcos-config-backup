#!/bin/bash
# Get a set of users configured in a running DC/OS cluster, and save
#them to a file in raw JSON format for backup and restore purposes.
#These can be restored into a cluster with the accompanying 
#"post_users.sh" script.

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')
echo "TOKEN: "$TOKEN

USERS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/users)

touch $USERS_FILE
echo $USERS > $USERS_FILE

echo "USERS: " && \
echo $USERS | jq '.array'

echo "Done."
