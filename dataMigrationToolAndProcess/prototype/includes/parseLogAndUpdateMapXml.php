#!/usr/bin/env php
<?php
require __DIR__ . '/_top.inc.php';

function usage()
{
    echo "
    
    To be run after a migration attempt
    
    Will parse the log file and then update the mapping xml with excludes accordingly
    
    Usage:
    
    php -f " . basename(__FILE__) . " -- --vhostRoot=[root dir containing magento 2]
    
";
}

$type = 'data';
$logPath = $logDir . '/' . $type . 'Migration.log';
echo "\nCollecting $type information from " .  $type . "Migration.log... ";
$logContents = file_get_contents($logPath);

## parse out steps
preg_match_all(
    '%\[step: (?<step>.+?)\](?<log>.+?)((?=\[step)|$|\z)%s',
    $logContents,
    $steps
);

echo count($steps) . " steps found\n";

foreach ($steps['step'] as $k => $step) {
    $log = $steps['log'][$k];
    if (false !== strpos($log, 'ERROR')) {
        echo "\nErrors were found in step $step\n";
        processDocuments($step, $log);
        processFields($step, $log);
        processDestinationDocuments($step, $log);
        processDestinationFields($step, $log);
        processEavAttribute($step, $log);
        processEavEntityType($step, $log);
    }
}

