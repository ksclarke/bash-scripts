#! /bin/bash

#
# A script for indexing (in GSearch) all Fedora records in a given namespace.
#
# There are a few configurable things up front (host, port, etc.), but
# namespace and password are supplied by user when initiating the script.
#
# Usage: ./indexNS2GSearch edu.ucla.library.yourCollectionNameGoesHere
#
# Dependencies: cURL, Bash shell, and the Fedora Commons command line tools
#
# Author: Kevin S. Clarke <ksclarke@gmail.com>
# Created: 03/19/2013
# Updated: 03/19/2013
#
FEDORA_HOST="fedora.library.ucla.edu"
FEDORA_PORT="8080"

# If you want to index on a different machine, input those details here
GSEARCH_HOST="$FEDORA_HOST"
GSEARCH_PORT="$FEDORA_PORT"

FEDORA_USER="fedoraAdmin"
NS_FIELD="identifier"

# Nothing after this point should require editing; this script requires that
# the Fedora command line tools be installed and available on the system $PATH
CLIENT=$(which fedora-find.sh)

# Fedora tools don't exit with proper exit codes so we have to check this way
# so we don't look silly saying it was successful with an error on the screen
FOUND_RECORDS=false

# We want to be able to limit to X number of records to scan through
COUNT=0
TOTAL=0

# The below insures the gsearch alias works within this bash script
shopt -s expand_aliases
alias gsearch="curl --write-out %{http_code} --silent --output /dev/null"

# We must have the Fedora command line tools installed, and pass in a namespace
if [ -z "$CLIENT" ]; then
  echo " fedora-find.sh isn't on your system path; add it and rerun the script"
  exit 1
elif [ -z "$1" ]; then
  echo " You forgot to pass in a namespace; try something like:"
  echo " ./indexNS2GSearch edu.ucla.library.yourCollectionNameGoesHere"
  exit 1
fi

if [[ $2 != *[!0-9]* ]]; then
  TOTAL=$2
else
  echo " Your second argument doesn't look like an int; I'm ignoring it\n"
fi

# The script asks for the configured FEDORA_USER's password
read -p "Password please: " -s PW
echo ""

if [ -z "$PW" ]; then
  echo " You forgot to input a password; try again, please"
  exit 1
else
  # Starting our command with a space means it doesn't go into our history file
  FEDCMD=" $CLIENT $FEDORA_HOST $FEDORA_PORT $FEDORA_USER $PW $NS_FIELD $1* http"

  while read LINE ; do
    # We check the Fedora command's output for our queried namespace
    if [[ "$LINE" == *$1* ]]; then
      GSEARCH_SERVICE="http://$GSEARCH_HOST:$GSEARCH_PORT/fedoragsearch/rest"
      GSEARCH_QSTRING="?operation=updateIndex&action=fromPid&value="

      # Then we extract the item ID from the namespaced ID output string
      ITEM_ID=${LINE#*:}
      # This works if your gsearch isn't behind an authentication layer
      RESPONSE=$(gsearch "$GSEARCH_SERVICE$GSEARCH_QSTRING$1%3A$ITEM_ID")

      # If we get back a 200 HTTP response code, we're truckin; otherwise, fail
      if [ "$RESPONSE" = "200" ]; then
        echo "$1:$ITEM_ID successfully indexed"
        FOUND_RECORDS=true
      else
        echo "Failed to index $1:$ITEM_ID; check the logs for why ($RESPONSE)"
        exit 1
      fi

      if [[ $TOTAL -ne 0 ]]; then
        COUNT=`expr $COUNT + 1`

        if [ $COUNT -ge $TOTAL ]; then
          echo "Processed $COUNT records"
          exit 0
        fi
      fi
    fi
  done < <($FEDCMD)
fi;

if $FOUND_RECORDS; then
  echo "Successfully indexed all the namespaced records!"
fi;
