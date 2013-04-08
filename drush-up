#! /bin/bash

#
# A script to disable and enable all the currently installed Drupal modules.
# This is useful because I pull a bunch of in-process modules in via git (so
# changes come in via git pulls but I need a batch way to enable the changes).
#

if [ -z "$1" ]; then
  DRUPAL_DIR=`pwd`
else
  DRUPAL_DIR=$1
fi

drush -y --root=$DRUPAL_DIR pml --status=enabled --type=module --no-core --pipe > modulelist.txt
drush -y --root=$DRUPAL_DIR dis `cat modulelist.txt`
drush -y --root=$DRUPAL_DIR en `cat modulelist.txt`

rm modulelist.txt
