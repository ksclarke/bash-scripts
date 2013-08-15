#! /bin/bash

#===========================================================================
# A Bash script that uses `drush` to update Drupal core on a site
#===========================================================================

# Where Drupal is installed and running from
if [[ -z "$1" ]]; then
  DRUPAL_HOME=/var/www/drupal
else
  DRUPAL_HOME=${1}
fi

# Running Drupal under Apache, the user Apache runs as
if [[ -z "$2" ]]; then
  DRUPAL_USER=www-data
else
  DRUPAL_USER=${2}
fi

#===========================================================================
# Shouldn't need to edit anything under here (where the work is done)
#===========================================================================

# Make sure we have the rights to change the Drupal space
sudo chown -R ${USER} ${DRUPAL_HOME}

# Update Drupal core
drush -y -r ${DRUPAL_HOME} up drupal

# Update the databases of all sites using this core
drush -y -r ${DRUPAL_HOME} @sites updb

# Clear the caches
drush -y -r ${DRUPAL_HOME} @sites cc all

# Change the ownership back to the real Drupal user
sudo chown -R ${DRUPAL_USER} ${DRUPAL_HOME}
