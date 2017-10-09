#!/usr/bin/env php
<?php
require __DIR__ . '/_top.inc.php';

function usage()
{
    echo "
    
    To be run after a migration attempt
    
    Will parse the move.xml file and then update the map.xml with fields that needs to be moved to particular place
    
    Usage:
    
    php -f " . basename(__FILE__) . " -- --vhostRoot=[root dir containing magento 2]
    
";
}

removeIgnoredNodes();
removeDestinationIgnoredNodes();
appendMoveFieldRulesToMapXml();
renameDocuments();
ignoreAttributes();

/**
 * Matches the move fields in the move.xml file, and removes specific
 * <ignore><field>Something something</field></ignore> nodes from map.xml
 */

function removeIgnoredNodes()
{
    $file = 'move.xml';

    $moveFieldValues = getMoveFieldValues($file, 'field');

    $map = xmlUpdater::instance()->getDomByFile('map.xml');

    $xpath = new DOMXPath($map);
    // find all the ignore nodes, that has field with the values from move.xml
    $query                = "//map/source/field_rules/ignore[./field = '" . implode("' or ./field = '",
                                                                                    $moveFieldValues) . "']";
    $movieFieldValueNodes = $xpath->query($query);

    if ($movieFieldValueNodes !== false && $movieFieldValueNodes->length !== 0) {
        $fieldRulesNode = $map->getElementsByTagName('field_rules')->item(0);
        foreach ($movieFieldValueNodes as $moveFieldValueNode) {
            $fieldRulesNode->removeChild($map->importNode($moveFieldValueNode, true));
        }
    }
    echo "Removed ignored nodes " . implode(", ", $moveFieldValues) . "\n";
}

/**
 * Matches the move fields in the move.xml file, and removes specific
 * <ignore><field>Something something</field></ignore> nodes from map.xml
 */

function removeDestinationIgnoredNodes()
{
    $file = 'move.xml';

    $moveFieldValues = getMoveFieldValues($file, 'to');


    $map = xmlUpdater::instance()->getDomByFile('map.xml');

    $xpath = new DOMXPath($map);
    // find all the ignore nodes, that has field with the values from move.xml
    $query = "//map/destination/field_rules/ignore[./field = '" . implode("' or ./field = '", $moveFieldValues) . "']";

    $movieFieldValueNodes = $xpath->query($query);

    if ($movieFieldValueNodes !== false && $movieFieldValueNodes->length !== 0) {
        $fieldRulesNode = $map->getElementsByTagName('field_rules')->item(1);
        foreach ($movieFieldValueNodes as $moveFieldValueNode) {
            $fieldRulesNode->removeChild($map->importNode($moveFieldValueNode, true));
        }
    }
    echo "Removed ignored nodes " . implode(", ", $moveFieldValues) . "\n";
}

/**
 * Find all move nodes in the specified XML file
 * You can pass @param $skipNodes which will skip specific nodes from the return
 */

function getMoveFieldNodes($file = 'move.xml', $skipNodes = array())
{
    $move = xmlUpdater::instance()->getDomByFile($file);
    // find all the move fields in the file
    $xpath = new DOMXPath($move);
    $query = '//map/source/field_rules/move';

    if (!empty($skipNodes)) {
        // find all move fields, except not the ones that exist in $skipNodes array
        $query = "//map/source/field_rules/move[./field != '" . implode("' and ./field != '", $skipNodes) . "']";
    }

    $fieldRulesMove = $xpath->query($query);

    return $fieldRulesMove;
}

function renameDocuments($file = 'move.xml')
{
    $move = xmlUpdater::instance()->getDomByFile($file);
    // find all the move fields in the file
    $xpath = new DOMXPath($move);
    $query = '//map/source/document_rules/rename';

    $fieldRulesMove = $xpath->query($query);
    $map            = xmlUpdater::instance()->getDomByFile('map.xml');
    $mapPath        = new DOMXPath($map);

    foreach ($fieldRulesMove as $element) {
        /** @var $element DOMElement */
        $document = $element->getElementsByTagName('document')->item(0)->textContent;
        $mapQuery = "//map/source/document_rules/ignore/document[.=\"$document\"]";
        $result   = $mapPath->query($mapQuery);
        if ($result->length > 0) {
            $ignoredNode = $result->item(0)->parentNode;
            $ignoredNode->parentNode->removeChild($ignoredNode);
        }

        $imported = $map->importNode($element, true);
        $map->getElementsByTagName('document_rules')->item(0)->appendChild($imported);
    }
}

