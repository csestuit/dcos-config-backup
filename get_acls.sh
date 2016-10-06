#!/bin/bash
# Get a set of ACLs configured in a running DC/OS cluster, and save
#them to a file in raw JSON format for backup and restore purposes.
#These can be restored into a cluster with the accompanying 
#"post_acls.sh" script.

#variables should be exported with launch.sh
#TODO: add check

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')


ACLS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_URL/acs/api/v1/acls)

touch $ACLS_FILE
echo $ACLS > $ACLS_FILE

echo "\nACLs: " $(echo $ACLS | jq)
echo "\nDone."