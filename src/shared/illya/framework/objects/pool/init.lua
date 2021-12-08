
--direct port from love2d miyu framework
local require = require;
local math = math;
local math_floor = math.floor;

local script = script;
local core = script:FindFirstAncestor('illya');
local class = require(core.class);
local debug = require(core.framework.api.debug);
local enums = require(core.framework.api.enum);
local extension = require(core.framework.api.extension);
local table = extension.table;
local table_remove = table.remove;

local pool = class('pool',
    {
        debug = false;
        total = 0;
        max = -1;
    });

debug.addErrorCode('EPLLIMALIGN', 'pool linear and max limit misaligned');
debug.addErrorCode('EPLLIM', 'pool is at max limit');
debug.addErrorCode('EPLBADPOS', 'bad position');
debug.addErrorCode('EPLVALMISS', 'value missing at index');
debug.addErrorCode('EPLIDXMISS', 'value missing an index');
debug.addErrorCode('EAPMISS', 'after point could not be found');
debug.addErrorCode('ECOLLIDX', 'colliding indexes');
debug.addErrorCode('EBND', 'outside of boundaries');

pool.init = function(self, maxn)
    self.max = maxn or -1;
    self[1], self[2], self[3], self[4] = {}, {}, {}, {};
end;

pool.checkSync = function(self, msg, ...)
    if (self.debug == true) then
        local queue_list, queue_dict, index_list, index_dict = self[1], self[2], self[3], self[4];
        for i, v in next, queue_list do
            if (queue_dict[v] ~= i) then
                print('Queue list out of sync with queue dict');
                break;
            end;
        end;
        for i, v in next, queue_dict do
            if (queue_list[v] ~= i) then
                print('Queue dict out of sync with queue list');
                break;
            end;
        end;
        for i, v in next, index_list do
            if (index_dict[v] ~= i) then
                print('Index list out of sync with index dict');
                break;
            end;
        end;
        for i, v in next, index_dict do
            if (index_list[v] ~= i) then
                print('Index dict out of sync with index list');
                break;
            end;
        end;
        local ql_c, qd_c, il_c, id_c = table.count(queue_list), table.count(queue_dict), table.count(index_list), table.count(index_dict);
        local res = ql_c == qd_c and qd_c == il_c and il_c == id_c;
        if (res == false) then
            print('Something went wrong with', msg or 'N/A', ...);
            print('Internal tables are out of sync?', ql_c, qd_c, il_c, id_c);
            print('Internal tables for reference:', queue_list, queue_dict, index_list, index_dict);
        end;
    end;
end;

