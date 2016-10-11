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
 	echo "** DEBUG: ERROR in creating RULE: "$key": "$_RID" was :"
	echo $RESPONSE| jq

done


#get the list of groups each ACL has
#loop through the list of groups, and 
#post the list of actions each group has

#get the list of users each ACL has
#loop through the list of users, and 
#post the list of actions each user has

echo "Done."
