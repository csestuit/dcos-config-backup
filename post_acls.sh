#!/bin/bash
# Post a set of ACLs to a running DC/OS cluster, read from a file 
#where they're stored in raw JSON format as received from the accompanying
#"get_acls.sh" script.

DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme
ACLS_FILE=./acls.txt


TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

#read groups from file
echo "** Loading ACLs"
cat $ACLS_FILE > ACLS

#length of the array, -1 as it starts in zero / ordinal
LENGTH=i`$(cat ACLS | jq '.array | length') - 1`

#loop through the list of ACLs
echo "** Posting ACLs to cluster"
for i in {0..$LENGTH}
do
	THIS_ACL=$(echo $ACLS | jq ".array[i]")
	RID=$(echo $THIS_ACL | jq ".rid")
	URL=$(echo $THIS_ACL | jq ".url")
	DESCRIPTION=$(echo $THIS_ACL | jq ".description")

	#post each group to cluster
	RESPONSE=$( curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d '{"description": "'"$DESCRIPTION"'"}' \
-X PUT \
http://$DCOS_URL/acs/api/v1/acls/rid )

	#report result
	echo "\nResult of creating Rule: "$RID" was "$RESPONSE
done

echo "\nDone."
