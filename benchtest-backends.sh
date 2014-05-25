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
#   fallocate
#
# Author: Kevin S. Clarke <ksclarke@gmail.com>
# Last updated: 2014-05-25
####

# TODO: make these arguments? Threads only work with benchtool.
THREADS=15
# What's put in OBJECTS is only kept for non-hierarchical tests
OBJECTS=30000

# If you want to use hierarchy, we'll reset the number of objects based
# on the structure you select: 256/256/256, 128/128/128, 64/64/64, etc.
HIERARCHY=true
LEVEL_MAX=64

# Whether we want extra logging output
DEBUG=true

#
# You shouldn't need to change anything below this point
#

# These are only used if we're testing with hierarchy
BATCH=1
DIR=1
FILE=0

# If we're testing with hierarchy, we set the total object count
if $HIERARCHY ; then
  OBJECTS=$(( LEVEL_MAX ** 3 ))

  if $DEBUG ; then
    echo "Setting number of hierarchical objects to: ${OBJECTS} (${LEVEL_MAX}/${LEVEL_MAX}/${LEVEL_MAX})"
  fi
fi

JETTY_MEMORY="-Xmx2048m"
CONFIG_OPTS=( \
  config/infinispan/leveldb-default/infinispan.xml \
#  config/infinispan/leveldb/infinispan.xml \
#  config/infinispan/file/infinispan.xml \
#  config/infinispan/ram/infinispan.xml \
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

# Set the directory to which all our output / work files will be written
REPORT_TIMESTAMP=$(date +"%Y%m%d%H%M%S")
REPORT_DIR=~/benchreport-${REPORT_TIMESTAMP}
mkdir -p ${REPORT_DIR}

# Function for using fcrepo4's benchtool to benchmark
function benchmark_with_benchtool {
  BENCHTOOL=`ls -tr $( find ~/.m2/repository -name bench-tool*-with-dependencies.jar ) | head -1`

  if [ -z "$BENCHTOOL" ] ; then
    echo ""
    echo "FF4's Benchtool doesn't seem to be installed in your local Maven repository."
    echo "Check out the project (https://github.com/futures/benchtool) and run `mvn install`"
    echo ""
    exit 1
  fi

  # Run benchtool with default size, 5 threads, and 20k objects
  java -jar ${BENCHTOOL} -f http://localhost:8080 -n ${OBJECTS} -t ${THREADS} -l ${REPORT_DIR}/${1}-durations-${OBJECTS}.log
}

# Function to change the hierarchical path of the next object
function increment_hierarchy {
  if [ $FILE -lt $LEVEL_MAX ] ; then
    FILE=$(( $FILE + 1 ))
  elif [ $DIR -lt $LEVEL_MAX ] ; then
    DIR=$(( $DIR + 1 ))
    FILE=1
  elif [ $BATCH -lt $LEVEL_MAX ] ; then
    BATCH=$(( $BATCH + 1 ))
    DIR=1
    FILE=1
  fi
}

# Function for using curl to benchmark
function benchmark_with_curl {
  echo "Starting benchmark with curl"

  for (( INDEX=1; INDEX<=$OBJECTS; INDEX++ )) ; do
    ID=`date +"%s.%N"`

    # Start our tests with just a 1MB file
    DS_FILE=${REPORT_DIR}/${ID}-datastream.bin
    START=`date +"%s%3N"`

    # Create unique datastream file for ingest
    fallocate -l 1048562 ${DS_FILE}
    echo ${START} >> ${DS_FILE}

    # Report how long generating the datastream file took
    END=`date +"%s%3N"`
    MILLISECS=`expr ${END} - ${START}`
    echo "Datastream created [${MILLISECS} ms]"

    if $HIERARCHY ; then
      URL="http://localhost:8080/rest/objects/${BATCH}/${DIR}/${FILE}/${ID}/ds1/fcr:content"
      increment_hierarchy
    else
      URL="http://localhost:8080/rest/objects/${ID}/ds1/fcr:content"
    fi

    if $DEBUG ; then
      echo "Connecting to Fedora with: $URL"
    fi

    START=`date +"%s%3N"`
    CODE=`curl -X POST -o /dev/null --silent --write-out '%{http_code}\n' --upload-file ${DS_FILE} ${URL}`

    # '201 Created' means the object was successfully loaded into fcrepo4
    if [[ ${CODE} -ne 201 ]] ; then
      echo "  Failed to load '${ID}' into fcrepo4: ${CODE}"
      echo "${INDEX} objects loaded before the failure"
      return 1
    else
      END=`date +"%s%3N"`
      MILLISECS=`expr ${END} - ${START}`
      echo "  Successfully ingested: ${ID} (${INDEX} objects) [${MILLISECS} ms]"
      echo ${MILLISECS} >> ${REPORT_DIR}/${1}-durations-${OBJECTS}.log
    fi

    # Clean up old datastream
    rm -rf ${DS_FILE}
    echo ${INDEX} > ${REPORT_DIR}/${1}-lastcount.out
  done
}

for CONFIG in "${CONFIG_OPTS[@]}" ; do
  LABEL=`expr match "$CONFIG" '^config/infinispan/\(.*\)/infinispan.xml$'`
  MAVEN_OPTS=${JETTY_MEMORY} mvn -Dfcrepo.infinispan.cache_configuration=${CONFIG} clean jetty:run > /tmp/jetty.console 2>&1 &
  tail -F /tmp/jetty.console | while read LOGLINE ; do
    [[ "${LOGLINE}" == *"Started Jetty Server"* ]] && pkill -P $$ tail
  done
  JETTY_PID=`pgrep -P $$ java`
  echo "Running new test [config: ${CONFIG}] [Jetty pid: ${JETTY_PID}]"

# TODO: configure a choice based on a argument to the script or something
#  benchmark_with_benchtool ${LABEL}
  benchmark_with_curl ${LABEL}

  # Clean up the Jetty process
  kill ${JETTY_PID}
  wait ${JETTY_PID}

  # Do an explicit cleanup since lazy garbage collection doesn't seem to finish with Jetty shutdown
  rm -r ${FCREPO_HOME}/fcrepo4-data/*

  # Output images of the benchmark's durations if the output .log file was successfully generated
  if [ ! -f ${REPORT_DIR}/${LABEL}-durations-${OBJECTS}.log ] ; then
    echo "No durations file found, skipping gnuplot"
  else
    gnuplot <<- EOF
	set term png
	set output "${REPORT_DIR}/${LABEL}-durations-${OBJECTS}-${REPORT_TIMESTAMP}.png"
        set ylabel "Milliseconds"
        set xlabel "Objects"
	plot "${REPORT_DIR}/${LABEL}-durations-${OBJECTS}.log" title "Duration" with lines
	EOF
  fi
done
