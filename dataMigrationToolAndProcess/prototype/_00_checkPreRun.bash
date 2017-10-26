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

if [[ ! -f ${vhostRoot}/bin/dataMigration/mage1Files/local.xml ]]
then
    echo "
    ERROR - Not found local.xml file at ${vhostRoot}/bin/dataMigration/mage1Files/local.xml
    "
    usage
    exit 1
fi

### PROCESS ###
DBCHECK=$(mysql -NBe 'SHOW DATABASES' | grep ${magento1DbName});

if [[ "" == "${DBCHECK}" ]]
then
    echo "ERROR

    Database not found - please import it

NOTE:
    You probably want to run ./preRun/run.bash

"
    exit 1
fi

if (( $(find ${vhostRoot}/pub/media/ -type f | wc -l) < 100 ))
then
    echo "Media directory seems empty - make sure we have downloaded all media

NOTE:
    You probably want to run ./preRun/run.bash

"
    exit 1
fi

if [[ ! -f ~/jiraShell/env ]]
then
    echo "ERROR

    No file found and jiraShell/env

    Please run ~/jiraShell/run.bash

    "
    exit 1
fi

echo "
It looks like everything has been setup to allow this to run
"

echo "
----------------
$(hostname) $0 completed
----------------
"