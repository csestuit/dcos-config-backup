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
BODY="{ \
"\"array"\": \
["
echo $BODY > $ACLS_PERMISSIONS_FILE

#loop through the list of ACLs received and get the permissions
# /acls/{rid}/permissions
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

	echo -e "** DEBUG: Loading ACL "$key" ..."	
	#extract fields from file
	_ACL=$( cat $ACLS_FILE | jq ".array[$key]" )
	_RID=$( echo $_ACL | jq -r ".rid" )
	BODY=" { \
"\"rid"\": "\"$_RID"\",
"\"'groups'"\": \
["
	#write to the file and continue
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	echo -e "** DEBUG: RULE "$key" is: "$_RID
	#get the information of the groups and user memberships of this ACL
	MEMBERSHIPS=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls/$_RID/permissions )

	echo -e "** DEBUG: received MEMBERSHIPs are: "$MEMBERSHIPS
	#Memberships is an array of the different member USERS and GROUPS
	#loop through both of them.
	#TODO: change for two-dimensional array instead of nested
	#loop through the GROUPS and add them to the file
	echo $MEMBERSHIPS | jq -r '.groups|keys[]' | while read key; do

  		GROUP=$( echo $MEMBERSHIPS | jq ".groups[$key]" )
		_GID=$( echo $GROUP | jq ".gid" )
		echo -e "** DEBUG: GID is : "$_GID
		GROUPURL=$( echo $GROUP | jq ".groupurl" )
		echo -e "** DEBUG: GROUPURL is : "$GROUPURL
		#these are the FIELDS of this GROUP (before further arrays)
		#prepare the body of this GROUP
		#and leave open for the next array
		BODY=" { \
"\"gid"\": $_GID,\
"\"groupurl"\": $GROUPURL,\
"\"actions"\": ["
		#write to the file and continue
		echo $BODY >> $ACLS_PERMISSIONS_FILE
		#actions is *YET ANOTHER* array, loop through it etc.
		#TODO: change for three-dimensional array instead of nested
		echo $GROUP | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $GROUP | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			echo -e "** DEBUG: NAME is : "$NAME
			URL=$( echo $ACTION | jq -r ".url" )
			echo -e "** DEBUG: URL is : "$_URL
			#prepare body of this ACTION to add it to file
			BODY=" { \
"\"name"\": "\"$NAME"\",\
"\"url"\": "\"$URL"\"
},"
 			#no deeper arrays so close the JSON
			#write to the file and continue
			echo $BODY >> $ACLS_PERMISSIONS_FILE
		
		done
		#close the ACTIONS array, add null last item (comma issue)
		echo "{} ] }," >> $ACLS_PERMISSIONS_FILE

	done
	#close the GROUPS array, add null last item
	echo "{} ]," >> $ACLS_PERMISSIONS_FILE

#close groups, start users
	BODY=" "\"'users'"\" : ["
	#write to the file and continue
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	#loop through the users and add them to the file
	echo $MEMBERSHIPS | jq -r '.users|keys[]' | while read key; do

		_UID=$( echo $_USERS | jq -r ".uid" )
		USERURL=$( echo $_USERS | jq -r ".userurl" )
		#these are the FIELDS of this USER (before further arrays)
		#prepare the body of this USER
		#and leave open for the next array
		BODY=" { \
"\"uid"\": "\"$_UID"\",\
"\"userurl"\": "\"$USERURL"\",
"\"actions"\": ["
		#write to the file and continue
		echo $BODY >> $ACLS_PERMISSIONS_FILE
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
			echo $BODY >> $ACLS_PERMISSIONS_FILE


		done
		#close the ACTIONS array, add null last item (comma issue)
		echo "{} ] }," >> $ACLS_PERMISSIONS_FILE

	done
	#close the USERS array, add null last item
	#close USERS
	BODY="{} ] },"
	#write to the file and continue
	echo $BODY >> $ACLS_PERMISSIONS_FILE

done
#close this PERMISSIONS
BODY="{} ] }"
#write to the file and continue
echo $BODY >> $ACLS_PERMISSIONS_FILE


#get ACLs_GROUPS

echo "Done."
