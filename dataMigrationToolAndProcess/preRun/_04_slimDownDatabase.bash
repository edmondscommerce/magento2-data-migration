#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash
set -x
if [[ "$(whoami)" != "root" ]]
then
    echo "Please run this as root"
    exit 1
fi

function usage(){
    echo "

Usage:
    ./$0 [databaseName] (useBeast='true')

    [databaseName]    - The database name to fix up
    (useBeast='true') - Whether this is on the beast or not

    "
}

if (( $# < 2 ))
then
    usage
    exit 1
fi

IFS=$standardIFS;
databaseName=$1;
useBeast=${2:-"true"}


mysqlBeast="";
if [[ "$useBeast" == "true" ]]
then
    echo -n "Enter password for the beast mysql root user: ";
    read beastPassword
    mysqlBeast="-u root --password=${beastPassword} -h beast";
fi

echo "

Clear out the visitor log tables

"

echo "Clearing out log_visitor";

mysql -NB $mysqlBeast "$databaseName" -e "TRUNCATE TABLE log_visitor"

echo "Clearing out log_visitor_info";

mysql -NB $mysqlBeast "$databaseName" -e "TRUNCATE TABLE log_visitor_info"