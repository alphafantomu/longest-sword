
local require, pcall, unpack, assert = require, pcall, unpack, assert;
local table = table;
local table_insert = table.insert;

local script = script;
local core = script:FindFirstAncestor('illya');
local illya = require(core);
local class = require(illya.class);
local debug = require(illya.framework.api.debug);
local runtime = require(illya.framework.api.runtime);

local linker = class('linker');

debug.addErrorCode('ECBMISS', 'callback function is missing');
debug.addErrorCode('EAFXMISS', 'async function is missing');

linker.init = function(self, ...)
	self[1], self[2] = {...}, {};
	self.catch = illya.event('catch');
end;

linker.pull = function(self, fx)
	local ran = pcall(table_insert, self[2], fx or 0);
	local process_code = ran and self or nil;
	return process_code, debug.fail(process_code, 'EIOP');
end;

linker.push = function(self, ...)
	local a_fx, c_fx = self[1], self[2];
	local l_args = {...};
	local na, i, stop_chain = #a_fx, 1, 1;
	local stop = function(err)
		stop_chain = 0;
		self.catch:Fire(err);
	end;
	local wrapper; wrapper = function(...)
		local cb_fx = assert(c_fx[i], debug.fail(nil, 'ECBMISS'));
		local ni = i + 1;
		if (cb_fx ~= 0 and stop_chain == 1) then
			local wenv = debug.getwenv(cb_fx);
			wenv.stop = stop;
			l_args = {cb_fx(...)};
			if (ni <= na) then
				i = ni;
				local async_fx = assert(a_fx[i], debug.fail(nil, 'EAFXMISS'));
				table_insert(l_args, wrapper);
				async_fx(unpack(l_args));
			end;
		end;
	end;
	runtime.linkFx(tostring(wrapper), 'linker wrapper -> callback()');
	local async_fx = assert(a_fx[i], debug.fail(nil, 'EAFXMISS'));
	table_insert(l_args, wrapper);
	return async_fx(unpack(l_args));
end;

return linker;