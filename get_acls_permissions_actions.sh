#!/bin/bash
# Get a set of ACTIONS associated with ACL permission rules associated with the ACLs in the system
#and save them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
#"post_acls_permissionsi_actions.sh" script.

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

#Reset and initialize contents of ACLS_PERMISSIONS_ACTIONS_FILE
touch $ACLS_PERMISSIONS_ACTIONS_FILE
echo "{ "\"array"\": [" > $ACLS_PERMISSIONS_ACTIONS_FILE

#loop through the ACL_PERMISSIONSs in the ACLS_PERMISSIONS_FILE and get their respective actions
#then save each action to ACLS_PERMISSIONS_ACTIONS_FILE
jq -r '.array|keys[]' $ACLS_PERMISSIONS_FILE | while read key; do

	echo -e "*** Loading Permission "$key" ..."
	_RID=$( jq ".array[$key].rid" $ACLS_PERMISSIONS_FILE )
	echo "** DEBUG: Permission number "$key" is associated with rule ID"$_RID
	PERMISSION=$( jq ".array[$key].permission" $ACLS_PERMISSIONS_FILE ) 
	echo "** DEBUG: Permission number "$key" of rule "$_RID" is "$PERMISSION

	#check whether it's a USER or GROUP rule
	_USER=$(echo $PERMISSION | jq -r '.users[0]')
	_GROUP=$(echo $PERMISSION | jq -r '.groups[0]')
	echo "** DEBUG: Users for rule "$_RID" is "$_USER
	echo "** DEBUG: Group for rule "$_RID" is "$_GROUP

	#if the user array is empty - length 0
	if [ $( echo $_USER | jq '. | length' ) == 0 ]; then
		
		if [ $( echo $_GROUP | jq '. | length' ) == 0 ]; then

			#SYSTEM/services/ops rule
			#have no ACTIONS so we just log and keep going
			echo "** DEBUG: SYSTEM/service/ops rule"
		
		else
			
			#GROUP rule
			echo "** DEBUG: GROUP Rule"
			#Groups includes the .Actions array, need to loop through it
			
			ACTIONS=$( echo $_GROUP | jq ".actions" )
			$( echo $ACTIONS | jq -r '.actions|keys[]' ) | while read key; do	
			
				NAME=$( echo $ACTIONS | jq -r ".actions[$key].name" )
				echo "** DEBUG: Name is: "$NAME
				URL=$( echo $ACTIONS | jq -r ".actions[$key].url" )
				echo "** DEBUG: $URL is: "$URL
				#GET ACTION value from the URL and store it
				echo -e "*** Getting ACTION for rule "key": "$_RID" ..."
				ACTION=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X GET \
http://$DCOS_IP/$URL )				
				sleep 1
				
				echo -e "** DEBUG: Action received is: "$ACTION
				#Actions dont have an index, so in order to ID them,
				#embed a first field in each entry with the associated _RID and GID
				BODY=" { "\"rid"\": "\"$_RID"\", "\"gid"\": "\"$_GID"\", "\"action"\": "
				BODY+="\"$ACTION"\"
				BODY+="},"
				echo -e "** DEBUG: BODY is: "$BODY
				#once the action has a BODY with and index, save it
				echo $BODY >> $ACLS_PERMISSIONS_ACTIONS_FILE

				#DEBUG: show contents of file to stdout to check progress
				echo "*** DEBUG current contents of file after RULE: "$_RID
				cat $ACLS_PERMISSIONS_ACTIONS_FILE
			
			done
		
		fi
	
	else
		
		#USER rule
		echo "** DEBUG: USER Rule"
		_UID=$( echo $_USER | jq -r ".uid" )
		echo "** DEBUG: USER is: "$_UID
		#Groups includes the .Actions array, need to loop through it
		ACTIONS=$( echo $_USER | jq ".actions" )        
		$( echo $ACTIONS | jq -r '.actions|keys[]' ) | while read key; do
																
			NAME=$( echo $ACTIONS | jq -r ".actions[$key].name" )
			echo "** DEBUG: Name is: "$NAME
			URL=$( echo $ACTIONS | jq -r ".actions[$key].url" )
			echo "** DEBUG: $URL is: "$URL

			#GET ACTION value from the URL and store it
			echo -e "*** Getting ACTION for rule "key": "$_RID" ..."
			ACTION=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X GET \
http://$DCOS_IP/$URL )	
			sleep 1
		
			echo -e "** DEBUG: Action received is: "$ACTION
			#Actions dont have an index, so in order to ID them,
			#embed a first field in each entry with the associated _RID and UID
			BODY=" { "\"rid"\": "\"$_RID"\", "\"uid"\": "\"$_UID"\", "\"action"\": "
			BODY+="\"$ACTION"\"
			BODY+="},"
		
			#once the action has a BODY with and index, save it
			echo $BODY >> $ACLS_PERMISSIONS_ACTIONS_FILE

			#DEBUG: show contents of file to stdout to check progress
			echo "*** DEBUG current contents of file after RULE: "$_RID
			cat $ACLS_PERMISSIONS_ACTIONS_FILE
		
		done
	
	fi

#Close ACLS_PERMISSIONS_ACTIONS_FILE
echo "{} ] }" >> $ACLS_PERMISSIONS_ACTIONS_FILE

echo "Done."
