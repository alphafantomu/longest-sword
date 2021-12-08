
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

local hitbox = blacksmith_class:extend('hitbox');

hitbox.startHitbox = runtime.async(function(self)

	return self:sendPacket(nil, 'startHitbox');
end);

hitbox.endHitbox = runtime.async(function(self)

	return self:sendPacket(nil, 'endHitbox');
end);

hitbox.onHit = runtime.async(function(self)

	return self:sendPacket(nil, 'onHit');
end);

hitbox.run = function(self)
	self
	:openRequest('updateHitbox', function(self, plr, data)
		--update on this
		local user_blacksmith = global.user_blacksmith;
		local userdata = assert(user_blacksmith:getUserdata(plr));
		

		local userdata = data:getUserdata(plr);
		local character = plr.Character;
		local hitboxObject = userdata.hitboxObject;


		local started = userdata.hitboxStarted;
		if (hitboxObject ~= nil and character ~= nil) then
			local startedAt = hitboxObject.startedAt;
			hitbox:Deinitialize(character);
			if (started == true) then
				hitboxObject = hitbox:Initialize(character, {character});
				hitboxObject:DebugMode(true);
				hitboxObject.startedAt = startedAt;
				hitboxObject:HitStart();
				userdata.hitboxObject = hitboxObject;
			else userdata.hitboxObject = nil;
			end;
		end;
		local hitboxEvent = userdata.hitboxEvent;
		if (hitboxEvent ~= nil) then
			hitboxEvent:disconnect();
			userdata.hitboxEvent = ((started == true) and (hitboxObject.OnHit:connect(function(part, humanoid)
				if (humanoid.Health > 0) then
					util.onHit(plr, part, humanoid);
				end;
			end))) or nil;
		end;
	end);
end;

return hitbox;