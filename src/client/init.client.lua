
local script = script;
local rep_storage, plrs, sgui, run = game:service('ReplicatedStorage'), game:service('Players'), game:service('StarterGui'), game:service('RunService');
local common, sockets, bindings = rep_storage:WaitForChild('common'), rep_storage:WaitForChild('socket'), rep_storage:WaitForChild('bindings');
local rbx_illya, rbx_auria = common:WaitForChild('illya'), common:WaitForChild('auria');
local illya = require(rbx_illya).run();
local auria = illya.use(rbx_auria).run();

local debug = require(illya.framework.api.debug); debug.display = true;
local runtime = require(illya.framework.api.runtime);
local hitbox = require(illya.framework.api.hitbox);
local network = require(illya.framework.objects.network);
local timer = require(illya.framework.objects.timer);
local global = require(auria.framework.reference.global);
local user_class = require(auria.framework.objects.user);

local animations = illya.rbxExtender(rep_storage:WaitForChild('Animations'));
local swordAnim = animations.Sword;
local swordAnims = swordAnim:getChildren();
local nSwordAnims = #swordAnims;

local localplayer = plrs.LocalPlayer;
local mouse = localplayer:GetMouse();

sgui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false);

sockets = illya.rbxExtender(sockets);

local system = illya.rbxExtender(script);
local blacksmith = system.blacksmith;
local rbx_user_socket, rbx_replicator_socket, rbx_hitbox_socket = sockets.user, sockets.replicator, sockets.hitbox;
local user_port, replicator_port, hitbox_port = network(), network(), network();
local user_blacksmith_class, replicator_blacksmith_class, hitbox_blacksmith_class = require(blacksmith.user), require(blacksmith.replicator), require(blacksmith.hitbox);

local error_handler = function(err, callTraceback, traceback)
	warn('\n'..err, '\n'..callTraceback, '\n'..traceback);
end;

runtime.execute_error:connect(error_handler);
user_port.on_reject.Event:connect(print);
replicator_port.on_reject.Event:connect(print);
hitbox_port.on_reject.Event:connect(print);

local debug_list = runtime.scan_list;
local added_list = {
	{'blacksmith', blacksmith};
	{'user_blacksmith', blacksmith.user};
	{'replicator_blacksmith', blacksmith.replicator};
	{'hitbox_blacksmith', blacksmith.hitbox};
};
for i = 1, #added_list do
	table.insert(debug_list, added_list[i]);
end;

user_port:bind(rbx_user_socket, function(err)
	assert(not err, err);
	print('Binded to user socket');
	local user_blacksmith = user_blacksmith_class();
	user_blacksmith:bind(user_port, function(err)
		assert(not err, err);
		print('User blacksmith binded to user port');
		global.user_blacksmith = user_blacksmith;
		user_blacksmith:sendPacket(nil, 'login', nil, function(err, result, data)
			assert(not err, err);
			local user_pointer = result.user_pointer;
			print('Login successful at', data.requested);
			print('Received', user_pointer);
			local user_object = assert(user_class.deserialize(nil, user_pointer, plrs.LocalPlayer));
			user_blacksmith.user = user_object;
			print('Server sent', user_blacksmith.user:express());
			user_blacksmith:sendPacket(nil, 'character', nil, function(err, result, data)
				assert(not err, err);
				local char_pointer = result.char_pointer;
				print('Character retrieval successful at', data.requested);
				print('Received', char_pointer);
				local cache_character = assert(user_object:getCharacter());
				assert(cache_character.deserialize(cache_character, char_pointer));
				print('Client got character with HP:', cache_character.hp, user_object.character.hp);
			end);
		end);
	end);
end);

replicator_port:bind(rbx_replicator_socket, function(err)
	assert(not err, err);
	print('Binded to replicator socket');
	local replicator_blacksmith = replicator_blacksmith_class();
	replicator_blacksmith:bind(replicator_port, function(err)
		assert(not err, err);
		print('Replicator blacksmith binded to replicator port');
		global.replicator_blacksmith = replicator_blacksmith;
	end);
end);

