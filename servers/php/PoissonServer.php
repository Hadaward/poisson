<?php
//Requires:
//PHP 5.4+
//Sockets (extension=php_sockets.dll in php.ini)
define("Main","");
include_once('Server.php');
include_once('Room.php');
include_once('Client.php');
date_default_timezone_set('America/New_York');
//error_reporting(E_ALL);
error_reporting(E_ERROR);
set_time_limit(0);
ob_implicit_flush();

function printn($msg) {
    echo $msg."\n";
}

function sendOutput($msg) {
    echo date('Y-m-d H:i:s.').substr(strval(round(microtime() * 1000))."000000", 0, 6)." ".$msg."\n";
}

function getCurrentTime() {
    return time()+microtime();
}

$server = new Server("0.0.0.0",59156);
