#!/usr/bin/env bash

if [ "$PWD" != "/var/web/mo" ]; then
    echo Please run this from /var/web/mo.
    exit 1
fi

if [ "$USER" != "mo" ]; then
    echo Please run this as the mo user
    exit 1
fi

if [ "$RAILS_ENV" != "production" ]; then
    echo Please set RAILS_ENV to production
    exit 1
fi

echo Going for it

git pull && bundle install && rake lang:update && rake assets:precompile && rake db:migrate && uni reload
