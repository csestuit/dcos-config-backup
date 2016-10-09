#!/bin/bash
#
# post_acls_permissions_actions.sh: load from file and restore actions associated with permission rules
# from ACLs to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get from file a set of Actions associated with ACL permission rules associated with the ACLs in the system
# and post them to a running cluster.
# They must have been stored by the accompanying "get_acls_permissions_actions.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_groups_gid_action

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

#loop through the list of ACL Permission Actions Rules
jq -r '.array|keys[]' $ACLS_PERMISSIONS_ACTIONS_FILE | while read key; do

	echo -e "*** Loading rule "$key" ..."	
	#get this rule
	RULE=$( jq ".array[$key]" $ACLS_PERMISSIONS_ACTIONS_FILE )
	#extract Rule ID
	_RID=$( echo $RULE | jq -r ".rid" )
	#check whether it's a USER or GROUP rule
	#if it includes ".gid" it's a group rule
	if [[ $RULE == *".gid"* ]]; then
		#This is a GROUP rule
		echo "** DEBUG: GROUP Rule"
		_GID=$( echo $RULE | jq -r .[$key].gid )
		echo "** DEBUG: RULE is :"$RULE
		ACTION=$( echo $RULE | jq -r .[$key].action )
		#ACTION is an array, need to loop through it
		#TODO: do both loops at once with a two-dimensional array
		echo $ACTION | jq -r '.|keys[]' | while read key; do

			NAME=$( echo $ACTIONS | jq -r .[$key].name )
			echo "** DEBUG: Name is: "$NAME									
			#post RULE to cluster
			RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/groups/$_GID/$NAME )
#/acls/{rid}/users/{gid}/{action}
			sleep 1
			#report result
			echo "** DEBUG: ERROR in creating permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME" was :"
			echo $RESPONSE

		done

	else
		
		#This is a USER rule
		echo "** DEBUG: USER Rule"
		_UID=$( echo $RULE | jq -r ".uid" )
		echo "** DEBUG: USER ID is: "$_UID
		#USERS is an array, need to loop through it
		ACTION=$( echo $RULE | jq -r .[$key].action )
		echo "** DEBUG: ACTION is: "$ACTION
		#ACTION is yet another array, loop through it. Even when currently is just 1 element.
		#TODO: consolidate in a two-dimensional array .array[].groups|users[].actions[]'
		echo $ACTION | jq -r '.|keys[]' | while read key; do

				NAME=$( echo $ACTIONS | jq -r .[$key].name )
				echo "** DEBUG: Name is: "$NAME									
				RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X PUT \
http://$DCOS_IP/acs/api/v1/$_RID/users/$_UID/$NAME )
#/acls/{rid}/groups/{uid}/{action}
				sleep 1
				#report result
				echo "** DEBUG: ERROR in creating permission "$key" with Rule ID "$_RID" for User "$_UID" and value "$NAME" was :"
				echo $RESPONSE

		done
	
	fi

done

echo "Done."
