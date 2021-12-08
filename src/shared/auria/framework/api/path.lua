
local require = require;
local table = table;
local table_insert, table_remove = table.insert, table.remove;

local script = script;
local rbx_auria = script:FindFirstAncestor('auria');
local workspace = game:service('Workspace');
local auria = require(rbx_auria);
local illya = auria.illya;

local class = require(illya.class);
local debug = require(illya.framework.api.debug);
local enums = require(illya.framework.api.enum);
local runtime = require(illya.framework.api.runtime);
local extension = require(illya.framework.api.extension);
local struct = require(illya.framework.api.struct);
local json = require(illya.framework.api.json);

local path = class('path');

local path_link = {
	workspace = workspace;
};

path.encode = runtime.async(function(self, obj)
	local encoding, reversed = {}, {};
	local p = obj.Parent
	table_insert(encoding, obj == path_link.workspace and 'workspace' or obj.Name);
	while (p ~= nil) do
		table_insert(encoding, p == path_link.workspace and 'workspace' or p.Name);
		p = p.Parent;
	end;
	local n = #encoding;
	for i = n, 1, -1 do
		reversed[(n - i) + 1] = encoding[i];
	end;
	table_remove(reversed, 1);
	return json.encode(reversed);
end);

path.decode = runtime.async(function(self, encoding)
	local encoded_path = json.decode(encoding);
	local starter = encoded_path[1];
	local rbx_starter = path_link[starter];
	if (rbx_starter ~= nil) then
		for i = 2, #encoded_path do
			rbx_starter = rbx_starter:FindFirstChild(encoded_path[i]);
		end;
		return rbx_starter;
	else return nil, debug.fail(nil, 'UNKNOWN');
	end;
end);

return path;