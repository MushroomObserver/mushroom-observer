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

if [ "$(git branch | grep '^\*')" != "* main" ]; then
    echo Please switch to main branch.
    exit 1
fi

tag=`date "+deploy-%Y-%m-%d-%H-%M"`
echo Going for it\!
echo Stash local changes... && git stash && \
echo Getting latest code from github... && git pull && \
echo Reapply local changes... && git stash pop && \
echo Installing bundle... && bundle install && \
echo Checking for migrations... && rake db:migrate && \
echo Updating translations... && rake lang:update && \
echo Precompiling assets... && rake assets:precompile && \
# echo Reloading unicorn... && sudo service unicorn reload && \
echo Reloading puma... && sudo service puma restart && \
echo Tagging repo with $tag... && git tag $tag && \
echo Pushing new tag... && git push --tags && \
echo SUCCESS\!
