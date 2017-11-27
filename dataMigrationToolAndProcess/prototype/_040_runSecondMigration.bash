#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

echo "
After clearing the most obvious errors let's try migrating the data again
"
set +e
magento -vvv --no-ansi migrate:data -r ${dataMigrationDir}/config.xml |& tee ${vhostRoot}/var/dataMigration/dataMigration.log
set -e

php -f ${DIR}/includes/parseLogAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
php -f ${DIR}/includes/parseLogAndUpdateClassMapXml.php -- --vhostRoot=${vhostRoot}
php -f ${DIR}/includes/parseMoveXmlAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
