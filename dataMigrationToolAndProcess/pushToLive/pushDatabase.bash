#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
echo "
===========================================
$(hostname) $0 $@
===========================================
"

function usage(){
    echo "

Usage:
    ./$0 [localDbUserName] [localDbPassword] [localDbHost] [localDbName] [sshHost] (sshPort=2020)

    localDbUserName - Local db username
    localDbPassword - Local db password
    localDbHost     - Local host
    sshHost         - The SSH host
    remoteMediaPath - The remote public path containing the Magento 2 media directory
    remoteOwner     - User by which web server is running
    sshPort         - The SSH port number
    "
}


if (( $# < 5 ))
then
    usage
    exit 1
fi

localDbUserName=$1
localDbPassword=$2
localDbHost=$3
localDbName=$4
sshHost=$5
sshPort=${6:-2020}


echo "Making sure we have pv installed"
if [[ "" = "$(command -v pv)" ]]
then
    sudo yum -y install pv
fi

echo "
Dumping, compressing, piping over SSH and decompressing and inserting on remote
.. all in one big beautiful pipe
"
mysqldump \
    --default-character-set=utf8 \
    --single-transaction \
    --add-drop-database \
    --add-drop-table \
    -u ${localDbUserName} \
    -p${localDbPassword} \
    -h ${localDbHost} \
    $localDbName  \
    | gzip -c \
    | pv \
    | ssh "root@$sshHost" -p $sshPort \
<<<<<<< HEAD
        -- bash -c "zcat -d | mysql $localDbName"
=======
        -- bash -c "
        zcat -d | mysql $localDbName
    "
>>>>>>> 5da3c4c3773f614692e9c66554d11791c301eea1
