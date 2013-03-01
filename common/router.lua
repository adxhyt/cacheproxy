module("commom.router", package.seeall)

_VERSION = '0.02'

local mt = { __index = commom.router }
local config = ngx.shared.config;

local function _splitQuery()
    return ngx.req.get_post_args()
end

local function _fmtDex(s)
	local mix =
	{
		[48] = 0,
		[49] = 1,
		[50] = 2,
		[51] = 3,
		[52] = 4,
		[53] = 5,
		[54] = 6,
		[55] = 7,
		[56] = 8,
		[57] = 9,
		[97] = 10,
		[98] = 11,
		[99] = 12,
		[100] = 13,
		[101] = 14,
		[102] = 15
	}
    local result = 0;
    for i = 1, #s do
		result = result * 16 + mix[string.byte(s, i)]
	end
	return result
end

function split(self, s, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(s, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(s, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(s, delimiter, from)
    end
    table.insert(result, string.sub(s, from))
    return result
end

function router(self, s)
    local request_args = _splitQuery()
    local key_hash = _fmtDex(string.sub(ngx.md5(request_args.key), 1, 2))
    local target = key_hash % config:get("total") + 1
    request_args.target = target
    return request_args;
end

function router_mem(self, s)
    local request_args = _splitQuery()
    return request_args;
end

function parse_args(self, s)
    local request_args = _splitQuery()
    return request_args;
end

-- to prevent use of casual module global variables
getmetatable(commom.router).__newindex = function (table, key, val)
    error('attempt to write to undeclared variable "' .. key .. '": '
            .. debug.traceback())
end
