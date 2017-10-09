#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash

function usage(){
    echo "

Usage:
    ./$0 [databaseName]

    databaseName    - The database name locally

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

mysql "$targetDb" -e "
update eav_attribute set frontend_input = 'text' where frontend_input not in (
'select',
'text',
'date',
'hidden',
'boolean',
'multiline',
'textarea',
'image',
'multiselect',
'price',
'weight',
'media_image',
'gallery'
)
"

mysql "$targetDb" -e "TRUNCATE TABLE design_change"
