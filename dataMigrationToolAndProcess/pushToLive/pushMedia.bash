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
    ./$0 [sshHost] [remoteMediaPath]  (sshPort=2020)

    sshHost         - The SSH host
    remoteMediaPath - The remote public path containing the Magento 2 media directory
    remoteOwner     - User by which web server is running
    sshPort         - The SSH port number
    "
}


if (( $# < 3 ))
then
    usage
    exit 1
fi

### Paramaters ###
sshHost="$1"
remoteMediaPath="$2/"
remoteOwner="$3"
sshPort="${4:-2020}"
localMediaPath="./../../../../../pub/media/"


echo "
Setting up SSH ID
"
set +e
"ssh -p $sshPort root@$sshHost -oBatchMode=yes exit" &> /dev/null
if (( $? != 0 ))
then
    ssh-copy-id  -o StrictHostKeyChecking=no root@$sshHost -p $sshPort
fi
set -e



echo "$localMediaPath --> $remoteMediaPath";
rsync -avz \
    --omit-dir-times \
    --exclude '*/cache/*' \
    --exclude '*.gz' \
    -e "ssh -p $sshPort" \
    $localMediaPath \
    "root@$sshHost":"$remoteMediaPath"

echo "Done!";

echo "Logging in to remote and chaging file and directories permissions";

echo "
echo \"Changed directory to $remoteMediaPath\"
cd $remoteMediaPath;
echo \"Giving ownership and permissions to $remoteMediaPath\"
chown $remoteOwner:$remoteOwner -R .
find . -type f -exec chmod 664 {} \;
find . -type d -exec chmod 775 {} \;
echo \"All done!\"
" | ssh "root@$sshHost" -p $sshPort;
