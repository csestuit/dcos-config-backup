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

	echo -e "** DEBUG: Loading rule "$key" ..."	
	#get this rule
	RULE=$( jq ".array[$key]" $ACLS_FILE )
  	#extract fields
	_RID=$( echo $RULE | jq -r ".rid" )
	URL=$( echo $RULE | jq -r ".url" )
	DESCRIPTION=$( echo $RULE | jq -r ".description" )
	echo -e "** DEBUG:  Rule "$key" is: "$_RID
    #add BODY for this RULE's fields
    BODY="{ "\"description"\": "\"$DESCRIPTION"\" }"
	echo -e "** DEBUG: Body *post-rule* "$_RID" is: "$BODY
	#Create this RULE
	echo -e "** DEBUG: Posting RULE "$key": "$_RID" ..."
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID )
	#report result
	if [ ! RESPONSE == "" ; then]
 		echo "** DEBUG: ERROR in creating RULE: "$key": "$_RID" was :"
		echo $RESPONSE| jq
	fi

done

#loop through the list of ACL permission rules and create the ACLS in the system
#/acls/{rid}/groups/{gid}/{action}
#/acls/{rid}/users/{uid}/{action}
jq -r '.array|keys[]' $ACLS_PERMISSIONS_FILE | while read key; do

	echo -e "** DEBUG: Loading permissions rule "$key" ..."	
	#extract fields from file. Memberships for groups and users of this rule
	MEMBERSHIPS=$( jq ".array[$key]" $ACLS_PERMISSIONS_FILE )	
	_RID=$( echo $RULE | jq -r ".rid" )
	#loop through the GROUPS array included in each MEMBERSHIP
	#that contains the groups assigned to this rule
	echo $MEMBERSHIPS | jq -r '.groups|keys[]' | while read key; do	

  		GROUP=$( echo $MEMBERSHIPS | jq ".groups[$key]" )
		_GID=$( echo $GROUP | jq ".gid" )
		echo -e "** DEBUG: GID is : "$_GID
		GROUPURL=$( echo $GROUP | jq ".groupurl" )
		echo -e "** DEBUG: GROUPURL is : "$GROUPURL

		#loop through the ACTIONS array included in each GROUP
		echo $GROUP | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $GROUP | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			echo -e "** DEBUG: NAME is : "$NAME
			URL=$( echo $ACTION | jq -r ".url" )
			echo -e "** DEBUG: URL is : "$_URL
			#post group to cluster
			# /acls/{rid}/groups/{gid}/{action}
			echo -e "** DEBUG: Posting ACTION "$key": "$NAME" for GROUP "$_GID" on RULE "$_RID" ..."
			RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID/groups/$_GID/$NAME )
			#report result
			if [ ! RESPONSE == "" ]; then
				echo "** DEBUG: ERROR in creating GROUP: "$_GID" was :"
				echo $RESPONSE| jq
			fi

		done

	done

	#loop through the USERS array included in each MEMBERSHIP
	#that contains the users assigned to this rule
	echo $MEMBERSHIPS | jq -r '.users|keys[]' | while read key; do	

  		USER=$( echo $MEMBERSHIPS | jq ".users[$key]" )
		_UID=$( echo $USER | jq ".uid" )
		echo -e "** DEBUG: UID is : "$_UID
		USERURL=$( echo $USER | jq ".userurl" )
		echo -e "** DEBUG: USERURL is : "$USERURL

		#loop through the ACTIONS array included in each USER
		echo $USER | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $USER | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			echo -e "** DEBUG: NAME is : "$NAME
			URL=$( echo $ACTION | jq -r ".url" )
			echo -e "** DEBUG: URL is : "$_URL
			#post user to cluster
			# /acls/{rid}/users/{uid}/{action}
			echo -e "** DEBUG: Posting ACTION "$key": "$NAME" for USER "$_UID" on RULE "$_RID" ..."
			RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID/users/$_UID/$NAME )
			#report result
 			echo "** DEBUG: ERROR in creating ACTION "$key": "$NAME" for USER "$_UID" on RULE "$_RID"  was :"
			echo $RESPONSE| jq

		done

	done

done

echo "Done."
