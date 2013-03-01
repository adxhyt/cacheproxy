<?php

ini_set("memory_limit", "7096M");

$fileHandle = fopen("op.conf", "r");

if (!$fileHandle) {
    echo "load config file error!\n";
	exit(1);
}
else {
	//init
    $host = trim(fgets($fileHandle, 4096));
    $port = trim(fgets($fileHandle, 4096));
    $url = trim(fgets($fileHandle, 4096));
	$limit = trim(fgets($fileHandle, 4096)); //每次发送操作数据个数
    fclose($fileHandle);

    $fifo_name = "FIFO:MEM:SET";
	$status_url = $url . "/status?key=set";
    $sync_url = $url . "/setcache";

    $handing_proxy = match_proxy($status_url); 
    if (empty($handing_proxy)) {
        exit("receive empty response from the proxy!");
    }  
	
	$opHandler = new memOperate($fifo_name, $host, $port, $limit);
	while (1) {
		$current_stamp = $opHandler->get_stamp();

		$contents = $opHandler->get_hash($current_stamp);

        if (empty($contents)) {
            $ret = $opHandler->load();
            $contents = $opHandler->get_hash($current_stamp);
        }

        if (empty($contents)) {
            continue;
        }

		$trans_contents = implode("||", $contents);
		$trans_url = $sync_url . "?stamp=" . $current_stamp;
		list($curl_info, $ret) = trans($trans_contents, $trans_url);
		if (200 == $curl_info['http_code']) {
			if (!empty($ret)) {
				print_r($ret);
			}
			//process success
			$opHandler->passed($current_stamp);
		}
		else {
            print_r($curl_info);
			//do nothing, just try again
			continue;
		}
    }

}

function trans($post_body = NULL, $url) {
    static $handle = NULL;
    empty($handle) && $handle = curl_init();
    $header[] = "Connection: keep-alive";
	$header[] = "Content-Type: application/x-www-form-urlencoded";
    $header[] = "Keep-Alive: 60";
    $header[] = "Expect:";
    curl_setopt($handle, CURLOPT_CONNECTTIMEOUT, 5); 
    curl_setopt($handle, CURLOPT_TIMEOUT, 5); 
    curl_setopt($handle, CURLOPT_HEADER, FALSE);
    curl_setopt($handle, CURLOPT_URL, $url);
    curl_setopt($handle, CURLOPT_HTTPHEADER, $header);
    curl_setopt($handle, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($handle, CURLOPT_POST, TRUE);
    curl_setopt($handle, CURLOPT_POSTFIELDS, $post_body);

    $ret = curl_exec($handle);
    $info = curl_getinfo($handle);
    return array($info, $ret);
}

function match_proxy($url) {
    static $adapt_handle = NULL;
    empty($adapt_handle) && $adapt_handle = curl_init();
    $adapt_handle = curl_init();
    $header[] = "Connection: keep-alive";
	$header[] = "Content-Type: application/x-www-form-urlencoded";
    $header[] = "Keep-Alive: 60";
    $header[] = "Expect:";
    curl_setopt($adapt_handle, CURLOPT_CONNECTTIMEOUT, 5);
    curl_setopt($adapt_handle, CURLOPT_TIMEOUT, 5);
    curl_setopt($adapt_handle, CURLOPT_HEADER, FALSE);
    curl_setopt($adapt_handle, CURLOPT_URL, $url);
    curl_setopt($adapt_handle, CURLOPT_HTTPHEADER, $header);
    curl_setopt($adapt_handle, CURLOPT_RETURNTRANSFER, TRUE);

    $ret = curl_exec($adapt_handle);
    if (!empty($ret)) {
        return json_decode($ret, TRUE);
    }
    else {
        return FALSE;
    }
}

class memOperate {

    private $fifo = NULL;
    private $redis = NULL;
	private $stampKey = NULL;
	private $limit = NULL;

	public function __construct($fifo_key, $host, $port = 6379, $limit) {
        $this->fifo = $fifo_key;
		$this->stampKey = $fifo_key . ":stamp";
        $this->redis = new Redis();
        $this->redis->pconnect($host, $port, 5); 
		$this->limit = $limit;
	}

	public function load() {
        $stamp = $this->get_stamp();
        $key = $this->fifo . ":hash:" . $stamp;
        $next_stamp = $stamp + 1;
        $next_key = $this->fifo . ":hash:" . $next_stamp;
        for ($i = 0; $i < $this->limit; $i++) {
            $content = $this->redis->rpop($this->fifo);
            if (empty($content)) {
                sleep(1);
                continue;
            }
            if (strlen($content) > 10240) {
                $this->fill($next_key, 0, $content);
                break;
            }
            else {
                $this->fill($key, $i, $content);
            }
        }

        return $key;
	}

    public function get_stamp() {
        return $this->redis->get($this->stampKey);
    } 

    public function get_hash($stamp) {
        $key = $this->fifo . ":hash:" . $stamp;
        return $this->redis->hgetall($key);
    }

    public function incr_stamp() {
        return $this->redis->incr($this->stampKey);
    }

    public function fill($key, $field, $value) {
        return $this->redis->hset($key, $field, $value);
    }

    public function passed($stamp) {
        $key = $this->fifo . ":hash:" . $stamp;
        $this->redis->del($key);
        $this->incr_stamp();
    }
}