pool.accept = function(self, var)
    --warn(self.id, 'pool accepting', var);
    local pool_max = self.max;
    local pool_coll, inverse_pool_coll, total_coll, inverse_total_coll = self[1], self[2], self[3], self[4];
    local linear_limit, n_pool = #pool_coll, self.total;
    if not (linear_limit <= n_pool) then
        return nil, debug.fail(nil, 'EPLLIMALIGN');
    end;
    local next_index = ((linear_limit == n_pool and n_pool) or (linear_limit < n_pool and linear_limit)) + 1;
    if not (pool_max == -1 or next_index <= pool_max) then
        return nil, debug.fail(nil, 'EPLLIM');
    end;
    pool_coll[next_index], inverse_pool_coll[var] = var, next_index;
    --index list adjusting
    --local record = {};
    local total_n = #total_coll;
    local min, max = 1, total_n;
    --table.insert(record, 'checking for min and max compatability');
    if (min <= max) then
        --table.insert(record, 'min is less than or equal to max');
        local min_index, max_index = total_coll[min], total_coll[max];
        --add more collision checks
        if (next_index > max_index) then --add to the end of the array
            --table.insert(record, 'next index outside of upper range');
            self.total = next_index;
            local pos = total_n + 1;
            --table.insert(record, 'total_coll: set '..pos..' to '..next_index);
            --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..pos);
            total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
        elseif (next_index < min_index) then --shift all values in total_coll and inverse_total_coll up one
            --table.insert(record, {'next index outside of lower range', pool_coll, inverse_pool_coll, total_coll, inverse_total_coll});
            local changes = {};
            for pos = min, max do
                local pos_index = total_coll[pos];
                if (pos_index ~= nil) then
                    --table.insert(record, 'total_coll: set '..pos..' to nil');
                    changes[pos + 1], total_coll[pos] = pos_index, nil;
                else break;
                end;
            end;
            for pos, pos_index in next, changes do
                --table.insert(record, 'total_coll: set '..pos..' to '..pos_index);
                --table.insert(record, 'inverse_total_coll: set '..pos_index..' to '..pos);
                total_coll[pos], inverse_total_coll[pos_index] = pos_index, pos;
            end;
            --table.insert(record, 'finished setting');
            --table.insert(record, 'total_coll: set '..min..' to '..next_index);
            --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..min);
            total_coll[min], inverse_total_coll[next_index] = next_index, min;

        elseif (next_index > min_index and next_index < max_index) then
            --table.insert(record, 'next index within range');
            --this algorithm will be purely dependent on index_list, which should always have an ascending order of indexes by 1
            --for there to be an average position, there has to be atleast 3 values, basically greater than 2
            --if there is exactly 2, lower_pos will be the min, if there is exactly 2 they have to be the min and max
            --if there is exactly 1, shouldn't get here because if it is one, then there is an index of 1, which should be handled by the above since you cannot be both
            --under and above a value
            if (total_n > 2) then
                --table.insert(record, 'enough elements to estimate average');
                local lower_pos;
                local first_min, first_max = min, max;
                while (lower_pos == nil) do
                    if ((first_max - first_min) == 1) then --there is no inbetween, integers only
                        lower_pos = first_min;
                    else
                        local average_pos = first_min + math_floor((first_max - first_min)/2);
                        local average_index = total_coll[average_pos]; --due to the nature of index_list, average_index should always exist
                        local first_min_index, first_max_index = total_coll[first_min], total_coll[first_max];
                        if (next_index > average_index and next_index < first_max_index) then
                            first_min = average_pos;
                        elseif (next_index < average_index and next_index > first_min_index) then
                            first_max = average_pos;
                        else --warn('BAD BOUNDARY');
                            return nil, debug.fail(nil, 'EBND');
                        end;
                    end;
                end;
                local changes, pos = {}, lower_pos + 1;
                for exist_pos = pos, max do
                    local pos_index = total_coll[exist_pos];
                    if (pos_index ~= nil) then
                        --table.insert(record, 'total_coll: set '..pos..' to nil');
                        changes[exist_pos + 1], total_coll[exist_pos] = pos_index, nil;
                    else break;
                    end;
                end;
                for exist_pos, pos_index in next, changes do
                    --table.insert(record, 'total_coll: set '..exist_pos..' to '..pos_index);
                    --table.insert(record, 'inverse_total_coll: set '..pos_index..' to '..exist_pos);
                    total_coll[exist_pos], inverse_total_coll[pos_index] = pos_index, exist_pos;
                end;
                total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
            elseif (total_n == 2) then --we established that "pos" must be between min and max, so we'll do "pos" by min + 1, and shifting max up by 1 also
                --table.insert(record, 'skipping estimation due to only 2 elements');
                local pos = min + 1;
                if (pos == max) then
                    --table.insert(record, 'total_coll: set '..(max + 1)..' to '..max_index);
                    total_coll[max + 1], inverse_total_coll[max_index] = max_index, max + 1;
                end;
                --table.insert(record, 'total_coll: set '..pos..' to '..next_index);
                --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..pos);
                total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
            else --warn('BAD BOUNDARY 2');
                return nil, debug.fail(nil, 'EBND');
            end;
        else --warn('COLLISION?');
            return nil, debug.fail(nil, 'ECOLLIDX');
        end;
    elseif (max == 0 and self.total == 0) then
        --table.insert(record, 'max is 0 and total is 0');
        self.total = next_index;
        local pos = max + 1;
        total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
    else --warn('DO NOT KNOW', min, max, self.total, pool_coll, inverse_pool_coll, total_coll, inverse_total_coll);
        return nil, debug.fail(nil, 'UNKNOWN');
    end;
    --[[
    if (self.debug == true) then
        warn('Accepting', next_index, record, pool_coll, inverse_pool_coll, total_coll, inverse_total_coll);
    end;
    self:checkSync('accept', next_index, record);]]
    return next_index;
end;

