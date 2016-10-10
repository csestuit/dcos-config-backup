#!/bin/bash
#
# get_groups.sh: retrieve and save configured groups on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of groups configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_groups.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/get_groups_gid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/groups/get_groups_gid_users

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

  DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
  GROUPS_FILE=$( cat $CONFIG_FILE | jq -r '.GROUPS_FILE' )
  GROUPS_USERS_FILE=$( cat $CONFIG_FILE | jq -r '.GROUPS_USERS_FILE' )
  TOKEN=$( cat $CONFIG_FILE | jq -r '.TOKEN' )


else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"

fi

#get GROUPS
_GROUPS=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/groups )
#save to file
touch $GROUPS_FILE
echo $_GROUPS > $GROUPS_FILE
#debug
echo "** Groups: "
echo $_GROUPS | jq

#get GROUPS_USERS: information about user membership for each group 
#these will be saved on a JSON file with array structure
#initialize the file where the users will be stored and add JSON header
touch $GROUPS_USERS_FILE
echo "{ "\"array"\": [" > $GROUPS_USERS_FILE

#loop through the list of groups in the GROUPS file
#for each group, get the a list of users that are members
jq -r '.array|keys[]' $GROUPS_FILE | while read key; do

	echo -e "** DEBUG: Loading GROUP "$key" ..."	
	#extract fields from file
	_GROUP=$( jq ".array[$key]" $GROUPS_FILE )
	_GID=$( echo $_GROUP | jq -r ".gid" )
	echo -e "** DEBUG: GROUP "$key" is: "$_GID
	#get the information of the members of this particular group
	#at /groups/{gid}/users
	MEMBERSHIPS=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/groups/$_GID/users )
	echo -e "** DEBUG: received MEMBERSHIPs are: "$MEMBERSHIPS
	#Memberships is an array of the different member users
	#loop through it
	#TODO: change for two-dimensional array instead of nested
	echo $MEMBERSHIPS | jq -r '.array|keys[]' | while read key; do

		MEMBERSHIP=$( echo $MEMBERSHIPS | jq ".array[$key]" )
		echo -e "** DEBUG: Memberships "$key" of group "_GID" is: "$MEMBERSHIP
		MEMBERSHIPURL=$( echo $MEMBERSHIP | jq -r '.membershipurl' )
		echo -e "** DEBUG: Membership URL "$key" is: "$MEMBERSHIPURL
		_UID=$( echo $MEMBERSHIP | jq -r '.user.uid' )
		echo -e "** DEBUG: UID "$key" is: "$_UID
		URL=$( echo $MEMBERSHIP | jq -r '.user.url' )
		echo -e "** DEBUG: URL "$key" is: "$URL
		DESCRIPTION=$( echo $MEMBERSHIP | jq -r '.user.description' )
		echo -e "** DEBUG: Description "$key" is: "$DESCRIPTION
		IS_REMOTE=$( echo $MEMBERSHIP | jq -r '.user.is_remote' )
		echo -e "** DEBUG: Is Remote "$key" is: "$IS_REMOTE
		IS_SERVICE=$( echo $MEMBERSHIP | jq -r '.user.is_service' )
		echo -e "** DEBUG: Is Service "$key" is: "$IS_SERVICE
		PUBLIC_KEY=$( echo $MEMBERSHIP | jq -r '.user.public_key' )
		echo -e "** DEBUG: Public Key "$key" is: "$PUBLIC_KEY
		#prepare body of this particular Membership to add it to file
		BODY=" { \
"\"membershipurl"\": "\"$MEMBERSHIPURL"\",\
"\"user"\": {\
"\"uid"\": "\"$_UID"\",\
"\"url"\": "\"$URL"\",\
"\"description"\": "\"$DESCRIPTION"\",\
"\"is_remote"\": "\"$IS_REMOTE"\",\
"\"is_service"\": "\"$IS_SERVICE"\",\
"\"public_key"\": "\"$PUBLIC_KEY"\" } },"
		#once the Membership information has a BODY, save it
		echo $BODY >> $GROUPS_USERS_FILE

	done

done

	
#close down the file with correct formatting. Add a last member to avoid comma issues
echo "{} ] }" >> $GROUPS_USERS_FILE

#debug
echo "** Group memberships: "
cat $GROUPS_USERS_FILE | jq 

echo "Done."
