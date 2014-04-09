#! /bin/bash

LSOF_OUTPUT=`lsof -w -u www-data | wc -l`
WEB_USERS=`sudo netstat -plan | grep :80 | wc -l`
TIMESTAMP=`date "+%Y%m%d.%H%M%S"`
OUT_FILE=/opt/freelib-djatoka/lsof.log

echo "<lsof ts=\"${TIMESTAMP}\"><files>${LSOF_OUTPUT}</files><users>${WEB_USERS}</users></lsof>" >> $OUT_FILE
