
local require, assert, tostring, type = require, assert, tostring, type;

local game = game;
local rep_storage, plrs = game:service('ReplicatedStorage'), game:service('Players');
local common = rep_storage:WaitForChild('common');
local rbx_auria = common:WaitForChild('auria');
local auria = require(rbx_auria);
local illya = auria.illya;

local class = require(illya.class);
local enums = require(illya.framework.api.enum);
local debug = require(illya.framework.api.debug);
local runtime = require(illya.framework.api.runtime);
local network = require(illya.framework.objects.network);
local timer = require(illya.framework.objects.timer);
local global = require(auria.framework.reference.global);

local blacksmith = class('blacksmith');

local sessions, rates = {}, {};

debug.addErrorCode('EBADPORT', 'bad port');
debug.addErrorCode('EBADPT', 'bad packet type');
debug.addErrorCode('ENHNDLR', 'handler not found');
debug.addErrorCode('ENFPORT', 'port not found');
debug.addErrorCode('ERL', 'attempted to exceed rate limit');
debug.addErrorCode('ENT', 'bad time');
debug.addErrorCode('ENRT', 'requested time not found');
debug.addErrorCode('EO', 'can only be accessed once');

blacksmith.init = runtime.async(function(self)
	self.__prototype = {
		requests = {};
		responses = {};
	};
	if (self.run ~= nil) then
		self:run();
	end;
end);

blacksmith.getPort = runtime.async(function(self)
	local port = self.port or nil;
	return port, debug.fail(port, 'ENFPORT');
end);

blacksmith.bind = runtime.async(function(self, port)
	if (type(port) == 'table' and port.instanceOf ~= nil and port:instanceOf(network) == true) then
		local read_connection = self.read_connection;
		if (read_connection ~= nil) then
			read_connection:disconnect();
		end;
		self.port, self.read_connection = port, port.on_accept.Event:connect(function(plr, data)
			assert(self:readPacket(plr, data));
		end);
		return enums.ErrorCode.OK;
	else return nil, debug.fail(nil, 'EBADPORT');
	end; return nil, debug.fail(nil, 'UNKNOWN');
end);

blacksmith.setRateLimit = runtime.async(function(self, request_id, limit)
	rates[request_id] = limit;
	return self;
end);

blacksmith.openRequest = function(self, request_id, handler)
	local __prototype = self.__prototype;
	local requests = __prototype.requests;
	requests[request_id] = handler;
	return self;
end;

blacksmith.rateCheck = runtime.async(function(self, plr, request_id)
	local user_session, rate_limit = assert(self:getSession(plr)), rates[request_id];
	local requests = user_session.requests;
	local request_rate = requests[request_id];
	local ideal_rate = (request_rate or 0) + 1;
	if (rate_limit == -1 and ideal_rate > 1) then
		return nil, debug.fail(nil, 'ERL');
	elseif (rate_limit == nil) then
		return enums.ErrorCode.OK;
	end;
	local res = rate_limit ~= -1 and ideal_rate <= rate_limit and enums.ErrorCode.OK or rate_limit == -1 and enums.ErrorCode.OK or nil;
	if (res == enums.ErrorCode.OK) then
		requests[request_id] = ideal_rate;
	end;
	return res, debug.fail(res, 'ERL');
end);

blacksmith.timeCheck = runtime.async(function(self, plr, requested)
	if (requested == nil) then
		return nil, debug.fail(nil, 'ENRT');
	end;
	local user_session = assert(self:getSession(plr));
	local last_requested = user_session.last_requested;
	local res = last_requested < requested;
	return res, debug.fail(res, 'ENT');
end);

blacksmith.getSession = runtime.async(function(self, plr)
	local user_session = sessions[plr];
	if (user_session == nil) then
		user_session = {
			requests = {};
			last_requested = 0;
		};
		sessions[plr] = user_session;
	end;
	return user_session;
end);

blacksmith.removeSession = runtime.async(function(self, plr)
	sessions[plr] = nil;
	local res = sessions[plr] == nil and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end);

