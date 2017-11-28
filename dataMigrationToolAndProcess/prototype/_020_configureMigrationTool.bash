#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd ${DIR};
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

useBeast=${1:-"true"}
mysqlHost="localhost";
dbUsername="root";
if [[ "${useBeast}" == "true" ]]
then
    mysqlHost="beast";
    dbUsername=${beastDbUsername};
fi

function copyMagentoDistFile() {

    if [[ "$#" == "0" ]]
    then
        echo "Usage: copyMagentoDistFile [distFileName] (versionFolderPrefix='')"
        echo "Example: copyMagentoDistFile map 1.9.0.1"
        exit 1
    fi

    local distFileName="$1"
    local versionFolder="${2:-''}"

    echo -n "Setting up $distFileName.xml file..."
    cd ${dataMigrationDir}
    if [[ ! -f ./map.xml ]]
    then
        cp ${xmlConfigFoldersPath}/${magento1Version}/map.xml.dist ./map.xml
    fi

    sed -i "s#/map.xml.dist#/map.xml#"  ./config.xml
    cd ${xmlConfigFoldersPath}/${magento1Version}/
    set +e
    rm -f map.xml
    ln -s ${dataMigrationDir}/map.xml
    set -e
    cd ${vhostRoot}
    echo "done"


}

cd ${vhostRoot}

cronTabContents=$(crontab -l)
if [[ "" != "${cronTabContents}" ]]
then
    echo "Removing crontab contents"
    echo "-------------------------"
    echo "saving current crontab to _crontab_temp"
    echo ${cronTabContents} > ${vhostRoot}/_crontab_temp
    echo '' | crontab
    echo "crontab -l:"
    crontab -l
fi

dataMigrationToolDir=${vhostRoot}/vendor/magento/data-migration-tool

if [ ! -d ${dataMigrationToolDir} ]
then
    echo "

    Installing Data Migration Tool

    "
    #magento2Version="2$(magento --version --no-ansi | cut -d '2' -f 2)"
    composer config repositories.data-migration-tool vcs https://github.com/edmondscommerce/data-migration-tool
    composer require magento/data-migration-tool:dev-master --dev --prefer-source
    cd ${vhostRoot}/vendor/magento/data-migration-tool
    git remote add magento https://github.com/magento/data-migration-tool.git
    git pull magento master
    echo "

YOU NEED TO DO THIS NEXT COMMAND FROM A TERMINAL ON YOUR HOST MACHINE
only required if there were changes pulled down just above

COMMAND:
cd /var/lib/lxc/$(hostname | sed 's/-desktop//')/rootfs/${dataMigrationToolDir}; git push origin master

please press any key to continue..
    "
    read confirm

else
    echo "Found existing data migration tool folder at:"
    echo ${vhostRoot}/vendor/magento/data-migration-tool
fi

echo -n "Checking that the dist config files exist... "

if [[ -d ${vhostRoot}/vendor/magento/data-migration-tool/etc/ce-to-ce ]]
then
    xmlConfigFoldersPath=${vhostRoot}/vendor/magento/data-migration-tool/etc/ce-to-ce
elif [[ -d ${vhostRoot}/vendor/magento/data-migration-tool/etc/opensource-to-opensource ]]
then
    xmlConfigFoldersPath=${vhostRoot}/vendor/magento/data-migration-tool/etc/opensource-to-opensource
else
    echo "Couldn't find Magento's XML config files at either of these paths:"
    echo ${vhostRoot}/vendor/magento/data-migration-tool/etc/ce-to-ce
    echo ${vhostRoot}/vendor/magento/data-migration-tool/etc/opensource-to-opensource
    exit 1
fi

echo "done"

if [[ "" != "${magento1Version}" ]]
then
    echo "Using files for Magento 1 version ${magento1Version}"
    if [ ! -d ${xmlConfigFoldersPath}/${magento1Version} ]
    then
        echo "Invalid magento1Version ${magento1Version}"
        echo "Faileding finding directory: ${xmlConfigFoldersPath}/${magento1Version}"
        exit 1
    fi
else
    echo "What Magento 1 Version are we migrating from?"
    echo "
    Hint: you might want to run:
        grep -A6 'static function getVersionInfo' app/Mage.php
    On the Magento 1 server to get the version
    "
    dataMigrationVersions=( $(
        cd ${xmlConfigFoldersPath};
        find . -type d ! -path . \
        | sed 's#\./##g' \
        | sort -n
    ) )
    select opt in "${dataMigrationVersions}[@]"
    do
        if [[ "" != "${opt}" ]]
        then
            echo "You chose:"
            echo ${opt};
            echo
            echo "confirm y/n:"
            read confirm
            if [[ "y" == "${confirm}" ]]
            then
                magento1Version=${opt}
                break;
            else
                echo "You didn't confirm, please try again"
            fi
        else
            echo "... please select a valid option"
        fi
    done
