#!/bin/bash

##########################################################################################################
##########################################################################################################
##                  _                  __         _      _                                              ##
##    __ _   _  _  | |__   ___  ___   / _|  ___  | |  __| |  ___   _ _   ___   ___  _  _   _ _    __    ##
##   / _` | | || | | '_ \ (_-< |___| |  _| / _ \ | | / _` | / -_) | '_| |___| (_-< | || | | ' \  / _|   ##
##   \__,_|  \_,_| |_.__/ /__/       |_|   \___/ |_| \__,_| \___| |_|         /__/  \_, | |_||_| \__|   ##
##                                                                                  |__/                ##
##########################################################################################################
##########################################################################################################
##
## v0.0.1 aubs-folder-sync v0.0.1
## https://github.com/AubsUK/aubs-folder-sync
## _________________________________________
##
## Changes
## v0.0.1 - 2023-08-29 - Initial Release
##
##
##
##
##########################################################################################################
##########################################################################################################



FOLDERS_TO_SYNC=("/etc/nginx/") # Other folders can be added in the format ("/path/to/" "/another/path/")
FILES_TO_IGNORE_REGEX=".*\.swp"  # Files can be excluded using regex format e.g. ".*\.swp|.*\.tmp"
SERVERS_TO_REFRESH=("192.168.1.233") # List of servers (IP/hostname) to synchronise from this server
REMOTE_PORT="22122" # Specify the SSH port to be used for the remote servers
REMOTE_USER="aubs-folder-sync" # Speficy the user that will be used for the SSH connections
REMOTE_COMMANDS="sudo service nginx restart" # Commands to run on the remote servers after synchronising
LOGFILE_LOCATION="/var/log/aubs-folder-sync.log" # Full pat for the log file

#####################################################
################ DO NOT CHANGE BELOW ################
#####################################################

## Initialise/empty temporary files, one to store the reasons, and another to store the running count
TEMP_REASONS="$PWD/aubs-folder-sync.tmp.reasons"
TEMP_RUNNING="$PWD/aubs-folder-sync.tmp.running"
touch "$TEMP_REASONS"
touch "$TEMP_RUNNING"
true > "$TEMP_REASONS"
true > "$TEMP_RUNNING"


## Logging function
LogThis() {
	echo "$(date):$(printf %s " $*")" >> "$LOGFILE_LOCATION"
}


## Main function to synchronise folders
SyncFolder() {
	## If this is not a queue run, append the reason to file, increment the running count and add it to file
	if [[ $3 != "queue" ]]; then
		echo "$3 $1$2" >> "$TEMP_REASONS"
		RUNNING_COUNT="$(head -1 "$TEMP_RUNNING")"
		((RUNNING_COUNT++))
		echo "$RUNNING_COUNT" > "$TEMP_RUNNING"
	fi
	## If a sync is already running, return out.
	if [[ $RUNNING_COUNT -gt 1 ]]; then return; fi

	## Log the current run details
	LogThis "--------------------------------------------------"
	LogThis "Sync Folders: '${FOLDERS_TO_SYNC[*]}'"
	LogThis "Refresh Servers: '${SERVERS_TO_REFRESH[*]}'"
	LogThis "Remote Commands: '$REMOTE_COMMANDS'"
	LogThis "Remote User: '$REMOTE_USER'"
	LogThis "Reason: ($(wc -l < "$TEMP_REASONS")) - $(echo $(cat -n "$TEMP_REASONS"))"
	## Reason has been logged, clear it ready for any additional entries
	true > "$TEMP_REASONS"

	## For each server, synchronise local folders with remote folders and execute the remote commands
	for server in "${SERVERS_TO_REFRESH[@]}"
	do

		LogThis "Synchronising to $server"

		rsync --rsync-path="sudo rsync" -azR -v --delete --exclude="$FILES_TO_IGNORE_REGEX" -e "ssh -p $REMOTE_PORT -o BatchMode=yes -o ConnectTimeout=15 -o ConnectionAttempts=4 -o StrictHostKeyChecking=yes" "${FOLDERS_TO_SYNC[@]}" $REMOTE_USER@"$server":/
		if [ $? -eq 0 ]; then
			LogThis "Sync success."
		else
			LogThis "Sync FAILED. "
		fi

		LogThis "Running commands on server $server"
		ssh $REMOTE_USER@$server -p $REMOTE_PORT "$REMOTE_COMMANDS"
		if [ $? -eq 0 ]; then
			LogThis "Commands completed."
		else
			LogThis "Commands FAILED. "
		fi
		LogThis "Done"
	done ##End of synchronising folders loop
	LogThis "Synchronise complete."

	## Get the running count from file and remove one as we've just completed it
	RUNNING_COUNT="`head -1 $TEMP_RUNNING`"
	((RUNNING_COUNT--))
	if [[ $RUNNING_COUNT -gt 0 ]]; then
		## If there are more to complete and there are reasons, run the sync again
		if [[ $(wc -l < $TEMP_REASONS) -gt 0 ]]; then
			RUNNING_COUNT=1
			echo "$RUNNING_COUNT" > $TEMP_RUNNING
			SyncFolder "" "" "queue"
		## If there's no reasons, we have already taken them into account so finish
		else
			RUNNING_COUNT=0
			echo "$RUNNING_COUNT" > $TEMP_RUNNING
		fi
	else
		RUNNING_COUNT=0
		echo "$RUNNING_COUNT" > $TEMP_RUNNING
	fi ## End of running count
}


## START ##
LogThis "=================================================="
LogThis "================= Service Started ================"

## Set the default to false (nothing wrong)
FOLDER_NOT_EXIST=false
## Loop through local folders in the list and check they exist
for i in "${FOLDERS_TO_SYNC[@]}"
do
	if [[ ! -d $i ]]; then
		LogThis "Folder '$i' - does not exist or is not accessible"
		FOLDER_NOT_EXIST=true
	fi
done #End of loop through local folders

## If at least one folder doesn't exist, exit the script
if [[ $FOLDER_NOT_EXIST == true ]]; then
	LogThis "An error occurred checking existing folders. Check and try again."
	exit 1
fi # End of loop for checking if at least one local folder doesn't exist

LogThis "All folders checked ok."
LogThis "Starting First Run"

## When the script starts, sync straight away
SyncFolder "" "" "First Run validating sync"


## use inotifywait to monitor changes and call the SyncFolder function when detected
inotifywait --exclude "$FILES_TO_IGNORE_REGEX" -q -m -r -e modify,delete,delete_self,create,move,move_self "${FOLDERS_TO_SYNC[@]}" | while read DIRECTORY EVENT FILE; do
	## Call the function asynchronously
	SyncFolder "$DIRECTORY" "$FILE" "$EVENT" &
done
