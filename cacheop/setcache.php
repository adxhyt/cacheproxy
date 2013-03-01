<?php
/**
 * set cache 脚本
 */
header('Content-type: text/html;charset=utf8');
require_once ('../commons.php');

//得到原始的POST数据
$data = file_get_contents("php://input");
//得到GET数据
$stamp = $_GET['stamp'];

$cacheObj = Cache::instance();

$logHandle = new zx_log('cache_content', 'normal');

//初始化redis 查看cache队列处理status
$redis = new Redis();
$redis_key = "FIFO:MEM:SET:status";
$host = "192.168.60.4";
$port = 6579;
$timeout = 5;
$result = $redis->pconnect($host, $port, $timeout);
if (empty($result)) {
	$str = "redis server went away!";
	$logHandle->w_log(print_r($str, TRUE));	
	exit;
}

//得到本次操作前 process status
$result = $redis->hgetall($redis_key);
$processing = $result['processing'];
$processed = $result['processed'];
if ($stamp <= $processed) {
	echo "$stamp has been processed!\n";
}
if ($stamp <= $processing) {
	echo "$stamp has been processing!\n";
}
$redis->hset($redis_key, 'processing', $stamp);

$response = split_and_set($data, '||', $cacheObj, $logHandle);
if (empty($response)) {
	$log = new zx_log('cache_content_error', 'normal');
	$str = "stamp: $stamp error when operate, content is: $data\n";
	$logHandle->w_log(print_r($str, TRUE));
}

//本次操作后设置redis
$redis->hset($redis_key, 'processed', $stamp);

//处理cache值并set
function split_and_set($str, $delimiter = '||', $cacheObj, $logHandle) {
	$resp = array();
	$data = explode($delimiter, $str);
	if (empty($data)) {
		return FALSE;
	}
	foreach($data as $key => $value) {
		$temp = explode('&', $value);
		array_shift($temp);
		if (empty($temp[0]) || empty($temp[1]) || empty($temp[2])) {
			continue;
		}
		$resp[$key]['key'] = substr($temp[0], strlen('key='));
		$resp[$key]['expire'] = substr($temp[1], strlen('expire='));
		$arg = substr($temp[2], strlen('arg='));
		$resp[$key]['value'] = unserialize(base64_decode($arg));

		$logHandle->w_log(print_r($resp[$key], TRUE));
		$cacheObj->set($resp[$key]['key'], $resp[$key]['value'], $resp[$key]['expire']);
	} 
	return TRUE;
}
