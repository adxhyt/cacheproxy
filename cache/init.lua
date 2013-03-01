local cjson = require "cjson";

local config = ngx.shared.config;

local file = io.open("/home/service/openresty/nginx/cache/config/testing/memcache.json", "r");
local content = cjson.decode(file:read("*all"));
file.close(file);

for no, sub_conf in pairs(content) do
    for name, value in pairs(sub_conf) do
        config:set("cache_" .. no .. "_" .. name, value);
    end
    config:set("total", no);
end

local file = io.open("/home/service/openresty/nginx/cache/config/testing/fifo.json", "r");
local content = cjson.decode(file:read("*all"));
file.close(file);

for no, sub_conf in pairs(content) do
    for name, value in pairs(sub_conf) do
        config:set("fifo_" .. name, value);
    end
end

