
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

local pool = require(illya.framework.objects.pool);

local math = extension.math;

local character = class('character',
	{
		length = 0;
	});

local queue = illya.require{
	user = auria.framework.objects.user;
};

debug.addErrorCode('EUSR', 'missing user');
debug.addErrorCode('EBUSR', 'bad user');
debug.addErrorCode('ENDMG', 'no damage can be inflicted');
debug.addErrorCode('ENHEAL', 'no healing can be applied');

character.debug_table = {
	length 	= 'number|<=4294967295';
	user 	= 'table';
};

character.init = function(self, user_obj)
	assert(self:bind(user_obj));
	self.conditions = pool();
end;

character.bind = runtime.async(function(self, user_obj)
	if (user_obj ~= nil) then
		if (type(user_obj) == 'table' and user_obj.instanceOf ~= nil and user_obj:instanceOf(queue.user) == true) then
			self.user = user_obj;
			local res = self.user == user_obj and enums.ErrorCode.OK or nil;
			return res, debug.fail(res, 'EIOP');
		else return nil, debug.fail(nil, 'EBUSR');
		end;
	else return nil, debug.fail(nil, 'EUSR');
	end; return nil, debug.fail(nil, 'UNKNOWN');
end);

character.getUser = runtime.async(function(self)
	local user_obj = self.user;
	return user_obj, debug.fail(user_obj, 'EUSR');
end);

character.serialize = runtime.async(function(self)
	local debug_table = self.debug_table;
	local res, err_res = debug.scan(debug_table, self);
	debug.assert(res == enums.ErrorCode.OK, 'character.serialize() -> Scan failed: \n'..debug.compress_set(err_res));
	if (res == enums.ErrorCode.OK) then
		local length = math.clamp(self.length, 0, 4294967295);
		local binary = struct.pack('ii', enums.serial.character, length);
		return binary;
	else return nil, debug.fail(nil, 'ESCAN');
	end;
end);

character.deserialize = runtime.async(function(self, binary)
	local serial_id = struct.unpack('i', binary);
	assert(serial_id == enums.serial.character, 'not acceptable binary');
	local length = struct.unpack('i', binary:sub(5));
	local new_character = self or character(1);
	new_character.length = math.clamp(length, 0, 4294967295);
	return new_character;
end);

return character;