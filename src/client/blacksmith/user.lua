
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
local global = require(auria.framework.reference.global);

local user_class = require(auria.framework.objects.user);

local user = blacksmith_class:extend('user');

local user_list = {};

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

user.run = function(self)
	self
	:openRequest('updateLength', function(self, plr, data)
		
	end)
end;

return user;