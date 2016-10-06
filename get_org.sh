

#get auth token
#get new token with username and password
MASTER=172.31.3.244
USERNAME="bootstrapuser"
PASSWORD="deleteme"

curl \
--data '{"uid":$USERNAME,"password":$PASSWORD}' \
--header "Content-Type:application/json" \
http://$MASTER/acs/api/v1/auth/login
{
 "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOiIxNDYyODQ2NTY1IiwidWlkIjoiYm9vdHN0cmFwdXNlciJ9.lwRX9QgZU8HVYhCBIo4VlcHBrXDxUPX7tLSnKJWop5s"
}


curl \
-H "Content-Type: application/json" \
-H "Authorization: token=eyJhbGciOiJIUzI1NiIsImtpZCI6InNlY3JldCIsInR5cCI6IkpXVCJ9.eyJhdWQiOiIzeUY1VE9TemRsSTQ1UTF4c3B4emVvR0JlOWZOeG05bSIsImVtYWlsIjoiZmVybmFuZG9AbWVzb3NwaGVyZS5pbyIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJleHAiOjEuNDMDE4OTM1ZSswOSwiaWF0IjoxLjQ3MDU4NjkzNWUrMDksImlzcyI6Imh0dHBzOi8vZGNvcy5hdXRoMC5jb20vIiwic3ViIjoiZ2l0aHVifDQyNjYzMTgiLCJ1aWQiOiJmZXJuYW5kb0BtZXNvc3BoZXJlLmlvIn0.wM22Bt5xQ1NITEF2ZAkn7x-KcNBMBncSvx8_A6BycIQ" \
-X POST \
http://awsmaster/mesos/slaves \
|jq
