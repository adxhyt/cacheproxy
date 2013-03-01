local redis = require "resty.redis"
local config = ngx.shared.config;

local uri_args = ngx.req.get_uri_args()

local fifo = redis:new();
local host, port = config:get("fifo_host"), config:get("fifo_port");
local ok, err = fifo:connect(host, port);
if not ok then
    ngx.log(ngx.ERR, "fifo server " .. host .. ":" .. port .. " went away")
end

local stamp_key
for key, val in pairs(uri_args) do
	if type(val) == "table" then
		ngx.log(ngx.ERR, "error status paramter")
	elseif val == 'set' then
		stamp_key = 'FIFO:MEM:SET:status'
	elseif val == 'delete' then
		stamp_key = 'FIFO:MEM:status'
	else 
		ngx.log(ngx.ERR, "stamp_key " .. stamp_key .. " error")
    	ngx.status = 502;
    	ngx.exit(ngx.HTTP_OK)
	end
end


local res, err = fifo:hgetall(stamp_key)
if not res then
    ngx.log(ngx.ERR, "hgetall " .. stamp_key .. " error")
    ngx.status = 502;
    ngx.exit(ngx.HTTP_OK)
end
res = redis:array_to_hash(res)
ngx.say(cjson.encode(res))

