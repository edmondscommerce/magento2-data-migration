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

hostname=$(hostname)
split=(${hostname//-/$IFS})
readonly clientname=${split[0]}
readonly subSubDomain=${split[1]}
readonly vhostRoot="/var/www/vhosts/www.$subSubDomain.$clientname.developmagento.co.uk"
readonly dbName="$clientname"
readonly dbUser="$clientname"
readonly keyMasterIp="192.168.236.109"

readonly beastDbUsername="cnt_${clientname}";
readonly beastDbPrefix="${clientname}_";

#https://gist.github.com/JamieMason/4761049
function program_is_installed {
  # set to 1 initially
  local return_=1
  # set to 0 if not found
  type $1 >/dev/null 2>&1 || { local return_=0; }
  # return value
  echo "$return_"
}

localLiveFilesStorage=${vhostRoot}/bin/dataMigration/mage1Files
magento1Version=$(cat ${localLiveFilesStorage}/mage1Version.txt)
magento1CryptKey="$(xmllint --xpath "string(config/global/crypt)"  ${localLiveFilesStorage}/local.xml)"
magento1DbName="${clientname}_magento1";
magento1DbPrefix="$(xmllint --xpath "string(config/global/resources/db/table_prefix)"  ${localLiveFilesStorage}/local.xml)"
magento2DbName="${clientname}_magento2";
dataMigrationDir=${vhostRoot}/bin/dataMigration