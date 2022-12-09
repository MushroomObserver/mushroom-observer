#!/usr/bin/env bash

if [ ! -d config ]; then
  echo Please run this from /var/web/mo.
  exit 1
fi

if [ ! -d config/blocked_ips ]; then
  mkdir config/blocked_ips
fi

cp config/blocked_ips.txt config/blocked_ips/backup-`date +%d`-daily
cp config/blocked_ips.txt config/blocked_ips/backup-`date +%m`-monthly
cp config/blocked_ips.txt config/blocked_ips/backup-`date +%Y`-yearly
