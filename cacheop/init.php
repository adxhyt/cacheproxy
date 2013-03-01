<?php
//ATTENTION!!!
//run the script only once at the beginning and not aging;

$fileHandle = fopen("op.conf", "r");

if (!$fileHandle) {
    echo "load config file error!\n";
	exit(1);
}
else {
    $host = trim(fgets($fileHandle, 4096));
    $port = trim(fgets($fileHandle, 4096));

	$redis = new Redis();
	$redis->pconnect($host, $port, 5);

	$stampKey = "FIFO:MEM:stamp";
	if ($redis->exists($stampKey)) {
		die("exists stampkey!\n");
	}
	$redis->set($stampKey, 1);
	
	//for set only
	$set_stampKey = "FIFO:MEM:SET:stamp";
	if ($redis->exists($set_stampKey)) {
		die("exists set stampkey!\n");
	}
	$redis->set($set_stampKey, 1);

	$statusKey = "FIFO:MEM:status";
	if ($redis->exists($statusKey)) {
		die("exists statusKey!\n");
	}
	$redis->hset($statusKey, 'processing', 0);
	$redis->hset($statusKey, 'processed', 0);

	//for set only
	$set_statusKey = "FIFO:MEM:SET:status";
	if ($redis->exists($set_statusKey)) {
		die("exists set statusKey!\n");
	}
	$redis->hset($set_statusKey, 'processing', 0);
	$redis->hset($set_statusKey, 'processed', 0);
}

