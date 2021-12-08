
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
local global = require(auria.framework.reference.global);

local blacksmith = class('blacksmith');

debug.addErrorCode('EBADPORT', 'bad port');
debug.addErrorCode('EBADPT', 'bad packet type');
debug.addErrorCode('ENHNDLR', 'handler not found');
debug.addErrorCode('ENFPORT', 'port not found');
debug.addErrorCode('ERL', 'attempted to exceed rate limit');
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

blacksmith.openRequest = function(self, request_id, handler)
	local __prototype = self.__prototype;
	local requests = __prototype.requests;
	requests[request_id] = handler;
	return self;
end;

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
	return enums.ErrorCode.OK;
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

return blacksmith;