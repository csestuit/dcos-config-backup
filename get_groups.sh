#!/bin/bash
# Get a set of groups configured in a running DC/OS cluster, and save
#them to a file in raw JSON format for backup and restore purposes.
#These can be restored into a cluster with the accompanying 
#"post_groups.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/get_groups_gid

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then
  DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
  USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
  PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
  DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
  DEFAULT_USER_SECRET=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_SECRET')
  WORKING_DIR=$(cat $CONFIG_FILE | jq -r '.WORKING_DIR')
  CONFIG_FILE=$(cat $CONFIG_FILE | jq -r '.CONFIG_FILE')
  USERS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_FILE')
  ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
  GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
  TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')
else
  echo "** ERROR: Configuration not found. Please run ./run.sh first"
fi

#get groups
GROUPS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/groups)

#save to file
touch $GROUPS_FILE
echo $GROUPS > $GROUPS_FILE

#debug
echo "GROUPS: "
echo $GROUPS | jq

echo "Done."
exit 0
