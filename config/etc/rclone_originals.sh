#!/bin/sh
#
# Nightly originals -> Google Cloud Storage archive sync. Deployed on
# the IMAGES server (images.mushroomobserver.org) at
# /data/images/mo/rclone/rclone_originals.sh, run by mo's crontab:
#   15 1 * * * /data/images/mo/rclone/rclone_originals.sh
#
# `rclone copy` compares size+modtime for every local orig against the
# bucket and uploads what's new OR modified. This replaces the original
# once-only orig.done-ledger version (kept in ~mo's rclone dir until
# 2026-07), whose one-shot design meant post-archival modifications --
# remote GPS strips, rotations pushed by TransferImagesJob -- never
# reached the archive; issue #4859 documents the ~9,700-image cleanup
# that followed. The ledger files (orig.done etc.) are now unused.
#
# NEVER change `copy` to `sync`: the bucket holds pre-cutover originals
# (id < next_image_id_to_go_to_cloud) whose server copies are deliberately
# deleted -- sync would delete them from the archive too.
#
# Cost: the nightly listing of the bucket (~2M objects) is ~2000 list
# calls, pennies; uploads are free ingress.

root=/data/images/mo
bucket=mo-image-archive-bucket
log=$root/rclone/rclone_originals.log

# fresh log each night -- INFO logs one line per uploaded file
rm -f "$log"
# rclone is the last command so its exit status is the script's --
# cron/operators can detect a failed sync instead of a masking exit 0.
rclone --config /home/mo/.config/rclone/rclone.conf \
  copy "$root/orig" "google:$bucket/orig" \
  --log-file "$log" --log-level INFO
