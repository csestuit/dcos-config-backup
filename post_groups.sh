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

#read groups from file
cat $GROUPS_FILE > GROUPS


#get first roup

echo "Done."
