#DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme
USERS_FILE=./users.txt


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
http://$DCOS_URL/acs/api/v1/users)

touch $USERS_FILE
echo $USERS > $USERS_FILE

echo" Users: $USERS"
