#! /bin/bash

#
# A script to add @author tags to Maven projects by polling Git logs for the first
# author from each untagged Java file.
#
# Not generally useful for others at this point because it relies on a modified
# version of license-maven-plugin.  Also depends on jq (which isn't installed by
# default on most distros).
#
# Author: Kevin S. Clarke <ksclarke@gmail.com>
# Last Modified: 2014/05/08
#

if [ ! -d ".git" ]; then
  echo "Directory in which this is run must be a git repo"
  exit 1
fi

if [ ! -f "pom.xml" ]; then
  echo "Directory in which this is run must be a Maven project"
  exit 1
fi

CURRENT_DIR=`pwd`
PROECT="futures/fcrepo4"
USERNAMES=(`curl -s "https://api.github.com/repos/${PROJECT}/contributors" | jq '.[] | .login'`)

#
# Adds author tag, working around a bug with the maven-javadoc-plugin
# using a modified version of the license-maven-plugin
#
add_author_tag() {
  SOURCE=${1:14}
  AUTHOR=`echo $2 | tr -d '"'`
  echo "  Adding \"@author ${AUTHOR}\" to ${SOURCE}"
  # We are using Maven's offline mode to ensure our modified license-maven-plugin is used
  mvn -q -o -Dincludes=${1} -Dmapping.default=java:SLASHSTAR_STYLE license:format
  mvn -q javadoc:test-fix -Dforce=true -DfixMethodComment=false -DfixFieldComment=false \
    -DfixClassComment=true -DfixTags=author -DdefaultAuthor=${AUTHOR} -Dincludes=${SOURCE}
  mvn -q -o -Dincludes=${1} -Dmapping.default=java:JAVADOC_STYLE license:format
}

#
# Gets the author of a particular file from the git log
#
get_author() {
  COLON_INDEX=`expr index "${1}" :`
  FILE=${1:0:$COLON_INDEX - 1}
  DIR_INDEX=`expr length ${CURRENT_DIR}`
  GIT_FILE=${FILE:$DIR_INDEX + 1}
  OLD_IFS=$IFS
  IFS=$'\n'
  # Get list of committers from git log
  AUTHORS=(`git log --format="%an" ${GIT_FILE}`)
  IFS=$OLDIFS
  AUTHORS_LENGTH=${#AUTHORS[@]}
  # Pull the first committer for our @author tag
  FIRST_AUTHOR=${AUTHORS[$AUTHORS_LENGTH - 1]}
  # Remove the current directory from the file path
  PROJECT_INDEX=`expr index "${GIT_FILE}" /`
  FILE_PATH=${GIT_FILE:$PROJECT_INDEX}
  # Clean up commiter's name for GitHub username search
  FIRST_AUTHOR=${FIRST_AUTHOR// /%20}
  FIRST_AUTHOR=${FIRST_AUTHOR//./}
  POSSIBLE_USERS=(`curl -s "https://api.github.com/search/users?q=${FIRST_AUTHOR}" | jq '.items[0].login'`)

  # Now let's compare possible users to actual user github accounts; flip this flag when we find a match
  CONTINUE=true

  for USER in ${POSSIBLE_USERS[@]} ; do
    for ACCOUNT in ${USERNAMES[@]} ; do
      if [[ "${USER}" == "${ACCOUNT}" ]] ; then
        # We've found a match! Go ahead and add the @author tag
        add_author_tag ${FILE_PATH} ${USER}
        CONTINUE=false
        break
      fi
    done

    if [ ! ${CONTINUE} ] ; then
      break;
    fi
  done
}

# Let's fire this off with a check for files lacking the @author tag
mvn checkstyle:check | while read LINE ; do
  [[ ${LINE} == /* ]] && [[ ${LINE} == *Javadoc*author*tag*missing* ]] && get_author $LINE
done
