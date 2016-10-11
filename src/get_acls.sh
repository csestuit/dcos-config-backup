#!/bin/bash
# get_acls.sh: retrieve and save configured ACLs on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of ACLs configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_acls.sh" script.

#reference: 
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/get_acls

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

	DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
	ACLS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_FILE' )
	ACLS_PERMISSIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE' )
	ACLS_GROUPS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_GROUPS_FILE' )
	ACLS_GROUPS_ACTIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_GROUPS_ACTIONS_FILE' )
	ACLS_USERS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_USERS_FILE' )
	ACLS_USERS_ACTIONS_FILE=$( cat $CONFIG_FILE | jq -r '.ACLS_USERS_ACTIONS_FILE' )
	TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#get ACLs
#GET /acls

ACLS=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls )

#save to file
touch $ACLS_FILE
echo $ACLS > $ACLS_FILE

#debug
echo "** ACLs: "
echo $ACLS | jq

#initialize the file where the permissions will be stored
touch $ACLS_PERMISSIONS_FILE
echo "{ "\"array"\": [" > $ACLS_PERMISSIONS_FILE

#loop through the list of ACLs received and get the permissions
# /acls/{rid}/permissions
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

	echo -e "** DEBUG: Loading ACL "$key" ..."	
	#extract fields from file
	_ACL=$( jq ".array[$key]" $ACLS_FILE )
	_RID=$( echo $_ACL | jq -r ".rid" )
	echo -e "** DEBUG: RULE "$key" is: "$_GID
	#get the information of the groups and user memberships of this particular ACL
	MEMBERSHIPS=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls/$_RID/permissions )

	echo -e "** DEBUG: received MEMBERSHIPs are: "$MEMBERSHIPS
	#Memberships is an array of the different member USERS and GROUPS
	#loop through both of them.
	#TODO: change for two-dimensional array instead of nested
	_GROUPS=$( echo $MEMBERSHIPS | jq -r ".groups" )
	#loop through the groups and add them to the file
	echo $_GROUPS | jq -r '.|keys[]' | while read key; do

		_GID=$( echo $_GROUPS | jq -r ".gid" )
		GROUPURL=$( echo $_GROUPS | jq -r ".groupurl" )
		#these are the FIELDS of this GROUP (before further arrays)
		#prepare the body of this GROUP
		#and leave open for the next array
		BODY=" { \
"\"gid"\": "\"$_GID"\",\
"\"groupurl"\": "\"$GROUPURL"\",
"\"actions"\": ["
		#write to the file and continue
		echo $BODY >> $PERMISSIONS_FILE
		ACTIONS=$( echo $_GROUPS | jq -r ".actions" )
		#actions is *YET ANOTHER* array, loop through it etc.
		#TODO: change for three-dimensional array instead of nested
		echo $ACTIONS | jq -r '.|keys[]' | while read key; do

			NAME=$( echo $ACTIONS | jq -r ".name" )
			URL=$( echo $ACTIONS | jq -r ".url" )
			#prepare body of this ACTION to add it to file
			BODY=" { \
"\"name"\": "\"$NAME"\",\
"\"url"\": "\"$URL"\"\
},"
 			#no deeper arrays so close the JSON
			#write to the file and continue
			echo $BODY >> $PERMISSIONS_FILE

		done
		#close the ACTIONS array, add null last item (comma issue)
		echo "{} ]," >> $PERMISSIONS_FILE
	done
	#close the GROUPS array, add null last item
	echo "{} ]," >> $PERMISSIONS_FILE

	_USERS=$( echo $MEMBERSHIPS | jq -r ".users" )
	#loop through the users and add them to the file
	echo $_USERS | jq -r '.|keys[]' | while read key; do

		_UID=$( echo $_USERS | jq -r ".uid" )
		USERURL=$( echo $_USERS | jq -r ".userurl" )
		#these are the FIELDS of this USER (before further arrays)
		#prepare the body of this USER
		#and leave open for the next array
		BODY=" { \
"\"uid"\": "\"$_UID"\",\
"\"userpurl"\": "\"$USERURL"\",
"\"actions"\": ["
		#write to the file and continue
		echo $BODY >> $PERMISSIONS_FILE
		ACTIONS=$( echo $_USERS | jq -r ".actions" )
		#actions is *YET ANOTHER* array, loop through it etc.
		#TODO: change for three-dimensional array instead of nested
		echo $ACTIONS | jq -r '.|keys[]' | while read key; do

			NAME=$( echo $ACTIONS | jq -r ".name" )
			URL=$( echo $ACTIONS | jq -r ".url" )
			#prepare body of this ACTION to add it to file
			BODY=" { \
"\"name"\": "\"$NAME"\",\
"\"url"\": "\"$URL"\"\
},"
 			#no deeper arrays so close the JSON
			#write to the file and continue
			echo $BODY >> $PERMISSIONS_FILE

		done
		#close the ACTIONS array, add null last item (comma issue)
		echo "{} ]," >> $PERMISSIONS_FILE
	
	done
	#close the USERS array, add null last item
	echo "{} ]," >> $PERMISSIONS_FILE

done
#close the PERMISSIONS, add null last item
echo "{} ] }" >> $PERMISSIONS_FILE

#get ACLs_GROUPS

echo "Done."
