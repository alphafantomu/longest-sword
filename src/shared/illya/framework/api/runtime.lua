

local require, xpcall, unpack, select, type, assert, tick, next, tostring = require, xpcall, unpack, select, type, assert, tick, next, tostring;
local table, debug_lib = table, debug;
local table_remove, table_insert, table_concat = table.remove, table.insert, table.concat;
local debug_traceback = debug_lib.traceback;

local script, game = script, game;

local run = game:service('RunService');
local stepped = run.Stepped;

local core = script:FindFirstAncestor('illya');
local illya = require(core);
local class = require(illya.class);
local enums = require(illya.framework.api.enum);
local debug = require(illya.framework.api.debug);
local pool = require(illya.framework.objects.pool);
local puller = require(illya.framework.objects.pool.puller);

local enum = enums.enum;

local queue = illya.require{
	timer 		= illya.framework.objects.timer;
};

local trace, event_pool, timer_pool, puller_pool = pool(), pool(), pool(), pool();
local loop_push, execute_error = illya.event('loop_push'), illya.event('execute_error');
local loop_push_event = loop_push.Event;

local trace_queue = trace:getQueue();
local timer_queue, timer_indexes = timer_pool:getQueue(), timer_pool:getIndexList();
local event_queue, event_indexes = event_pool:getQueue(), event_pool:getIndexList();
local puller_queue, puller_indexes = puller_pool:getQueue(), puller_pool:getIndexList();

local puller_list, wrapper_inverse, links, trace_data = {}, {}, {}, {};

enums.Async = enum{
	Yield 	= 0;
	Channel = 1;
};

local runtime = class('runtime',
	{
		mode = 'hybrid';
		dt = 0;
		event_pool = event_pool;
		timer_pool = timer_pool;
		puller_pool = puller_pool;
		loop_push  = loop_push_event;
		execute_error = execute_error.Event;
		scan_list = {
			{'debug', illya.framework.api.debug};
			{'enum', illya.framework.api.enum};
			{'extension', illya.framework.api.extension};
			{'json', illya.framework.api.json};
			{'runtime', illya.framework.api.runtime};
			{'sha2', illya.framework.api.sha2};
			{'struct', illya.framework.api.struct};
			{'util', illya.framework.api.util};
			{'pool', illya.framework.objects.pool};
			{'puller', illya.framework.objects.pool.puller};
			{'linker', illya.framework.objects.linker};
			{'network', illya.framework.objects.network};
			{'timer', illya.framework.objects.timer};
		};
	});

debug.addErrorCode('EIC', 'chunk error');

loop_push_event:connect(function(id, async_type, callback, fx, ...)
	local closures = {runtime.execute(id, fx, ...)};
	if (callback ~= nil and async_type ~= enums.Async.Channel) then
		runtime.execute(id, callback, unpack(closures));
	end;
end);

--implement call traceback instead of line traceback for Lua?, method might not work, fx and callback have to be connected somehow or wrapper?
--[[
	fx runs -> runs callback
	In order for proper traceback to work, we have to link fx to run callback somehow?
	Inject fx's environment with the callback, then use fx.loadstring to run code directly inside the environment to run the callback to get traceback
	^ Don't have to inject with the callback, it should already exist

	Calling order goes:
	fx()
	chunk = fx.loadstring()
	    callback()
	setfenv(chunk, fx);
	chunk();
	should be noted that fx should always have a "callback" variable in it's environment, use this reference to link
	also call tracing has its limits

	Some wrappers that appear: xpcall, runtime.execute, runtime.eventUpdate

	Calling order with wrappers goes:
	1 fx()
	global xpcall()
	global runtime.execute()
	
	global chunk = fx.loadstring()
	  1 callback()
	  global xpcall()
	  global runtime.execute()
	
	global -> chunk()

	Just realized the tracing might not work?
	Since we are calling the chunk, in the global environment, the chunk using getfenv(...) will not get fx environment, instead they will get the global environment

	local chunk = loadstring('return tostring(getfenv(1)), tostring(getfenv(2));')
	setfenv(chunk, {tostring = tostring, getfenv = getfenv});
	print(tostring(getfenv(1)), tostring(getfenv(chunk)), chunk())

	The above returns as expected: table: 0x137b61407e2a3486 table: 0xcaba1384682373c6 table: 0xcaba1384682373c6 table: 0x137b61407e2a3486
	
	Is there a way we can use a less harmful method than forcefully injecting a call into the environment?

	- We can easily link fx to callbacks, as when fx runs, the callback runs but that's not enough
	  - We need callbacks to link to other fx, in a completely different function

	Note that fx() can be both async or sync
	Callbacks can run like this:

	fx() -> callback
		fx() -> callback
			fx() -> callback

	fx() -> callback
		fx() -> callback
		fx() -> callback

	fx()
		fx() -> callback
		fx() -> callback

	fx()
		fx() -> callback
			fx() -> callback

	fx()
		fx()
		fx()

	fx()
		fx()
			fx()
]]