function ignoreAttributes($file = 'move.xml')
{
    $move = xmlUpdater::instance()->getDomByFile($file);
    // find all the move fields in the file
    $xpath              = new DOMXPath($move);
    $query              = '//map/source/attributes/ignore/attribute';
    $fieldRulesMove     = $xpath->query($query);
    $eavAttributeGroups = xmlUpdater::instance()->getDomByFile('eav-attribute-groups.xml');
    foreach ($fieldRulesMove as $element) {
        $imported = $eavAttributeGroups->importNode($element, true);
        $eavAttributeGroups->getElementsByTagName('group')->item(0)->appendChild($imported);
    }
}

/**
 * In combination with getMoveFieldValues(), gets the node text values of found nodes
 *
 * @return array
 */

function getMoveFieldValues($file = 'move.xml', $fieldName = 'field')
{
    $fieldRules            = getMoveFieldNodes($file);
    $fieldValuesCollection = [];
    foreach ($fieldRules as $fieldRule) {
        // get field node value
        $field      = $fieldRule->getElementsByTagName($fieldName)->item(0);
        $fieldValue = $field->textContent;
        // add all fields to array
        $fieldValuesCollection[] = $fieldValue;
    }

    return $fieldValuesCollection;
}

/**
 * Compares move.xml and map.xml for <move> nodes, and appends the missing one to map.xml
 */

function appendMoveFieldRulesToMapXml()
{
    $mapFile  = 'map.xml';
    $moveFile = 'move.xml';

    $map            = xmlUpdater::instance()->getDomByFile($mapFile);
    $fieldRulesNode = $map->getElementsByTagName('field_rules')->item(0);
    if ($fieldRulesNode) {
        $mapXmlMoveFieldValues  = getMoveFieldValues($mapFile, 'field');
        $moveXmlMoveFieldValues = getMoveFieldValues($moveFile, 'field');

        $skipNodes = [];
        if (!empty($mapXmlMoveFieldValues)) {
            foreach ($mapXmlMoveFieldValues as $moveFieldValue) {
                if (in_array($moveFieldValue, $moveXmlMoveFieldValues)) {
                    // specifies, which nodes exist in map.xml already, therefore can be skipped
                    $skipNodes[] = $moveFieldValue;
                }
            }
        }

        $moveNodes = getMoveFieldNodes($moveFile, $skipNodes);
        foreach ($moveNodes as $moveNode) {
            // append field_rules node with move nodes from move.xml
            $fieldRulesNode->appendChild($map->importNode($moveNode, true));
        }
    }
    echo "Appended <move> nodes \n";
}


echo "\nALL DONE\n";


######## FUNCTIONS ########

class xmlUpdater
{
    private $doms = [];

    private static $instance;

    private function __construct()
    {
        //singleton only
    }

    /**
     * @return xmlUpdater
     */
    public static function instance()
    {
        if (!static::$instance) {
            static::$instance = new static();
        }

        return static::$instance;
    }

    /**
     * @param string $step
     *
     * @return DOMDocument
     */
    public function getDomByStep($step)
    {
        switch ($step) {
            case 'EAV Step':
                $mapFile = 'map-eav.xml';
                break;

            default:
                $mapFile = 'map.xml';
        }

        return $this->getDom($mapFile);
    }

    public function getDomByFile($mapFile)
    {
        return $this->getDom($mapFile);
    }

    /**
     * @param $mapFile
     *
     * @return DOMDocument
     */
    protected function getDom($mapFile)
    {
        if (!isset($this->doms[$mapFile])) {
            $xmlDom = new DOMDocument();
            $xmlDom->load($GLOBALS['vhostRoot'] . '/bin/dataMigration/' . $mapFile);
            $this->doms[$mapFile] = $xmlDom;
        }

        return $this->doms[$mapFile];
    }

    public function __destruct()
    {
        foreach ($this->doms as $mapFile => $xmlDom) {
            $xmlDom->formatOutput = true;
            $xmlDom->save($GLOBALS['vhostRoot'] . '/bin/dataMigration/' . $mapFile);
        }
    }
}