echo "\nLog data processing complete\n";


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
     * @return DOMDocument
     */
    public function getDomByStep($step)
    {
        switch ($step) {
            case 'EAV Step Classes':
                $mapFile = 'class-map.xml';
                break;
            case 'EAV Step Groups':
                $mapFile = 'eav-attribute-groups.xml';
                break;
            case 'EAV Step':
                $mapFile = 'map-eav.xml';
                break;
            case 'Customer Attributes Step':
                $mapFile = 'map-customer.xml';
                break;
            default:
                $mapFile = 'map.xml';
        }

        return $this->getDom($mapFile);
    }

    /**
     * @param $mapFile
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

function processDocuments($step, $log)
{
    global $jiraShell;
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";
    $subTasks = [];
    echo "Finding unmapped documents... ";
    preg_match_all(
        '%\[ERROR\]: Source documents are not mapped. (?<documents>[a-zA-Z0-9_,-]+)%si',
        $log,
        $sourceDocuments
    );
    if (!empty($sourceDocuments['documents'])) {
        echo count($sourceDocuments['documents']) . " document lines found\n";
        echo "Processing documents... ";
        foreach ($sourceDocuments['documents'] as $n => $line) {
            echo "\n$line";
            $map = xmlUpdater::instance()->getDomByStep($step);
            $documentsToIgnore = explode(',', $line);
            $documentsToIgnore = array_map('trim', $documentsToIgnore);
            echo "\nFound " . count($documentsToIgnore) . " documents\n";
            $documentRulesNode = $map->getElementsByTagName('document_rules')->item(0);
            foreach ($documentsToIgnore as $i) {
                $ignoreNode = $map->createElement('ignore');
                $docNode = $map->createElement('document', $i);
                $ignoreNode->appendChild($docNode);
                $documentRulesNode->appendChild($ignoreNode);
                $subTasks[] = [
                    $jiraIssueTitlePrefix . ' , Ignored Doc: ' . $i,
                    $jiraIssueTitlePrefix . ' , Ignored Doc: ' . $i
                ];
            }
            echo "done\n";
        }
        if (!empty($subTasks)) {
            $jiraShell->queueIssue(
                $jiraIssueTitlePrefix . ' Ignored Documents',
                'Documents are being ignored. These need to be checked one by one to either confirm it should be ignored or to manage proper migration',
                $subTasks
            );
        }
    } else {
        echo "none found\n";
    }
}

function processFields($step, $log)
{
    echo "Finding unmapped fields for " . $step . "... ";
    global $jiraShell;
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";

    preg_match_all(
        '%\[ERROR\]: Source fields are not mapped. Document: (?<document>[^.]+?)\. Fields: (?<fields>[a-zA-Z0-9_,]+)%si',
        $log,
        $sourceFields
    );
    if (!empty($sourceFields['fields'])) {
        echo count($sourceFields['fields']) . " field lines found\n";
        echo "Processing fields...";
        foreach ($sourceFields['fields'] as $k => $line) {
            echo "\nLine $k: ";
            $map = xmlUpdater::instance()->getDomByStep($step);
            $document = $sourceFields['document'][$k];
            $fieldsToIgnore = explode(',', $line);
            $fieldsToIgnore = array_map('trim', $fieldsToIgnore);
            echo "found " . count($fieldsToIgnore) . " fields: " . implode(", ", $fieldsToIgnore) . "\n";
            $fieldRulesNode = $map->getElementsByTagName('field_rules')->item(0);
            foreach ($fieldsToIgnore as $i) {
                echo "[" . $i . "] adding to the ignore list... ";
                $ignoreNode = $map->createElement('ignore');
                $docNode = $map->createElement('field', "$document.$i");
                $ignoreNode->appendChild($docNode);
                $fieldRulesNode->appendChild($ignoreNode);
                echo "done\n";
                echo "[" . $i . "] preparing jira ticket... ";
                $subTasks[] = [
                    $jiraIssueTitlePrefix . ' , Ignored Field: ' . $i,
                    $jiraIssueTitlePrefix . ' Document: ' . $document . ' , Ignored Field: ' . $i
                ];
                echo "done\n";
            }
        }
        if (!empty($subTasks)) {
            $jiraShell->queueIssue(
                $jiraIssueTitlePrefix . ' Ignored Fields',
                'Fields are being ignored. These need to be checked one by one to either confirm it should be ignored or to manage proper migration',
                $subTasks
            );
        }
    } else {
        echo "none found\n";
    }
}

function processDestinationDocuments($step, $log)
{
    global $jiraShell;
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";
    $subTasks = [];
    echo "Finding unmapped destination documents... ";
    preg_match_all(
        '%\[ERROR\]: Destination documents are not mapped. (?<documents>[a-zA-Z0-9_,]+)%si',
        $log,
        $sourceDocuments
    );
    if (!empty($sourceDocuments['documents'])) {
        echo count($sourceDocuments['documents']) . " document lines found\n";
        echo "Processing destination documents... ";
        foreach ($sourceDocuments['documents'] as $n => $line) {
            echo "\n$line";
            $map = xmlUpdater::instance()->getDomByStep($step);
            $documentsToIgnore = explode(',', $line);
            $documentsToIgnore = array_map('trim', $documentsToIgnore);
            echo "\nFound " . count($documentsToIgnore) . " documents\n";
            $documentRulesNode = $map->getElementsByTagName('document_rules')->item(1);
            foreach ($documentsToIgnore as $i) {
                $ignoreNode = $map->createElement('ignore');
                $docNode = $map->createElement('document', $i);
                $ignoreNode->appendChild($docNode);
                $documentRulesNode->appendChild($ignoreNode);
                $subTasks[] = [
                    $jiraIssueTitlePrefix . ' , Ignored Doc: ' . $i,
                    $jiraIssueTitlePrefix . ' , Ignored Doc: ' . $i
                ];
            }
            echo "done\n";
        }
        if (!empty($subTasks)) {
            $jiraShell->queueIssue(
                $jiraIssueTitlePrefix . ' Ignored Documents',
                'Documents are being ignored. These need to be checked one by one to either confirm it should be ignored or to manage proper migration',
                $subTasks
            );
        }
    } else {
        echo "none found\n";
    }
}

function processDestinationFields($step, $log)
{
    echo "Finding unmapped destination fields $step... ";
    global $jiraShell;
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";

    preg_match_all(
        '%\[ERROR\]: Destination fields are not mapped. Document: (?<document>[^.]+?)\. Fields: (?<fields>[a-zA-Z0-9_,]+)%si',
        $log,
        $sourceFields
    );
    if (!empty($sourceFields['fields'])) {
        echo count($sourceFields['fields']) . " field lines found\n";
        echo "Processing destination fields... ";
        foreach ($sourceFields['fields'] as $k => $line) {
            echo "\nLine $k\n";
            $map = xmlUpdater::instance()->getDomByStep($step);
            $document = $sourceFields['document'][$k];
            $fieldsToIgnore = explode(',', $line);
            $fieldsToIgnore = array_map('trim', $fieldsToIgnore);
            echo "\nFound " . count($fieldsToIgnore) . " fields\n";
            $fieldRulesNode = $map->getElementsByTagName('field_rules')->item(1);
            foreach ($fieldsToIgnore as $i) {
                $ignoreNode = $map->createElement('ignore');
                $docNode = $map->createElement('field', "$document.$i");
                $ignoreNode->appendChild($docNode);
                $fieldRulesNode->appendChild($ignoreNode);
                $subTasks[] = [
                    $jiraIssueTitlePrefix . ' , Ignored Field: ' . $i,
                    $jiraIssueTitlePrefix . ' Document: ' . $document . ' , Ignored Field: ' . $i
                ];
            }
            echo "done\n";
        }
        if (!empty($subTasks)) {
            $jiraShell->queueIssue(
                $jiraIssueTitlePrefix . ' Ignored Fields',
                'Fields are being ignored. These need to be checked one by one to either confirm it should be ignored or to manage proper migration',
                $subTasks
            );
        }
    } else {
        echo "none found\n";
    }
}

function processEavEntityType(string $step, string $log): void
{
    if (! isEavStep($step)) {
        return;
    }

    echo "Finding EAV Entity Type Issues $step...\n";

    $document = 'eav_entity_type';
    $pattern  = '%\[ERROR\]: Incompatibility in data. Source document: ' . $document . '\. Field: (?<fields>[a-zA-Z0-9_,]+)\. Error: (?<error>[^]+)%si';
    $fields   = extractMatches($pattern, $log);

    if (empty($fields['fields'])) {
        echo "none found\n";
        return;
    }

    echo count($fields['fields']) . " issues found\n";
    echo "Processing issues ...\n";

    $subtasks = [];
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";

    foreach ($fields['fields'] as $index => $field) {
        $error = $fields['error'][$index];
        $class = extractMatches('%Class (?<class>[^ ]+) is not mapped .*%', $error)['class'][0];

        ignoreClass($class);

        $subtasks[] = [
            "$jiraIssueTitlePrefix, EAV Entity Type Issues $index",
            "$jiraIssueTitlePrefix, Document: $document, Field: $field, Error: $error"
        ];

        echo "$document - $field - $error\n";
    }

    queueJiraIssue(
        "$jiraIssueTitlePrefix, EAV Entity Type Issues",
        'EAV entity types that cannot currently be migrated',
        $subtasks
    );
}

function processEavAttribute(string $step, string $log): void
{
    if (! isEavStep($step)) {
        return;
    }

    echo "Finding EAV Attribute Issues $step...\n";

    $document = 'eav_attribute';
    $pattern  = '%\[ERROR\]: Incompatibility in data. Source document: ' . $document . '\. Field: (?<fields>[a-zA-Z0-9_,]+)\. Error: (?<error>[^]+)attribute_id=(?<attribute_id>[^]+)%si';
    $fields   = extractMatches($pattern, $log);

    if (empty($fields['fields'])) {
        echo "none found\n";
        return;
    }

    echo count($fields['fields']) . " issues found\n";
    echo "Processing issues ...\n";

    $subtasks = [];
    $jiraIssueTitlePrefix = "Magento 2 Data Migration, Step: $step";

    foreach ($fields['fields'] as $index => $field) {
        $id    = $fields['attribute_id'][$index];
        $error = $fields['error'][$index] . "attribute_id=$id";

        ignoreAttribute((int)$id);

        $subtasks[] = [
            "$jiraIssueTitlePrefix, EAV Attribute Issues $index",
            "$jiraIssueTitlePrefix, Document: $document, Field: $field, Error: $error, attribute_id: $id"
        ];

        echo "$document - $field - $error\n";
    }

    queueJiraIssue(
        "$jiraIssueTitlePrefix, EAV Attribute Issues",
        'EAV attributes that cannot currently be migrated',
        $subtasks
    );
}

function isEavStep(string $step): bool
{
    return 'EAV Step' === $step;
}

function extractMatches(string $pattern, string $subject): array
{
    preg_match_all($pattern, $subject, $matches);

    return $matches;
}

function queueJiraIssue(string $title, string $description, array $subtasks = []): void
{
    global $jiraShell;

    if ([] === $subtasks) {
        return;
    }

    $jiraShell->queueIssue($title, $description, $subtasks);
}

function ignoreAttribute(int $id): void
{
    global $migrationSelect;

    $query = <<<QUERY
SELECT
    entity_type_code, attribute_code
FROM
    `eav_attribute`
     JOIN `eav_entity_type` ON `eav_attribute`.`entity_type_id` = `eav_entity_type`.`entity_type_id`
WHERE
    attribute_id = ?
QUERY;

    $result = $migrationSelect->execute($query, [$id]);

    if (0 === \count($result)) {
        throw new \RuntimeException("No attribute found with id: $id");
    }

    $attr     = array_pop($result);
    $typeCode = $attr['entity_type_code'];
    $attrCode = $attr['attribute_code'];

    $config = xmlUpdater::instance()->getDomByStep('EAV Step Groups');

    // Check that ignore exists

    $hasIgnore = 'ignore' === $config->getElementsByTagName('group')->item(0)->getAttribute('name');

    if (! $hasIgnore) {
        $group     = $config->createElement('group');
        $attribute = $config->createAttribute('name');

        $attribute->value = 'ignore';

        $group->appendChild($attribute);
        $config->insertBefore($group, $config->firstChild);
    }

    // Add new ignore rule

    $ignore    = $config->getElementsByTagName('group')->item(0);
    $rule      = $config->createElement('attribute', $attrCode);
    $attribute = $config->createAttribute('type');

    $attribute->value = $typeCode;

    $rule->appendChild($attribute);
    $ignore->appendChild($rule);
}

function ignoreClass(string $class): void
{
    /*
     * https://github.com/magento/data-migration-tool/issues/444
     */

    $config   = xmlUpdater::instance()->getDomByStep('EAV Step Classes');
    $classmap = $config->getElementsByTagName('classmap')->item(0);

    $rename = $config->createElement('rename');
    $from   = $config->createElement('from', $class);
    $to     = $config->createElement('to', '');

    $rename->appendChild($from);
    $rename->appendChild($to);
    $classmap->appendChild($rename);
}
