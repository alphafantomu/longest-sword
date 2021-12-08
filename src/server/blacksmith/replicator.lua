
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
local global = require(auria.framework.reference.global);

local replicator = blacksmith_class:extend('replicator');

replicator.getOtherPlayers = runtime.async(function(self, plr)
	local list = plrs:players();
	for i = 1, #list do
		local list_plr = list[i];
		if (list_plr == plr) then
			table.remove(list, i);
			break;
		end;
	end;
	return list;
end);

replicator.run = function(self)
	--[[
	self
	:openRequest('repDirection', function(self, plr, data)
		local body = data.body;
		local x, z = body.x, body.z;
		local list = assert(self:getOtherPlayers(plr));
		for i = 1, #list do
			local rbx_player = list[i];
			self:sendPacket(rbx_player, 'repDirection', {plrName = plr.Name, x = x, z = z});
		end;
	end)
	:setRateLimit('repDirection', 35000)]]
end;

return replicator;