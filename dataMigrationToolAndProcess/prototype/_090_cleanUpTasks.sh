#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
set -e
set -u
set -o pipefail
standardIFS="$IFS"
IFS=$'\n\t'
source ../../_top.inc.bash
echo "
===========================================
$(hostname) $0 $@
===========================================
"

echo "

And now, assuming it worked, lets flush caches etc

"
echo "
recompile
"
magento setup:di:compile

echo "
cache:flush
"
magento cache:flush
echo "
indexer:reindex
"
magento indexer:reindex

echo "
----------------
$(hostname) $0 completed
----------------
"