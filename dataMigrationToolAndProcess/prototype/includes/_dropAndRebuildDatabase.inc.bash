#!/usr/bin/env bash

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

echo "This will drop and rebuild the database ${targetDb}. Proceed? (y/n)"
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
    echo "Enter the password for the beast's root mysql user";
    read beastPassword
    mysqlBeastCmd="mysql -u root --password=${beastPassword} -h beast";
    grantHost="192.168.%.%";
else
    grantHost="localhost";
fi

echo "Granting access on ${targetDb} to ${beastDbUsername}@'${grantHost}"
grantAccess="GRANT ALL ON ${targetDb}.* to ${beastDbUsername}@'${grantHost}';";

echo "Dropping ${targetDb}"
eval "${mysqlBeastCmd} -e  \"DROP DATABASE IF EXISTS ${targetDb}\""

echo "Creating ${targetDb}"
eval "mysql ${mysqlBeastCmd} -e \"CREATE DATABASE ${targetDb} CHARACTER SET utf8 COLLATE utf8_general_ci; ${grantAccess}\" "

echo "Disabling every non-Magento module to allow a clean install"
sed -i "/'Magento_/! s/1,/0,/" ${vhostRoot}/app/etc/config.php

if [[ -f ${vhostRoot}/justInstalledClean.sql.gz && ${forceReinstall} == "false" ]]
then
    echo "Reimporting previously created database dump"
    zcat ${vhostRoot}/justInstalledClean.sql.gz | mysql ${mysqlBeast} "${targetDb}"
else
    echo "No database dump found, doing a full install"
    set +e
    rm -rf ${vhostRoot}/var/cache/*
    rm -rf ${vhostRoot}/var/di/*
    rm -rf ${vhostRoot}/var/generation/*
    rm -rf ${vhostRoot}/var/page_cache/*
    set -e
    bash ${vhostRoot}/bin/installScript.bash
fi

echo "Reenabling all the modules"
sed -i 's#0,#1,#' ${vhostRoot}/app/etc/config.php
echo "Disabling EdmondsCommerce_ProductionSettings because it breaks the install"
sed -i "s#EdmondsCommerce_ProductionSettings' => 1#EdmondsCommerce_ProductionSettings' => 0#" ${vhostRoot}/app/etc/config.php

echo "Running setup:upgrade again, because we recreated the database, and we need all the important fields"

magento setup:upgrade

echo "
----------------
$(hostname) $0 completed
----------------
"
