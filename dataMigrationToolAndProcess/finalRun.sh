#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../_top.inc.bash
echo "
===========================================
$(hostname) $0 $@
===========================================
"

useBeast=${1:-"true"}

echo "
With that done, let's reset the database to a clean state and migrate again
"
bash -${-//s} ./prototype/_010_dropAndRebuildDatabase.sh ${magento2DbName} ${useBeast} true
bash -${-//s} ./prototype/_070_runFinalMigration.sh
echo "
Assuming that all went to plan, there are a couple of things that we need to clean up
"
bash -${-//s} ./prototype/_080_postImportTasks.bash "${magento2DbName}"
bash -${-//s} ./prototype/_090_cleanUpTasks.sh

echo "
----------------
$(hostname) $0 completed
----------------
"