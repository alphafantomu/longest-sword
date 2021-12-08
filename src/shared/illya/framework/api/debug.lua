
local require, assert, type, next, tostring, tonumber, getfenv, setfenv, setmetatable, unpack = require, assert, type, next, tostring, tonumber, getfenv, setfenv, setmetatable, unpack;

local script, game = script, game;
local test = game:service('TestService');
local core = script:FindFirstAncestor('illya');
local class = require(core.class);
local extension = require(core.framework.api.extension);
local enums = require(core.framework.api.enum);
local json = require(core.framework.api.json);
local struct = require(core.framework.api.struct);

local enum = enums.enum;
local string, table = extension.string, extension.table;
local string_lower, string_char = string.lower, string.char;
local table_insert, table_remove = table.insert, table.remove;

local debug = class('debug');

local wenv_cache = {};
local error_messages, error_codes =
{
	[-1] 			= 'unknown error';
	[ 0] 			= 'success';
	[ 1] 			= 'data exceeds upper limit';
	[ 2] 			= 'data exceeds lower limit';
	[ 3] 			= 'failed conditionals';
	[ 4] 			= 'misaligned';
	[ 5] 			= 'type not supported';
	[ 6] 			= 'lua operation failed';
}, {
	UNKNOWN 		= -1;
	OK 				=  0;
	ESIZEU 			=  1;
	ESIZEL 			=  2;
	ECOND 			=  3;
	EALIGN 			=  4;
	ETYPE 			=  5;
	EIOP 			=  6;
};

debug.addErrorCode = function(err_name, err_msg)
	local enum_id = #error_messages + 1;
	error_messages[enum_id], error_codes[err_name] = err_msg, enum_id;
end;

debug.fail = function(res, err_name)
	if (res == nil) then
		local msg = assert(error_messages[error_codes[err_name]], tostring(err_name)..' has not been registered as an error code');
		return err_name..': '..msg, err_name;
	end;
end;

debug.error = function(str)
	if (debug.display == true) then
		test:Error(str);
	end;
end;

debug.assert = function(bool, str)
	if (debug.display == true) then
		test:Check(bool, str);
	end;
	return bool, str;
end;

debug.warn = function(bool, str)
	if (debug.display == true) then
		test:Warn(bool, str);
	end;
	return bool, str;
end;

debug.compress_binary_table = function(array)
	local binary_array = {};
	for i, v in next, array do
		if (type(v) == 'table' and v.serialize ~= nil) then
			v = assert(v:serialize());
		end;
		binary_array[i] = v;
	end;
	local json_array = json.encode(binary_array);
	return struct.pack('<s', json_array);
end;

debug.decompress_binary_table = function(binary, fx_deserialize)
	local binary_json = struct.unpack('<s', binary);
	local json_array = json.decode(binary_json);
	if (fx_deserialize ~= nil) then
		for i, v in next, json_array do
			json_array[i] = assert(fx_deserialize(nil, v));
		end;
	end;
	return json_array;
end;

debug.compress_set = function(err_res)
	local tab = string_char(9);
	local stream = '{\n';
	if (err_res ~= nil) then
		for i, v in next, err_res do
			stream = stream..tab..v..' '..i..'\n';
		end;
		stream = stream:sub(1, stream:len() - 1);
	end;
	return stream..'\n}\n';
end;

debug.express = function(t, base)
	base = base or '';
	local tab = string_char(9);
	local stream = base..'{\n';
	for i, v in next, t do
		if (type(v) == 'table' and v.__index == nil) then
			v = debug.express(v, base..tab);
		end;
		stream = stream..base..tab..tostring(i)..' > '..tostring(v)..'\n';
	end;
	stream = stream:sub(1, stream:len() - 1);
	return stream..'\n'..base..'}';
end;

debug.condition = function(data_value, data_type, options)
	local data_value_type = type(data_value);
	if (data_value_type == data_type) then
		if (data_type == 'string') then
			--max string lengths, identical strings
			local identical_failed_once, found_match = false, false;
			for i = 1, #options do
				local option = string.trim(options[i]);
				local number_option = tonumber(option);
				if (number_option ~= nil and data_value:len() > number_option) then
					return nil, debug.fail(nil, 'ESIZEU');
				elseif (number_option == nil) then
					if (data_value ~= option) then
						identical_failed_once = true;
					elseif (data_value == option) then
						found_match = true;
					end;
				end;
			end;
			if (identical_failed_once == true and found_match == false) then
				return nil, debug.fail(nil, 'ECOND');
			end;
		elseif (data_type == 'number') then
			--<= or >= or > or < conditionals, identical numbers
			local identical_failed_once, found_match = false, false;
			for i = 1, #options do
				local option = string.trim(options[i]):gsub('n', '-');
				local number_option = tonumber(option);
				if (number_option ~= nil) then
					if (data_value ~= number_option) then
						identical_failed_once = true;
					elseif (data_value == number_option) then
						found_match = true;
					end;
				elseif (number_option == nil) then
					local two, one = option:sub(1, 2), option:sub(1, 1);
					local compare_three, compare_two = tonumber(option:sub(3)), tonumber(option:sub(2));
					if (compare_three ~= nil and two == '<=' and data_value > compare_three) or (compare_two ~= nil and one == '<' and data_value >= compare_two) then
						return nil, debug.fail(nil, 'ESIZEU');
					elseif (compare_three ~= nil and two == '>=' and data_value < compare_three) or (compare_two ~= nil and one == '>' and data_value <= compare_two) then
						return nil, debug.fail(nil, 'ESIZEL');
					elseif (compare_three ~= nil and (two == '==' and data_value ~= compare_three) or (two == '~=' and data_value == compare_three)) then
						return nil, debug.fail(nil, 'EALIGN');
					end;
				end;
			end;
			if (identical_failed_once == true and found_match == false) then
				return nil, debug.fail(nil, 'ECOND');
			end;
		elseif (data_type == 'boolean') then
			--identical booleans, they are on an "AND" basis
			for i = 1, #options do
				local option = string.trim(options[i]);
				local number_option = tonumber(option);
				if (number_option ~= nil and (number_option == 1 and data_value ~= true or number_option == 2 and data_value ~= false)) or (number_option == nil and (option == 'true' and data_value ~= true or option == 'false' and data_value ~= false)) then
					return nil, debug.fail(nil, 'EALIGN');
				end;
			end;
		elseif (data_type == 'table') then
			--index and value scan for specific types, no complex conditional nesting
			for i = 1, #options do
				local option = string.trim(options[i]);
				if (option:find(':') ~= nil) then
					local data_pair = string.split(option, ':');
					local index_type, value_type = string.trim(data_pair[1]), string.trim(data_pair[2]);
					for e, v in next, data_value do
						local e_type, v_type = type(e), type(v);
						if (e_type ~= index_type or v_type ~= value_type) then
							return nil, debug.fail(nil, 'EALIGN');
						end;
					end;
				end;
			end;
		elseif (data_type == 'any') then
			
		else
			return nil, debug.fail(nil, 'ETYPE');
		end;
		return error_codes.OK;
	end;
	return nil, debug.fail(nil, 'UNKNOWN');
