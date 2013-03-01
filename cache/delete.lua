local cache = require "resty.memcached"
local cjson = require "cjson"
local config = ngx.shared.config;

local m = cache:new();
local key = ngx.ctx.key
local args = ngx.ctx.args
local no = ngx.ctx.no

local host, port =  config:get("cache_" .. no .. "_host"), config:get("cache_" .. no .. "_port")
local ok, err = m:connect(host, port);
if not ok then
	ngx.say("cache server " .. host .. ":" .. port .. " went away")
end 

local res, err = m:delete(key)
if res then
	ngx.say("found cache in server" .. host .. ":" .. port)
elseif err == 'NOT_FOUND' then
	ngx.status = 404;
	ngx.say("cache not found in server " .. host .. ":" .. port)
elseif not res then
	ngx.status = 404;
	ngx.say("cache server" .. host .. ":" .. port .. "write error")
	ngx.exit(ngx.HTTP_OK)
end

m:set_keepalive(200, 300 * config:get("total"));

