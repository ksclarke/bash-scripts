#! /bin/bash

####
# A quick and dirty script to run a benchmark across various FcRepo4 backends.
#
# Usage:
#   benchtest-backends.sh (with script in $PATH, run from the fcrepo-webapp directory)
#   ./benchtest-backends.sh ~/Workspace/fcrepo4/fcrepo-webapp (runs all config options)
#
# Dependencies:
#   pkill, pgrep (not standard across all *nixs?)
#   fcrepo benchtool installed in Maven's local repository
#   the fcrepo4 code base, checked out from Git repository
#
# Author: Kevin S. Clarke <ksclarke@gmail.com>
# Last updated: 2014-04-10
####

# TODO: make these arguments?
THREADS=15
OBJECTS=30000

MAVEN_MEMORY="-Xmx2048m"
CONFIG_OPTS=( \
  config/infinispan/leveldb-default/infinispan.xml \
  config/infinispan/leveldb/infinispan.xml \
  config/infinispan/file/infinispan.xml \
  config/infinispan/ram/infinispan.xml \
)

if [ $# -eq 0 ] ; then
  FCREPO_HOME=`pwd`
else
  FCREPO_HOME=${1}
fi

# Not a very strict check, but this is just quick and dirty at this point
if [ ! -f ${FCREPO_HOME}/pom.xml ]; then
  echo ""
  echo "Please start script using (or from) the fcrepo-webapp directory."
  echo "  Usage: benchtest-backends.sh /path/to/fcrepo-webapp"
  echo "         benchtest-backends.sh (if you are in fcrepo-webapp)"
  echo ""
  exit 1
else
  cd ${FCREPO_HOME}
fi

BENCHTOOL=`ls -tr $( find ~/.m2/repository -name bench-tool*-with-dependencies.jar ) | head -1`

if [ -z "$BENCHTOOL" ] ; then
  echo ""
  echo "FF4's Benchtool doesn't seem to be installed in your local Maven repository."
  echo "Check out the project (https://github.com/futures/benchtool) and run `mvn install`"
  echo ""
  exit 1
fi

REPORT_DIR=~/benchreport-$(date +"%Y%m%d%H%M%S")
mkdir -p ${REPORT_DIR}

for CONFIG in "${CONFIG_OPTS[@]}" ; do
  LABEL=`expr match "$CONFIG" '^config/infinispan/\(.*\)/infinispan.xml$'`
  MAVEN_OPTS=${MAVEN_MEMORY} mvn -Dfcrepo.infinispan.cache_configuration=${CONFIG} clean jetty:run > /tmp/jetty.console 2>&1 &
  tail -f /tmp/jetty.console | while read LOGLINE ; do
    [[ "${LOGLINE}" == *"Started Jetty Server"* ]] && pkill -P $$ tail
  done
  JETTY_PID=`pgrep -P $$ java`
  echo "Running new test [config: ${CONFIG}] [Jetty pid: ${JETTY_PID}]"

  # Run benchtool with default size, 5 threads, and 20k objects
  java -jar ${BENCHTOOL} -f http://localhost:8080 -n ${OBJECTS} -t ${THREADS} -l ${REPORT_DIR}/${LABEL}-durations-${OBJECTS}.log

  # Clean up the Jetty process
  kill ${JETTY_PID}
  wait ${JETTY_PID}

  # Output images of the benchtool durations
  gnuplot <<- EOF
	set term png
	set output "${REPORT_DIR}/${LABEL}-durations-${OBJECTS}.png"
	 plot "${REPORT_DIR}/${LABEL}-durations-${OBJECTS}.log" title "Duration" with lines
	EOF
done