pool.acceptPos = function(self, var, next_index)
    --assert(false, 'disabled');
    --warn(self.id, 'pool accepting', var);
    local pool_max = self.max;
    local pool_coll, inverse_pool_coll, total_coll, inverse_total_coll = self[1], self[2], self[3], self[4];
    local linear_limit, n_pool = #pool_coll, self.total;
    if not (linear_limit <= n_pool) then
        return nil, debug.fail(nil, 'EPLLIMALIGN');
    end;
    if not (pool_max == -1 or next_index <= pool_max) then
        return nil, debug.fail(nil, 'EPLLIM');
    end;
    if (pool_coll[next_index] ~= nil) then
        return nil, debug.fail(nil, 'EPLBADPOS');
    end;
    pool_coll[next_index], inverse_pool_coll[var] = var, next_index;
    local total_n = #total_coll;
    local min, max = 1, total_n;
    --table.insert(record, 'checking for min and max compatability');
    if (min <= max) then
        --table.insert(record, 'min is less than or equal to max');
        local min_index, max_index = total_coll[min], total_coll[max];
        --add more collision checks
        if (next_index > max_index) then --add to the end of the array
            --table.insert(record, 'next index outside of upper range');
            self.total = next_index;
            local pos = total_n + 1;
            --table.insert(record, 'total_coll: set '..pos..' to '..next_index);
            --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..pos);
            total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
        elseif (next_index < min_index) then --shift all values in total_coll and inverse_total_coll up one
            --table.insert(record, {'next index outside of lower range', pool_coll, inverse_pool_coll, total_coll, inverse_total_coll});
            local changes = {};
            for pos = min, max do
                local pos_index = total_coll[pos];
                if (pos_index ~= nil) then
                    --table.insert(record, 'total_coll: set '..pos..' to nil');
                    changes[pos + 1], total_coll[pos] = pos_index, nil;
                else break;
                end;
            end;
            for pos, pos_index in next, changes do
                --table.insert(record, 'total_coll: set '..pos..' to '..pos_index);
                --table.insert(record, 'inverse_total_coll: set '..pos_index..' to '..pos);
                total_coll[pos], inverse_total_coll[pos_index] = pos_index, pos;
            end;
            --table.insert(record, 'finished setting');
            --table.insert(record, 'total_coll: set '..min..' to '..next_index);
            --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..min);
            total_coll[min], inverse_total_coll[next_index] = next_index, min;

        elseif (next_index > min_index and next_index < max_index) then
            --table.insert(record, 'next index within range');
            --this algorithm will be purely dependent on index_list, which should always have an ascending order of indexes by 1
            --for there to be an average position, there has to be atleast 3 values, basically greater than 2
            --if there is exactly 2, lower_pos will be the min, if there is exactly 2 they have to be the min and max
            --if there is exactly 1, shouldn't get here because if it is one, then there is an index of 1, which should be handled by the above since you cannot be both
            --under and above a value
            if (total_n > 2) then
                --table.insert(record, 'enough elements to estimate average');
                local lower_pos;
                local first_min, first_max = min, max;
                while (lower_pos == nil) do
                    if ((first_max - first_min) == 1) then --there is no inbetween, integers only
                        lower_pos = first_min;
                    else
                        local average_pos = first_min + math_floor((first_max - first_min)/2);
                        local average_index = total_coll[average_pos]; --due to the nature of index_list, average_index should always exist
                        local first_min_index, first_max_index = total_coll[first_min], total_coll[first_max];
                        if (next_index > average_index and next_index < first_max_index) then
                            first_min = average_pos;
                        elseif (next_index < average_index and next_index > first_min_index) then
                            first_max = average_pos;
                        else --warn('BAD BOUNDARY');
                            return nil, debug.fail(nil, 'EBND');
                        end;
                    end;
                end;
                local changes, pos = {}, lower_pos + 1;
                for exist_pos = pos, max do
                    local pos_index = total_coll[exist_pos];
                    if (pos_index ~= nil) then
                        --table.insert(record, 'total_coll: set '..pos..' to nil');
                        changes[exist_pos + 1], total_coll[exist_pos] = pos_index, nil;
                    else break;
                    end;
                end;
                for exist_pos, pos_index in next, changes do
                    --table.insert(record, 'total_coll: set '..exist_pos..' to '..pos_index);
                    --table.insert(record, 'inverse_total_coll: set '..pos_index..' to '..exist_pos);
                    total_coll[exist_pos], inverse_total_coll[pos_index] = pos_index, exist_pos;
                end;
                total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
            elseif (total_n == 2) then --we established that "pos" must be between min and max, so we'll do "pos" by min + 1, and shifting max up by 1 also
                --table.insert(record, 'skipping estimation due to only 2 elements');
                local pos = min + 1;
                if (pos == max) then
                    --table.insert(record, 'total_coll: set '..(max + 1)..' to '..max_index);
                    total_coll[max + 1], inverse_total_coll[max_index] = max_index, max + 1;
                end;
                --table.insert(record, 'total_coll: set '..pos..' to '..next_index);
                --table.insert(record, 'inverse_total_coll: set '..next_index..' to '..pos);
                total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
            else --warn('BAD BOUNDARY 2');
                return nil, debug.fail(nil, 'EBND');
            end;
        else --warn('COLLISION?');
            return nil, debug.fail(nil, 'ECOLLIDX');
        end;
    elseif (max == 0 and self.total == 0) then
        --table.insert(record, 'max is 0 and total is 0');
        self.total = next_index;
        local pos = max + 1;
        total_coll[pos], inverse_total_coll[next_index] = next_index, pos;
    else --warn('DO NOT KNOW', min, max, self.total, pool_coll, inverse_pool_coll, total_coll, inverse_total_coll);
        return nil, debug.fail(nil, 'UNKNOWN');
    end;
    return enums.ErrorCode.OK;
end;

pool.getQueue = function(self)
    return self[1];
end;

pool.getIndexList = function(self)
    return self[3];
