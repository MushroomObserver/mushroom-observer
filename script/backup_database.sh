#!/usr/bin/env bash
#
#  USAGE::
#
#    script/backup_database.sh
#
#  DESCRIPTION::
#
#  Makes a new snapshot of the database in:
#
#    db/backups/
#
################################################################################
set -e

app_root="$( cd "$(dirname "$0")"; pwd -P | sed 's/\/script*//' )"
config_file=$app_root/config/mysql-$RAILS_ENV.cnf
backup_dir=$app_root/db/backups
backup_name=snapshot-`date +%Y%m%d`.gz
temp_file=/tmp/backup_database.$$
db=mo_$RAILS_ENV

[ -d $backup_dir ] || mkdir $backup_dir
cd $backup_dir

# Create a new snapshot.
mysqldump --defaults-extra-file=$config_file $db | gzip -c - > $backup_name
chmod 640 $backup_name

# Decide which snapshots we want to keep.
(
  ls snapshot-????????.gz 2>&1 | tail -7;            # keep 7 daily backups
  ls snapshot-??????{01,09,16,23}.gz 2>&1 | tail -9; # keep 8 weekly backups
  ls snapshot-??????01.gz 2>&1 | tail -14;           # keep 12 monthly backups
  ls snapshot-????0101.gz 2>&1                       # keep all yearly backups
) | sort -u > $temp_file

# Delete everything in this directory that's not one of the kept backups.
ls | comm -23 - $temp_file | xargs rm -f

rm $temp_file
exit 0
