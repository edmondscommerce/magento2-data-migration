#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash;
echo "
===========================================
$(hostname) $0 $@
===========================================
"
if (( $# < 1 ))
then
    echo "
This is used to run through the migration process and generate the config files for the final run.
If you have made any modifications to the config files these will be wiped, so if you need to run the final process use
the following command

    $(dirname ${DIR})/finalRun.sh

To run this command you need to use the following command

    ${DIR}/$0 go [useBeast] (optional defaults to true)
    "
    exit 1
fi
useBeast=${2:-"true"}

echo "
Let's make sure everything is set up and ready to run
"
bash -${-//s} ./_00_checkPreRun.sh ${useBeast}
bash -${-//s} ./_010_dropAndRebuildDatabase.sh ${magento2DbName} ${useBeast}
bash -${-//s} ./_020_configureMigrationTool.sh ${useBeast}
echo "
Now lets try running the migration - this is very likely to fail
"
bash -${-//s} ./_030_runFirstMigration.sh
php -f ${DIR}/_040_parseLogAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
echo "
After clearing the most obvious errors lets try migrating the data again
"
set +e
magento -vvv --no-ansi migrate:data -r ${dataMigrationDir}/config.xml |& tee ${vhostRoot}/var/dataMigration/dataMigration.log
set -e
echo "
Now let's try and clean this up properly
"
php -f ${DIR}/_040_parseLogAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
php -f ${DIR}/_050_parseLogAndUpdateClassMapXml.php -- --vhostRoot=${vhostRoot}
php -f ${DIR}/_060_parseMoveXmlAndUpdateMapXml.php -- --vhostRoot=${vhostRoot}
echo "
With that done, let's reset the database to a clean state and migrate again
"
bash -${-//s} ./_010_dropAndRebuildDatabase.sh ${magento2DbName} ${useBeast} true
bash -${-//s} ./_070_runFinalMigration.sh
echo "
Assuming that all went to plan, there are a couple of things that we need to clean up
"
bash -${-//s} ./_080_postImportTasks.bash "${magento2DbName}"
bash -${-//s} ./_090_cleanUpTasks.sh


echo "
----------------
$(hostname) $0 completed
----------------
"
