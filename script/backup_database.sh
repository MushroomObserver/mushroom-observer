#!/usr/bin/env bash
#
#  USAGE::
#
#    script/backup_database.sh
#
#  DESCRIPTION::
#
#  Makes a new snapshot of the database on the image server:
#
#    /data/images/backup/database-YYYYMMDD.gz
#
################################################################################
set -e

app_root="$( cd "$(dirname "$0")"; pwd -P | sed 's/\/script*//' )"
config_file=$app_root/config/mysql-$RAILS_ENV.cnf
snapshot_file=$app_root/db/checkpoint.gz
remote_host=mo@images.mushroomobserver.org
backup_dir=/data/images/backup
backup_file=database-`date +%Y%m%d`.gz
temp_file=/tmp/backup_database.$$
db=mo_$RAILS_ENV

# Create a new snapshot.
mysqldump --defaults-extra-file=$config_file $db | gzip -c - > $snapshot_file
chmod 640 $snapshot_file

# Transfer snapshot to image server and abort if this fails.
dest=$remote_host:$backup_dir/$backup_file
if ! scp $snapshot_file $dest; then
  echo "Failed to transfer $snapshot_file to $dest!"
  exit 1
fi

# Get listing of snapshots currently on the image server.
# (Make extra certain that these are actually files in the backup dir!!)
ssh $remote_host "ls -d $backup_dir/*" | egrep "^$backup_dir/" > $temp_file.1

# Decide which snapshots we want to keep.
(
  egrep '/database-2........gz$'            $temp_file.1 | tail -7;  # daily
  egrep '/database-2.....(01|09|16|23).gz$' $temp_file.1 | tail -9;  # weekly
  egrep '/database-2.....01.gz$'            $temp_file.1 | tail -14; # monthly
  egrep '/database-2...0101.gz$'            $temp_file.1             # yearly
) | sort -u > $temp_file.2

# Delete everything in this directory that's not one of the kept backups.
# The -f tells it not to complain if there is nothing to delete.
comm -23 $temp_file.1 $temp_file.2 | ssh $remote_host 'xargs rm -f'

# Tidy up temp files, but leave the latest snapshot on the webserver.
# It just overwrites it each time, so it should be fine.
rm -f $temp_file.?
exit 0
