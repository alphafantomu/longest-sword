
local script = script;

local setmetatable, assert, require, rawset = setmetatable, assert, require, rawset;
local Instance = Instance;
local i_new = Instance.new;

local illya = 
	setmetatable({
		_VERSION = 'v1.4.6';
		_DESCRIPTION = 'Illya, a reference to the God Slayer herself, Illya, from Fate/Kaleid Liner Prisma Illya, is designed to be a mirrored framework for the roblox engine.';
		_URL = 'https://github.com/alphafantomu/illya/';
	}, {
		__index = function(self, index)
			return script:WaitForChild(index);
		end;
	});

illya.event = function(name)
	local fast_event = i_new('BindableEvent');
	fast_event.Name = name or fast_event.Name;
	return fast_event;
end;

illya.use = function(framework)
	local data = require(framework);
	data.illya = illya;
	illya[framework.Name] = data;
	return data;
end;

illya.rbxExtender = function(rbx_object, data)
	return setmetatable(data or {}, {
		__index = function(self, index)
			return rbx_object:WaitForChild(index);
		end;
	});
end;

illya.require = function(obj_list, pipe)
	return setmetatable(pipe or {list = obj_list}, {
		__index = function(self, index)
			local obj = obj_list[index];
			assert(obj ~= nil, 'object missing');
			local data = require(obj);
			rawset(self, index, data);
			return data;
		end;
	});
end;

--[[
illya.require = function(lib_table) --decide whether this is adaptable or self contained
	local caller_env = getfenv(2);
	local meta = env_list[caller_env];
	local lib_cache = {};
	local event = util.event('illya_require_queue');
	if (meta == nil) then
		meta = {
			__index = function(self, index)
				local self_value, lib_value, caller_value = rawget(self, index), lib_table[index], caller_env[index];
				if (self_value ~= nil) then
					return self_value;
				elseif (lib_value ~= nil) then
					local cache_value = lib_cache[lib_value];
					if (cache_value == nil) then
						cache_value = require(lib_value);
						lib_cache[lib_value] = cache_value;
						event:Fire(index, cache_value);
					end;
					return cache_value;
				elseif (caller_value ~= nil) then
					return caller_value;
				end;
			end;
			__metatable = getmetatable(caller_env);
		};
		env_list[caller_env] = meta;
		setfenv(2, setmetatable({}, meta));
	elseif (meta ~= nil) then --update meta by layering the old index
		local old_index = meta.__index;
		meta.__index = function(self, index)
			local self_value, lib_value, caller_value = rawget(self, index), lib_table[index], caller_env[index];
			if (self_value ~= nil) then
				return self_value;
			elseif (lib_value ~= nil) then
				local cache_value = lib_cache[lib_value];
				if (cache_value == nil) then
					cache_value = require(lib_value);
					lib_cache[lib_value] = cache_value;
					event:Fire(index, cache_value);
				end;
				return cache_value;
			elseif (caller_value ~= nil) then
				return caller_value;
			end;
			return old_index(self, index);
		end;
	end;
	return event.Event;
end;]]

illya.run = function(mode)
	require(illya.framework.api.debug).run();
	require(illya.framework.api.runtime).run('hybrid');
	return illya;
end;

return illya;