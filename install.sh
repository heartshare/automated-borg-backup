#!/bin/bash -ue

# -u option: exits if error on unset variables
# -e option: exits if any commands exits non-zero

# Location of the current script
SCRIPT_PATH=`dirname $0`


ln -s $SCRIPT_PATH/40-backup.rules /etc/udev/rules.d/40-backup.rules
ln -s $SCRIPT_PATH/automatic-backup.service /etc/systemd/system/automatic-backup.service
systemctl daemon-reload
udevadm control --reload

echo "Installation of automated-borg-backup: Successful"
echo "Make sure general.conf and backup jobs configuration files are well defined. Templates can be found here:
- general.conf.template: $SCRIPT_PATH/general.conf.template
- job.conf.template: $SCRIPT_PATH/backups_config/job.conf.template"

exit 0