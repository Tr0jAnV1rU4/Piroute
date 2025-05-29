#!/bin/bash


# this script should be executed when box starts up and executed periodically
# this script itself should not depends on any partition space, meaning it should be able to run with all disks full
# threshold
# regular:
# remove files under /log/blog that are not modified for more than 24 hours, also remove empty directories
# soft: (/log is over 85%)
# remove
# /var/log/*.gz
# /log/blog//files.gz
# /log/forever/main.log
# /log/forever/main_last.log
# /log/apt/cache/*
# any files under /log/firewalla that is older than one day
# hard (/log is over 95%)
# remove
# all files under soft
# /var/log/syslog
# /log/apt/lib/*
# /log/forever/*
# /log/firewalla/*




# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------
mylog() {
    echo "$(date -u): $@"
}

loginfo() {
    mylog "INFO: $@"
}

logerror() {
    mylog "ERROR: $@" >&2
}

soft_clean() {
    loginfo "do SOFT cleaning ..."
    sudo journalctl --vacuum-size=40M
    sudo rm -f /var/log/*.gz
    sudo find /log/blog/ -type f -name "*.gz" -mmin +720 -exec rm -f {} \; # only retain zeek logs in the past 12 hours
    rm -f /log/forever/main_last.log
    : > /log/forever/main.log
    # any files under /log/firewalla that is older than one day
    find /log/firewalla -mtime +1 -exec truncate -s 0 {} \;
    sudo \apt clean
}

hard_clean() {
    loginfo "do HARD cleaning ..."
    : | sudo  tee /var/log/syslog
    sudo journalctl --vacuum-size=20M
    sudo find /var/log/ -type f -size +1M -exec truncate -s 0 {} \;
    sudo rm -rf /log/apt/cache/*
    sudo rm -rf /log/apt/lib/*
    sudo find /log/blog/ -type f -name "*.gz" -exec rm -f {} \;
    sudo chown pi:pi /log/forever/*
    sudo find /log/forever/ /log/firewalla/ /log/redis/ -type f -size +1M -exec truncate -s 0 {} \;
}

# ----------------------------------------------------------------------------
# MAIN goes here
# ----------------------------------------------------------------------------
: ${FIREWALLA_HOME:='/home/pi/firewalla'}
source ${FIREWALLA_HOME}/platform/platform.sh

blog_dir=$(get_zeek_log_dir)
# remove old files
sudo find "$blog_dir" -type f -regex '.*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/.*$' -mmin +1440 -delete
# remove conn_long logs older than 8 hours, conn_long log generation interval is reduced to 1 min and may generate as many as conn logs
sudo find "$blog_dir" -type f -regex '.*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/conn_long.*$' -mmin +480 -delete
# remove old directories, non-empty directories will not be removed by rmdir
sudo find "$blog_dir" -type d -regex '.*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' ! -name $(date +"%Y-%m-%d") -exec rmdir '{}' ';' 2>/dev/null

use_percent=$( df --output=pcent /log | tail -1 | tr -d ' %' )
loginfo "/log usage at ${use_percent}%"
inode_percent=$( df --output=ipcent /log | tail -1 | tr -d ' %' )
loginfo "/log inode usage at ${inode_percent}%"
use_percent_root=$( df --output=pcent / | tail -1 | tr -d ' %' )
loginfo "/ usage at ${use_percent_root}%"
inode_percent_root=$( df --output=ipcent / | tail -1 | tr -d ' %' )
loginfo "/ usage at ${inode_percent_root}%"

if (( use_percent > 85 || inode_percent > 85 || use_percent_root > 85 || inode_percent_root > 85 )); then
    soft_clean
    use_percent=$( df --output=pcent /log | tail -1 | tr -d ' %' )
    loginfo "/log usage at ${use_percent}%"
fi

if (( use_percent > 95 || inode_percent > 95 || use_percent_root > 95 || inode_percent_root > 95 )); then
    hard_clean
    use_percent=$( df --output=pcent /log | tail -1 | tr -d ' %' )
    loginfo "/log usage at ${use_percent}%"
fi

exit $rc