runtime.handleError = function(err)
	return err;
end;

runtime.scanForMethod = function(fx_address)
	local scan_list = runtime.scan_list;
	for i = 1, #scan_list do
		local module_data = scan_list[i];
		local module_name, data = module_data[1], require(module_data[2]);
		for index, value in next, data do
			if (type(value) == 'function') then
				local address = tostring(value);
				if (address == fx_address) then
					return module_name..':'..index..'()';
				end;
			end;
		end;
	end;
end;

runtime.linkFx = function(address, display)
	links[address] = display;
	local res = links[address] == display and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end;

runtime.getLinkFx = function(address)
	return links[address];
end;

runtime.callTraceback = function(a, b)
	local parsed_traceback, raw_traceback = {}, {};
	for i = a, b do
		table_insert(raw_traceback, trace_queue[i]);
	end;
	local n_raw = #raw_traceback;
	local scan_list = runtime.scan_list;
	for i = 1, n_raw do
		local fx_address = raw_traceback[i];
		local possible_link = links[fx_address];
		if (possible_link == nil) then
			for oi = 1, #scan_list do
				local module_data = scan_list[oi];
				local module_name, data = module_data[1], require(module_data[2]);
				for index, value in next, data do
					if (type(value) == 'function') then
						local address = tostring(value);
						if (address == fx_address) then
							parsed_traceback[i] = module_name..':'..index..'()';
							break;
						end;
					end;
				end;
				if (parsed_traceback[i] ~= nil) then break; end;
			end;
		else
			parsed_traceback[i] = possible_link;
		end;
		if (parsed_traceback[i] == nil) then
			parsed_traceback[i] = fx_address;
		end;
	end;
	return table_concat(parsed_traceback, '\n');
end;

runtime.toString = function(var, ...)
	local display = '';
	local type_var = type(var);
	if (type_var == 'number') then
		display = display..', n'..var;
	elseif (type_var == 'string') then
		display = display..', "'..var..'"';
	elseif (type_var == 'boolean') then
		display = display..', '..(var == true and 'true' or var == false and 'false');
	elseif (type_var == 'function' or type_var == 'userdata' or type_var == 'thread') then
		display = display..', '..tostring(var);
	elseif (type_var == 'table') then
		local table_display = '';
		for index, value in next, var do
			table_display = table_display..', '..tostring(index)..' = '..tostring(value);
		end;
		display = display..', '..(table_display == '' and '<table read failed>' or '{'..table_display..'}');
	elseif (type_var == 'nil') then
		display = display..', nil';
	else
		display = display..', <unsupported type>';
	end;
	if (select('#', ...) > 0) then
		display = display..', '..runtime.toString(...);
	end;
	if (display:sub(1, 2) == ', ') then
		display = display:sub(3);
	end;
	return display;
end;

runtime.execute = function(fx, ...)
	local wrapper = wrapper_inverse[fx] or fx;
	local address = tostring(wrapper);
	local a = assert(trace:accept(address));
	--trace_data[address] = runtime.toString(...);
	local process_data = {xpcall(fx, runtime.handleError, ...)};
	local b = trace.total;
	local result = process_data[1] or nil;
	table_remove(process_data, 1);
	if (result == nil) then
		local err_msg = process_data[1] or debug.fail(nil, 'EIC');
		local caller_traceback = runtime.callTraceback(a, b);
		execute_error:Fire(err_msg, caller_traceback, debug_traceback());
		return err_msg;
	end;
	return debug.autoshift(process_data);
end;

runtime.executeSync = function(fx, ...)
	local wrapper = wrapper_inverse[fx] or fx;
	local address = tostring(wrapper);
	local a = assert(trace:accept(address));
	--trace_data[address] = runtime.toString(...);
	local process_data = {xpcall(fx, runtime.handleError, ...)};
	local b = trace.total;
	local result = process_data[1] or nil;
	table_remove(process_data, 1);
	local err_msg = process_data[1];
	if (result == nil and err_msg ~= nil) then
		local caller_traceback = runtime.callTraceback(a, b);
		execute_error:Fire(err_msg, caller_traceback, debug_traceback());
		if (err_msg == nil) then
			return nil, debug.fail(nil, 'EIC');
		end;
		return nil, err_msg;
	elseif (result == nil and err_msg == nil) then
		process_data[1] = enums.ErrorCode.OK;
	end;
	return unpack(process_data);
end;

runtime.illya_queue = function(async_type, callback, fx, ...)
	return event_pool:accept{async_type, callback, fx, {...}};
end;

runtime.rbx_queue = function(async_type, callback, fx, ...)
	return loop_push:Fire(async_type, callback, fx, ...);
end;

runtime.getPuller = function(fx)
	return puller_list[fx];
end;

runtime.getWrapper = function(puller_obj)
	for i, v in next, puller_list do
		if (v == puller_obj) then
			return i;
		end;
	end;
end;

