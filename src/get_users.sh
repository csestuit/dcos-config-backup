#!/bin/bash
#
# get_users.sh: retrieve and save configured users on a DC/OS cluster
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# Get a set of users configured in a running DC/OS cluster, and save
# them to a file in raw JSON format for backup and restore purposes.
# These can be restored into a cluster with the accompanying 
# "post_users.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/users/get_users

#Load configuration if it exists
#config is stored directly in JSON format in a fixed location
CONFIG_FILE=$PWD"/.config.json"
if [ -f $CONFIG_FILE ]; then

  DCOS_IP=$( cat $CONFIG_FILE | jq -r '.DCOS_IP' )
  USERS_FILE=$( cat $CONFIG_FILE | jq -r '.USERS_FILE' )
  USERS_GROUPS_FILE=$( cat $CONFIG_FILE | jq -r '.USERS_GROUPS_FILE' )
  TOKEN=$( cat $CONFIG_FILE | jq -r '.TOKEN' )

else

  echo "** ERROR: Configuration not found. Please run ./run.sh first"
  exit 1

fi

#get USERS
#GET /users
#TODO: I'm not getting (because they're not needed and this information is on the groups)
#GET /users/{UID}
USERS=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/users )
#show progress after curl
echo "OK."
#save to file
touch $USERS_FILE
echo $USERS > $USERS_FILE

#debug
echo "** DEBUG: SAVED Users: " && \
echo $USERS | jq '.array'

#initialize the file where the permissions will be stored
touch $USERS_GROUPS_FILE
echo "{ "\"array"\": [" > $USERS_GROUPS_FILE

#loop through the list of users in the USERS file
#for each user, get the a list of groups that the user is a member of
#GET /users/{uid}/groups
#TODO: I'm not getting:
#  /users/{uid}/permissions
jq -r '.array|keys[]' $USERS_FILE | while read key; do

	#extract fields from file
	_USER=$( jq ".array[$key]" $USERS_FILE )
	_UID=$( echo $_USER | jq -r ".uid" )
	#get the information of the groups of this particular user
	#at /users/{uid}/groups
	MEMBERSHIPS=$( curl \
-s \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_IP/acs/api/v1/users/$_UID/groups )
	#show progress after curl
	echo "OK."
	#Memberships is an array of the different groups that the user is a member of
	#loop through it
	#TODO: change for two-dimensional array instead of nested
	echo $MEMBERSHIPS | jq -r '.array|keys[]' | while read key; do

		MEMBERSHIP=$( echo $MEMBERSHIPS | jq ".array[$key]" )
		MEMBERSHIPURL=$( echo $MEMBERSHIP | jq -r '.membershipurl' )
		_GID=$( echo $MEMBERSHIP | jq -r '.group.gid' )
		URL=$( echo $MEMBERSHIP | jq -r '.group.url' )
		DESCRIPTION=$( echo $MEMBERSHIP | jq -r '.group.description' )
		#prepare body of this particular Membership to add it to file
		BODY=" { \
"\"uid"\": "\"$_UID"\",\
"\"membershipurl"\": "\"$MEMBERSHIPURL"\",\
"\"group"\": {\
"\"gid"\": "\"$_GID"\",\
"\"url"\": "\"$URL"\",\
"\"description"\": "\"$DESCRIPTION"\"} },"
		#once the Membership information has a BODY, save it
		echo $BODY >> $USERS_GROUPS_FILE

	done

done

#close the Users/Groups File with the correct formatting. Add a null last member to avoid comma issues
echo "{} ] }" >> $USERS_GROUPS_FILE

#debug
echo "** DEBUG: SAVED User to Group memberships: "
cat $USERS_GROUPS_FILE | jq 

echo "Done."
