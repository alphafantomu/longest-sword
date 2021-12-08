
local require, assert, select, type, next, tostring, tonumber, tick, pcall = require, assert, select, type, next, tostring, tonumber, tick, pcall;
local string, math, table = string, math, table;
local string_gmatch, string_char, string_byte, string_format = string.gmatch, string.char, string.byte, string.format;
local math_random = math.random;
local table_concat, table_remove = table.concat, table.remove;
local script, game = script, game;

local core = script:FindFirstAncestor('illya');
local illya = require(core);
local class = require(illya.class);
local sha2 = require(illya.framework.api.sha2);
local debug = require(illya.framework.api.debug);
local runtime = require(illya.framework.api.runtime);
local enums = require(illya.framework.api.enum);
local json = require(illya.framework.api.json);
local linker = require(illya.framework.objects.linker);

local run, plrs = game:service('RunService'), game:service('Players');
local is_server, is_client = run:IsServer(), run:IsClient();

local network = class('network',
	{
		identifier = run:IsServer() and enums.IdentifierType.Server or run:IsClient() and enums.IdentifierType.Client or enums.IdentifierType.Unknown;
	});

debug.addErrorCode('ENETIVAL', 'identification failed');
debug.addErrorCode('EBADSOC', 'rbx object is not a "RemoteEvent"');
debug.addErrorCode('ERDIVAL', 'raw data mishandled by sender');
debug.addErrorCode('EDECRYPT', 'failed to decrypt string');
debug.addErrorCode('EJSDECODE', 'failed to decode json string');
debug.addErrorCode('EJSENCODE', 'failed to encode json object');
debug.addErrorCode('EENCRYPT', 'failed to encrypt string');
debug.addErrorCode('EHASH', 'failed to generate hash');
debug.addErrorCode('EBADHASH', 'bad hash');
debug.addErrorCode('ELOCKED', 'locked function');

local only_hash = '8f079e767fef1e08373d2c50e16757668fa11f89605bdb29120f08381a75ea0b6da7a62ca18bdd1888e92ecce5882922f21fb23fa1554f6f04b96f05e42efb93';
local key_cache = {};
local __prototype = {};

network.valid = function(self)
	local process_code = self.identifier ~= enums.IdentifierType.Unknown and enums.ErrorCode.OK or nil;
	return process_code, debug.fail(process_code, 'ENETIVAL');
end;

network.init = runtime.async(function(self, socket)
	assert(self:valid());
	self.on_accept, self.on_reject = illya.event('on_accept'), illya.event('on_reject');
	if (socket ~= nil) then
		self:bind(socket);
	end;
end);

--local n = 0;
network.bind = runtime.async(function(self, socket)
	local callback = callback;
	assert(self:valid());
	--n = n + 1;
	--warn('NETWORK BIND RUNNING', n);
	local puller = runtime.getPuller(self.bind);
	local valid_socket = socket.ClassName == 'RemoteEvent' or nil;
	if (valid_socket == nil) then
		return assert(puller:push_callback(callback, nil, debug.fail(valid_socket, 'EBADSOC')));
	end;
	local identifier = self.identifier;
	(identifier == enums.IdentifierType.Server and self.setSocketArt or identifier == enums.IdentifierType.Client and self.getSocketArt)(self, socket, function(err)
		assert(not err, err);
		local listen_event = self.listen_event;
		if (listen_event ~= nil) then
			listen_event:disconnect();
		end;
		self.listen_event = (identifier == enums.IdentifierType.Server and socket.OnServerEvent or identifier == enums.IdentifierType.Client and socket.OnClientEvent):connect(function(...)
			self:read(...);
		end);
		self.socket = socket;
		assert(puller:push_callback(callback, enums.ErrorCode.OK));
	end);
end, enums.Async.Channel);

