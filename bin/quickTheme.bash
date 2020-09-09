#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;

function usage(){
    echo "

Usage:
    ./$0 mageroot themeName mainColour mainContrast secondaryColour secondaryContrast

    mageroot          - The Magento root directory
    themeName         - The name of the theme
    mainColour        - The main colour of the theme (Hex Code with no hash i.e. ffffff)
    mainContrast      - A colour to contrast the main colour of the theme (Hex Code with no hash i.e. 000000)
    secondaryColour   - The secondary colour of the Theme (Hex Code with no hash i.e. ffffff)
    secondaryContrast - A colour to contrast the secondary colour of the theme (Hex Code with no hash i.e. 000000)
    "
}

if (( $# < 6 ))
then
    usage
    exit 1
fi

### Paramaters ###
IFS=$standardIFS;
mageroot=$1;
themeName=$2;
mainColour=$3;
mainContrast=$4;
secondaryColour=$5;
secondaryContrast=$6;

cd $mageroot

design="app/design/frontend/";
themeBase="${design}${themeName}/Default/";
cssDir="${themeBase}web/css/source/"

echo "Creating Directory Structure
"

mkdir -p "$design"
mkdir -p "$themeBase"
mkdir -p "$cssDir"

echo "Creating Registartion File
"

cat >${themeBase}registration.php <<EOF
<?php

use \Magento\Framework\Component\ComponentRegistrar;

ComponentRegistrar::register(ComponentRegistrar::THEME, 'frontend/${themeName}/Default', __DIR__);

EOF

echo "Creating theme.xml File
"
cat >${themeBase}theme.xml <<EOF
<theme xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="urn:magento:framework:Config/etc/theme.xsd">
    <title>${themeName} Default</title>
    <parent>Magento/luma</parent>
</theme>

EOF

echo "Creating less stylesheet
"

cat >${cssDir}_extend.less <<EOF
@main_colour: #${mainColour};
@secondary_colour: #${secondaryColour};
@main_contrast: #${mainContrast};
@secondary_contrast: #${secondaryContrast};

@header__background-color: @main_colour;
@header_panel__background-color: @main_colour;

@button-primary__background: @main_colour;
@button-primary__hover__background: lighten(@main_colour, 5%);
@button-primary__hover__border: lighten(@main_colour, 5%);
@button-primary__color: @main_contrast;
@button-primary__border: @main_colour;

@navigation__background: @secondary_colour;
@navigation__border: @secondary_contrast;
@navigation-level0-item__background: @secondary_colour;
@navigation-level0-item__border: @secondary_contrast;
@navigation-level0-item__color: @secondary_contrast;

.navigation {
  color: @secondary_contrast;
}

.panel.wrapper {
  background-color: @main_colour;
}

.page-footer {
  background-color: @main_colour;
  color: @main_contrast;

  a {
    color: @main_contrast;
  }

  .bugs {
    display: none;
  }
}
EOF

echo "Running Magento Setup To Install the Theme
"

php /var/www/vhosts/www.magento2.dgu.developmagento.co.uk/bin/magento setup:upgrade

echo "Setting the theme with magerun2
"

command -v magerun2 >/dev/null 2>&1 || { echo >&2 "No magerun2 installed. Please use the Magento admin to set the theme."; exit 1; }

THEME_ID=$(magerun2 dev:theme:list --format=csv | grep "${themeName}/Default" | cut -d, -f1)
magerun2 config:set design/theme/theme_id "${THEME_ID}"

echo "
This theme generation script is a work in progress.
Please edit ${cssDir}_extend.less with custom changes and replicate any general improvements in this script.

"
