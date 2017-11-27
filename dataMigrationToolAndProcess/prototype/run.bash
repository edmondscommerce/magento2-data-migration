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

    $(dirname ${DIR})/finalRun.bash

To run this command you need to use the following command

    ${DIR}/$0 go [useBeast] (optional defaults to true)
    "
    exit 1
fi
useBeast=${2:-"true"}

echo "
Let's make sure everything is set up and ready to run
"
bash -${-//s} ./_00_checkPreRun.bash ${useBeast}

echo "
Dropping and rebuilding the M2 database
"

bash -${-//s} ./_010_dropAndRebuildDatabase.bash ${magento2DbName} ${useBeast}

echo "
Configuring Magento's migration tool
"
bash -${-//s} ./_020_configureMigrationTool.bash ${useBeast}

echo "
Running the first migration
Note: This is expected to output a lot of errors due to unmapped data
"
bash -${-//s} ./_030_runFirstMigration.bash


echo "
Now let's try and clean this up properly
"
bash -${-//s} ./_040_runSecondMigration.bash

echo "
With that done, let's reset the database to a clean state and migrate again
"
bash -${-//s} ./_050_dropAndRebuildDatabase.bash ${magento2DbName} ${useBeast} true
bash -${-//s} ./_060_runFinalMigration.bash
echo "
Assuming that all went to plan, there are a couple of things that we need to clean up
"
bash -${-//s} ./_070_postImportTasks.bash "${magento2DbName}"
bash -${-//s} ./_080_cleanUpTasks.bash


echo "
----------------
$(hostname) $0 completed
----------------
"