fi

mkdir -p ${dataMigrationDir}
cd ${dataMigrationDir}
echo -n "Copying the distributed config.xml... "
cp ${xmlConfigFoldersPath}/${magento1Version}/config.xml.dist ./config.xml
echo "done"

echo -n "Getting mysql password from ~/.my.cnf... "
mysqlRootPass=$(cat ~/.my.cnf | grep password | cut -d = -f 2)
echo "done"

echo -n "Updating the config.xml file with the Magento 1 database details... "
magento1DbXmlFind='<database host="localhost" name="magento1" user="root"/>'
magento1DbXmlReplace="<database host=\"${mysqlHost}\" name=\"${magento1DbName}\" user=\"${dbUsername}\" password=\"${mysqlRootPass}\"/>"
sed -i  "s#${magento1DbXmlFind}#${magento1DbXmlReplace}#" ./config.xml
echo "done"

echo -n "Updating the config.xml file with the Magento 2 database details... "
magento2DbXmlFind='<database host="localhost" name="magento2" user="root"/>'
magento2DbXmlReplace="<database host=\"${mysqlHost}\" name=\"${magento2DbName}\" user=\"${dbUsername}\" password=\"${mysqlRootPass}\"/>"

sed -i  "s#${magento2DbXmlFind}#${magento2DbXmlReplace}#" ./config.xml
echo "done"

echo -n "Updating the config.xml file with other configurations... "
sed -i "#<source_prefix />#<source_prefix>${magento1DbPrefix}</source_prefix>#" ./config.xml

sed -i "s#<crypt_key />#<crypt_key>${magento1CryptKey}</crypt_key>#" ./config.xml

# better performance apparently
sed -i "s#<direct_document_copy>0#<direct_document_copy>1#"  ./config.xml
echo "done"

echo "
Setting up XML Config files in ${dataMigrationDir}"

echo -n "Setting up map.xml file..."

cd ${dataMigrationDir}
if [[ ! -f ./map.xml ]]
then
    cp ${xmlConfigFoldersPath}/${magento1Version}/map.xml.dist ./map.xml
fi

sed -i "s#/map.xml.dist#/map.xml#"  ./config.xml
cd ${xmlConfigFoldersPath}/${magento1Version}/
set +e
rm -f map.xml
ln -s ${dataMigrationDir}/map.xml
set -e
cd ${vhostRoot}
echo "done"

echo -n "Setting up map-eav.xml... "
cd ${dataMigrationDir}
if [[ ! -f ./map-eav.xml ]]
then
    cp ${xmlConfigFoldersPath}/map-eav.xml.dist ./map-eav.xml
fi
sed -i "s#/map-eav.xml.dist#/map-eav.xml#"  ./config.xml
cd ${xmlConfigFoldersPath}/
set +e
rm -f map-eav.xml
ln -s ${dataMigrationDir}/map-eav.xml
set -e
cd ${vhostRoot}
echo "done"

echo -n "Setting up eav-attribute-groups.xml... "
cd ${dataMigrationDir}
if [[ ! -f ./eav-attribute-groups.xml ]]
then
    cp ${xmlConfigFoldersPath}/eav-attribute-groups.xml.dist ./eav-attribute-groups.xml
fi
sed -i "s#/eav-attribute-groups.xml.dist#/eav-attribute-groups.xml#"  ./config.xml
cd ${xmlConfigFoldersPath}/
set +e
rm -f eav-attribute-groups.xml
ln -s ${dataMigrationDir}/eav-attribute-groups.xml
set -e
cd ${vhostRoot}
echo "done"


echo -n "Setting up class-map.xml..."
cd ${dataMigrationDir}
if [[ ! -f ./class-map.xml ]]
then
    cp ${xmlConfigFoldersPath}/class-map.xml.dist ./class-map.xml
fi
sed -i "s#/class-map.xml.dist#/class-map.xml#"  ./config.xml
cd ${xmlConfigFoldersPath}/
set +e
rm -f class-map.xml
ln -s ${dataMigrationDir}/class-map.xml
set -e
cd ${vhostRoot}
echo "done"

echo -n "Setting up move.xml... "
cd ${dataMigrationDir}
if [[ ! -f 'move.xml' ]]; then
    cat << EOF > move.xml
<?xml version="1.0" encoding="UTF-8"?>
<map xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xs:noNamespaceSchemaLocation="../../map.xsd">
    <source>
        <field_rules></field_rules>
        <document_rules></document_rules>
        <attributes></attributes>
    </source>
</map>
EOF
fi
echo "done"

echo "
----------------
$(hostname) $0 completed
----------------
"