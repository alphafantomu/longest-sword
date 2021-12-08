
local game = game;
local rep_storage, plrs = game:service('ReplicatedStorage'), game:service('Players');
local common = rep_storage:WaitForChild('common');
local rbx_blacksmith = script:FindFirstAncestor('blacksmith');
local rbx_auria = common:WaitForChild('auria');
local blacksmith_class = require(rbx_blacksmith);
local auria = require(rbx_auria);
local illya = auria.illya;

local enums = require(illya.framework.api.enum);
local debug = require(illya.framework.api.debug);
local runtime = require(illya.framework.api.runtime);
local timer = require(illya.framework.objects.timer);
local vfx = require(auria.framework.api.vfx);
local sfx = require(auria.framework.api.sfx);
local global = require(auria.framework.reference.global);

local misc = rep_storage:WaitForChild('Misc');
local local_handle = misc:WaitForChild('Handle');
local local_sword = misc:WaitForChild('Sword');

local user_class = require(auria.framework.objects.user);

local user = blacksmith_class:extend('user');

local user_list = {};

user.userExists = runtime.async(function(self, rbx_player)
	if (rbx_player.ClassName ~= 'Player') then
		return nil, debug.fail(nil, 'EPLR');
	end;
	return user_list[rbx_player] ~= nil;
end);

user.getUser = runtime.async(function(self, rbx_player)
	if (rbx_player.ClassName ~= 'Player') then
		return nil, debug.fail(nil, 'EPLR');
	end;
	local userdata = user_list[rbx_player];
	if (userdata == nil) then
		userdata = user_class(rbx_player);
		user_list[rbx_player] = userdata;
	end;
	return userdata;
end);

user.removeUser = runtime.async(function(self, rbx_player)
	if (rbx_player.ClassName ~= 'Player') then
		return nil, debug.fail(nil, 'EPLR');
	end;
	user_list[rbx_player] = nil;
	local res = user_list[rbx_player] == nil and enums.ErrorCode.OK or nil;
	return res, debug.fail(res, 'EIOP');
end);

user.updateLength = runtime.async(function(self, rbx_player, length)
	if (rbx_player.ClassName ~= 'Player') then
		return nil, debug.fail(nil, 'EPLR');
	end;
	return self:sendPacket(rbx_player, 'updateLength', {length = length});
end);

user.run = function(self)
	self
	:openRequest('login', function(self, plr, data) --sync closure formatting
		print(plr, 'requested to login at', data.requested);
		local userdata = assert(self:getUser(plr));
		--implement loading here
		print('Server sending', userdata:express());
		local character = assert(userdata:getCharacter());
		assert(character:recover());
		print('Sending user_pointer', assert(userdata:serialize()):len());
		return {
			user_pointer = assert(userdata:serialize());
		};
	end)
	:setRateLimit('login', -1)
	:openRequest('disconnect', function(self, plr, data)
		assert(self:removeSession(plr));
		--implement saves here
		assert(self:removeUser(plr));
	end)
	:setRateLimit('disconnect', -1)
	:openRequest('character', function(self, plr, data)
		local userdata = assert(self:getUser(plr));
		local character = assert(userdata:getCharacter());
		warn('SENDING CHAR HP', character.hp);
		return {
			char_pointer = assert(character:serialize());
		};
	end)
	:openRequest('equipSword', function(self, plr, data)
		local userdata = assert(self:getUser(plr));
		local character = assert(userdata:getCharacter());
		if (character.swordModel == nil) then
			local rbx_character = assert(plr.Character);
			local rbx_sword = character:FindFirstChild('Sword');
			if (rbx_sword ~= nil) then
				rbx_sword:Destroy();
			end;
			local rightArm = assert(character:WaitForChild('Right Arm', .5));
			local handle, weapon = local_handle:clone(), local_sword:clone();
			handle.Parent, weapon.Parent = rbx_character, rbx_character;
			handle.Handle.Part0, weapon.mainWeld.Handle.Part1 = rightArm, handle;
			character.swordModel = weapon;
			local length = character.length;
			if (length > 0) then
				assert(vfx:elongate(weapon, length));
			end;
		end;
	end);
	do
		local disconnect_timer = timer();
		disconnect_timer:start(20, 20, function(err, dt, elapsed)
			for rbx_player, _ in next, user_list do
				local rbx_player_name = rbx_player.Name;
				if (plrs:FindFirstChild(rbx_player_name) == nil) then
					assert(self:removeUser(rbx_player));
				end;
			end;
		end);
	end;
end;

return user;