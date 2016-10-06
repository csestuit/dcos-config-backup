#!/bin/bash
# Get an authentication token from a DC/OS cluster from username/pass

DCOS_URL=172.31.3.244
USERNAME=bootstrapuser
PASSWORD=deleteme

TOKEN=$(curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST	\
http://$DCOS_URL/acs/api/v1/auth/login \
| jq -r '.token')

echo "Token is: "$(echo $$TOKEN | jq)
echo "Done."
