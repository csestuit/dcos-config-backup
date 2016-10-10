#!/bin/bash

# get_acls_permissions.sh: retrieve and save configured permissions for ACLs on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of ACL permission rules associated with the ACLs in the system
# and save them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_acls_permissions.sh" script.

#reference: 
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/get_acls

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/../.config.json"
if [ -f $CONFIG_FILE ]; then

  DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
  ACLS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_FILE' )
  ACLS_PERMISSIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE' )
  TOKEN=$( cat $CONFIG_FILE | jq -r '.TOKEN' )

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#Reset and initialize contents of ACLS_PERMISSIONS_FILE
touch $ACLS_PERMISSIONS_FILE
echo "{ "\"array"\": [" > $ACLS_PERMISSIONS_FILE

#loop through the ACLs in the ACLS_FILE and get their respective permissions
#then save each permission to ACLS_PERMISSIONS_FILE
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

  echo -e "*** Loading ACL "$key" ..."
  ACL=$( jq ".array[$key]" $ACLS_FILE )
	_RID=$( echo $ACL | jq -r ".rid" )
  #get the associated URL which gives the permissions
	URL=$( echo $ACL | jq -r ".url" )
	echo "** DEBUG: URL is :"$URL
	#query the ACL's URL to get the associated permissions
  echo -e "** DEBUG: Getting PERMISSIONS for rule "key": "$_RID" ..."
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
	#embed a first field in each entry with the associated _RID
	BODY=" { "\"rid"\": "\"$_RID"\", "\"permission"\":"
	BODY+=$PERMISSION
	BODY+="},"
	#once the permission has a BODY with and index, save it
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	#DEBUG: show contents of file to stdout to check progress
	echo "*** DEBUG current contents of file after RULE: "$_RID
	cat $ACLS_PERMISSIONS_FILE

done

#Close ACLS_PERMISSIONS_FILE - add a last empty element to ensure no final comma.
echo "{} ] }" >> $ACLS_PERMISSIONS_FILE

echo "Done."
