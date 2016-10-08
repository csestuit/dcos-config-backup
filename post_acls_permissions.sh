#!/bin/bash
# Get from file a set of ACL permission rules associated with the ACLs in the system
#and post them to a running cluster.
# They must have been stored by the accompanying #"post_acls_permissions.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action

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

#loop through the list of ACL Rules
jq -r '.array|keys[]' $ACLS_PERMISSIONS_FILE | while read key; do

	echo -e "*** Loading rule "$key" ..."	
	#get this rule
	RULE=$(jq ".array[$key]" $ACLS_PERMISSIONS_FILE)
  	#extract Rule ID
	_RID=$(echo $RULE | jq -r ".rid")
	#extract Permission inside
	PERMISSION=$(echo $RULE | jq -r ".permission")
	echo "** DEBUG: Permission for rule "$_RID" is "$PERMISSION
	#check whether it's a USER or GROUP rule
	#TODO: This is an array, would need to do a loop through it instead of only first member
 	_USER=$(echo $PERMISSION | jq -r '.users[0]')
	_GROUP=$(echo $PERMISSION | jq -r '.groups[0]')
	echo "** DEBUG: Users for rule "$_RID" is "$USERS
#TODO:check if empty equals [] or ""	
	if [ $_USER == null ]; then
		#group rule
		_GID=$(echo $_GROUP | jq -r ".gid")
		echo "** DEBUG: Group Rule"
		echo "** DEBUG: Group ID is: "$_GID
		GROUPURL=$(echo $_GROUP | jq -r ".groupurl")
		echo "** DEBUG: Group URL is: "$GROUPURL
		#TODO: Actions is an array, would need to do a loop through it instead of only first member
		ACTION=$(echo $_GROUP | jq -r ".actions[0]")
		echo "** DEBUG: Actions is: "$ACTION
		NAME=$(echo $ACTION | jq -r ".name")
		echo "** DEBUG: Name is :"$NAME
		URL=$(echo $ACTION | jq -r ".url")
		echo "** DEBUG: $URL is: "$URL

        	#post Action to cluster
        	echo -e "*** Posting permission "$key" with Rule ID "$_RID" for Group "$_GID" and value "$NAME "..."
        	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/groups/$_GID/$NAME )
        	sleep 1

        	#report result
        	echo "ERROR in creating permission "$key" with Rule ID "$_RID" for Group "$_GID" and value "$NAME"  was :"
        	echo $RESPONSE
	else
		#users rule
                echo "** DEBUG: Users Rule"
                _UID=$(echo $_USER | jq -r ".uid")
                echo "** DEBUG: User ID is: "$_UID
                USERURL=$(echo $_USER | jq -r ".userurl")
                echo "** DEBUG: User URL is: "$USERURL
                #TODO: Actions is an array, would need to do a loop through it instead of only first member
                ACTION=$(echo $_USER | jq -r ".actions[0]")
                echo "** DEBUG: Actions is: "$ACTION
                NAME=$(echo $ACTION | jq -r ".name")
                echo "** DEBUG: Name is :"$NAME
                URL=$(echo $ACTION | jq -r ".url")
                echo "** DEBUG: $URL is: "$URL
                
		#post Action to cluster
                echo -e "*** Posting permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME " ..."
                RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/users/$_UID/$NAME )
                sleep 1

                #report result
                echo "ERROR in creating permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME" was :"
                echo $RESPONSE
	fi

done

echo "Done."
