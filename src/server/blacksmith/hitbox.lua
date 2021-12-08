
local game = game;
local math = math;
local math_min = math.min;
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
local extension = require(illya.framework.api.extension);
local path = require(auria.framework.api.path);
local vfx = require(auria.framework.api.vfx);
local global = require(auria.framework.reference.global);

local hitbox = blacksmith_class:extend('hitbox');

local math = extension.math;

hitbox.updateHitbox = runtime.async(function(self, plr)
	return self:sendPacket(plr, 'updateHitbox');
end);

hitbox.run = function(self)
	self
	:openRequest('onHit', function(self, plr, data)
		local user_blacksmith = global.user_blacksmith;
		if (user_blacksmith:userExists(plr) == true) then
			local userdata = assert(user_blacksmith:getUser(plr));
			local character = assert(userdata:getCharacter());
			assert(character.swordModel ~= nil, 'sword is not equipped');
			assert(character.hitboxActive == true, 'hitbox is not active');
			--check for hitbox time length, should not be too long
			local time_diff = character.hitboxStarted - data.requested;
			if (time_diff > 5 or time_diff <= 0) then
				return assert(self:sendRequestToSelf(plr, 'endHitbox', data));
			end;
			local body = data.body;
			local humanoid_path = body.humanoid_path;
			local humanoid = assert(path:decode(humanoid_path));
			local hum_character = humanoid.Parent;
			if (humanoid.ClassName == 'Humanoid' and humanoid.Health > 1) then
				local torso = hum_character:FindFirstChild('Torso') or hum_character:FindFirstChild('Upper Torso') or hum_character:FindFirstChild('HumanoidRootPart');
				assert(vfx:open(vfx.combat.basic_slash, torso))
				humanoid:TakeDamage(30);
				local swordModel = character.swordModel;
				if (humanoid.Health < 1 and swordModel ~= nil) then --Got last hit and humanoid dies
					assert(vfx:open(vfx.kill.kill_basic, torso));
					assert(vfx:elongate(swordModel, 1));
					assert(self:updateHitbox(plr));
					local length = math_min(character.length, 0) + 1;
					local hit_plr = plrs:GetPlayerFromCharacter(hum_character);
					if (length <= 4294967295) then
						character.length = length;
						user_blacksmith:updateLength(plr, length); --replicates to client
						if (length > userdata.max_length) then
							userdata.max_length = math.clamp(length, 0, 4294967295);
							--update max length
							
						end;
						--global.leaderboard_blacksmith:updateLengthsBoard(3); --replicates to all clients and server cache
					end;
					if (hit_plr ~= nil and user_blacksmith:userExists(hit_plr) == true) then
						local hit_userdata = assert(user_blacksmith:getUser(hit_plr));
						hit_userdata:newCharacter();
						--global.leaderboard_blacksmith:updateLengthsBoard(3);
						--replicate to client, don't have to, client will request it once they die
					end;
				end;
			end;
		end;
	end)
	:openRequest('startHitbox', function(self, plr, data)
		local user_blacksmith = global.user_blacksmith;
		if (user_blacksmith:userExists(plr) == true) then
			local userdata = assert(user_blacksmith:getUser(plr));
			local character = assert(userdata:getCharacter());
			assert(character.swordModel ~= nil, 'sword is not equipped');
			assert(character.hitboxActive == false and character.hitboxStarted == 0, 'hitbox is active');
			character.hitboxActive, character.hitboxStarted = true, data.requested;
		end;
	end)
	:setRateLimit('startHitbox', 40)
	:openRequest('endHitbox', function(self, plr, data)
		local user_blacksmith = global.user_blacksmith;
		if (user_blacksmith:userExists(plr) == true) then
			local userdata = assert(user_blacksmith:getUser(plr));
			local character = assert(userdata:getCharacter());
			assert(character.hitboxActive == true or character.hitboxStarted ~= 0, 'hitbox is inactive');
			character.hitboxActive, character.hitboxStarted = false, 0;
		end;
	end)
	:setRateLimit('endHitbox', 40);
end;

return hitbox;