network.readable = runtime.async(function(self, ...)
	local process_code = select('#', ...) == 1 and type(...) == 'string' and enums.ErrorCode.OK or nil;
	return process_code, debug.fail(process_code, 'ERDIVAL');
end);

network.decompressPacket = runtime.async(function(self, data, key)
	local res, cipher = pcall(__prototype.decrypt, data, key);
	if (res == false) then return nil, debug.fail(nil, 'EDECRYPT'); end;
	local compiled_data, art_pointers = '', self.art_pointers;
	for n in string_gmatch(cipher, '[%d][%d][%d]') do
		compiled_data = compiled_data..string_char(art_pointers[n]);
	end;
	local res, json_data = pcall(json.decode, compiled_data);
	if (res == false) then return nil, debug.fail(nil, 'EJSDECODE'); end;
	return json_data;
end);

network.compressPacket = runtime.async(function(self, data, key)
	local res, json_data = pcall(json.encode, data);
	if (res == false) then return nil, debug.fail(nil, 'EJSENCODE'); end;
	local compiled_data, art = '', self.art;
	for i = 1, json_data:len() do
		compiled_data = compiled_data..art[__prototype.extendDigits(string_byte(json_data:sub(i, i)), 3)];
	end;
	local res, cipher = pcall(__prototype.encrypt, compiled_data, key);
	if (res == false) then return nil, debug.fail(nil, 'EENCRYPT'); end;
	return cipher;
end);

network.key = runtime.async(function(self, plr)
	local key_string_cache = key_cache[plr];
	if (key_string_cache == nil) then
		key_string_cache = plr.Name..only_hash..plr.UserId;
		key_cache[plr] = key_string_cache;
	end;
	return key_string_cache;
end);

network.write = runtime.async(function(self, plr, str, data)
	assert(self:valid());
	local res, hash = pcall(sha2.sha512, str);
	if (res == false) then return nil, debug.fail(nil, 'EHASH'); end;
	if (hash ~= only_hash) then return nil, debug.fail(nil, 'EBADHASH'); end;
	local identifier, socket = self.identifier, self.socket;
	plr = identifier == enums.IdentifierType.Server and plr or identifier == enums.IdentifierType.Client and plrs.LocalPlayer;
	if (data.requested == nil) then
		data.requested = tick();
	end;
	local key = assert(self:key(plr));
	local cipher = assert(self:compressPacket(data, key));
	local stack_res = pcall(
		identifier == enums.IdentifierType.Server and socket.FireClient or identifier == enums.IdentifierType.Client and socket.FireServer,
		socket, identifier == enums.IdentifierType.Server and plr or cipher, identifier == enums.IdentifierType.Server and cipher or nil);
	local d_res = stack_res and enums.ErrorCode.OK or nil;
--[[
	local write_link = linker(self.key, self.compress_packet);
	local write_res;
	write_link
	:pull(function(err, key) assert(not err, err);
		if (data.requested == nil) then
			data.requested = tick();
		end;
		return self, data, key;
	end)
	:pull(function(err, cipher) assert(not err, err);
		local stack_res = pcall(
			identifier == enums.IdentifierType.Server and socket.FireClient or identifier == enums.IdentifierType.Client and socket.FireServer,
			socket, identifier == enums.IdentifierType.Server and plr or cipher, identifier == enums.IdentifierType.Server and cipher or nil);
		if (stack_res == false and write_res == nil) then
			write_res = false;
		end;
	end);
	if (type(plr) == 'table') then
		for i = 1, #plr do
			local rbx_plr = plr[i];
			write_link:push(self, rbx_plr);
		end;
	else
		write_link:push(self, plr);
	end;]]
	--local process_code = write_res == nil and  or nil;
	return d_res, debug.fail(d_res, 'EIOP');
end);