--need to reform architecture

runtime.async = function(fx, async_type)
	async_type = async_type or enums.Async.Yield;
	local wrapper; wrapper = function(...)
		local n_args = select('#', ...);
		local callback = select(n_args, ...);
		local is_callback = type(callback) == 'function';
		--implement call traceback here
		--getfenv(0-1,2,3,...) goes to current environment, caller environment, further caller environments infinitely
		--local a = function(b) return b() end; setfenv(a, {tostring = tostring, getfenv = getfenv}) local b = function() return tostring(getfenv(1)), tostring(getfenv(2)), tostring(getfenv(3)), getfenv(4) end setfenv(b, {tostring = tostring, getfenv = getfenv}) print(tostring(getfenv(a)), tostring(getfenv(b)), tostring(getfenv()), a(b))
		--call traceback will be implemented using getfenv() and environment differences
		if (is_callback == true) then
			local args = {...};
			table_remove(args, n_args);
			return runtime.illya_queue(async_type, callback, fx, unpack(args));
		else
			if (async_type == enums.Async.Channel) then --if it's a channel async function, we'll force thread to yield for the callback to come back
				local args;
				local adapt_callback = function(err, ...) --reverse autoshift, args should be assertable
					if (err ~= nil) then
						args = {nil, err, ...};
					elseif (err == nil) then
						args = {...};
					end;
				end;
				local wenv = debug.getwenv(fx);
				wenv.callback = adapt_callback;
				local wrapper_puller = runtime.getPuller(wrapper);
				assert(wrapper_puller:pull(adapt_callback));
				runtime.linkFx(tostring(adapt_callback), 'sync -> adapt_callback()');
				runtime.executeSync(fx, ...);
				repeat stepped:wait(); until args ~= nil;
				return unpack(args);
			else
				local wenv = debug.getwenv(fx);
				wenv.callback = nil;
				return runtime.executeSync(fx, ...);
			end;
		end;
	end;
	wrapper_inverse[fx] = wrapper;
	if (async_type == enums.Async.Channel) then
		assert(puller_pool:accept(wrapper));
		puller_list[wrapper] = puller();
	end;
	return wrapper;
end;

runtime.timerUpdate = function(elapsed, dt)
	local start_time = tick();
	for i = 1, timer_pool.total do
		if ((tick() - start_time) <= 8) then
			local var = timer_queue[i];
			if (var ~= nil and var:instanceOf(queue.timer) == true) then
				var:update(dt);
			end;
		else break;
		end;
	end;
end;

local list = {};

--event_pool.debug = true;

runtime.eventUpdate = function(elapsed, dt)
	local start_time = tick();
	runtime.dt = dt;
	--print(event_pool.total, event_pool, event_pool[1], event_pool[2], event_pool[3], event_pool[4]);
	for i = 1, event_pool.total do
		if ((tick() - start_time) <= 8) then
			local data = event_queue[i];
			if (data ~= nil) then
				local async_type, callback, fx, args = data[1], data[2], data[3], data[4];
				assert(event_pool:reject(data));
				--------------------------------------
				if (callback ~= nil) then
					local wenv = debug.getwenv(fx);
					wenv.callback = callback;
					if (async_type == enums.Async.Channel) then
						local wrapper = wrapper_inverse[fx];
						if (wrapper ~= nil) then
							--print('!!! Set Callback', callback, runtime.scanForMethod(tostring(wrapper)));
							local wrapper_puller = runtime.getPuller(wrapper);
							assert(wrapper_puller:pull(callback));
						end;
					end;
					local addr = tostring(callback);
					if (runtime.getLinkFx(addr) == nil) then
						runtime.linkFx(addr, 'async -> callback()');
					end;
				end;
				--------------------------------------
				local closures = {runtime.execute(fx, unpack(args))};
				if (callback ~= nil and async_type ~= enums.Async.Channel) then
					runtime.execute(callback, unpack(closures));
				end;
			end;
		else break;
		end;
	end;
end;

runtime.pullerUpdate = function(elapsed, dt)
	local start_time = tick();
	for i = 1, puller_pool.total do
		if ((tick() - start_time) <= 8) then
			local data = runtime.getPuller(puller_queue[i]);
			if (data ~= nil and data.args ~= nil) then
				data:update();
			end;
		else break;
		end;
	end;
end;

runtime.run = function(mode)
	runtime.mode = mode;
	local el, tl, pl = runtime.event_loop, runtime.timer_loop, runtime.puller_loop;
	if (el ~= nil) then
		el:disconnect();
	end; if (mode == 'hybrid') then
		runtime.event_loop = stepped:connect(runtime.eventUpdate);
	end;
	if (tl ~= nil) then
		tl:disconnect();
	end; runtime.timer_loop = stepped:connect(runtime.timerUpdate);
	if (pl ~= nil) then
		tl:disconnect();
	end; runtime.puller_loop = stepped:connect(runtime.pullerUpdate);
end;

return runtime;
