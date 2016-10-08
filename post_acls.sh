#!/bin/bash
# Post a set of ACLs (Permission Rules) to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_permissions.sh" script.

#reference:
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid
#https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/#!/permissions/put_acls_rid_users_uid_action

#variables should be exported with run.sh, which should be run first
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token')


#loop through the list of ACL Rules
jq -r '.array|xs[]' $ACLS_FILE | while read x; do

	echo -e "*** Loading rule "$x" ..."	
	#get this rule
	RULE=$(jq ".array[$x]" $ACLS_FILE)
  	#extract fields
    _RID=$(echo $RULE | jq -r ".rid")
    URL=$(echo $RULE | jq -r ".url")
    DESCRIPTION=$(echo $RULE | jq -r ".description")
	#DEBUG
	echo -e "*** Rule "$x" is: "$_RID

    #add BODY for this RULE's fields
    BODY="{ \
"\"description"\": "\"$DESCRIPTION"\",\
}"
	echo -e "** DEBUG: Body *post-rule* "$_RID" is: "$BODY

	#Create this RULE
	echo -e "*** Posting RULE "x": "$_RID" ..."
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/$_RID )
	sleep 1

	#report result
 	echo "ERROR in creating RULE: "$_RID" was :"
	echo $RESPONSE| jq

	#loop through the list of Users that this Rule is associated to 
	jq -r '.user|ys[]' $RULE | while read y; do

		echo -e "*** Loading user "$y" ..."	
		#get this USER
		USER=$(jq ".array[$y]" $RULE)
		#extract fields. Users are only PATH, no more fields.
		_UID=$(echo $USER | jq -r ".uid")
		#DEBUG
		echo -e "*** User "$y" is: "_UID

		#no BODY -- just PATH
	
		#no need to create this USER either (no body)

		#report result
 		echo "ERROR in creating USER: "$_UID" was :"
		echo $RESPONSE| jq

		#loop through the list of Actions of this User/Rule has
		jq -r '.user|zs[]' $USER | while read z; do

			echo -e "*** Loading action "$z" ..."	
			#get this ACTION
			ACTION=$(jq ".array[$z]" $USER)
			#extract fields
			_AID=$(echo $ACTION | jq ".array[$z]" $ACTION)
    		ALLOWED=$(echo $ACTION | jq -r ".allowed")    	
  			#DEBUG
			echo -e "*** User "$y" is: "_UID

     		#add BODY for this RULE's fields
     		BODY="{ \
"\"allowed"\": "\"$ALLOWED"\",\
}"

			echo -e "** DEBUG: Body *post-action* "$_AID" is: "$BODY
    		
			#Create this ACTION
			echo -e "*** Posting ACTION "$_AID" to USER "_$UID" ..."
			RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d "$BODY" \
-X PUT \
http://$DCOS_IP/acs/api/v1/acls/_$RID/users/$_UID/$_AID )
			sleep 1

			#report result
 			echo "ERROR in creating ACTION: "$_AID" was :"
			echo $RESPONSE| jq

		#ACTIONS
		done
	#USERS
	done
#****TODO: repeat with groups
#RULES
done

echo "Done."