network.read = runtime.async(function(self, ...)
	local args = {...};
	local plr = args[1];
	if (type(plr) == 'userdata' and plr.ClassName:lower() == 'player') then
		table_remove(args, 1);
	else
		plr = plrs.LocalPlayer;
	end;
	local cipher, on_accept, on_reject = args[1], self.on_accept, self.on_reject;
	local read_link = linker(self.readable, self.key, self.decompressPacket);
	read_link
	:pull(function(err)
		if (err == nil) then
			return self, plr;
		else
			on_reject:Fire(err);
			stop();
		end;
	end)
	:pull(function(err, key)
		if (err == nil) then
			return self, cipher, key;
		else
			on_reject:Fire(err);
			stop();
		end;
	end)
	:pull(function(err, data)
		if (err == nil) then
			on_accept:Fire(plr, data);
		else
			on_reject:Fire(err);
			stop();
		end;
	end);
	read_link:push(self, unpack(args));
	return enums.ErrorCode.OK;
end);

if (is_server == true) then
	network.setSocketArt = runtime.async(function(self, socket)
		if (is_server == false) then
			return nil, debug.fail(nil, 'ELOCKED');
		end;
		local art, art_pointers, local_stack = {}, {}, {};
		for i = 0, 255 do
			local ascii, pointer = __prototype.extendDigits(i, 3), __prototype.extendDigits(__prototype.random(0, 255, local_stack), 3);
			art[ascii], art_pointers[pointer] = pointer, ascii;
		end;
		socket:SetAttribute('wl', __prototype.pile(art));
		self.art, self.art_pointers = art, art_pointers;
		return socket;
	end);
elseif (is_client == true) then
	network.getSocketArt = runtime.async(function(self, socket)
		local callback = callback;
		local puller = runtime.getPuller(self.getSocketArt);
		local wl  = socket:GetAttribute('wl');
		if (wl == nil) then
			local wl_changed; wl_changed = socket:GetAttributeChangedSignal('wl'):connect(function()
				wl = socket:GetAttribute('wl');
				if (wl ~= nil and wl_changed ~= nil) then
					wl_changed:disconnect();
					wl_changed = nil;
					self.art, self.art_pointers = __prototype.spread(wl);
					assert(puller:push_callback(callback, socket));
				end;
			end);
		else
			self.art, self.art_pointers = __prototype.spread(wl);
			assert(puller:push_callback(callback, socket));
		end;
	end, enums.Async.Channel);
end;

__prototype.pile = function(a)
	local clump = '';
	for ascii, pointer in next, a do
		clump = clump..ascii..pointer;
	end;
	return clump;
end;

__prototype.spread = function(a)
	local clump, clump_pointers, hn = {}, {}, nil;
	for num in string_gmatch(a, '[%d][%d][%d]') do
		if (hn == nil) then
			hn = num;
		elseif (hn ~= nil) then
			clump[hn], clump_pointers[num] = num, hn;
			hn = nil;
		end;
	end;
	return clump, clump_pointers;
end;

__prototype.extendDigits = function(n, mn)
	n = tostring(n);
	local ln = n:len();
	if (mn ~= nil and ln < mn) then
		for i = 1, mn - ln do
			n = '0'..n;
		end;
	end;
	return n;
end;

__prototype.random = function(a, b, local_stack)
	local n = math_random(a, b);
	if (local_stack ~= nil) then
		local point = local_stack[n];
		if (point == nil) then
			local_stack[n] = 0;
		elseif (point ~= nil) then
			return __prototype.random(a, b, local_stack);
		end;
	end;
	return n;
end;

