DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme
USERS_FILE=./users.txt

#get token
TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

#get array of groups
USERS=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-X GET \
http://$DCOS_URL/acs/api/v1/users)

#save array of groups to file

#get first user
	USER0=$(echo $USERS | jq ".array[0]")
	UID="$(echo $USER0 | jq ".uid")
	IS_SERVICE=$(echo $USER0 | jq ".is_service")
	IS_REMOTE=$(echo $USER0 | jq ".is_remote")
	URL=$(echo $USER0 | jq ".url")
	DESCRIPTION=$(echo $USER0 | jq ".description")

#post first user to cluster
RESPONSE=$(curl \
-H "Content-Type:application/json" \
-H "Authorization: token=$TOKEN" \
-d '{"description": "'"$DESCRIPTION"'","password" :"deleteme"}
-X PUT \
http://$DCOS_URL/acs/api/v1/users/UID)

echo "PUT command response is: "$RESPONSE

