
local script = script;
local setmetatable, require = setmetatable, require;

local auria = 
	setmetatable({
		_VERSION = 'v0.0.1';
		_DESCRIPTION = 'Auria is a data handling framework dependent on the Illya framework.';
		_URL = 'unreleased';
	}, {
		__index = function(self, index)
			return script:WaitForChild(index);
		end;
	});

auria.run = function(mode)
	local enums = require(auria.illya.framework.api.enum);
	enums.serial = enums.enum{
		user 	  = 0;
		character = 1;
	};
	local runtime = require(auria.illya.framework.api.runtime);
	local debug_list = runtime.scan_list;
	local added_list = {
		{'character', auria.framework.objects.character};
		{'user', auria.framework.objects.user};
	};
	for i = 1, #added_list do
		table.insert(debug_list, added_list[i]);
	end;
	local debug = require(auria.illya.framework.api.debug);
	debug.addErrorCode('ESCAN', 'scan failed');
	debug.addErrorCode('EID', 'id pointer missing data');
	return auria;
end;

return auria;