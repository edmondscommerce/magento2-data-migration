#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

echo "Running Migration"

cd ${vhostRoot}
mkdir -p var/dataMigration
echo "
Running bin/magento's migrate:settings command"
echo "The output below will be logged to ${vhostRoot}/var/dataMigration/settingsMigration.log"

runCmd="magento -vvv --no-ansi migrate:settings ${dataMigrationDir}/config.xml  |& tee ${vhostRoot}/var/dataMigration/settingsMigration.log"

echo $runCmd;
eval $runCmd;

echo "

Running bin/magento's migrate:data command"
echo "The output below will be logged to ${vhostRoot}/var/dataMigration/dataMigration.log"

runCmd="magento -vvv --no-ansi migrate:data -r ${dataMigrationDir}/config.xml |& tee ${vhostRoot}/var/dataMigration/dataMigration.log"
echo $runCmd

set +e
eval $runCmd
set -e

php -f ${DIR}/includes/parseLogAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
php -f ${DIR}/includes/parseLogAndUpdateClassMapXml.php -- --vhostRoot=${vhostRoot}

echo "
----------------
$(hostname) $0 completed
----------------
"