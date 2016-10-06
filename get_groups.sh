DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme
GROUPS_FILE=./groups.txt


TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')


GROUPS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_URL/acs/api/v1/groups)

touch $GROUPS_FILE
echo $GROUPS > $GROUPS_FILE

echo "Done."
