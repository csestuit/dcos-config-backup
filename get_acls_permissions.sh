#!/bin/bash
# Get a set of ACL permission rules associated with the ACLs in the system
#and save them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
#"post_acls_permissions.sh" script.

#reference: 
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/get_acls

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
  GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
  ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
  ACLS_PERMISSIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE')
  ACLS_PERMISSIONS_ACTIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_ACTIONS_FILE')
else
  echo "** ERROR: Configuration not found. Please run ./run.sh first"
fi

#Reset contents of ACLS_PERMISSIONS_FILE
touch $ACLS_PERMISSIONS_FILE
echo "" > $ACLS_PERMISSIONS_FILE

#loop through the ACLs in the ACLS_FILE and get their respective permissions
#then save each permission to ACLS_PERMISSIONS_FILE
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

        echo -e "*** Loading ACL "$key" ..."
        ACL=$(jq ".array[$key]" $ACLS_FILE)
	_RID=$(echo $ACL | jq -r ".rid")
    	#get the associated URL which gives the permissions
	URL=$(echo $ACL | jq -r ".url")
	echo "** DEBUG: URL is :"$URL
	#query the ACL's URL to get the associated permissions
        echo -e "*** Saving PERMISSIONS for rule "key": "$_RID" ..."
        PERMISSION=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X GET \
http://$DCOS_IP/$URL/permissions )
        sleep 1

	echo -e "** DEBUG: Received permission is: "
	echo $PERMISSION | jq
	
	#Permissions dont have an index, so in order to ID them,
	#embed them into a new JSON including the associated _RID for INDEX
	#get the permission as a value inside each _RID
	BODY="{ \
"\"rid"\": "\"$_RID"\" \
{ "
	BODY+=$PERMISSION
	BODY+="}}
"

	#once the permission has a BODY with and index, save it
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	#DEBUG: show contents of file to stdout to check progress
	echo "*** DEBUG current contents of file after RULE: "$_RID
	cat $ACLS_PERMISSIONS_FILE
done

echo "Done."
