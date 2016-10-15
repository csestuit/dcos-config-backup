# DC/OS - IAM Config Backup and Restore Utility

This is a launcher program and a set of auxiliary scripts to backup and restore the Identity and Access Management information from a DC/OS cluster. This is useful to re-create the cluster somewhere else from scratch and preserve users/groups/memberships/acls/permission information.

It uses the DC/OS REST API as documented here: https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/

# Usage

Clone this repo and launch the `run.sh` launcher to use the script interactively:

```
git clone https://github.com/fernandosanchezmunoz/dcos-config-backup/
cd dcos-config-backup
./run.sh
```

The user is then presented with a first login screen where the connection to DC/OS can be configured, including:

* *DC/OS IP address or DNS* - Address to contact DC/OS at, without quotes or `http(s)://` headers.
* *DC/OS username* - username to log into the DC/OS cluster with.
* *DC/OS password* - password to log into the DC/OS cluster with.
* *Default password for restored users* - when restoring user information to a running DC/OS cluster, the password for those users must be reset. This is the value that all user's passwords will be set to.

With this information, the script tries to log into the DC/OS cluster and obtain an authentication token that will be used for the rest of the session. If the login is not successful, the script will exit.

Upon successfully logging into the DC/OS cluster, the user is presented with a second screen where he can interact with the cluster to backup or restore its configuration.

This program uses a ***_local buffer_*** to temporarily store in memory:

* the information received from a cluster (before writing it to disk for backup) or, 
* the information loaded from disk (before posting it to a running cluster to restore it) 

The local buffer is always empty upon launching the program. The user is presented with options to:

* ***LOAD/SAVE*** configurations to/from disk into local buffer:
  - to list a (D)IRECTORY of the configurations available on disk (the program ships with an `example` configuration to experiment with)
  - to (L)OAD previously saved configurations to the local buffer, in order to VERIFY it before POSTing it to a running DC/OS, or
  - to (S)AVE the configuration currently running in the local buffer, possibly after having done some type of GET operation to obtain the currently running configuration in the cluster.
   
* ***GET*** information from a running DC/OS instance into the local buffer (to verify it or as a previous step to save it later to disk):
  - to update the local buffer with information obtained from DC/OS, either:
    - the list of USERS currently configured in the cluster (which does NOT include their passwords, by design).
    - the list of GROUPS currently configured in the cluster, along with their USER-to-GROUP membership rules.
    - the list of ACLs (Access Control Lists), including their associated Permissions.
    or
    - an automated FULL GET of all the parameters above.
    
* ***POST*** information to a running DC/OS instance from the local buffer, either:
    - the list of USERS currently stored in the local buffer (all USER passwords will be set to the DEFAULT value entered in the first screen).
    - the list of GROUPS currently stored in the local buffer, along with their USER-to-GROUP membership rules in the local buffer.
    - the list of ACLs (Access Control Lists), including their associated Permissions as stored in the local buffer.
    or
    - an automated FULL POST of all the parameters above as stored in the local buffer in that moment.
    
* ***VERIFY*** the information currently stored in the local buffer, possibly before either SAVING it to disk, or before POSTing it to a running DC/OS cluster.
    - verify the list of USERS in local buffer
    - verify the list of GROUPS (and memberships) in local buffer
    - verify the list of ACLs (and permissions) in local buffer
    - verify the program's current CONFIGURATION (including DC/OS IP, username, password, and default user password to be used when restoring).
    
* ***EXIT*** the program, cleaning the local buffer.

# Structure and development

The program uses the following internal structure of directories and files:

* ***`./run.sh`*** - The main executable that launches the program. Reads the environment variables, receives the configuration and presents an interactive menu to launch each function as one of the auxiliary scripts described below.

* ***`./env.sh`*** - Includes environment variables and fixed file/directory locations for internal scripts to use.

* ***`./.config.json`*** - Hidden configuration buffer file. Generated on startup, stores the program configuration used to connect to the cluster. Includes the cluster's IP, username, password, authentication token obtained upon login, and also all the auxiliary scripts and storage files locations (local buffer location, and also the location to load/save other configurations).

* ***`./src/*`*** - Stores the auxiliary scripts that perform the actual GET and POST commands. The program has been designed to be completely modular, so that each auxiliary script is completely independent from each other:

  - ***`./src/get_users.sh`*** - reads the program configuration, gets the USER information from the cluster and stores in local buffer.
  - ***`./src/get_groups.sh`*** - reads the program configuration, gets the GROUP information, along with the USER-to-GROUP membership information from the cluster and stores them in local buffer.  
  - ***`./src/get_acls.sh`*** - reads the program configuration, gets the ACL information, along with the PERMISSIONs information in each ACL from the cluster and stores them in local buffer.  
  - ***`./src/post_users.sh`*** - reads the program configuration, reads the USER information from the local buffer, and posts it to the DC/OS cluster.
  - ***`./src/post_groups.sh`*** - reads the program configuration, reads the GROUP information from the local buffer, along with the USER-to-GROUP membership information, and posts it to the DC/OS cluster.
  - ***`./src/post_acls.sh`*** - reads the program configuration, reads the ACL information from the local buffer, along with the PERMISSION information for each rule, and posts it to the DC/OS cluster.

* ***`./data/*`*** - Directory generated on launch and cleaned on exit, stores the local buffer:
  
  All information is stored in clear JSON, as it's obtained from the DC/OS cluster and defined on the DC/OS information schemas. The exception is the `acls_permission.json` file, where information about the Permissions associated with each ACL is stored along with the Action names associated with each Permission, for convenience purposes. 

  - ***`./data/users.json`*** - Includes a list of the USERs in the system with their attributes.
  - ***`./data/users_groups.json`*** - Includes a list of the USER-to-GROUP associations corresponding with the list of users in the previous file.
  - ***`./data/groups.json`*** - Includes a list of the GROUPs in the system with their attributes.
  - ***`./data/groups_users.json`*** - Includes a list of the GROUP-to-USER associations corresponding with the list of groups in the previous file.
  - ***`./data/acls.json`*** - Includes a list of the ACLs in the system with their attributes.
  - ***`./data/acl_permissions.json`*** - Includes a list of the PERMISSIONs associated with the list of acls in the previous file. Each PERMISSION is also stored with its corresponding list of ACTIONs.

* ***`./backup/*`*** - Stores the saved configurations

  Each configuration is saved in a subdirectory of its own, incuding all JSON files with the configuration running in the local buffer at the moment of saving. Each configuration's internal sctructure is a copy of the `./data/*` local buffer directory state in the moment of SAVING the configuration.

  - ***`./backup/example/*/*`*** - the program ships with an example configuration to facilitate testing/validation.
  
Please check the documentation in the code for further details.

#TODO

- "Non-interactive mode" - The program would accept an IP address and configuration name as arguments, and would support "get" and "post" options. The invocation format would be:

```
usage: ./run.sh [options] DCOS_IP configuration_name
  options:
    -g, --get   Loads a full configuration stored under "configuration_name" and posts it to the DC/OS cluster running in "DCOS_IP"
    -p, --post  Gets a full configuration from the DC/OS cluster running in "DCOS_IP", and saves it under "configuration_name"
```

- Rewriting/refactoring - The program is modular so that each internal script can be written in a different language independently. Moving each module to Python for cleanliness and future maintenance should be feasible.

- Augment - Augment the program to other pieces of the DC/OS system: Networking configuration, Marathon app groups, etc.