end;

debug.get_options = function(data_type)
	if (data_type:find('|') ~= nil) then
		local options = string.split(data_type, '|');
		local mod_data_type = string_lower(options[1]);
		table_remove(options, 1);
		return mod_data_type, options;
	end;
	return data_type;
end;

debug.scan = function(debug_table, data)
	local success, bad_matches = error_codes.OK, {};
	for index, value in next, debug_table do
		local data_value = data[index];
		local data_value_type = type(data_value);
		local type_string = string.trim(value);
		local is_multi_type = type_string:find('-') ~= nil;
		if (is_multi_type == true) then
			local types = string.split(type_string, '-');
			local match_any, complex_fail = false, nil;
			local type_names = {};
			for i = 1, #types do
				local data_type, options = debug.get_options(types[i]);
				table_insert(type_names, data_type);
				if (data_value_type == data_type or data_type == 'any') then
					if (options ~= nil) then
						local res, err_msg = debug.condition(data_value, data_type, options);
						if (res == error_codes.OK) then
							match_any = true;
							break;
						else complex_fail = err_msg;
						end;
					else match_any = true;
						break;
					end;
				end;
			end;
			if (match_any == false) then
				bad_matches[index] = complex_fail or debug.fail(nil, 'EALIGN');
				if (success ~= nil) then success = nil; end;
			end;
		else
			local mod_type_string, options = debug.get_options(type_string);
			type_string = mod_type_string;
			local matched, complex_fail = false, nil;
			if (data_value_type == type_string or type_string == 'any') then
				if (options ~= nil) then
					local res, err_msg = debug.condition(data_value, type_string, options);
					if (res == nil) then
						complex_fail = err_msg;
					else
						matched = true;
					end;
				else
					matched = true;
				end;
			end;
			if (matched == false) then
				bad_matches[index] = complex_fail or debug.fail(nil, 'EALIGN');
				if (success ~= nil) then success = nil; end;
			end;
		end;
	end;
	return success, success ~= error_codes.OK and bad_matches or nil;
end;

debug.autoshift = function(args) --convert return args from sync to callback args from async
	local status_code = args[1];
	if (status_code == nil) then
		return args[2];
	else if (status_code == error_codes.OK) then
			table_remove(args, 1);
		end;
		return nil, unpack(args);
	end;
end;

debug.methodToMethodName = function(fx, queue_list)
	local address = tostring(fx);
	for module_name, data in next, queue_list.list do
		for method_name, method in next, require(data) do
			if (type(method) == 'function') then
				if (tostring(method) == address) then
					return module_name..'.'..method_name..'()';
				end;
			end;
		end;
	end;
	return fx;
end;

debug.removeObjectLineFromError = function(err_string)
	if (err_string ~= nil) then
		return err_string:gsub('.*:%d-: ', '');
	end;
end;

debug.getwenv = function(n)
	local n_type = type(n);
	if (n_type == 'function') then
		local wrapper_env = wenv_cache[n];
		if (wrapper_env == nil) then
			local base_env = getfenv(n);
			local dictionary = {};
			wrapper_env = setmetatable(dictionary,
			{
				__index = function(self, index)
					return base_env[index];
				end;
			});
			setfenv(n, wrapper_env);
			wenv_cache[n] = wrapper_env;
		end;
		return wrapper_env;
	else
		local base_env = getfenv(n);
		local wrapper_env = setmetatable({},
		{
			__index = function(self, index)
				return base_env[index];
			end;
		});
		setfenv(n, wrapper_env);
		return wrapper_env;
	end;
	return nil, debug.fail(nil, 'UNKNOWN');
end;

debug.run = function(mode)
	if (enums.ErrorMessage ~= nil) then
		enums.ErrorMessage = nil;
	end; if (enums.ErrorCode ~= nil) then
		enums.ErrorCode = nil;
	end;
	enums.ErrorMessage, enums.ErrorCode = enum(error_messages), enum(error_codes);
	enums.IdentifierType = enum{
		Server 			= 0;
		Client 			= 1;
		Unknown 		= 2;
	};
end;

return debug;
