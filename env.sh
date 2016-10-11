#!/bin/bash

# env: environment variables used for the functioning of the scripts

# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# These environment variables define the location and configuration values used 
# in the rest of the scripts. They're loaded upon running run.sh

#Configurable default values
DCOS_IP=127.0.0.1
USERNAME=bootstrapuser
PASSWORD=deleteme
DEFAULT_USER_PASSWORD=deleteme
DEFAULT_USER_SECRET=secret
WORKING_DIR=$PWD

#not exposed but saved
#config file is stored hidden in current directory, fixed location
CONFIG_FILE=$PWD"/.config.json"

#directories
DATA_DIR=$WORKING_DIR"/data"
SRC_DIR=$WORKING_DIR"/src"
BACKUP_DIR=$WORKING_DIR"/backup"

#data files
USERS_FILE=$DATA_DIR/users.json
USERS_GROUPS_FILE=$DATA_DIR/users_groups.json
GROUPS_FILE=$DATA_DIR/groups.json
GROUPS_USERS_FILE=$DATA_DIR/groups_users.json
ACLS_FILE=$DATA_DIR/acls.json
ACLS_PERMISSIONS_FILE=$DATA_DIR/acls_permissions.json
ACLS_GROUPS_FILE=$DATA_DIR/acls_groups.json
ACLS_GROUPS_ACTIONS_FILE=$DATA_DIR/acls_groups_actions.json
ACLS_USERS_FILE=$DATA_DIR/acls_users.json
ACLS_USERS_ACTIONS_FILE=$DATA_DIR/acls_users_actions.json

#scripts
GET_USERS=$SRC_DIR"/get_users.sh"
GET_GROUPS=$SRC_DIR"/get_groups.sh" 
GET_ACLS=$SRC_DIR"/get_acls.sh"
POST_USERS=$SRC_DIR"/post_users.sh"
POST_GROUPS=$SRC_DIR"/post_groups.sh"
POST_ACLS=$SRC_DIR"/post_acls.sh" 

#formatting env vars
#clear screen
CLS='printf \033c'
#pretty colours
RED='\033[0;31m'
BLUE='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
#symbols
PASS="${GREEN}\xE2\x9C\x93${NC}"
FAIL="${RED}\xE2\x9C\x97${NC}"
SKULL="\xE2\x98\xA0"

#state vars for options menu (to check whether things have been done and finished OK)
#initialized to FAIL (not done)
GET_USERS_OK=$FAIL
GET_GROUPS_OK=$FAIL
GET_ACLS_OK=$FAIL
POST_USERS_OK=$FAIL
POST_GROUPS_OK=$FAIL
POST_ACLS_OK=$FAIL