#!/bin/sh
wget http://checkip.dyndns.org/ -O - -o /dev/null | \
  sed 's/^.*Address: //' | sed 's/<.*//'
