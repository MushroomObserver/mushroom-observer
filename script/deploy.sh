#!/usr/bin/env bash

if [ "$PWD" != "/var/web/mo" ]; then
    echo Please run this from /var/web/mo.
    exit 1
fi

if [ "$USER" != "mo" ]; then
    echo Please run this as the mo user.
    exit 1
fi

if [ "$RAILS_ENV" != "production" ]; then
    echo Please set RAILS_ENV to production.
    exit 1
fi

if [ "$(git branch | grep '^\*')" != "* master" ]; then
    echo Please switch to master branch.
    exit 1
fi

if [ "$(git status -s | grep '^.[A-Z]')" != "" ]; then
    echo There are unstaged changes, please "\"git add\"" these files:
    git status -s | grep '^.[A-Z]'
    exit 1
fi

echo Going for it\!
echo Getting latest code from github... && git pull && \
echo Installing bundle... && bundle install && \
echo Checking for migrations... && rake db:migrate && \
echo Updating translations... && rake lang:update && \
echo Precompiling assets... && rake assets:precompile && \
echo Reloading unicorn... && /etc/init.d/unicorn reload && \
echo SUCCESS\!
