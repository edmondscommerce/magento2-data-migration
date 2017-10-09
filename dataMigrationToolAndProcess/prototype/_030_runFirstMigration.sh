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

Running Migration

"
cd ${vhostRoot}
mkdir -p var/dataMigration
echo "

migrating settings

"
magento -vvv --no-ansi migrate:settings ${dataMigrationDir}/config.xml  |& tee ${vhostRoot}/var/dataMigration/settingsMigration.log
echo "

migrating data and logging failures

"
set +e
magento -vvv --no-ansi migrate:data -r ${dataMigrationDir}/config.xml |& tee ${vhostRoot}/var/dataMigration/dataMigration.log
set -e

echo "
----------------
$(hostname) $0 completed
----------------
"