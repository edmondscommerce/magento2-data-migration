#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

useBeast=${1:-"true"}
mysqlHost="localhost";
dbUsername="root";
if [[ "${useBeast}" == "true" ]]
then
    mysqlHost="beast";
    dbUsername=${beastDbUsername};
fi

echo -n "Checking for a local.xml in the M1 files... "

if [[ ! -f ${vhostRoot}/bin/dataMigration/mage1Files/local.xml ]]
then
    echo "
    ERROR - Not found local.xml file at ${vhostRoot}/bin/dataMigration/mage1Files/local.xml
    "
    usage
    exit 1
fi
echo "done"

### PROCESS ###

echo -n "Checking that a M1 database has been created... "

DBCHECK=$(mysql -NBe 'SHOW DATABASES' | grep ${magento1DbName});

if [[ "" == "${DBCHECK}" ]]
then
    echo "ERROR

    Magento 1 database not found - please import it

NOTE:
    You probably want to run ./preRun/run.bash

"
    exit 1
fi
echo "done"

echo -n "Checking that a M2 media folder exists and is not empty... "

if (( $(find ${vhostRoot}/pub/media/ -type f | wc -l) < 100 ))
then
    echo "Media directory seems empty - make sure we have downloaded all media

NOTE:
    You probably want to run ./preRun/run.bash

"
    exit 1
fi
echo "done"

echo -n "Checking the jiraShell asset is present and configured... "

if [[ ! -f ~/jiraShell/env ]]
then
    echo "ERROR

    No file found and jiraShell/env

    Please run ~/jiraShell/run.bash

    "
    exit 1
fi
echo "done"

echo "Prerun checks completed successfully"

echo "
----------------
$(hostname) $0 completed
----------------
"