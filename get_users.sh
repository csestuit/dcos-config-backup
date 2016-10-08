#!/bin/bash
# Get a set of users configured in a running DC/OS cluster, and save
#them to a file in raw JSON format for backup and restore purposes.
#These can be restored into a cluster with the accompanying 
#"post_users.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/get_users

#Load configuration if it exists
#config is stored directly on JSON format
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then
  DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
  USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
  PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
  DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
  DEFAULT_USER_SECRET=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_SECRET')
  WORKING_DIR=$(cat $CONFIG_FILE | jq -r '.WORKING_DIR')
  CONFIG_FILE=$(cat $CONFIG_FILE | jq -r '.CONFIG_FILE')
else
  echo "** ERROR: Configuration not found. Please run ./run.sh first"
fi

#get token
TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')
echo "TOKEN: "$TOKEN

#get users from cluster
USERS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/users)

#save to file
touch $USERS_FILE
echo $USERS > $USERS_FILE

#debug
echo "USERS: " && \
echo $USERS | jq '.array'

echo "Done."
