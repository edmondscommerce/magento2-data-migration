#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash

function usage(){

echo "

This will use rsync to download the media directory.
Should be run every time you resync the local magento1 db with live

Usage:

./$0 [remoteVhostPublicPath] [sshUser] [sshHost] (optional ssh port - defaults to 22) (use beast defaults to 'true')

"
}

if (( $# < 3 ))
then
    usage
    exit 1
fi

### Paramaters ###
remoteVhostPublicPath="$1/"
sshUser=$2
sshHost=$3
sshPort=${4:-22}
useBeast=${5:-"true"}

### Variables ###

sshCmd="ssh -p $sshPort $sshUser@$sshHost"


### Process ###
localLiveFilesStorage=$vhostRoot/bin/dataMigration/mage1Files
mkdir -p "$localLiveFilesStorage"

echo "
Setting up SSH ID
"
set +e
"$sshCmd -oBatchMode=yes exit" &> /dev/null
if (( $? != 0 ))
then
    ssh-copy-id  -o StrictHostKeyChecking=no $sshUser@$sshHost -p $sshPort
fi
set -e

echo "

Getting Magento version from live

"
magento1Version=$(ssh -p $sshPort $sshUser@$sshHost -- "php -r \"require '$remoteVhostPublicPath/app/Mage.php'; echo Mage::getVersion(); \" ")
echo "Found version: $magento1Version"
echo $magento1Version > $localLiveFilesStorage/mage1Version.txt

dumpName="dbDump.sql.gz";
databaseName="${clientname}_magento1";

magento1RefPath="$localLiveFilesStorage/m1ref";
tableListPath="${magento1RefPath}/tableWhiteList.txt";

magento1DbRefName="${databaseName}_ref";

if [[ -d ${magento1RefPath} ]]
then
    echo -n "Magento 1 already appears to be installed, re-install? [y/n]: "
    read skip
    if [[ ${skip} == "y" ]]
    then
        bash -${-//s} ./_01_getM1ReferenceDbAndGenWhiteList.bash "$magento1Version" "$magento1RefPath" "$magento1DbRefName" "$useBeast";
    fi
fi

if [[ -f "$localLiveFilesStorage/$dumpName" ]]
then
    echo "Database dump already downloaded to $localLiveFilesStorage/$dumpName"
    echo -n "Acquire a new one from the live server? [y/n]: "
    read skip
    if [[ "${skip}" == "y" ]]
    then
        echo "
        Creating new database dump
        "
        bash -${-//s} ./_02_downloadDatabase.bash "$sshUser" "$sshHost" "$sshPort" "$remoteVhostPublicPath" "$localLiveFilesStorage" "$tableListPath" "$dumpName";
    fi
else
    echo "Dumping the live database"
    bash -${-//s} ./_02_downloadDatabase.bash "$sshUser" "$sshHost" "$sshPort" "$remoteVhostPublicPath" "$localLiveFilesStorage" "$tableListPath" "$dumpName";
fi
bash -${-//s} ./_03_importDatabase.bash "$databaseName" "$localLiveFilesStorage/$dumpName" "$useBeast";
bash -${-//s} ./_04_slimDownDatabase.bash "$databaseName" "$useBeast"
bash -${-//s} ./_05_fixKnownIssues.bash "$databaseName" "$useBeast"

remoteMediaPath="${remoteVhostPublicPath}media";
localMediaPath="${vhostRoot}/pub/media";
bash -${-//s} ./_06_downloadMedia.bash "$sshUser" "$sshHost" "$remoteMediaPath" "$localMediaPath" "$databaseName" "$sshPort" "$useBeast";

echo "PreRun process completed"