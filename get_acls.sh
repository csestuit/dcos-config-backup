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


USERS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_URL/acs/api/v1/acls)

touch $ACLS_FILE
echo $ACLS > $ACLS_FILE

echo "ACLs: $ACLS"
