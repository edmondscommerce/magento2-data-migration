<?php
set_error_handler(function ($errNo, $errStr, $errFile, $errLine) {
    $msg = "\n\n$errStr \n\nFile: $errFile \n\nLine $errLine\n\n";
    throw new ErrorException($msg, $errNo);
});
set_exception_handler(function (Throwable $e) {
    echo $e->getMessage();
    echo "\nTrace:\n------------------------------------------\n";
    $skippedErrorHandler = false;
    foreach ($e->getTrace() as $k => $i) {
        if (!$skippedErrorHandler) {
            $skippedErrorHandler = true;
            continue;
        }
        echo "\n[ $k ]\n";
        var_dump($i);
    }
    echo "\n------------------------------------------\n";
});
echo "

===========================================
" . php_uname('n') . " " . basename(__FILE__) . " " . implode(' ', $argv) . "
===========================================

";

$shortopts = "";
$longopts = [];
# required - vhostRoot
$longopts[] = "vhostRoot:";

$options = getopt($shortopts, $longopts);
if (empty($options)) {
    usage();
    exit(1);
}


$vhostRoot = $options['vhostRoot'];

$logDir = $vhostRoot . '/var/dataMigration/';

require '/home/ec/jiraShell/jiraShell.php';

$jiraShell = new jiraShell();
