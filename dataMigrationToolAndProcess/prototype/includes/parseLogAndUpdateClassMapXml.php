#!/usr/bin/env php
<?php
require __DIR__ . '/_top.inc.php';

function usage()
{
    echo "
    
    To be run after a migration attempt
    
    Will parse the log file and then update the class mapping xml with renames accordingly
    
    Usage:
    
    php -f " . basename(__FILE__) . " -- --vhostRoot=[root dir containing magento 2]
    
";
}

$mapFile = $vhostRoot . '/bin/dataMigration/class-map.xml';


/** @var DOMDocument $sxMapFile */
$xmlDom = new DOMDocument();
$xmlDom->load($mapFile);

$type = 'data';

$logPath = $logDir . '/' . $type . 'Migration.log';
echo "\nProcessing $type\n";
$logContents = file_get_contents($logPath);
$subTasks = [];
preg_match_all(
    '%\[ERROR\]: Class (?<class>[a-zA-Z0-9_/]+) does not exist%',
    $logContents,
    $classes
);
if (!empty($classes['class'])) {
    echo "\nFound " . count($classes['class']) . " Classes\n";
    $classMapNode = $xmlDom->getElementsByTagName('classmap')->item(0);
    foreach ($classes['class'] as $class) {
        echo "\n$class";
        $renameNode = $xmlDom->createElement('rename');
        $fromNode = $xmlDom->createElement('from', $class);
        $toNode = $xmlDom->createElement('to');
        $renameNode->appendChild($fromNode);
        $renameNode->appendChild($toNode);
        $classMapNode->appendChild($renameNode);
        $subTasks[] = ["Class $class is being renamed to empty", "Class $class is being renamed to empty - needs investigating"];
    }
}
if (!empty($subTasks)) {
    $jiraShell->queueIssue(
        'Magento 2 Data Migration, Class Mappings',
        'Classes have been added to the class map - each one needs to be investigated',
        $subTasks
    );
}
echo "\nSaving updated XML";
$xmlDom->save($mapFile, LIBXML_NOEMPTYTAG);

echo "\nALL DONE\n";
