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
    ./$0 [sshUser] [sshHost] [remoteMediaPath] [destinationLocalMediaPath] [databaseName] (sshPort=22) (useBeast=true)

    sshUser         - The SSH user
    sshHost         - The SSH host
    remoteMediaPath - The remote public path containing the Magento 1 media directory
    destinationDir  - The path to put the media files in
    databaseName    - The database name locally
    sshPort         - The SSH port number
    useBeast        - Use the beast as the database
    "
}

if (( $# < 5 ))
then
    usage
    exit 1
fi

### Paramaters ###
IFS=$standardIFS;
sshUser=$1
sshHost=$2
remoteMediaPath=$3
m2MediaPath=$4;
databaseName=$5;



sshPort=${6:-22}
useBeast=${7:-"true"}
echo "$sshPort";

### VARIABLES ###
#Remote paths (source)
remoteCatalogProductPath="$remoteMediaPath/catalog/product";
remoteCatalogCategoryPath="$remoteMediaPath/catalog/category";
remoteWysiwygPath="$remoteMediaPath/wysiwyg/";

#M2 paths (destination)
m2CatalogPath="$m2MediaPath/catalog/";
m2CatalogProductPath="${m2CatalogPath}product/"
m2CatalogCategoryPath="${m2CatalogPath}category/"
m2WysiwygPath="$m2MediaPath/wysiwyg/"

mysqlBeast="";
if [[ "$useBeast" == "true" ]]
then
    mysqlBeast="-u root -p -h beast";
fi


echo "

Ensuring required directories exist

"

if [[ ! -d "$m2MediaPath" ]]
then
    mkdir "$m2MediaPath";
fi
if [[ ! -d "$m2CatalogPath" ]]
then
    mkdir "$m2CatalogPath";
fi
if [[ ! -d "$m2CatalogProductPath" ]]
then
    mkdir "$m2CatalogProductPath";
fi
if [[ ! -d "$m2CatalogCategoryPath" ]]
then
    mkdir "$m2CatalogCategoryPath";
fi
if [[ ! -d "$m2WysiwygPath" ]]
then
    mkdir "$m2WysiwygPath";
fi


echo "

Getting list of product images to retrieve

"
#Clear the old index
productImageList="${m2MediaPath}/catalog_product_image.txt";
if [[ -f "$productImageList" ]]
then
    rm "$productImageList";
fi
touch "$productImageList";

mysql -NB $mysqlBeast "$databaseName" -e "SELECT t1.value
FROM catalog_product_entity_varchar AS t1
WHERE t1.value != 'no_selection'
      AND t1.attribute_id IN
          (
            SELECT eav_attribute.attribute_id
            FROM eav_attribute
            WHERE attribute_code IN ('image', 'small_image') AND entity_type_id IN (
              SELECT eav_entity_type.entity_type_id
              FROM eav_entity_type
              WHERE entity_type_code IN ('catalog_product')
            ))
  UNION
SELECT catalog_product_entity_media_gallery.value FROM catalog_product_entity_media_gallery;" | while read image
do
    echo "$image" >> "$productImageList";
done

echo "

Rsyncing Media from Live

"

set +e
echo "$remoteCatalogProductPath --> $m2CatalogProductPath";
rsync -avz -e "ssh -p $sshPort" --files-from="$productImageList" "$sshUser@$sshHost":"$remoteCatalogProductPath" "$m2CatalogProductPath"

echo "$remoteCatalogCategoryPath --> $remoteCatalogCategoryPath";
rsync -avz -e "ssh -p $sshPort" "$sshUser@$sshHost":"$remoteCatalogCategoryPath" "$m2CatalogCategoryPath";

echo "$remoteWysiwygPath --> $m2WysiwygPath";
rsync -avz -e "ssh -p $sshPort" "$sshUser@$sshHost":"$remoteWysiwygPath" "$m2WysiwygPath";
set -e

echo "
Done
";

echo -n "Calculating size of $m2MediaPath... "
du -hs "$m2MediaPath" | cut -f1;

echo -n "Changing ownership of M2 media folder to ec... "
chown ec:ec "$m2MediaPath" -R
echo "done"