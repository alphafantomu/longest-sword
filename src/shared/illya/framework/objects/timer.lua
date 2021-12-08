
--mirrored off of luvit's luv
--https://github.com/luvit/luv/blob/master/docs.md#uv_timer_t--timer-handle

local require = require;
local math = math;
local math_abs = math.abs;

local script = script;
local core = script:FindFirstAncestor('illya');
local illya = require(core);
local class = require(illya.class);
local runtime = require(illya.framework.api.runtime);
local debug = require(illya.framework.api.debug);
local enums = require(illya.framework.api.enum);

local timer_pool = runtime.timer_pool;

local timer = class('timer',
	{
		elapsed = 0;
		timeout = 0;
		loop_ms = 0;
		mode = 0;
		kill = 0;
	});

debug.addErrorCode('ETMRMDE', 'unhandled timer mode');

timer.start = runtime.async(function(self, timeout, loop_ms)
	local callback = callback;
	self.timeout, self.loop_ms, self.cb = timeout or self.timeout, loop_ms or self.loop_ms, callback or self.cb;
	self.mode, self.kill = 0, 0;
	return timer_pool:accept(self);
end, enums.Async.Channel);

timer.stop = function(self)
	self.mode, self.kill = 0, 0;
	return timer_pool:reject(self);
end;

timer.again = function(self) --delayed stop depending on repeat
	if (self.mode == 0) then
		self.kill = 0;
		return timer_pool:reject(self);
	elseif (self.mode == 1) then
		self.kill = 1;
		return enums.ErrorCode.OK;
	end;
	return nil, debug.fail(nil, 'ETMRMDE');
end;

timer.set_repeat = function(self, loop_ms)
	self.loop_ms = loop_ms;
	local process_code = self.loop_ms == loop_ms and enums.ErrorCode.OK or nil;
	return process_code, debug.fail(process_code, 'EIOP');
end;

timer.get_repeat = function(self)
	return self.loop_ms;
end;

timer.get_due_in = function(self) --libuv 1.40.0
	local total_elapsed, timeout, loop_ms = self.elapsed, self.timeout, self.loop_ms;
	local mode = self.mode;
	local left = total_elapsed - (mode == 0 and timeout or mode == 1 and loop_ms);
	return left < 0 and math_abs(left) or 0;
end;

timer.update = function(self, dt)
	local timeout, loop_ms, kill, cb = self.timeout, self.loop_ms, self.kill, self.cb;
	local total_elapsed = self.elapsed + dt;
	if (self.mode == 0) then
		if (total_elapsed >= timeout) then
			if (cb ~= nil) then
				local puller = runtime.getPuller(self.start);
				assert(puller:push_callback(cb, nil, dt, total_elapsed));
				assert(puller:pull(cb));
			end;
			if (loop_ms ~= 0) then
				self.mode = 1;
			else self:stop();
			end;
			total_elapsed = 0;
		end;
	elseif (self.mode == 1) then --repeating
		if (loop_ms ~= 0) then
			if (total_elapsed >= loop_ms) then
				if (cb ~= nil) then
					local puller = runtime.getPuller(self.start);
					assert(puller:push_callback(cb, nil, dt, total_elapsed));
					assert(puller:pull(cb));
				end;
				total_elapsed = 0;
				if (kill == 1) then
					self:stop();
				end;
			end;
		else self:stop();
		end;
	end;
	self.elapsed = total_elapsed;
end;

return timer;