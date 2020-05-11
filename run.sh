#!/bin/bash -ue

# -u option: exits if error on unset variables
# -e option: exits if any commands exits non-zero

# The udev rule is not terribly accurate and may trigger our service before
# the kernel has finished probing partitions. Sleep for a bit to ensure
# the kernel is done.
#
# This can be avoided by using a more precise udev rule, e.g. matching
# a specific hardware path and partition.

sleep 5

# Location of the current script
SCRIPT_PATH=`dirname $0`

#----------------------#
#  User configuration  #
#----------------------#

. $SCRIPT_PATH/general.conf


#----------------------#
# Script configuration #
#----------------------#

# Program name
PROGNAME="Borg Backup"

# Archive name schema
ARCHIVE_NAME=$(date  +%Y-%m-%d-%H-%M-%S)

# Date of today
TODAY=$(date +"%A, %d %b %Y")

# This is the file that will later contain UUIDs of registered backup drives
DISKS=/etc/backups/backup.disks


#----------------------#
#      FUNCTIONS       #
#----------------------#

# Notification function
notify()
{
	# The function will first try to send a Pushbullet notification.
	# If it doesn't work, it will try mail
	# And ultimately it will just print the message on the console

	# 2 arguments are required: Title and Message
        curl -s -u $PUSHBULLET_KEY: -X POST https://api.pushbullet.com/v2/pushes \
        --header 'Content-Type: application/json' \
        --data-binary '{"type": "note", "title": "'"$1"'", "body": "'"$2"'", "device_iden": "'"$PUSHBULLET_DEVICE"'"}' \
	|| \
	echo "$2" | mail -s "$1 - $TODAY" -a from:"Borg Backup" jeremymolla@gmail.com \
	|| \
	echo "$1: $2"
}

# Error Function used to exit the program while sending a notification
error_exit()
{
	# 1 argument is required: Message
    echo "${PROGNAME}: $1" 1>&2
	notify "ERREUR BACKUP" "$1" >/dev/null 2>&1
    exit 1
}


#----------------------#
#    BACKUP SCRIPT     #
#----------------------#

#Startup notification
notify "Démarrage du script de sauvegarde" ""

# Find whether the connected block device is a backup drive
for uuid in $(lsblk --noheadings --list --output uuid)
do
        if grep --quiet --fixed-strings $uuid $DISKS; then
                break
        fi
        uuid=
done

if [ ! $uuid ]; then
        error_exit "Aucun disque de sauvegarde reconnu. Branchez un disque de sauvegarde autorisé."
fi

echo "Disk $uuid is a backup disk"
partition_path=/dev/disk/by-uuid/$uuid
# Mount file system if not already done. This assumes that if something is already
# mounted at $MOUNTPOINT, it is the backup drive. It won't find the drive if
# it was mounted somewhere else.
(mount | grep $MOUNTPOINT) || mount $partition_path $MOUNTPOINT || error_exit "Le disque de sauvegarde n'a pas pu être monté."

drive=$(lsblk --inverse --noheadings --list --paths --output name $partition_path | head --lines 1)
echo "Drive path: $drive"


### BACKUP PREPARATION ###

# Options for borg create
BORG_OPTS="--stats --one-file-system --compression lz4 --checkpoint-interval 86400"

# No one can answer if Borg asks these questions, it is better to just fail quickly
# instead of hanging.
export BORG_RELOCATED_REPO_ACCESS_IS_OK=no
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no

# Log Borg version
borg --version || error_exit "Erreur lors de l'exécution de Borg."

echo -e "*** Backup jobs - $TODAY ***\n" | tee /tmp/borgresults.txt


#----------------------#
#   BACKUP EXECUTION   #
#----------------------#

for file in `ls $SCRIPT_PATH/backups_config/*.conf`
do
    . $file

    TARGET=$MOUNTPOINT/$BACKUP_DEST
    export BORG_PASSPHRASE=$BORG_PASSPHRASE

    echo -e "\n*** $BACKUP_NAME backup ***" | tee -a /tmp/borgresults.txt

    for (( i=0; i<${#PRE_BACKUP[@]}; i++ ))
    do
        ${PRE_BACKUP[i]} || { echo -e "\n /!\ Erreur rencontrée lors des actions pré-sauvegarde pour $BACKUP_NAME" | tee -a /tmp/borgresults.txt; continue 2; }
    done

    echo "$BACKUP_NAME: Starting Borg backup"
    # case sur le type de backup
    case $BACKUP_TYPE in
        local)
        borg create $BORG_OPTS \
        $TARGET::$ARCHIVE_NAME \
        $BACKUP_SOURCE \
        >> /tmp/borgresults.txt 2>&1 \
        || { echo -e "\n /!\ Erreur rencontrée lors de la sauvegarde de $BACKUP_NAME" | tee -a /tmp/borgresults.txt; continue 2; }
        
        ;;
        remote)
        ssh $BACKUP_SOURCE 2>&1 \
        | sed -n '/^---/,24p' >> /tmp/borgresults.txt \
        || { echo -e "\n /!\ Erreur rencontrée lors de la sauvegarde de $BACKUP_NAME" | tee -a /tmp/borgresults.txt; continue 2; }

        ;;
        NFS)
        umount $MOUNTPOINT_SOURCE || true
        mount $BACKUP_SOURCE $MOUNTPOINT_SOURCE -t nfs

        borg create $BORG_OPTS \
        $TARGET::$ARCHIVE_NAME \
        $MOUNTPOINT_SOURCE \
        >> /tmp/borgresults.txt 2>&1 \
        || { echo -e "\n /!\ Erreur rencontrée lors de la sauvegarde de $BACKUP_NAME" | tee -a /tmp/borgresults.txt; continue 2; }

        umount $MOUNTPOINT_SOURCE

        ;;
    esac
    #
    for (( i=0; i<${#POST_BACKUP[@]}; i++ ))
    do
        ${POST_BACKUP[i]} || { echo -e "\n /!\ Erreur rencontrée lors des actions post-sauvegarde pour $BACKUP_NAME" | tee -a /tmp/borgresults.txt; continue 2; }
    done

    echo "Completed $BACKUP_NAME backup"
    date +%s | cat > $SCRIPT_PATH/last_backup

done

# Just to be completely paranoid
sync

if [ -f $SCRIPT_PATH/autoeject ]; then
        umount $MOUNTPOINT || error_exit "Le disque de sauvegarde n'a pas pu être démonté. Essayez de le démonter manuellement."
        hdparm -Y $drive || error_exit "Le disque de sauvegarde n'a pas pu être démonté correctement. Essayez de le démonter manuellement."
fi

if [ -f $SCRIPT_PATH/backup-suspend ]; then
        systemctl suspend
fi

#Envoi des résultats par mail
cat "/tmp/borgresults.txt" | mail -s "Résultats de la sauvegarde - $TODAY" -a from:"Borg Backup" jeremymolla@gmail.com || echo "Not possible to send email"

#Final notification
notify "Sauvegarde terminée" "Retirez le disque de sauvegarde et consultez vos mails pour avoir les résultats de la sauvegarde."

exit 0

