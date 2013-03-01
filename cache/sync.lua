local router = require "common.router"
local memcached = require "resty.memcached"
local redis = require "resty.redis"
local config = ngx.shared.config;

local post_data = ngx.req.get_body_data()
local uri_args = ngx.req.get_uri_args()

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
    return response
end

local stamp = tonumber(uri_args['stamp'])

if nil == post_data then
    ngx.log(ngx.ERR, "post nil with stamp: " .. stamp)
    ngx.status = 500;
    ngx.say(stamp ..  " post nil!");
    ngx.exit(500)
end


--status key
local process_key = "FIFO:MEM:status"

local fifo = redis:new();
local host, port = config:get("fifo_host"), config:get("fifo_port");
local ok, err = fifo:connect(host, port);
if not ok then
    ngx.log(ngx.ERR, "fifo server " .. host .. ":" .. port .. " went away")
end

local res, err = fifo:hgetall(process_key)
if not res then
    ngx.log(ngx.ERR, "hgetall " .. process_key .. " with err " .. err)
    ngx.status = 502;
    ngx.exit(502)
end

res = redis:array_to_hash(res)

local processing_key = tonumber(res['processing'])
local processed_key = tonumber(res['processed'])

if stamp <= processed_key then
    ngx.log(ngx.ERR, stamp .. " has been processed!");
    fifo:set_keepalive(200, 200 * config:get("total"));
    if not res then
        ngx.log(ngx.ERR, "set fifo pool err with " .. err)
    end
    ngx.status = 200;
    ngx.say(stamp ..  " has been processed!");
    ngx.exit(ngx.HTTP_OK)
end

if stamp <= processing_key then
    ngx.log(ngx.ERR, stamp .. " is processing!");
    local res, err = fifo:set_keepalive(200, 200 * config:get("total"));
    if not res then
        ngx.log(ngx.ERR, "set fifo pool err with " .. err)
    end
    ngx.status = 200;
    ngx.say(stamp .. " is processing!");
    ngx.exit(ngx.HTTP_OK)
end

local res, err = fifo:hset(process_key, 'processing', stamp)
if not res then
    ngx.log(ngx.ERR, "set :" .. stamp .. " processing error with " .. err)
end


local reqs = {}
local threads = {}
local total = config:get("total");

local commands = router:split(post_data, "||")
for _, command in pairs(commands) do
    local request_args = router:parse_args(command)
    if not request_args.method then
        ngx.log(ngx.ERR, "wrong method with command" .. command)
	elseif (request_args.method == 'delete') then
		for no = 1, total, 1 do
			--ngx.thread.spawn线程并发
			local co = ngx.thread.spawn(query_memcache, no, request_args.key)
			insert(threads, co) 
		end 
		
		for i = 1, #threads do
			local ok, res = ngx.thread.wait(threads[i])
			if not ok then
				ngx.log(ngx.ERR, "thread " .. i .. "failed to run: ", res)
			end 
		end 
    else
        local method = "/" .. request_args.method
        local res = ngx.location.capture(method, {ctx = request_args})
        if res.status ~= 200 then
            ngx.log(ngx.ERR, "sync " .. command .. " error!")
        end 
    end 
end

local res, err = fifo:hset(process_key, 'processed', stamp)
if not res then
    ngx.log(ngx.ERR, "set:" .. stamp .. " processed error with " .. err)
end

local res, err = fifo:set_keepalive(200, 200 * config:get("total"));
if not res then
	ngx.log(ngx.ERR, "set fifo pool err with " .. err)
end

ngx.exit(ngx.HTTP_OK)

