
local require, type, next, assert, tostring = require, type, next, assert, tostring;
local string = string;
local string_char = string.char;

local script = script;
local rbx_auria = script:FindFirstAncestor('auria');
local auria = require(rbx_auria);
local illya = auria.illya;

local class = require(illya.class);
local debug = require(illya.framework.api.debug);
local enums = require(illya.framework.api.enum);
local runtime = require(illya.framework.api.runtime);
local extension = require(illya.framework.api.extension);
local struct = require(illya.framework.api.struct);

local math = extension.math;

local user = class('user',
	{
		max_length = 0;
	});

local mod_queue = illya.require{
	character = auria.framework.objects.character;
};

debug.addErrorCode('EBADPLR', 'not a valid player object');
debug.addErrorCode('ECHR', 'missing character');

user.debug_table = {
	max_length 		= 'number|<=4294967295';
};

user.init = function(self, plr)
	self.__prototype = {};
	self:setPlayer(plr);
	self.character = mod_queue.character(self);
end;

user.setPlayer = runtime.async(function(self, plr)
	if (type(plr) == 'userdata' and plr.ClassName == 'Player') then
		local __prototype = self.__prototype;
		local old_plr = __prototype.rbx_player;
		if (old_plr ~= plr) then
			__prototype.rbx_player = plr;
		end;
		return enums.ErrorCode.OK;
	else return nil, debug.fail(nil, 'EBADPLR');
	end; return nil, debug.fail(nil, 'UNKNOWN');
end);

user.newCharacter = runtime.async(function(self)
	self.character = mod_queue.character(self);
end);

user.getCharacter = runtime.async(function(self)
	local char_obj = self.character;
	return char_obj, debug.fail(char_obj, 'ECHR');
end);

user.setMaxLength = runtime.async(function(self, amt)
	local target_amt = math.clamp(amt, 0, 4294967295);
	self.max_length = target_amt;
	local res = self.max_length == target_amt and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end);

user.serialize = runtime.async(function(self)
	local debug_table = self.debug_table;
	local res, err_res = debug.scan(debug_table, self);
	debug.assert(res == enums.ErrorCode.OK, 'user.serialize() -> Scan failed: \n'..debug.compress_set(err_res));
	if (res == enums.ErrorCode.OK) then
		local max_length = math.clamp(self.max_length, 0, 4294967295);
		local binary = struct.pack('iI', enums.serial.user, max_length);
		return binary;
	else return res, debug.compress_set(err_res);
	end;
end);

user.deserialize = runtime.async(function(self, binary, plr)
	local serial_id = struct.unpack('i', binary);
	assert(serial_id == enums.serial.user, 'not acceptable binary');
	local max_length = struct.unpack('I', binary:sub(5));
	local user_object = self or user(plr);
	user_object.max_length = math.clamp(max_length, 0, 4294967295);
	return user_object;
end);

user.express = function(self)
	local tab = string_char(9);
	local stream = '{\n';
	for i, _ in next, self.debug_table do
		local self_value = self[i];
		stream = stream..tab..tostring(i)..' '..tostring(self_value)..'\n';
	end;
	stream = stream:sub(1, stream:len() - 1);
	return stream..'\n}\n';
end;

return user;