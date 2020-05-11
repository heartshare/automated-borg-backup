# Borg Backup Automation script
Automate your Borg Backup remote and local jobs.

## Prerequisites
Install Borg Backup: ```apt install borgbackup -y```

This script was developed and tested on Debian 9.
It should work on other Debian-based Linux distribution.

## Configuration
1. Clone the repository in the /etc/backups directory: ```sudo clone https://github.com/jeremyfritzen/storj_earnings_notify.git /etc/backups/automated-borg-backup```
2. Add Disk IDs in the backup.disks file. The backup will be launched only if one of these disks is plugged-in.
3. Copy general.conf.template file and rename it "general.conf". This will will allow to configure the backup script (pushbullet access, etc.)
4. Edit the general.conf file you just created with your own parameters to configure the backup script.
5. Copy the job.conf.template file and rename it as you want. Only the ".conf" extension in the end is important. This file will define your backup job.
6. Edit the conf file you just created with your own parameter to define your backup job.
7. Run setup script: ```./install.sh```


## Usage
WORK IN PROGRESS
