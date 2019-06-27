#!/usr/bin/env bash
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd $DIR;
source ../../_top.inc.bash
set -x
if [[ "$(whoami)" != "root" ]]
then
    echo "Please run this as root"
    exit 1
fi

function usage(){
    echo "

Usage:
    ./$0 [databaseName] (useBeast='true')

    [databaseName]    - The database name to fix up
    (useBeast='true') - Whether this is on the beast or not

    "
}

if (( $# < 2 ))
then
    usage
    exit 1
fi

IFS=$standardIFS;
databaseName=$1;
useBeast=${2:-"true"}


mysqlBeast="";
if [[ "$useBeast" == "true" ]]
then
    echo -n "Enter password for the beast mysql root user: ";
    read beastPassword
    mysqlBeast="-u root --password=${beastPassword} -h beast";
fi

# Prehook allows bin/dataMigration/preHooks/_04_fixKnownIssues.bash to be run before this
preHookFile

echo "
Remove orphaned attributes
"

mysql -NB $mysqlBeast "$databaseName" -e "
DELETE FROM catalog_eav_attribute
WHERE attribute_id NOT IN (
    SELECT attribute_id
    FROM eav_attribute
)
"
mysql -NB $mysqlBeast "$databaseName" -e "
DELETE FROM eav_entity_attribute
WHERE attribute_id NOT IN (
    SELECT attribute_id FROM eav_attribute
)
"

echo "
Remove orphaned attribute values
"
for f in datetime decimal gallery int media_gallery text varchar
do
    mysql -NB $mysqlBeast "$databaseName" -e "
    DELETE FROM catalog_product_entity_$f
    WHERE attribute_id NOT IN (
        SELECT attribute_id FROM eav_attribute
    )
    "
done

echo "
Remove unknown types
"

mysql -NB $mysqlBeast "$databaseName" -e "
DELETE FROM eav_attribute
WHERE entity_type_id NOT IN (
    SELECT entity_type_id FROM eav_entity_type
)
"
mysql -NB $mysqlBeast "$databaseName" -e "
DELETE FROM eav_attribute_set
WHERE entity_type_id NOT IN (
    SELECT entity_type_id FROM eav_entity_type
)
"

echo "
Now sorting out duplicate customer entity issues
"
mysql -NB $mysqlBeast "$databaseName" -e "
SELECT c1.entity_id, c1.email
FROM customer_entity c1
JOIN customer_entity c2 on (
    c1.email = c2.email
    and c1.website_id = c2.website_id
    and c1.entity_id != c2.entity_id
)
group by c1.email
" | while read entity_id email
do
    echo "Updating $email"
    mysql $mysqlBeast "$databaseName" -e "
    update customer_entity
    set email = TRIM(replace(email, email, CONCAT(email, '.DataMigrationDedupe')))
    WHERE entity_id = $entity_id
    "
done

echo "
And missing customer issues
"
mysql -NB $mysqlBeast "$databaseName" -e "
DELETE FROM tag
WHERE first_customer_id IS NOT NULL
AND first_customer_id NOT IN (
    SELECT entity_id FROM customer_entity
)
"
echo "

Done

"

# Fixes error:  Foreign key (FK_SALES_ORDER_TAX_ITEM_ITEM_ID_SALES_FLAT_ORDER_ITEM_ITEM_ID) constraint fails.
# Orphan records id: 1551,1607,1865,2272,2452,2453,2488,2985,2993,2994,3003,3004,3005,3006,3049 from `sales_order_tax_item`.`item_id` has no referenced records in `sales_flat_order_item`
echo "

Fixing any orphaned tax transaction records

"
mysql $mysqlBeast "$databaseName" -e "
DELETE FROM sales_order_tax_item
WHERE item_id NOT IN (
  SELECT item_id
  FROM sales_flat_order_item
);"



echo "

Fixing any orphaned configurable product labels

"
mysql $mysqlBeast "$databaseName" -e "
DELETE FROM catalog_product_super_attribute_label
WHERE product_super_attribute_id NOT IN (
  SELECT product_super_attribute_id
  FROM catalog_product_super_attribute
);"



echo "

Fixing any orphaned attribute options

"
mysql $mysqlBeast "$databaseName" -e "
DELETE FROM eav_attribute_option
WHERE attribute_id NOT IN (
  SELECT attribute_id
  FROM eav_attribute
);"


echo "

Fixing any orphaned attribute options

"
mysql $mysqlBeast "$databaseName" -e "
DELETE FROM sales_flat_quote_item_option
WHERE item_id NOT IN (
  SELECT item_id
  FROM sales_flat_quote_item
);"


echo "

Adding missing required attribute set groups

";

for group in 'General' 'Prices' 'Design' 'Images'
do
    mysql -NB $mysqlBeast "$databaseName" -e "
        SELECT
            eav_attribute_set.attribute_set_id,
            eav_attribute_set.attribute_set_name
        FROM
            eav_attribute_set
            JOIN eav_attribute_group ON eav_attribute_set.attribute_set_id = eav_attribute_group.attribute_set_id
        WHERE
            eav_attribute_set.attribute_set_id NOT IN (
                SELECT
                    eav_attribute_set.attribute_set_id
                FROM
                    eav_attribute_set
                    JOIN eav_attribute_group ON eav_attribute_set.attribute_set_id = eav_attribute_group.attribute_set_id
                WHERE
                    eav_attribute_group.attribute_group_name = '$group'
            )
            AND eav_attribute_set.attribute_set_name <> 'Default'
        GROUP BY
            eav_attribute_set.attribute_set_id
    " | while read attribute_set_id attribute_set_name
    do
        echo "Adding group '$group' to attribute set '$attribute_set_name'";

        mysql $mysqlBeast "$databaseName" -e "
            INSERT INTO eav_attribute_group (
                attribute_set_id, attribute_group_name, sort_order, default_id
            ) VALUES (
                $attribute_set_id, '$group', 100, 0
            )
        "
    done
done

echo "

Done

"

# Posthook allows bin/dataMigration/preHooks/_04_fixKnownIssues.bash to be run before this
postHookFile