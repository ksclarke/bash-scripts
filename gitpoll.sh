#! /bin/bash

#
# A simple script for automating git pulls
#
# This script assumes tags are created with:
#   git tag `date +%Y%m%d%H%M%S`
#
if [ $# -ne 2 ]; then
    echo "Usage: gitpoll <git-user> <git-dir>"
else
    # Set the user who has write permissions to the git directory
    GIT_USER=$1

    # Change into the supplied directory
    cd $2

    REMOTE_TAG=`sudo -u $GIT_USER git ls-remote --tags origin |tail -c 15`
    CURRENT_TAG=`sudo -u $GIT_USER git tag |tail -c 15`

    if [ "$REMOTE_TAG" != "$CURRENT_TAG" ]; then
        echo Updating to new repository tag: $REMOTE_TAG
       	sudo -u	$GIT_USER git stash
        sudo -u $GIT_USER git pull --quiet
        sudo -u $GIT_USER git fetch --tags --quiet > /dev/null 2>&1
    fi
fi
