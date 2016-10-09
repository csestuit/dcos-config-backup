#!/bin/bash
#
# post_acls_permissions.sh: load from file and restore permission rules from ACLs to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get from file a set of ACL permission rules associated with the ACLs in the system
# and post them to a running cluster.
# They must have been stored by the accompanying "get_acls_permissions.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

	DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
	ACLS_PERMISSIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE' )
	ACLS_PERMISSIONS_ACTIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_ACTIONS_FILE' )

else

	echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#loop through the list of ACL Rules
jq -r '.array|keys[]' $ACLS_PERMISSIONS_FILE | while read key; do

	echo -e "*** Loading rule "$key" ..."	
	#get this rule
	RULE=$( jq ".array[$key]" $ACLS_PERMISSIONS_FILE )
	#extract Rule ID
	_RID=$( echo $RULE | jq -r ".rid" )
	#extract Permission inside
	PERMISSION=$( echo $RULE | jq -r ".permission" )
	echo "** DEBUG: Permission for rule "$_RID" is "$PERMISSION
	#Get the .users and .groups rule sections of this rule
	_USERS=$( echo $PERMISSION | jq -r '.users' )
	_GROUPS=$( echo $PERMISSION | jq -r '.groups' )
	echo "** DEBUG: Users for rule "$_RID" is "$USERS
	echo "** DEBUG: Groups for rule "$_RID" is "$_GROUPS
	#if the user array is empty - length 0
	if [ $( echo $_USERS | jq '. | length' ) == 0 ]; then

		if [ $( echo $_GROUPS | jq '. | length' ) == 0 ]; then

			#This is a SYSTEM/services/ops rule
			#these have no ACTIONS so we just log and keep going
			echo "** DEBUG: SYSTEM/service/ops rule"
		
		else		
	
			#This is a GROUP rule
			echo "** DEBUG: GROUP Rule"
			#Groups includes the .Actions array, need to loop through it
			echo $_GROUPS | jq -r '.|keys[]' | while read key; do

				_GID=$( echo $_GROUPS | jq -r .[$key].gid )
				echo "** DEBUG: _GID is: "$_GID
				#Actions is yet another array, loop through it. Even when currently is just 1 element.
				#TODO: consolidate in a two-dimensional array .array[].groups|users[].actions[]'
				echo $ACTIONS | jq -r '.|keys[]' | while read key; do

					NAME=$( echo $ACTIONS | jq -r .[$key].name )
					echo "** DEBUG: Name is: "$NAME
					RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/groups/$_GID/$NAME )
					sleep 1
					#report result
					echo "ERROR in creating permission "$key" with Rule ID "$_RID" for Group "$_GID" and value "$NAME"  was :"
					echo $RESPONSE

				done

			done

		fi

	else
		
		#This is a USER rule
		echo "** DEBUG: USER Rule"
		_UID=$( echo $_USER | jq -r ".uid" )
		echo "** DEBUG: USER ID is: "$_UID
		#USERS is an array, need to loop through it
		echo $_USERS | jq -r '.|keys[]' | while read key; do

			_UID=$( echo $_USERS | jq -r .[$key].uid )
			echo "** DEBUG: USER ID is: "$_UID
			ACTIONS=$( echo $_GROUPS | jq -r .[$key].actions )
			echo "** DEBUG: ACTIONS is: "$ACTIONS
			#Actions is yet another array, loop through it. Even when currently is just 1 element.
			#TODO: consolidate in a two-dimensional array .array[].groups|users[].actions[]'
			echo $ACTIONS | jq -r '.|keys[]' | while read key; do

				NAME=$( echo $ACTIONS | jq -r .[$key].name )
				echo "** DEBUG: Name is: "$NAME									
				echo -e "** DEBUG: Posting permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME " ..."
				RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/users/$_UID/$NAME )
				sleep 1
				#report result
				echo "** DEBUG: ERROR in creating permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME" was :"
				echo $RESPONSE

			done

		done
	
	fi

done

echo "Done."
