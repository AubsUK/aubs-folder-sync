# aubs-folder-sync
  Custom script to synchronise folders between two hosts<br/>
  https://github.com/AubsUK/aubs-folder-sync


# Contents
[Top of Page](#aubs-folder-sync)<br/>
[Information](#information)<br/>
[Prerequisites](#prerequisites)<br/>
[Quick Start](#quick-start)<br/>
[Configurable Options](#configurable-options)<br/>
[Files Used and Created](#files-used-and-created)<br/>
[Planned changes](#planned-changes-in-no-particular-order)<br/>
[Example outputs](#example-outputs)<br/>
[Removal](#removal)<br/>
[Nginx and KeepAlive installation](#Nginx-and-KeepAlive-installation)<br/>
[Notes](#notes)<br/>

<br/><br/>


# Information
|[Back to top](#aubs-folder-sync)|<br/><br/>
This is a simple script which monitors folders for changes and (almost) instantly synchronises it with other servers.
It was born primarily through the need for a mechanism to synchronise configuration files between multiple servers used as failover Nginx reverse proxies.
- Runs automatically as a service (systemd)
- Allows monitoring and syncing of multiple folders
- Allows excluding certain files/folders (by regex)


<br/><br/>

# Prerequisites
|[Back to top](#aubs-folder-sync)|<br/><br/>
There are a few prerequisites, but they should be relatively simple.
* First: on all remote server(s), create service account, give sudo access, limit passwordless sudo to specific commands, allow it to log in via password.
* Second: on the primary server, pass its root account public key to each of the remote server(s).
* Third: on the primary server, install rsync and git.
* Fourth: on all remote server(s) remove the service account ability to log in with a password and lock the password.
* Fifth: on all remote server(s) install rsync.

## On the remote server(s)

1. Create a new user account with a temporary password (we'll remove it later)
    ```
    sudo useradd -m aubs-folder-sync -s /bin/bash
    sudo passwd aubs-folder-sync
    ```
2. Add it to sudoers and allow it to run select packages as sudo without a password
    ```
    sudo usermod -aG sudo aubs-folder-sync
    ```
3. Allow the account to run specific packages with sudo, but without requiring a password
    ```
    sudo nano /etc/sudoers.d/aubs-folder-sync
    ```
    Add in
    ```
    aubs-folder-sync ALL=NOPASSWD:/usr/bin/rsync<br>
    aubs-folder-sync ALL=NOPASSWD:/usr/sbin/service
    ````
4. Reload sudo config
    ```
    sudo /etc/init.d/sudo reload
    ```
5. Edit the sshd configuration
    ```
    sudo nano /etc/ssh/sshd_config
    ```
    Add aubs-folder-sync to the permit (add this to the bottom or if you've used Match User before, edit it there - NOTE: add your username in to the match or you might be locked out!)
    ```
    Match User aubsuk,aubs-folder-sync<br>
        PasswordAuthentication yes<br>
    Match User *<br>
        PasswordAuthentication no
    ```
6. Restart SSH service
    ```
    sudo service ssh restart
    ```
7. Repeat all the steps in items 1-6 on each of the 'remote' servers.

## On the primary server

Configure root SSH Access from the primary server to all remote server(s)
1. Check if an RSA key already exists
    ```
    sudo cat /root/.ssh/id_rsa.pub
    ```

2. IF IT DOES, DO NOT DO THE NEXT STEP
    1. Create a new RSA key (accept the defaults)
        ```
        sudo ssh-keygen -t rsa -b 4096
        ```
    2. View the key again
        ```
        sudo cat /root/.ssh/id_rsa.pub
        ```
3. Copy the key to the remote server(s)
    ```
    sudo ssh-copy-id -p 22122 aubs-folder-sync@192.168.1.20
    ```

4. Try and SSH to the remote server(s)
    ```
    sudo ssh -p '22122' 'aubs-folder-sync@192.168.1.20'
    ```
5. If you've logged in successfully, log out back to the primary server
    ```
    exit
    ```
6. Repeat steps 1-5 on the primary server for each of the 'remote' servers (Note: Step 2 should only ever need to be done once, if it doesn't already exist).
7. Install rsync and git
    ```
    sudo apt update
    sudo apt install rsync git
    ```

## On the remote server(s)

1. Remove aubs-folder-sync from login
    ```
    sudo nano /etc/ssh/sshd_config
    ```
    Remove aubs-folder-sync:
    ```
    Match User aubsuk
    ```
2. Restart SSH service
    ```
    sudo service ssh restart
    ```
3.	Remove password for aubs-folder-sync (lock prevents it from being used, delete leaves the account with no password and it could still log in)
    ```
    sudo passwd --lock aubs-folder-sync
    ```
4.	Install rsync
    ```
    sudo apt install rsync
    ```





<br/><br/>

# Quick Start
|[Back to top](#aubs-folder-sync)|<br/><br/>
1. Make sure all the prerequisites are set up.

2. Change directory to a secure location to hold the script
    ```
    cd /usr/local/sbin/
    ```

3. Clone the repository as root so permissions are set appropriately
    ```
    sudo git clone https://github.com/AubsUK/aubs-folder-sync
    ```
    or just create the folder and two files manually, and copy their contents

4. Make the script executable
    ```
    cd aubs-folder-sync
    sudo chmod 700 aubs-folder-sync.sh
    ```

5. Create a symbolic link for the service file; enable then start the service
    ```
    sudo ln -s /usr/local/sbin/aubs-folder-sync/aubs-folder-sync.service /etc/systemd/system/aubs-folder-sync.service
    sudo systemctl enable aubs-folder-sync.service
    sudo systemctl start aubs-folder-sync.service
    sudo systemctl status aubs-folder-sync.service
    ```
    NOTE: If the service is ever disabled, the symbolic link wil need to be re-created, so run the 4 lines of code again
6.	Testing  
    Edit, create and delete a file on the Primary server, while watching the journal and log file:
    1. Follow the journal (because rsync has -v, it'll show in the journal)
        ```
        sudo journalctl -f -u aubs-folder-sync.service
        ```
    2. Follow the log file
        ```
        sudo follow -f /var/log/aubs-folder-sync
        ```
    3. On the remote server(s) watch one folder being sync'd
       ```
       sudo watch ls -al /etc/nginx/
       ```
    4. On the Primary server, create/delete/modify
       ```
       sudo touch /etc/nginx/TEST-FILE01
       sudo touch /etc/nginx/TEST-FILE02
       sudo echo "test1" > /etc/nginx/TEST-FILE01
       sudo echo "test2" > /etc/nginx/TEST-FILE02
       sudo rm /etc/nginx/TEST-FILE01
       sudo rm /etc/nginx/TEST-FILE02
       ```


<br/><br/>

# Files Used and Created

|[Back to top](#aubs-folder-sync)|<br/><br/>

Following the Quick Start instructions and not modifying any variables, the following files are used:

## On the primary server

### /usr/local/sbin/aubs-folder-sync/

<table>
<tr><th>File Name</th><th>Purpose</th></tr>
<tr>
<td>aubs-folder-sync.sh</td>
<td>The script file</td>
</tr>
<tr>
<td>aubs-folder-sync.service</td>
<td>The service file</td>
</tr>
<tr>
<td>aubs-folder-sync.tmp.reasons</td>
<td>Contains a list of the reason, file and directory modified since the last run</td>
</tr>
<tr>
<td>aubs-folder-sync.tmp.running</td>
<td>Contains a count of the number of runs required, so the script knows if it needs to re-run</td>
</tr>
<tr>
<td>
.git/ (folder and all sub files)
<br>
images/ (folder and all sub files)
<br>
LICENSE<br>README.md<br>
</td>
<td>Git files, not used by the script</td>
</tr>

</table>


### /var/log/
<table>
<tr><th>File Name</th><th>Purpose</th></tr>
<td>aubs-folder-sync.log</td>
<td>Stores the logs from each run</td>
</tr>
</table>

## On the remote server(s)

### /home/aubs-folder-sync/

<table>
<tr><th>File Name</th><th>Purpose</th></tr>
<tr>
<td>various</td>
<td>Various files created for a standard user</td>
</tr>
<tr>
<td>.ssh/authorized_key</td>
<td>The service file</td>
</tr>
</table>

### /etc/sudoers.d/

<table>
<tr><th>File Name</th><th>Purpose</th></tr>
<tr>
<td>aubs-folder-sync</td>
<td>List of packages the account can run as sudo, but without having to enter a password</td>
</tr>
</table>

<br/><br/>

# Configurable Options

|[Back to top](#aubs-folder-sync)|<br/><br/>
<table>
<tr><th>Variable</th><th>Description</th><th>Default</th></tr>
<tr>
<td colspan=3>

### Basic settings

</td>
</tr>
<tr>
<td>

`FOLDERS_TO_SYNC`

</td>
<td>
List of folders to monitor and sync.  Multiple folders can be added in the format ("/path/to/" "/another/path/")
</td>
<td>
("/etc/nginx/")
</td>
</tr>
<tr>
<td>

`FILES_TO_IGNORE_REGEX`

</td>
<td>
Files can be excluded using regex format e.g. ".*\.swp|.*\.tmp"
</td>
<td>
".*\.swp"
</td>
</tr>
<tr>
<td>

`SERVERS_TO_REFRESH`

</td>
<td>
List of servers (IP/hostname) to synchronise from this server
</td>
<td>
("192.168.1.233")
</td>
</tr>
<tr>
<td>

`REMOTE_PORT`

</td>
<td>
Specify the SSH port to be used for the remote servers
</td>
<td>
"22122"
</td>
</tr>
<tr>
<td>

`REMOTE_USER`

</td>
<td>
Speficy the user that will be used for the SSH connections
</td>
<td>
"aubs-folder-sync"
</td>
</tr>
<tr>
<td>

`REMOTE_COMMANDS`

</td>
<td>
Commands to run on the remote servers after synchronising
</td>
<td>
"service nginx restart"
</td>
</tr>
<tr>
<td>

`LOGFILE_LOCATION`

</td>
<td>
Full pat for the log file
<td>
"/var/log/aubs-folder-sync.log"
</td>
</tr>
<tr>
<td colspan=3>

### Temporary Files (created on each run, not deleted)

</td>
</tr>
<tr>
<td>

`TEMP_REASONS`

</td>
<td>
Path where the reason the script is being executed are stored
</td>
<td>
  
`"$PWD/aubs-folder-sync.tmp.reasons"`

</td>
</tr>
<tr>
<td>

`TEMP_RUNNING`

</td>
<td>
Path where the reason the script is being executed are stored
</td>
<td>

`"$PWD/aubs-folder-sync.tmp.running"`

</td>
</tr>
<tr>
<td>

`RECIPIENT_EMAIL`

</td>
<td>
Recipient email address<br/>(multuple recipients separated by commas)
</td>
<td>

Automatically configured to `servers@domain.co.uk`<br/>(where domain.co.uk is provided automatically from `hostname -d`)

</td>
</tr>
<tr>
<td>

`RUNNING_COUNT`

</td>
<td>
DESC
</td>
<td>

DEFAULT

</td>
</tr>
<tr>
<td>

`FOLDER_NOT_EXIST`

</td>
<td>
Holds false or true.  When the script initialises, if any of the folders don't exist, this will change to true and the script will stop executing.
</td>
<td>

`false`

</td>
</tr>
<tr>
<td colspan=3>

### Packages used

</td>
</tr>
<tr>
<td>

`inotifywait`
<br>
`rsync`
<br>
`ssh`

</td>
<td>
Location of the main packages used.  These should normally be installed, but if not, it'll report in the log and stop running
</td>
<td>

$(which inotifywait)
<br>
$(which rsync)
<br>
$(which ssh)

</td>
</tr>
<tr>

</table>

<br/><br/>


# Testing
|[Back to top](#aubs-folder-sync)|<br/><br/>
Testing options

No testing elements yet


<br/><br/>


# Planned changes (in no particular order)
|[Back to top](#aubs-folder-sync)|<br/><br/>
1. What to do if unable to rsync or ssh - sleep/retry/fork process/continuous/email?
2. rsync/ssh just directories that contain changes (may need to consider storing
3. Split each server to have their own directory/port/user config (i.e. host port user /folder1/ /folder2, 192.168.1.20 22122 aubs-folder-sync /etc/nginx/, 192.168.1.30 22 aubs /etc/nginx/ /etc/pihole/)
4. Check packages are installed (as per Packages used above)
5. Email notification
6. Testing options
7. Running on multiple servers to sync between each other both ways (notes --delete would need to be removed because on startup could delete on remote before remote retries)
8. Restrict what the remote server account can and can't do
9. 

<br/><br/>


# Example outputs
|[Back to top](#aubs-folder-sync)|<br/><br/>
<br/>

## Log file output on start
```
Tue Aug 29 04:52:12 AM UTC 2023: ==================================================
Tue Aug 29 04:52:12 AM UTC 2023: ================= Service Started ================
Tue Aug 29 04:52:12 AM UTC 2023: All folders checked ok.
Tue Aug 29 04:52:12 AM UTC 2023: Starting First Run
Tue Aug 29 04:52:12 AM UTC 2023: --------------------------------------------------
Tue Aug 29 04:52:12 AM UTC 2023: Sync Folders: '/etc/nginx/'
Tue Aug 29 04:52:12 AM UTC 2023: Refresh Servers: '192.168.1.20'
Tue Aug 29 04:52:12 AM UTC 2023: Remote Commands: 'sudo service nginx restart'
Tue Aug 29 04:52:12 AM UTC 2023: Remote User: 'aubs-folder-sync'
Tue Aug 29 04:52:12 AM UTC 2023: Reason: (1) - 1 First Run validating sync
Tue Aug 29 04:52:12 AM UTC 2023: Synchronising to 192.168.1.20
Tue Aug 29 04:52:13 AM UTC 2023: Sync success.
Tue Aug 29 04:52:13 AM UTC 2023: Running commands on server 192.168.1.20
Tue Aug 29 04:52:14 AM UTC 2023: Commands completed.
Tue Aug 29 04:52:14 AM UTC 2023: Done
Tue Aug 29 04:52:14 AM UTC 2023: Synchronise complete.
```
```
Aug 29 04:52:12 proxy01 systemd[1]: Started aubs-folder-sync.service - aubs-folder-sync.
Aug 29 04:52:13 proxy01 aubs-folder-sync.sh[125056]: sending incremental file list
Aug 29 04:52:13 proxy01 aubs-folder-sync.sh[125056]: /etc/
Aug 29 04:52:13 proxy01 aubs-folder-sync.sh[125056]: sent 1,169 bytes  received 29 bytes  798.67 bytes/sec
Aug 29 04:52:13 proxy01 aubs-folder-sync.sh[125056]: total size is 25,556  speedup is 21.33
```

## Successful log file output on multiple file changes (Multiple CREATE in quick succession)
```
Tue Aug 29 05:05:37 AM UTC 2023: --------------------------------------------------
Tue Aug 29 05:05:37 AM UTC 2023: Sync Folders: '/etc/nginx/'
Tue Aug 29 05:05:37 AM UTC 2023: Refresh Servers: '192.168.1.20'
Tue Aug 29 05:05:37 AM UTC 2023: Remote Commands: 'sudo service nginx restart'
Tue Aug 29 05:05:37 AM UTC 2023: Remote User: 'aubs-folder-sync'
Tue Aug 29 05:05:37 AM UTC 2023: Reason: (2) - 1 CREATE /etc/nginx/TEST-FILE01 2 CREATE /etc/nginx/TEST-FILE02
Tue Aug 29 05:05:37 AM UTC 2023: Synchronising to 192.168.1.20
Tue Aug 29 05:05:38 AM UTC 2023: Sync success.
Tue Aug 29 05:05:38 AM UTC 2023: Running commands on server 192.168.1.20
Tue Aug 29 05:05:39 AM UTC 2023: Commands completed.
Tue Aug 29 05:05:39 AM UTC 2023: Done
Tue Aug 29 05:05:39 AM UTC 2023: Synchronise complete.
```
```
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: sending incremental file list
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: /etc/nginx/
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: /etc/nginx/TEST-FILE01
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: /etc/nginx/TEST-FILE02
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: sent 1,289 bytes  received 71 bytes  906.67 bytes/sec
Aug 29 05:05:38 proxy01 aubs-folder-sync.sh[125914]: total size is 25,556  speedup is 18.79
```

## Successful log file output on file change (MODIFY)
```
Tue Aug 29 05:06:00 AM UTC 2023: --------------------------------------------------
Tue Aug 29 05:06:00 AM UTC 2023: Sync Folders: '/etc/nginx/'
Tue Aug 29 05:06:00 AM UTC 2023: Refresh Servers: '192.168.1.20'
Tue Aug 29 05:06:00 AM UTC 2023: Remote Commands: 'sudo service nginx restart'
Tue Aug 29 05:06:00 AM UTC 2023: Remote User: 'aubs-folder-sync'
Tue Aug 29 05:06:00 AM UTC 2023: Reason: (1) - 1 MODIFY /etc/nginx/TEST-FILE01
Tue Aug 29 05:06:00 AM UTC 2023: Synchronising to 192.168.1.20
Tue Aug 29 05:06:01 AM UTC 2023: Sync success.
Tue Aug 29 05:06:01 AM UTC 2023: Running commands on server 192.168.1.20
Tue Aug 29 05:06:02 AM UTC 2023: Commands completed.
Tue Aug 29 05:06:02 AM UTC 2023: Done
Tue Aug 29 05:06:02 AM UTC 2023: Synchronise complete.
```
```
Aug 29 05:06:01 proxy01 aubs-folder-sync.sh[125977]: sending incremental file list
Aug 29 05:06:01 proxy01 aubs-folder-sync.sh[125977]: /etc/nginx/TEST-FILE01
Aug 29 05:06:01 proxy01 aubs-folder-sync.sh[125977]: sent 1,318 bytes  received 68 bytes  924.00 bytes/sec
Aug 29 05:06:01 proxy01 aubs-folder-sync.sh[125977]: total size is 25,568  speedup is 18.45
```

## Successful log file output on multiple file change (multiple DELETE in slow succession)
```
Tue Aug 29 05:06:21 AM UTC 2023: --------------------------------------------------
Tue Aug 29 05:06:21 AM UTC 2023: Sync Folders: '/etc/nginx/'
Tue Aug 29 05:06:21 AM UTC 2023: Refresh Servers: '192.168.1.20'
Tue Aug 29 05:06:21 AM UTC 2023: Remote Commands: 'sudo service nginx restart'
Tue Aug 29 05:06:21 AM UTC 2023: Remote User: 'aubs-folder-sync'
Tue Aug 29 05:06:21 AM UTC 2023: Reason: (1) - 1 DELETE /etc/nginx/TEST-FILE01
Tue Aug 29 05:06:21 AM UTC 2023: Synchronising to 192.168.1.20
Tue Aug 29 05:06:22 AM UTC 2023: Sync success.
Tue Aug 29 05:06:22 AM UTC 2023: Running commands on server 192.168.1.20
Tue Aug 29 05:06:22 AM UTC 2023: Commands completed.
Tue Aug 29 05:06:22 AM UTC 2023: Done
Tue Aug 29 05:06:22 AM UTC 2023: Synchronise complete.
Tue Aug 29 05:06:22 AM UTC 2023: --------------------------------------------------
Tue Aug 29 05:06:22 AM UTC 2023: Sync Folders: '/etc/nginx/'
Tue Aug 29 05:06:22 AM UTC 2023: Refresh Servers: '192.168.1.20'
Tue Aug 29 05:06:22 AM UTC 2023: Remote Commands: 'sudo service nginx restart'
Tue Aug 29 05:06:22 AM UTC 2023: Remote User: 'aubs-folder-sync'
Tue Aug 29 05:06:22 AM UTC 2023: Reason: (1) - 1 DELETE /etc/nginx/TEST-FILE02
Tue Aug 29 05:06:22 AM UTC 2023: Synchronising to 192.168.1.20
Tue Aug 29 05:06:23 AM UTC 2023: Sync success.
Tue Aug 29 05:06:23 AM UTC 2023: Running commands on server 192.168.1.20
Tue Aug 29 05:06:24 AM UTC 2023: Commands completed.
Tue Aug 29 05:06:24 AM UTC 2023: Done
Tue Aug 29 05:06:24 AM UTC 2023: Synchronise complete.
```
```
Aug 29 05:06:03 proxy01 aubs-folder-sync.sh[126020]: total size is 25,568  speedup is 20.62
Aug 29 05:06:22 proxy01 aubs-folder-sync.sh[126076]: sending incremental file list
Aug 29 05:06:22 proxy01 aubs-folder-sync.sh[126076]: deleting etc/nginx/TEST-FILE01
Aug 29 05:06:22 proxy01 aubs-folder-sync.sh[126076]: /etc/nginx/
Aug 29 05:06:22 proxy01 aubs-folder-sync.sh[126076]: sent 1,199 bytes  received 54 bytes  835.33 bytes/sec
Aug 29 05:06:22 proxy01 aubs-folder-sync.sh[126076]: total size is 25,562  speedup is 20.40
Aug 29 05:06:23 proxy01 aubs-folder-sync.sh[126117]: sending incremental file list
Aug 29 05:06:23 proxy01 aubs-folder-sync.sh[126117]: deleting etc/nginx/TEST-FILE02
Aug 29 05:06:23 proxy01 aubs-folder-sync.sh[126117]: /etc/nginx/
Aug 29 05:06:23 proxy01 aubs-folder-sync.sh[126117]: sent 1,169 bytes  received 54 bytes  815.33 bytes/sec
Aug 29 05:06:23 proxy01 aubs-folder-sync.sh[126117]: total size is 25,556  speedup is 20.90
```

<br/><br/>

# Removal
|[Back to top](#aubs-folder-sync)|<br/><br/>
If you installed the script using the prerequisites and quick start guide, it's pretty easy to remove.

1. Stop the service and disable it (this will remove the symbolic link)
    ```
    sudo systemctl stop aubs-folder-sync.service
    sudo systemctl disable aubs-folder-sync.service
    ```
2. Move into the sbin folder and delete the folder:
    ```
    cd /usr/local/sbin/
    sudo rm -r aubs-folder-sync
    ```
3. Move into the logs folder and delete the log file(s):
    ```
    cd /var/log/
    sudo rm aubs-folder-sync*
    ```
4. On each of the remote server(s), delete the account (this will remove the home folder too and so remove the authorized_keys)
    ```
    userdel -r aubs-folder-sync
    ```
5. On each of the remote server(s), remove the sudo access configuration
    ```
    sudo rm /etc/sudoers.d/aubs-folder-sync
    ```
6. On each of the remote server(s), reload sudo config
    ```
    sudo /etc/init.d/sudo reload
    ```

That's it, everything has been removed.

<br/><br/>

# Nginx and KeepAlive installation

Although not relevant to this script, I am currently using two proxy (proxy01 and proxy02) servers, both running as containers on separate Proxmox hosts in a cluster.
Container configuration is using the Debian_Bookworm_amd64_20230626_cloud_rootfs.tar.xz template / 2GB Disk (local_sda) / 1 CPU / 512 MB RAM

1. Nginx
    1. Install Nginx
        ```
        sudo apt install nginx -y
        ```

    2. Check Nginx is running
        ```
        sudo systemctl status nginx
        ```

    3. Make sure you can see the default page via IPv4 and IPv6 if appropriate from the primary and secondary servers  
        [http://192.168.1.10](http://192.168.1.10) (substitute for your IPv4 IP)  
        [http://192.168.1.20](http://192.168.1.20) (substitute for your IPv4 IP)  
        [http://[2a01:4b00::10]/](http://[2a01:4b00::10]/) (substitute for your IPv6 IP)  
        [http://[2a01:4b00::20]/](http://[2a01:4b00::20]/) (substitute for your IPv6 IP)  

    4. On each server, edit the main index page with the server it is (primary/secondary1/secondary2/etc)
        ```
        sudo nano /var/www/html/index.html
        ```
        Add in one of:
            ```
            <h1>PRIMARY1</h1>
            <h1>SECONDARY2</h1>
            <h1>SECONDARY3</h1>
            ```
2. KeepAlived
    1. Install keepalived
        ```
        sudo apt install keepalived -y
        ```
    2. Choose an IP address that can be used as a virtual IP between the hosts  
       192.168.1.50  
       2a01:4b00::50  
    3. Configure keepalived on each server
        ```
        sudo nano /etc/keepalived/keepalived.conf
        ```
       Declare the global defs and vrrp monitoring script
        ```
        global_defs {
          # Keepalived process identifier
          router_id nginx
        }
        # Script used to check if Nginx is running
        vrrp_script check_nginx {
          script "/bin/check_nginx.sh"
          interval 2
          weight 50
        }
        ```
        Create a group for the interfaces
        ```
        #Virtual Interface Group
        vrrp_sync_groupVI_01 {
          group {
            VI_01_4
            VI_01_6
          }
        }
        ```
        Create the virtual intefaces
        Notes:
        * eth0 is my physical interface, change yours to suite
        * Set state to MASTER or BACKUP
        * Set priority (MASTER=120, BACKUP=110, BACKUP=100)
  
        For IPv4
        ```
        # Virtual interface
        # The priority specifies the order in which the assigned interface to take over in a failover
        vrrp_instance VI_01_4 {
          state MASTER
          interface eth0
          virtual_router_id 51
          priority 120
          # The virtual ip address shared between the two loadbalancers
          virtual_ipaddress {
            192.168.1.50
          }
          track_script {
            check_nginx
          }
          authentication {
            auth_type AH
            auth_pass secret
          }
        }
        ```
        For IPv6
        ```
        vrrp_instance VI_01_6 {
          state MASTER
          interface eth0
          virtual_router_id 51
          priority 120
          # The virtual ip address shared between the two loadbalancers
          virtual_ipaddress {
            2a01:4b00::50/64
          }
          track_script {
            check_nginx
          }
          authentication {
            auth_type AH
            auth_pass secret
          }
        }
        ```
    4. Create a script that'll be used to check nginx is running
        ```
        sudo nano /bin/check_nginx.sh
        ```
        Add in
        ```
        #!/bin/sh
        if [ -z "`/bin/pidof nginx`" ]; then
          exit 1
        fi
        ```
        make the script executable
        ```
        sudo chmod 755 /bin/check_nginx.sh
        ```

    5. Check if KeepAliveD is started, if not, start it
        ```
        sudo systemctl status keepalived
        sudo systemctl start keepalived
        ```
    6. Check the event log
        ```
        sudo tail -f /var/log/syslog
        ```
        if the following is received
        ```
        Keepalived_vrrp[4040]: SECURITY VIOLATION - scripts are being executed but script_security not enabled
        ```
        add the keepalived_script user to the 'users' group
        ```
        sudo useradd -g users -M keepalived_script
        ```


# Notes
|[Back to top](#aubs-folder-sync)|<br/><br/>
Inspiration taken from many support sites including [Stack Overflow](https://stackoverflow.com/).
