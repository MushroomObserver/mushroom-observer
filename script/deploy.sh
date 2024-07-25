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

STASH_RESULT=`git stash`
if [ $? -ne 0 ]; then
    echo git stash failed.
    exit 1
fi

echo $STASH_RESULT | grep 'No local changes to save'
STASH_STATUS=$?

if [ $STASH_STATUS -ne 0 ]; then
    echo Stashed some changes...
fi

echo Getting latest code from github... && git pull
if [ $? -ne 0 ]; then
    echo git pull failed.
    exit 1
fi

if [ $STASH_RESULT -ne 'No local changes to save' ]; then
    echo Reapply local changes... && git stash pop
    if [ $? -ne 0 ]; then
	echo Applying the stashed changes failed.
	exit 1
    fi
fi

echo Installing bundle... && bundle install && \
echo Checking for migrations... && rake db:migrate && \
echo Updating translations... && rake lang:update && \
echo Precompiling assets... && rake assets:precompile && \
echo Reloading puma... && sudo service puma restart && \
echo Reloading solidqueue... && sudo service solidqueue restart && \
echo Tagging repo with $tag... && git tag $tag && \
echo Pushing new tag... && git push --tags && \
echo SUCCESS\!
