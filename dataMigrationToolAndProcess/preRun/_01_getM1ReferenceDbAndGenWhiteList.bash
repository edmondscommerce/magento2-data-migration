#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash

IFS=$standardIFS;

if [[ "$(whoami)" != "root" ]]
then
    echo "Please run this as root"
    exit 1
fi

function usage(){
    echo "

Usage:
    ./$0 [version] [installPath] [databaseName] [useBeast]

    [version]          - The version of Magento to install
    [installPath]      - The path to install to, will also contain the table list for later
    [databaseName]     - The database name to use
    [useBeast]         - Use beast or not
    Retrieves the list of tables to download by getting the tables from a fresh Magento 1 install
    Prepares a blank database to import into to be used later
    "
}

if (( $# < 3 ))
then
    usage
    exit 1
fi

version=$1;
installPath=$2;
databaseName=$3;
useBeast=$4;



#Get mycnf values
databaseUser="$(grep -i user ~/.my.cnf | sed 's/user=//')";
databasePass="$(grep -i password ~/.my.cnf | sed 's/password=//')";
set +e
databaseHost="$(grep -i host ~/.my.cnf)";
set -e

if [[ "$databaseHost" == "" ]]
then
    databaseHost="localhost"
else
    databaseHost="$(echo "$databaseHost" | sed 's/host=//')"
fi;

echo "

Installing Magento version $version in $installPath on database $databaseName@$databaseHost

"



#https://github.com/netz98/n98-magerun#magento-installer
if [[ "$(program_is_installed magerun)" == 0 ]]
then
    #Get Magerun and place it in to a known place
    echo "Please install Magerun with the magento1 cluster asset";
    exit 1;
fi

#If the reference DB exists, prompt to recreate it or reuse
echo "

Clearing the existing database if it exists...

"

echo "$useBeast";
if [[ "$useBeast" == "true" ]]
then
    echo -n "Enter password for the beast mysql root user: ";
    read beastPassword
    mysqlBeast=" -uroot --password=${beastPassword} -h beast";
    databaseHostGrant="192.168.%.%";
    databaseHost="beast";
    databaseUser=$beastDbUsername;

    echo "
    Now importing the DB to the Beast - give the root database user for the database when prompted
    ";
else
    echo "
    Now importing the DB to the localhost - give the root database user for the database when prompted
    ";
    mysqlBeast=" -uroot";
    databaseHostGrant=$databaseHost;
fi

    mysqlQuery="
    DROP DATABASE IF EXISTS $databaseName;
    CREATE DATABASE $databaseName CHARACTER SET utf8 COLLATE utf8_general_ci;
    GRANT ALL ON $databaseName.* to $beastDbUsername@'${databaseHostGrant}' IDENTIFIED BY '${databasePass}';
    FLUSH PRIVILEGES;
    "
    echo "$mysqlQuery";
    mysql $mysqlBeast -e "
        $mysqlQuery
    "

    echo "
    Created database $databaseName and granted permissions to $databaseUser
    ";



if [[ -d "$installPath" ]]
then
    echo "Detected previously installed Magento at path: $installPath, deleting...
    ";

    rm -rf "$installPath";
fi

# Install Magento 1 reference into home directory, and then copy it after it's done
homeM1ref="/home/ec/m1ref";
if [[ -d "$homeM1ref" ]]
then
    echo "Detected previously installed home Magento at path: $homeM1ref, deleting...
    ";

    rm -rf "$homeM1ref";
fi

echo "
Don't run this under a webroot or there will be problems
"

cd /home/ec/

magerun install --dbHost="$databaseHost" --dbUser="$databaseUser" --dbPass="$databasePass" --dbName="$databaseName" \
--installSampleData=no --useDefaultConfigParams=yes --magentoVersionByName="magento-mirror-$version" --installationFolder="$homeM1ref" \
--baseUrl="http://baseurl.com";

mv $homeM1ref $installPath;

if [[ ! -f $installPath/tableWhiteList.txt ]]
then
    echo "
    No Whitelist found will generate a new one
    "
    #Dump to a file and append a whitelist of tables TODO: Added report product views to ignore, sales_bestsellers, etc
    mysql -NBe "SHOW TABLES;" "$databaseName" | grep -v '^log' | grep -v 'core_session' > "$installPath/tableWhiteList.txt";
fi