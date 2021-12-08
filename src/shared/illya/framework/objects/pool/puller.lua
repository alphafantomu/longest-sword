
local require, assert = require, assert;
local debug_lib = debug;

local script = script;
local core = script:FindFirstAncestor('illya');
local illya = require(core);
local debug = require(core.framework.api.debug);
local enums = require(core.framework.api.enum);
local pool = require(core.framework.objects.pool);

local puller = pool:extend('puller');

local queue = illya.require{
	runtime = illya.framework.api.runtime;
};

debug.addErrorCode('ENRCB', 'callback is not registered');

puller.init = function(self)
	self.links = {};
	pool.init(self);
end;

puller.push = function(self, ...)
	self.args = {...};
	local res = self.args ~= nil and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end;

puller.push_callback = function(self, callback, ...)
	local runtime = queue.runtime;
	--local wrapper = runtime.getWrapper(self);
	--warn('PULLER DETECTED PUSHING CALLBACK', callback, wrapper, runtime.scanForMethod(tostring(wrapper)), 'END');
	if (self:getIndex(callback) ~= nil) then
		--print('Rejected callback', callback);
		assert(self:reject(callback));
		return queue.runtime.illya_queue(enums.Async.Yield, nil, callback, debug.autoshift{...});
	else
		--print('Puller', self[1], self[2], self[3], self[4]);
		--print('Callback', callback, debug_lib.traceback(), runtime.getLinkFx(tostring(callback)));
		return nil, debug.fail(nil, 'ENRCB');
	end; return nil, debug.fail(nil, 'UNKNOWN');
end;

puller.pull = function(self, callback)
	--local res, em, en = self:accept(callback);
	--print('Accepted callback', callback, self:getIndex(callback));
	return self:accept(callback);
end;

puller.undoPull = function(self, callback)
	return self:reject(callback);
end;

puller.update = function(self)
	local args = self.args;
	if (args ~= nil) then
		local pool_coll, total_coll = self:getQueue(), self:getIndexList();
		for i = 1, #total_coll do
			local cb_fx = pool_coll[total_coll[i]];
			assert(self:reject(cb_fx));
			queue.runtime.illya_queue(enums.Async.Yield, nil, cb_fx, debug.autoshift(args));
		end;
		self.args = nil;
	end;
end;

return puller;