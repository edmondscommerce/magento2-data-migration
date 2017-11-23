#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash

if [[ "$(whoami)" != "root" ]]
then
    echo "Please run this as root"
    exit 1
fi

function usage(){
    echo "

Usage:
    ./$0 [databaseName] [dumpLocation] (useBeast='true')

    [databaseName]    - The database name to use
    [dumpLocation]    - The full path to the dump archive
    (useBeast='true') - Whether to use the beast or not

    "
}

if (( $# < 3 ))
then
    usage
    exit 1
fi

databaseDestination=$1;
dumpFilePath=$2;
useBeast=${3:-"true"}

echo "Importing database in to $databaseDestination from $dumpFilePath";

echo "$useBeast";
if [[ "$useBeast" == "true" ]]
then
    echo "
    Now importing the DB to the Beast
    ";
    echo -n "Enter password for the beast mysql root user: ";
    read beastPassword
    mysqlQuery="
    DROP DATABASE IF EXISTS $databaseDestination;
    CREATE DATABASE $databaseDestination CHARACTER SET utf8 COLLATE utf8_general_ci;
    GRANT ALL ON $databaseDestination.* to $beastDbUsername@'192.168.%.%';
    FLUSH PRIVILEGES;
    "
    echo "$mysqlQuery";
    mysql -u root --password=${beastPassword} -h beast -e "
        $mysqlQuery
    "

    echo "Created database $databaseDestination and granted permissions to $beastDbUsername";
    echo "Importing the database dump into $databaseDestination"

    zcat "$dumpFilePath" | mysql -u root --password=${beastPassword} -h beast "$databaseDestination"
    echo "Import completed";
else
    echo "
    Now importing the DB locally
    ";
    mysql -e "DROP DATABASE IF EXISTS $databaseDestination"
    mysql -e "CREATE DATABASE $databaseDestination CHARACTER SET utf8 COLLATE utf8_general_ci;
        GRANT ALL ON $databaseDestination.* to $beastDbUsername@'localhost';
    "

    zcat "$dumpFilePath" | mysql "$databaseDestination"
    echo "
    Done
    "
fi
