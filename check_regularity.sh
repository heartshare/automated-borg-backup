#!/bin/bash -ue

# Location of the current script
CHECK_SCRIPT_PATH=`dirname $0`

# Get the variables of the main script 
. $CHECK_SCRIPT_PATH/general.conf

# Get the period since the last backup
TODAY=$(date +%s)
LAST_BKP=$(cat $CHECK_SCRIPT_PATH/last_backup)
let "PERIOD = ($TODAY - $LAST_BKP)/60/60/24"

# Check if the last backup was made more than a week ago.
# Send a pushbullet notification if so. 
if [ $PERIOD -gt 6 ]; then
	echo "No backup since $PERIOD days!"
        curl -s -u $PUSHBULLET_KEY: -X POST https://api.pushbullet.com/v2/pushes \
        --header 'Content-Type: application/json' \
        --data-binary '{"type": "note", "title": "Borg Backup -  Backup your data!", "body": "'"No backup since $PERIOD days! Plug-in your backup disk now."'", "device_iden": "'"$PUSHBULLET_DEVICE"'"}'
fi

exit 0