end;

pool.getValue = function(self, i)
    local pool_coll = self[1];
    local value = pool_coll[i];
    return value, debug.fail(value, 'EPLVALMISS');
end;

pool.getIndex = function(self, var)
    local inverse_pool_coll = self[2];
    local index = inverse_pool_coll[var];
    return index, debug.fail(index, 'EPLIDXMISS');
end;

pool.canAcceptPos = function(self, i)
    local pool_max = self.max;
    local pool_coll = self[1];
    local linear_limit, n_pool = #pool_coll, self.total;
    if not (linear_limit <= n_pool) then
        return false;
    end;
    if not (pool_max == -1 or i <= pool_max) then
        return false;
    end;
    return true;
end;

pool.canAccept = function(self)
    local pool_max = self.max;
    local pool_coll = self[1];
    local linear_limit, n_pool = #pool_coll, self.total;
    if not (linear_limit <= n_pool) then
        return false;
    end;
    local next_index = ((linear_limit == n_pool and n_pool) or (linear_limit < n_pool and linear_limit)) + 1;
    if not (pool_max == -1 or next_index <= pool_max) then
        return false;
    end;
    return true;
end;

pool.canReject = function(self, var)
    return self[2][var] ~= nil;
end;

pool.reject = function(self, var)
    local n_pool = self.total;
    local pool_coll, inverse_pool_coll, total_coll, inverse_total_coll = self[1], self[2], self[3], self[4];
    local index = inverse_pool_coll[var];
    if (index ~= nil) then
        pool_coll[index], inverse_pool_coll[var] = nil, nil;
        local list_index = inverse_total_coll[index];
        --[[
            Total Coll looks like:
            1  = 5
            2  = 6
            3  = 9
            4  = 15

            Inverse Total Coll looks something like:
            5  = 1
            6  = 2
            9  = 3
            15 = 4

            We have to account for the table.remove shifting, which means the all list indexes above list_index will be shifting down,
            we won't be doing anything with index here except checking if it exists

            Lets say index is "6", this is what will happen:
                - list index of "2" from total coll will be removed using table.remove
                    - anything above list index of "2" like the list index of "3" and "4" will keep their values, but the list indexes will be shifted down by 1, so becoming "2" and "3"
                - "6" will be removed from inverse total coll
                    - "9" and "15" will have their values subtracted by 1
                    - To find "9", "15" and any other values above it.

            Essentially we are removing and shifting all values above that index down by 1
            ! but we're only shifting if the list index is NOT the highest index
        ]]
        local total_n = #total_coll;
        if (list_index ~= total_n) then --not the highest index
            for first_list_index = list_index + 1, total_n do
                local first_index = total_coll[first_list_index];
                inverse_total_coll[first_index] = first_list_index - 1;
            end;
        end;
        inverse_total_coll[index] = nil;
        table_remove(total_coll, list_index);
        if (index == n_pool) then
            local highest_list_index = #total_coll;
            if (highest_list_index > 0) then
                self.total = total_coll[highest_list_index] or 0;
            else self.total = 0;
            end;
        end;
    else return nil, debug.fail(nil, 'EPLIDXMISS');
    end;
    --[[
    local t_index = inverse_pool_coll[var];
    if (t_index ~= nil) then
        pool_coll[t_index], inverse_pool_coll[var] = nil, nil;
        local total_index = inverse_total_coll[t_index];
        --we don't have to worry about total_coll, because table_remove shifts everything down for us

        local len_total_coll, after_point = #total_coll, total_index + 1; --1, 2
        if (after_point <= len_total_coll) then
            --anything above the total index, we will loop through to shift them all down, but we are shifting inverse_total_coll instead to make sure of consistency
            for i = after_point, len_total_coll do
                local total_value = total_coll[i];
                local current_index = inverse_total_coll[total_value];
                if (current_index ~= nil) then
                    inverse_total_coll[total_value] = current_index - 1;
                end;
            end;
        end;
        inverse_total_coll[t_index] = nil;
        table_remove(total_coll, total_index); --this will shift anything above the total_index, this is a problem when trying to loop within runtime
        if (t_index == n_pool) then
            --because the highest value has been removed, we have to update `pool.total` now for the new highest
            local highest_value_index = #total_coll;
            if (highest_value_index > 0) then
                local highest_value = total_coll[highest_value_index]; --total_coll is a theoretically gapless array, we can len for the highest index easily
                self.total = highest_value or 0;
            else self.total = 0;
            end;
        end;
    else
        return nil, debug.fail(nil, 'EPLIDXMISS');
    end;]]
    --[[
    if (self.debug == true) then
        warn('Rejecting', index, pool_coll, inverse_pool_coll, total_coll, inverse_total_coll);
    end;
    self:checkSync('reject');]]
    return enums.ErrorCode.OK;
end;

return pool;