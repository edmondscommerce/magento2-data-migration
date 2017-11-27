#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash

IFS=${standardIFS};

source includes/_dropAndRebuildDatabase.inc.bash

echo "
----------------
$(hostname) $0 completed
----------------
"
