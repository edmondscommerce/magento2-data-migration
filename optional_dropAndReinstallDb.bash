#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source _top.inc.bash

IFS=$standardIFS;

function usage(){
    echo "

Usage:
    ./$0 [databaseName] [useBeast]

    databaseName    - The database name locally
    useBeast - Will create database in beast, default is true
    "
}

targetDb="$1";

if (( $# < 1 ))
then
    usage
    exit 1
fi


if [[ "$(whoami)" != "ec" ]]
then
    echo "Please run this as ec"
    exit 1
fi

echo "

You're about to destroy your database, confirm!

"
echo "confirm y/n"
read confirm
if [[ "y" != "$confirm" ]]
then
    echo "aborted"
    exit 1
fi

useBeast=${2:-"true"}
mysqlBeast="";
grantAccess="";
if [[ "$useBeast" == "true" ]]
then
    echo "Enter password the beast db \n";
    read beastPassword
    mysqlBeast=" -uroot --password=${beastPassword} -h beast";
    grantHost="192.168.%.%";
else
    grantHost="localhost";
fi

grantAccess="GRANT ALL ON $targetDb.* to $beastDbUsername@'${grantHost}';";

mysql $mysqlBeast -e   "DROP DATABASE IF EXISTS $targetDb"

mysql $mysqlBeast -e "CREATE DATABASE $targetDb CHARACTER SET utf8 COLLATE utf8_general_ci; $grantAccess"



if [[ -f $vhostRoot/justInstalledClean.sql.gz ]]
then
    echo "Found just installed dump, reimporting that"
    zcat $vhostRoot/justInstalledClean.sql.gz | mysql $mysqlBeast "$targetDb"
else
    echo "Not found just installed db dump, doing a full install"
    bash $vhostRoot/bin/installScript.bash
fi