__prototype.encrypt = function(message, key)
	local key_bytes;
	if type(key) == 'string' then
		key_bytes = {};
		for key_index = 1, #key do
			key_bytes[key_index] = string_byte(key, key_index);
		end;
	else
		key_bytes = key;
	end;
	local message_length = #message;
	local key_length = #key_bytes;
	local message_bytes = {};
	for message_index = 1, message_length do
		message_bytes[message_index] = string_byte(message, message_index);
	end;
	local result_bytes = {};
	local random_seed = 0;
	for key_index = 1, key_length do
		random_seed = (random_seed + key_bytes[key_index] * key_index) * 1103515245 + 12345;
		random_seed = (random_seed - random_seed % 65536) / 65536 % 4294967296;
	end;
	for message_index = 1, message_length do
		local message_byte = message_bytes[message_index];
		for key_index = 1, key_length do
			local key_byte = key_bytes[key_index];
			local result_index = message_index + key_index - 1;
			local result_byte = message_byte + (result_bytes[result_index] or 0);
			if result_byte > 255 then
				result_byte = result_byte - 256;
			end;
			result_byte = result_byte + key_byte;
			if result_byte > 255 then
				result_byte = result_byte - 256;
			end;
			random_seed = (random_seed % 4194304 * 1103515245 + 12345);
			result_byte = result_byte + (random_seed - random_seed % 65536) / 65536 % 256;
			if result_byte > 255 then
				result_byte = result_byte - 256;
			end;
			result_bytes[result_index] = result_byte;
		end;
	end;
	local result_buffer = {};
	local result_buffer_index = 1;
	for result_index = 1, #result_bytes do
		local result_byte = result_bytes[result_index];
		result_buffer[result_buffer_index] = string_format('%02x', result_byte);
		result_buffer_index = result_buffer_index + 1;
	end;
	return table_concat(result_buffer);
end;

__prototype.decrypt = function(cipher, key)
	local key_bytes;
	if type(key) == 'string' then
		key_bytes = {};
		for key_index = 1, #key do
			key_bytes[key_index] = string_byte(key, key_index);
		end;
	else
		key_bytes = key;
	end;
	local key_length = #key_bytes;
	local cipher_bytes = {};
	local cipher_length = 0;
	for byte_str in string_gmatch(cipher, '%x%x') do
		cipher_length = cipher_length + 1;
		cipher_bytes[cipher_length] = tonumber(byte_str, 16);
	end;
	local random_bytes = {};
	local random_seed = 0;
	for key_index = 1, key_length do
		random_seed = (random_seed + key_bytes[key_index] * key_index) * 1103515245 + 12345;
		random_seed = (random_seed - random_seed % 65536) / 65536 % 4294967296;
	end;
	for random_index = 1, (cipher_length - key_length + 1) * key_length do
		random_seed = (random_seed % 4194304 * 1103515245 + 12345);
		random_bytes[random_index] = (random_seed - random_seed % 65536) / 65536 % 256;
	end;
	local random_index = #random_bytes;
	local last_key_byte = key_bytes[key_length];
	local result_bytes = {};
	for cipher_index = cipher_length, key_length, -1 do
		local result_byte = cipher_bytes[cipher_index] - last_key_byte;
		if result_byte < 0 then
			result_byte = result_byte + 256;
		end;
		result_byte = result_byte - random_bytes[random_index];
		random_index = random_index - 1;
		if result_byte < 0 then
			result_byte = result_byte + 256;
		end;
		for key_index = key_length - 1, 1, -1 do
			cipher_index = cipher_index - 1;
			local cipher_byte = cipher_bytes[cipher_index] - key_bytes[key_index];
			if cipher_byte < 0 then
				cipher_byte = cipher_byte + 256;
			end;
			cipher_byte = cipher_byte - result_byte;
			if cipher_byte < 0 then
				cipher_byte = cipher_byte + 256;
			end;
			cipher_byte = cipher_byte - random_bytes[random_index];
			random_index = random_index - 1;
			if cipher_byte < 0 then
				cipher_byte = cipher_byte + 256;
			end;
			cipher_bytes[cipher_index] = cipher_byte;
		end;
		result_bytes[cipher_index] = result_byte;
	end;
	local result_characters = {};
	for result_index = 1, #result_bytes do
		result_characters[result_index] = string_char(result_bytes[result_index]);
	end;
	return table_concat(result_characters);
end;

return network;