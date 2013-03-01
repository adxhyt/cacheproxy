local router = require "common.router"
local memcached = require "resty.memcached"
local redis = require "resty.redis"
local config = ngx.shared.config
local insert = table.insert

--ngx.req.read_body()
local param = ngx.req.get_body_data()
local request_args = router:router_mem(param)

local method = "/" .. request_args.method
local threads = {}
local total = config:get("total");

local fifo = redis:new();

--调用resty.memcached 完成delete操作
local function query_memcache(no, key) 
    local cacheHandle = memcached:new();

    local host, port =  config:get("cache_" .. no .. "_host"), config:get("cache_" .. no .. "_port")
    local ok, err = cacheHandle:connect(host, port);
    if not ok then
        ngx.say("cache server " .. host .. ":" .. port .. " went away")
    end 

    local res, err = cacheHandle:delete(key)
    if res then
        ngx.say("found cache in server" .. host .. ":" .. port)
        response = 'OK'
    elseif err == 'NOT_FOUND' then
        ngx.say("cache not found in server " .. host .. ":" .. port)
        response = 'NOT_FOUND'
    elseif not res then
        response = 'ERROR'
        ngx.say("cache server" .. host .. ":" .. port .. "write error")
        ngx.exit(ngx.HTTP_OK)
    end

    cacheHandle:set_keepalive(200, 300 * config:get("total"));
    --ngx.say(response)
    return response
end

--本地操作delete cache成功后,执行插入队列
local function insert_redis(config, fifo, param) 
    local host, port = config:get("fifo_host"), config:get("fifo_port");
    local ok, err = fifo:connect(host, port);
    if not ok then
        ngx.log(ngx.ERR, "fifo server " .. host .. ":" .. port .. " went away")
    end 
    local fifokey = "FIFO:MEM"
    res = fifo:lpush(fifokey, param)

    --to the connection pool
    fifo:set_keepalive(200, 200 * config:get("total"));
end

--delete 利用http-nginx-lua-module处理, set在php端处理,这里直接压入redis
if (request_args.method == 'delete') then
    for no = 1, total, 1 do
		--ngx.thread.spawn线程并发
        local co = ngx.thread.spawn(query_memcache, no, request_args.key)
        insert(threads, co)
    end
    
    for i = 1, #threads do
        local ok, res = ngx.thread.wait(threads[i])
        if not ok then
            ngx.say(i, ": failed to run: ", res)
        else
            ngx.say(i, ": status: ", res)
            if (res == 'OK') then 
                insert_redis(config, fifo, param)
            end
        end
    end 
elseif (request_args.method == 'set') then
    local host, port = config:get("fifo_host"), config:get("fifo_port");
    local ok, err = fifo:connect(host, port);
    if not ok then
        ngx.log(ngx.ERR, "fifo server " .. host .. ":" .. port .. " went away")
    end
    local fifokey = "FIFO:MEM:SET"
    res = fifo:lpush(fifokey, param)

    --to the connection pool
    fifo:set_keepalive(200, 200 * config:get("total"));
end
