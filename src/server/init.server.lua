
--[[
	We'll detect when a player has logged in when they send a request into a socket
	
	PlayerRemoving, i think it has issues when players suddenly disconnect, so instead we'll use PlayerRemoving and a backup system

	Error Handling
	-> runtime.push_error;
	-> network.on_reject;
	-> threader.on_error;

	We need to add better error handling, error handling can occur at these libraries:
	-> Runtime -> Error handling here can chain, we'll need to set it up into a proper format for multiple errors at different points, like a traceback
		-> Need to somehow implement our own traceback? xpcall completely overrides the traceback in "err", worked out a good solution

	-> Network -> Error handling here is singular and outstreamed to .on_reject, covers itself
	-> Threader -> Error handling here is singular and outstreamed to .on_error
	-> Linker -> Error handling here cannot chain and is singular, even though the object itself is chaining, currently not outstreamed, runtime covers
	-> Timer -> Error handling here is singular but currently not outstreamed, indirectly outstreams into runtime, which covers it
	
	After error handling is done, remove all error codes that are unused

	-> Timer -> Puller -> Runtime Illya Queue DONE
	-> Linker -> Add object specific error handling DONE
	-> Threader -> Not sure
	-> Network -> All good DONE
	-> Runtime -> Probably all good DONE
	-> Puller -> Update code for new runtime DONE

	Note for 8/10/2021, direction replication is way too fucking laggy and it's actually creating a latency problem in roblox physics.

	Here is the actual architecture we need to do:
		- Clients should have some kind of reference to other players via "User" class
		- hit position x and z should be attached to this "User" class
		- Position updating for other players should occur in a runtime loop that is determined by delta time
		- Client's position updating should occur in real time, but the hit position x and z for the client should be on a timer to send to the server
]]

local script = script;
local rep_storage = game:service('ReplicatedStorage');
local common, sockets = rep_storage:WaitForChild('common'), rep_storage:WaitForChild('socket');
local rbx_illya, rbx_auria = common:WaitForChild('illya'), common:WaitForChild('auria');
local illya = require(rbx_illya).run();
local auria = illya.use(rbx_auria).run();

local debug = require(illya.framework.api.debug); debug.display = true;
local runtime = require(illya.framework.api.runtime);
local network = require(illya.framework.objects.network);
local global = require(auria.framework.reference.global);

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
		print('User blacksmith binded to user port', user_blacksmith.port);
		global.user_blacksmith = user_blacksmith;
	end);
end);

replicator_port:bind(rbx_replicator_socket, function(err)
	assert(not err, err);
	print('Binded to replicator socket');
	local replicator_blacksmith = replicator_blacksmith_class();
	replicator_blacksmith:bind(replicator_port, function(err)
		assert(not err, err);
		print('Replicator blacksmith binded to replicator port', replicator_blacksmith.port);
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

--[[
local test_timer = timer();
local start_time;

local workspace = workspace;
local p_clone = Instance.new'Part';
p_clone.Size = Vector3.new(1, 1, 1);
p_clone.Anchored = true;

local i = 0;
local printer = function(x, y)
	i = i + 1;
	local c = p_clone:clone();
	c.Position = Vector3.new(x, 0, y);
	c.Parent = workspace;
	print('Pixel', i, tick() - start_time);
end;

test_timer:start(20, 0, function(err, dt, elapsed)
	start_time = tick();
	for x = 1, 175 do
		for y = 1, 175 do
			runtime.illya_queue(nil, 'yield', nil, printer, x, y);
		end;
	end;
end);]]

--[[
local user_port = network();

user_port:bind(user_socket, function(err)
	assert(not err, err);
	print('Socket binded');
end);

user_port.onAccept.Event:connect(function(plr, data)
	print('Accepted', plr, data);
end);]]
--[[
local air = require(core);
local network = require(air.illya.framework.objects.network);

local user_manager = require(script:WaitForChild('user_manager'));
local battle_manager = require(script:WaitForChild('battle_manager'));

local user_socket = sockets:WaitForChild('user');
local battle_socket = sockets:WaitForChild('battle');

local event = air.event;

local global = {
	hash_string = 'FateGrandOrderIllya';
	user_manager = user_manager;
	battle_manager = battle_manager;
};

local user_port, battle_port = network(user_socket), network(battle_socket);

air.run();

user_manager.run(global, user_port);
battle_manager.run(global, battle_port);

event.network_on_reject.Event:connect(function(...)
	print('Server Network found rejection', ...);
end);]]