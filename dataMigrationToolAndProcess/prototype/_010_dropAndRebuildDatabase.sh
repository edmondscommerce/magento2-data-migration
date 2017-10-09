#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

IFS=${standardIFS};

function usage(){
    echo "

Usage:
    ./$0 [databaseName] [useBeast] [forceReinstall]

    databaseName    - The database name locally
    useBeast - Will create database in beast, default is true
    forceReinstall - Will force Magento to reinstall, default is false
    "
}

targetDb="$1";
useBeast=${2:-"true"}
forceReinstall=${3:-false}

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

grantAccess="GRANT ALL ON ${targetDb}.* to ${beastDbUsername}@'${grantHost}';";

mysql ${mysqlBeast} -e   "DROP DATABASE IF EXISTS ${targetDb}"

mysql ${mysqlBeast} -e "CREATE DATABASE ${targetDb} CHARACTER SET utf8 COLLATE utf8_general_ci; ${grantAccess}"

echo "
Going to disable every non Magento module to allow a clean install
"
sed -i "/'Magento_/! s/1,/0,/" ${vhostRoot}/app/etc/config.php

if [[ -f ${vhostRoot}/justInstalledClean.sql.gz && ${forceReinstall} == "false" ]]
then
    echo "Found just installed dump, reimporting that"
    zcat ${vhostRoot}/justInstalledClean.sql.gz | mysql ${mysqlBeast} "${targetDb}"
else
    echo "Not found just installed db dump, doing a full install"
    set +e
    rm -rf ${vhostRoot}/var/cache/*
    rm -rf ${vhostRoot}/var/di/*
    rm -rf ${vhostRoot}/var/generation/*
    rm -rf ${vhostRoot}/var/page_cache/*
    set -e
    bash ${vhostRoot}/bin/installScript.bash
fi

echo "
Running setup:upgrade again, because we recreated the database, and we need all the important fields

First let's re-enable all of the modules
"
sed -i 's#0,#1,#' ${vhostRoot}/app/etc/config.php

echo "
But not the one that breaks the install
"
sed -i "s#EdmondsCommerce_ProductionSettings' => 1#EdmondsCommerce_ProductionSettings' => 0#" ${vhostRoot}/app/etc/config.php

magento setup:upgrade

echo "
----------------
$(hostname) $0 completed
----------------
"
