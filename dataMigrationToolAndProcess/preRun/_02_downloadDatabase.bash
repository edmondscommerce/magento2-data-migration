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
    ./$0 [sshUser] [sshHost] [sshPort] [remotePublicPath] [destinationDir] [tableListPath] [dumpName]

    [sshUser]          - The SSH user
    [sshHost]          - The SSH host
    [sshPort]          - The ssh port
    [remotePublicPath] - The remote public path containing the Magento 1 install
    [destinationDir]   - The path to put the dump files in
    [tableListPath]    - The list of tables to get data for
    [dumpName]         - The name to use for the dump with the .sql.gz suffix

    "
}

if (( $# < 7 ))
then
    usage
    exit 1
fi

sshUser=$1;
sshHost=$2;
sshPort=${3:-22}
remotePublicPath=$4;
destinationDir=$5; #Where to put the dumps
tableListPath=$6;
dumpName=$7;

echo "

Getting DB dump from live

"
localXml=$(ssh -p $sshPort $sshUser@$sshHost -- "bash -c \"cat $remotePublicPath/app/etc/local.xml\" ")
if [[ "" == "$localXml" ]]
then
    echo "Failed getting local.xml from $remotePublicPath/app/etc/local.xml"
    exit 1
fi

echo $localXml > $destinationDir/local.xml

liveDbHost="$(xmllint --xpath "string(config/global/resources/default_setup/connection/host)"  $destinationDir/local.xml)"
liveDbName="$(xmllint --xpath "string(config/global/resources/default_setup/connection/dbname)"  $destinationDir/local.xml)"
liveDbUserName="$(xmllint --xpath "string(config/global/resources/default_setup/connection/username)"  $destinationDir/local.xml)"
liveDbPassword="$(xmllint --xpath "string(config/global/resources/default_setup/connection/password)"  $destinationDir/local.xml)"

tableList=$(cat "$tableListPath" | tr '\n' ' ';)

if [[ "" == "$liveDbHost" ]]
then
    echo "Empty DB host - error"
fi

echo "
Dumping Live DB and Downloading
"

echo "Database structure for all tables, no data"
ssh -p $sshPort $sshUser@$sshHost -- " \
mysqldump \
    -u ${liveDbUserName} \
    -p${liveDbPassword} \
    -h ${liveDbHost} \
    $liveDbName \
    --no-data \
    --single-transaction \
| grep -v '50013 DEFINER' \
| gzip -c
" > "$destinationDir/$dumpName"

echo "Get data for the whitelisted tables (excludes logs)";
ssh -p $sshPort $sshUser@$sshHost -- " \
mysqldump \
    -u ${liveDbUserName} \
    -p${liveDbPassword} \
    -h ${liveDbHost} \
    $liveDbName \
    $tableList \
    --force \
    --single-transaction \
| grep -v '50013 DEFINER' \
| gzip -c
" >> $destinationDir/$dumpName

echo "
Done
"
ls -alh "$destinationDir/$dumpName"