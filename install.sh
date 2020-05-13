#!/bin/bash -ue

# -u option: exits if error on unset variables
# -e option: exits if any commands exits non-zero

# Location of the current script
SCRIPT_PATH=`dirname $0`


# Import of udev rules to detect the backup external drive
ln -s $SCRIPT_PATH/40-backup.rules /etc/udev/rules.d/40-backup.rules

# Import the backup service
ln -s $SCRIPT_PATH/automatic-backup.service /etc/systemd/system/automatic-backup.service

# Reload systemd and udev rules
systemctl daemon-reload
udevadm control --reload

# Create the daily check to make sure last backup is not older than a week
crontab -l > /tmp/crontab_file
echo "0 20 * * * $SCRIPT_PATH/check_regularity.sh" >> /tmp/crontab_file
crontab /tmp/crontab_file
rm /tmp/crontab_file

echo "Installation of automated-borg-backup: Successful"
echo "Make sure general.conf and backup jobs configuration files are well defined. Templates can be found here:
- general.conf.template: $SCRIPT_PATH/general.conf.template
- job.conf.template: $SCRIPT_PATH/backups_config/job.conf.template"

exit 0