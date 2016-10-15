# DC/OS - Config Backup and Restore Utility

This is a set of scripts to backup and restore the Identity and Access Management information from a DC/OS cluster. It uses the DC/OS REST API as documented here: https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/

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

This program uses a *local buffer* to temporarily store in memory:

* the information received from a cluster (before writing it to disk for backup)
or 
* the information loaded from disk (before posting it to a running cluster to restore it) 

The local buffer is always empty upon launching the program. The user is presented with options to:

* *LOAD/SAVE* configurations to/from disk into local buffer:
  - to list a (D)IRECTORY of the configurations available on disk (the program ships with an `example` configuration to experiment with)
  - to (L)OAD previously saved configurations to the local buffer, in order to VERIFY it before POSTing it to a running DC/OS
  or
  - to (S)AVE the configuration currently running in the local buffer, possibly after having done some type of GET operation to obtain the currently running configuration in the cluster.
   
* *GET* information from a running DC/OS instance into the local buffer (to verify it or as a previous step to save it later to disk):
  - to update the local buffer with information obtained from DC/OS, either:
    - the list of USERS currently configured in the cluster (which does NOT include their passwords, by design).
    - the list of GROUPS currently configured in the cluster, along with their USER-to-GROUP membership rules.
    - the list of ACLs (Access Control Lists), including their associated Permissions.
    or
    - an automated FULL GET of all the parameters above.
    
* *POST* information to a running DC/OS instance from the local buffer, either:
    - the list of USERS currently stored in the local buffer (all USER passwords will be set to the DEFAULT value entered in the first screen).
    - the list of GROUPS currently stored in the local buffer, along with their USER-to-GROUP membership rules in the local buffer.
    - the list of ACLs (Access Control Lists), including their associated Permissions as stored in the local buffer.
    or
    - an automated FULL POST of all the parameters above as stored in the local buffer in that moment.
    
* *VERIFY* the information currently stored in the local buffer, possibly before either SAVING it to disk, or before POSTing it to a running DC/OS cluster.
    - verify the list of USERS in local buffer
    - verify the list of GROUPS (and memberships) in local buffer
    - verify the list of ACLs (and permissions) in local buffer
    - verify the program's current CONFIGURATION (including DC/OS IP, username, password, and default user password to be used when restoring).
    
* *EXIT* the program, cleaning the local buffer.


