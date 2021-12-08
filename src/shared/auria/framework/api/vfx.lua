
local require, assert = require, assert;
local table, math = table, math;
local table_insert = table.insert;
local math_random, math_round, math_floor = math.random, math.round, math.floor;

local Enum, Vector3, CFrame, Color3, TweenInfo, Instance = Enum, Vector3, CFrame, Color3, TweenInfo, Instance;
local v3, cf, fRGB, ti, ins = Vector3.new, CFrame.new, Color3.fromRGB, TweenInfo.new, Instance.new;

local script = script;
local rbx_auria = script:FindFirstAncestor('auria');
local rep_storage, workspace, tween, plrs = game:service('ReplicatedStorage'), game:service('Workspace'), game:service('TweenService'), game:service('Players');
local auria = require(rbx_auria);
local illya = auria.illya;

local class = require(illya.class);
local debug = require(illya.framework.api.debug);
local runtime = require(illya.framework.api.runtime);
local enums = require(illya.framework.api.enum);
local timer = require(illya.framework.objects.timer);
local linker = require(illya.framework.objects.linker);

local effects = illya.rbxExtender(rep_storage:WaitForChild('Effects'));
local vfx = illya.rbxExtender(effects.VFX);
local vfx_combat = illya.rbxExtender(vfx.Combat);
local vfx_kill = illya.rbxExtender(vfx.Kill);

local vfx_elongate = vfx.elongate;

local glow_tween_info = ti(1.5, Enum.EasingStyle.Quart);
local glow_tween = {Transparency = 1};
local to_tween = {Color = fRGB(14, 255, 255)};
local neon_color = fRGB(255, 195, 14);

local vfx = class('vfx');

vfx.combat = vfx_combat;
vfx.kill = vfx_kill;

vfx.open = runtime.async(function(self, effect, part)
	local vfx_effect = effect:clone();
	vfx_effect.Parent, vfx_effect.Position = workspace, part.Position;
	local vfx_desc = vfx_effect:GetDescendants();
	local soundLongest, rSounds = 0, {};
	for i = 1, #vfx_desc do
		local true_vfx = vfx_desc[i];
		local className = true_vfx.ClassName;
		if (className == 'ParticleEmitter') then
			true_vfx:Emit(1);
		elseif (className == 'Sound') then
			if (true_vfx:GetAttribute('isRandom') == true) then
				table_insert(rSounds, true_vfx);
			else
				local tl = true_vfx.TimeLength;
				if (soundLongest < tl) then
					soundLongest = tl;
				end;
				true_vfx:Play();
			end;
		end;
	end;
	local n_rSounds = #rSounds;
	if (n_rSounds > 0) then
		local sound = rSounds[math_random(1, n_rSounds)];
		local tl = sound.TimeLength;
		if (soundLongest < tl) then
			soundLongest = tl;
		end;
		sound:Play();
	end;
	return timer():start((soundLongest >= 5 and soundLongest) or 5, 0, function(err)
		assert(not err, err);
		vfx_effect:Destroy();
	end);
end);

vfx.glow = runtime.async(function(self, part)
	local copy = part:clone()
	copy.Parent = part.Parent;
	copy.Size = copy.Size + v3(0.1, 0.1, 0.1);
	copy.Material = Enum.Material.Neon;
	copy.Color = fRGB(216, 134, 62);
	copy.Transparency = .1;
	tween:Create(copy, glow_tween_info, glow_tween):Play();
	return timer():start(5.5, 0, function(err)
		assert(not err, err);
		copy:Destroy();
	end);
end);

vfx.relinkAttachmentsToLength = runtime.async(function(self, blade)
	local blade_children = blade:children();
	local n_blade_children = #blade_children;
	if (n_blade_children > 0) then
		for i = 1, n_blade_children do
			local obj = blade_children[i];
			if (obj ~= nil and obj.ClassName == 'Attachment' and obj.Name == 'DmgPoint') then
				obj:Destroy();
			end;
		end;
	end;
	local trueLength, spacing = blade.Size.Z, .4;
	local n_attachments = math_round(trueLength/spacing);
	local z = -(math_floor(n_attachments/2) * spacing);
	for _ = 1, n_attachments do
		local dmgPoint = ins('Attachment', blade);
		dmgPoint.Name, dmgPoint.Visible, dmgPoint.Position = 'DmgPoint', true, v3(0, 0, z);
		z = z + spacing;
	end;
end);

vfx.elongate = runtime.async(function(self, swordModel, extension)
	extension = extension or 1;
	local swordExtender = illya.rbxExtender(swordModel);
	local blade, tip, neon = swordExtender.blade, swordExtender.tip, swordExtender.neon;
	local bladeSize = blade.Size;
	if (bladeSize.Z < 2048) then
		local character = swordModel.Parent;
		local plr = plrs:GetPlayerFromCharacter(character);
		if (plr ~= nil) then
			local handle = character.Handle;
			blade.Size = bladeSize + v3(0, 0, extension);
			blade.main.C1 = blade.main.C1 * cf(0, 0, extension/2);
			tip.main.C1 = tip.main.C1 * cf(0, 0, extension);
			local effect_linker = linker(self.glow, self.glow, self.relinkAttachmentsToLength, self.open)
			:pull(function(err)
				if (err ~= nil) then
					return stop(err);
				end;
				return tip;
			end)
			:pull(function(err)
				if (err ~= nil) then
					return stop(err);
				end;
				return blade;
			end)
			:pull(function(err)
				if (err ~= nil) then
					return stop(err);
				end;
				neon.Color = neon_color;
				tween:Create(neon, glow_tween_info, to_tween):Play();
				return vfx_elongate, handle;
			end)
			:pull()
			return effect_linker:push(blade);
		end;
	end;
	return nil, debug.fail(nil, 'UNKNOWN');
end);

return vfx;