#!/bin/bash
#
# post_acls.sh: load from file  and restore ACLs to a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Post a set of ACLs to a running DC/OS cluster, read from a file 
# where they're stored in raw JSON format as received from the accompanying
# "get_acls.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

  DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
  ACLS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_FILE' )
  ACLS_PERMISSIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE' )
  TOKEN=$( cat $CONFIG_FILE | jq -r '.TOKEN' )

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#loop through the list of ACL Rules and create the ACLS in the system
#PUT /acls/{rid}
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

	#get this rule
	RULE=$( jq ".array[$key]" $ACLS_FILE )
  	#extract fields
	_RID=$( echo $RULE | jq -r ".rid" )
	URL=$( echo $RULE | jq -r ".url" )
	DESCRIPTION=$( echo $RULE | jq -r ".description" )
    #add BODY for this RULE's fields
    BODY="{ "\"description"\": "\"$DESCRIPTION"\" }"
	#Create this RULE
	RESPONSE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID )
	#show progress after curl
	echo "** OK."
	#report result
	echo "."
	if [ -n "$RESPONSE" ]; then
 		echo -e "** ${RED}ERROR${NC} in creating RULE: "$key": "$_RID" was :"
		echo -e $RESPONSE| jq
	fi

done

#loop through the list of ACL permission rules and create the ACLS in the system
#/acls/{rid}/groups/{gid}/{action}
#/acls/{rid}/users/{uid}/{action}
jq -r '.array|keys[]' $ACLS_PERMISSIONS_FILE | while read key; do

	#extract fields from file. Memberships for groups and users of this rule
	PERMISSION=$( jq ".array[$key]" $ACLS_PERMISSIONS_FILE )	
	_RID=$( echo $PERMISSION | jq -r ".rid" )
	#loop through the GROUPS array included in each PERMISSION
	#that contains the groups assigned to this rule
	echo $PERMISSION | jq -r '.groups|keys[]' | while read key; do	

  		GROUP=$( echo $PERMISSION | jq ".groups[$key]" )
		_GID=$( echo $GROUP | jq -r ".gid" )
		GROUPURL=$( echo $GROUP | jq -r ".groupurl" )
		#loop through the ACTIONS array included in each GROUP
		echo $GROUP | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $GROUP | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			URL=$( echo $ACTION | jq -r ".url" )
			#post group to cluster
			# /acls/{rid}/groups/{gid}/{action}
			RESPONSE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID/groups/$_GID/$NAME )
			#show progress after curl
			echo "** OK."
			#report result - 'null' actions are omitted because these are created on purpose for the JSON compatibility
			if ( [ -n "$RESPONSE" ] && [ "$ACTION" != "{}" ] ); then
				echo "ACTION = "$ACTION
 				echo -e "** ${RED}ERROR${NC} in creating ACTION: "$key": "$NAME" for GROUP "$_GID" was :"
				echo -e $RESPONSE| jq
			fi

		done

	done

	#loop through the USERS array included in each PERMISSION
	#that contains the users assigned to this rule
	echo $PERMISSION | jq -r '.users|keys[]' | while read key; do	

  		USER=$( echo $PERMISSION | jq -r ".users[$key]" )
		_UID=$( echo $USER | jq -r ".uid" )
		USERURL=$( echo $USER | jq -r ".userurl" )

		#loop through the ACTIONS array included in each USER
		echo $USER | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $USER | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			URL=$( echo $ACTION | jq -r ".url" )
			#post user to cluster
			# /acls/{rid}/users/{uid}/{action}
			RESPONSE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID/users/$_UID/$NAME )
			#show progress after curl
			echo "** OK."
			#report result - 'null' actions are omitted because these are created on purpose for the JSON compatibility
			echo "."
			if ( [ -n "$RESPONSE" ] && [ "$ACTION" != "{}" ] ); then
 				echo -e "** ${RED}ERROR${NC} in creating ACTION: "$key": "$NAME" for USER "$UID" was :"
				echo -e $RESPONSE| jq
			fi

		done

	done

done

echo "Done."
