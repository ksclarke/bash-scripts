# bash-scripts

A small collection of bash script utilities:

 * gitpoll

    Periodically polls a git repo looking for a new tag; if it finds one, it
    performs a new pull.

 * curl_time

    Uses curl to time (and output) the aspects of a website's response time.

 * indexNS2GSearch
    Indexes all the records in Fedora that have a supplied namespace; GSearch
    doesn't have a way to batch index records; this script works around that.

 * pidgin

    A simple wrapper for the Pidgin IM client, resolving issues it has with
    the Microsoft Lync plugin.

 * drupal-up

    Runs a series of drush scripts to perform Drupal core updates on a series
    of Drupal sites (multisites or Drupal installs at different locations).

 * drush-up

    A script to disable and enable all the currently installed Drupal modules.