hitbox_port:bind(rbx_hitbox_socket, function(err)
	assert(not err, err);
	print('Binded to hitbox socket');
	local hitbox_blacksmith = hitbox_blacksmith_class();
	hitbox_blacksmith:bind(hitbox_port, function(err)
		assert(not err, err);
		print('Hitbox blacksmith binded to hitbox port', hitbox_blacksmith.port);
		global.hitbox_blacksmith = hitbox_blacksmith;
	end);
end);

local comboAnims, nCombo, st, lst, t, animDeb = {}, 1, 0, 0, 0, false;
local startTime, attackEnd, hStart, hEnd;

local onAttackEnd = function()
	if (attackEnd ~= nil) then
		attackEnd:disconnect();
		attackEnd = nil;
	end;
	local nResult = nCombo + 1;
	if (nResult > nSwordAnims) then
		nResult = 1;
	end;
	nCombo = nResult;
	util.when(0, function() 
		assert(data.allowEndDebounce, 'Animation debounce is locked');
		animDeb = false;
		--connection.send(attackEndData);
	end, true);
end;

local onHitboxEnd = function()
	if (hEnd ~= nil) then
		hEnd:disconnect();
		hEnd = nil;
	end;
	--send to server
end;

local onHitboxStart = function()
		if (hStart ~= nil) then
			hStart:disconnect();
			hStart = nil;
		end;
		hitboxStartData.currentCombo = nCombo;
		--send to server
end;

local onCharacterAdded = function(character)
	if (attackEnd ~= nil) then
		attackEnd:disconnect();
		attackEnd = nil;
	end;if (hEnd ~= nil) then
		hEnd:disconnect();
		hEnd = nil;
	end;if (hStart ~= nil) then
		hStart:disconnect();
		hStart = nil;
	end;
	data.allowEndDebounce = true;
	local humanoid = character:WaitForChild('Humanoid');
	local animator = humanoid:FindFirstChildOfClass('Animator');

	
	connection.send(equipSwordData);


	comboAnims, nCombo, animDeb = {}, 1, false;
	--if we get performance issues we can just iterate through the whole table and remove anims that way
	for i = 1, nSwordAnims do
		local loaded = animator:LoadAnimation(swordAnim['basic'..i]);
		table.insert(comboAnims, {
			loaded;
			hitboxStart = loaded:GetMarkerReachedSignal('hitboxStart');
			hitboxEnd = loaded:GetMarkerReachedSignal('hitboxEnd');
			attackEnd = loaded:GetMarkerReachedSignal('attackEnd');
		});
	end;
end;

mouse.Button1Down:connect(function()
	if (localplayer.Character ~= nil and localplayer.Character:FindFirstChild('Sword') ~= nil and animDeb == false) then
		animDeb = true;
		if (startTime ~= nil and (#comboAnims == nSwordAnims) and ((tick() - startTime) > ((comboAnims[nCombo - 1] or comboAnims[nSwordAnims])[1].Length + .2))) then
			nCombo = 1;
		end;
		local comboData = comboAnims[nCombo];
		local anim = comboData[1];
		data.currentAnimation = anim;
		startTime = tick();
		anim:Play();
		local hitboxEnd = comboData.hitboxEnd;
		hStart, hEnd = comboData.hitboxStart:connect(onHitboxStart), hitboxEnd:connect(onHitboxEnd);
		attackEnd = (((nCombo >= nSwordAnims) and comboData.attackEnd) or hitboxEnd):connect(onAttackEnd);
	end;
end);

localplayer.CharacterAdded:connect(onCharacterAdded);

do
	local character = localplayer.Character;
	if (character ~= nil) then
		onCharacterAdded(character);
	end;
end;