blacksmith.resetRequestRates = runtime.async(function(self, plr)
	local user_session = assert(self:getSession(plr));
	local requests = user_session.requests;
	local n_requests = {};
	for request_id, rate in next, requests do
		if (rates[request_id] == -1) then
			n_requests[request_id] = rate;
		end;
	end;
	user_session.requests = n_requests;
	local res = user_session.requests == n_requests and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end);

blacksmith.sendRequestToSelf = runtime.async(function(self, plr, request_id, data)
	local __prototype = self.__prototype;
	local requests = __prototype.requests;
	local request_handler = requests[request_id];
	return runtime.execute(request_handler, self, plr, data);
end);

blacksmith.sendPacket = runtime.async(function(self, plr, request_id, body)
	local callback = callback;
	local port = assert(self:getPort());
	local address = tostring(callback):gsub('function: ', '');
	assert(port:write(plr, global.hash_string, {
		type = 0,
		address = callback ~= nil and address or nil,
		id = request_id,
		body = body
	}, function(err)
		assert(not err, err);
		if (callback ~= nil) then
			local __prototype = self.__prototype;
			local responses = __prototype.responses;
			responses[address] = callback;
		end;
	end));
end, enums.Async.Channel);

blacksmith.readPacket = runtime.async(function(self, plr, data)
	local __prototype = self.__prototype;
	local packet_type = data.type;
	if (packet_type == 0) then
		local requests, request_id = __prototype.requests, data.id;
		local request_handler = requests[request_id];
		local response_address = data.address;
		local port = assert(self:getPort());
		if (request_handler == nil and response_address ~= nil) then
			port:write(plr ~= plrs.LocalPlayer and plr or nil, global.hash_string, {
				type = 1,
				address = response_address,
				success = 1,
				result = debug.fail(nil, 'ENHNDLR')
			});
			return nil, debug.fail(nil, 'ENHNDLR');
		end;
		assert(self:timeCheck(plr, data.requested));
		assert(self:rateCheck(plr, request_id));
		local closures = {runtime.execute(request_handler, self, plr, data)};
		if (response_address ~= nil) then
			local success = closures[1] ~= nil and 1 or 0;
			port:write(plr ~= plrs.LocalPlayer and plr or nil, global.hash_string, {
				type = 1,
				address = response_address,
				success = success,
				result = success == 1 and debug.removeObjectLineFromError(closures[1]) or success == 0 and closures[2]; --the fact that this is an array is causing problems
			});
		end;
		return enums.ErrorCode.OK;
	elseif (packet_type == 1) then
		local responses = __prototype.responses;
		local response_address, success, result = data.address, data.success, data.result;
		local puller = runtime.getPuller(self.sendPacket);
		local callback = responses[response_address]; responses[response_address] = nil;
		assert(puller:push_callback(callback, success == 0 and result or nil, success == 1 and (type(result) == 'string' and result or type(result) == 'nil' and debug.fail(nil, 'UNKNOWN')) or data or nil));
		return enums.ErrorCode.OK;
	else return nil, debug.fail(nil, 'EBADPT');
	end; return nil, debug.fail(nil, 'UNKNOWN');
end);

do
	local rate_reset_timer, disconnect_timer = timer(), timer();
	disconnect_timer:start(20, 20, function(err, dt, elapsed)
		for rbx_player, _ in next, sessions do
			local rbx_player_name = rbx_player.Name;
			if (plrs:FindFirstChild(rbx_player_name) == nil) then
				blacksmith:removeSession(rbx_player);
			end;
		end;
	end);
	rate_reset_timer:start(60, 60, function(err, dt, elapsed)
		for rbx_player, _ in next, sessions do
			blacksmith:resetRequestRates(rbx_player);
		end;
	end);
	plrs.PlayerRemoving:connect(function(rbx_player)
		blacksmith:removeSession(rbx_player);
	end);
end;

return blacksmith;