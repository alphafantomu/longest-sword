
local string = string;
local string_format = string.format;
local tostring, next, pairs, setmetatable, error = tostring, next, pairs, setmetatable, error;

local function enum(tbl)
	local call = {};
	for k, v in pairs(tbl) do
		if (call[v]) then
			return error(string_format('enum clash for %q and %q', k, call[v]));
		end;
		call[v] = k;
	end;
	return setmetatable({}, {
		__call = function(_, k)
			if (call[k] ~= nil) then
				return call[k];
			else
				return error('invalid enumeration: ' .. tostring(k));
			end;
		end,
		__index = function(_, k)
			if (tbl[k] ~= nil) then
				return tbl[k];
			else
				return error('invalid enumeration: ' .. tostring(k));
			end;
		end,
		__pairs = function()
			return next, tbl;
		end,
		__newindex = function()
			return error('cannot overwrite enumeration');
		end,
	});
end;

return {enum = enum};