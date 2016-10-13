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
	TOKEN=$(cat $CONFIG_FILE | jq -r '.TOKEN')

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#get ACLs
#GET /acls

ACLS=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls )
#show progress
echo "OK."
#save to file
touch $ACLS_FILE
echo $ACLS > $ACLS_FILE

#debug
echo "** DEBUG: SAVED ACLs: "
cat $ACLS_FILE | jq 

#initialize the file where the permissions will be stored
touch $ACLS_PERMISSIONS_FILE
BODY="{ \
"\"array"\": \
["
echo $BODY > $ACLS_PERMISSIONS_FILE

#loop through the list of ACLs received and get the permissions
# /acls/{rid}/permissions
jq -r '.array|keys[]' $ACLS_FILE | while read key; do

	#extract fields from file
	_ACL=$( cat $ACLS_FILE | jq ".array[$key]" )
	_RID=$( echo $_ACL | jq -r ".rid" )
	BODY=" { \
"\"rid"\": "\"$_RID"\",
"\"'groups'"\": \
["
	#write to the file and continue
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	#get the information of the groups and user memberships of this ACL
	PERMISSIONS=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls/$_RID/permissions )
	#show progress after curl
	echo "OK."
	#Memberships is an array of the different member USERS and GROUPS
	#loop through both of them.
	#TODO: change for two-dimensional array instead of nested
	#loop through the GROUPS and add them to the file
	echo $PERMISSIONS | jq -r '.groups|keys[]' | while read key; do

  		GROUP=$( echo $PERMISSIONS | jq ".groups[$key]" )
		_GID=$( echo $GROUP | jq ".gid" )
		GROUPURL=$( echo $GROUP | jq ".groupurl" )
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
			URL=$( echo $ACTION | jq -r ".url" )
			#prepare body of this ACTION to add it to file
			BODY=" { \
"\"name"\": "\"$NAME"\",\
"\"url"\": "\"$URL"\"
},"
			#SLIGHT CHANGE TO THE SCHEMA TO ADD THE VALUE OF THE ACTION
			#to each action in the same JSON
			#get it from /acls/{rid}/groups/{gid}/{action}
			ACTION_VALUE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls/$_RID/groups/$_GID/$NAME )
			#show progress after curl
			echo "OK."
			#response is already a JSON so we attach it directly
			BODY=$BODY$ACTION_VALUE" ,"		
 			#no deeper arrays so close the JSON
			#write to the file and continue
			echo $BODY >> $ACLS_PERMISSIONS_FILE
		
		done
		#close the ACTIONS array, add null last item (comma issue)
		echo "{} ] }," >> $ACLS_PERMISSIONS_FILE

	done
	#close the GROUPS array, add null last item
	echo "{} ]," >> $ACLS_PERMISSIONS_FILE

#close GROUPS, 
#start USERS
	BODY=" "\"'users'"\" : ["
	#write to the file and continue
	echo $BODY >> $ACLS_PERMISSIONS_FILE

	#loop through the users and add them to the file
	echo $PERMISSIONS | jq -r '.users|keys[]' | while read key; do

		_USER=$( echo $PERMISSIONS | jq ".users[$key]" )
		_UID=$( echo $_USER | jq -r ".uid" )
		USERURL=$( echo $_USER | jq -r ".userurl" )
		#these are the FIELDS of this USER (before further arrays)
		#prepare the body of this USER
		#and leave open for the next array
		BODY=" { \
"\"uid"\": "\"$_UID"\",\
"\"userurl"\": "\"$USERURL"\",
"\"actions"\": ["
		#write to the file and continue
		echo $BODY >> $ACLS_PERMISSIONS_FILE
		#actions is *YET ANOTHER* array, loop through it etc.
		#TODO: change for three-dimensional array instead of nested
		echo $_USER | jq -r '.actions|keys[]' | while read key; do

			ACTION=$( echo $_USER | jq -r ".actions[$key]" )
			NAME=$( echo $ACTION | jq -r ".name" )
			URL=$( echo $ACTION | jq -r ".url" )
			#prepare body of this ACTION to add it to file
			BODY=" { \
"\"name"\": "\"$NAME"\",\
"\"url"\": "\"$URL"\"\
},"
			#SLIGHT CHANGE TO THE SCHEMA TO ADD THE VALUE OF THE ACTION
			#to each action in the same JSON
			#get it from /acls/{rid}/users/{uid}/{action}
			ACTION_VALUE=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/acls/$_RID/users/$_UID/$NAME )
			#show progress after curl
			echo "OK."
			#response is already a JSON so we attach it directly
			BODY=$BODY$ACTION_VALUE" ,"		
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

#debug
echo "** DEBUG: SAVED ACL permission rules: "
cat $ACLS_PERMISSIONS_FILE | jq 

echo "Done."
