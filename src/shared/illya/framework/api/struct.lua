
--[[
	* Copyright (c) 2015-2020 Iryont <https://github.com/iryont/lua-struct>
	*
	* Permission is hereby granted, free of charge, to any person obtaining a copy
	* of this software and associated documentation files (the "Software"), to deal
	* in the Software without restriction, including without limitation the rights
	* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	* copies of the Software, and to permit persons to whom the Software is
	* furnished to do so, subject to the following conditions:
	*
	* The above copyright notice and this permission notice shall be included in
	* all copies or substantial portions of the Software.
	*
	* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	* THE SOFTWARE.

	Optimized by Ari ->
		- Converted some references from global to local
		- Reduced lines by one-line variable initializing
		- Reduced length of if statements by cutting down lines if they are single line statements
		- Subsequent if statements compressed into length of a if else or if elseif statement
		- Adjusted "unpack" variable reference slightly
]]

local math, table, string = math, table, string;
local tonumber, tostring, unpack = tonumber, tostring, unpack or table.unpack or _G.unpack;
local math_floor, math_frexp, math_ldexp = math.floor, math.frexp, math.ldexp;
local table_remove, table_insert, table_concat = table.remove, table.insert, table.concat;
local string_char, string_reverse, string_rep, string_byte = string.char, string.reverse, string.rep, string.byte;

local struct = {};

function struct.pack(format, ...)
	local stream, vars, endianness = {}, {...}, true;
	for i = 1, format:len() do
		local opt = format:sub(i, i);
		if (opt == '<') then
			endianness = true;
		elseif (opt == '>') then
			endianness = false;
		elseif (opt:find('[bBhHiIlL]')) then
			local n, val, bytes = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1, tonumber(table_remove(vars, 1)), {};
			for _ = 1, n do
				table_insert(bytes, string_char(val % (2 ^ 8)));
				val = math_floor(val / (2 ^ 8));
			end;
			if not (endianness) then
				table_insert(stream, string_reverse(table_concat(bytes)));
			else table_insert(stream, table_concat(bytes));
			end;
		elseif (opt:find('[fd]')) then
			local val, sign = tonumber(table_remove(vars, 1)), 0;
			if (val < 0) then
				sign, val = 1, -val;
			end;
			local mantissa, exponent = math_frexp(val);
			if (val == 0) then mantissa, exponent = 0, 0;
			else mantissa, exponent = (mantissa * 2 - 1) * math_ldexp(0.5, (opt == 'd') and 53 or 24), exponent + ((opt == 'd') and 1022 or 126);
			end;
			local bytes = {};
			if (opt == 'd') then
				val = mantissa;
				for _ = 1, 6 do
					table_insert(bytes, string_char(math_floor(val) % (2 ^ 8)));
					val = math_floor(val / (2 ^ 8));
				end;
			else
				table_insert(bytes, string_char(math_floor(mantissa) % (2 ^ 8)));
				val = math_floor(mantissa / (2 ^ 8));
				table_insert(bytes, string_char(math_floor(val) % (2 ^ 8)));
				val = math_floor(val / (2 ^ 8));
			end;
			table_insert(bytes, string_char(math_floor(exponent * ((opt == 'd') and 16 or 128) + val) % (2 ^ 8)));
			val = math_floor((exponent * ((opt == 'd') and 16 or 128) + val) / (2 ^ 8));
			table_insert(bytes, string_char(math_floor(sign * 128 + val) % (2 ^ 8)));
			val = math_floor((sign * 128 + val) / (2 ^ 8));
			if not (endianness) then table_insert(stream, string_reverse(table_concat(bytes)));
			else table_insert(stream, table_concat(bytes));
			end;
    	elseif opt == 's' then
			table_insert(stream, tostring(table_remove(vars, 1)));
			table_insert(stream, string_char(0));
		elseif opt == 'c' then
			local n = format:sub(i + 1):match('%d+');
			local str, len = tostring(table_remove(vars, 1)), tonumber(n);
			if (len <= 0) then
				len = str:len();
			end; if (len - str:len() > 0) then
				str = str..string_rep(' ', len - str:len());
			end;
			table_insert(stream, str:sub(1, len));
			i = i + n:len();
		end;
  	end;
  	return table_concat(stream);
end;

function struct.unpack(format, stream, pos)
	local vars, iterator, endianness = {}, pos or 1, true;
	for i = 1, format:len() do
		local opt = format:sub(i, i);
		if (opt == '<') then
			endianness = true;
		elseif (opt == '>') then
			endianness = false;
		elseif (opt:find('[bBhHiIlL]')) then
			local n, signed, val = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1, opt:lower() == opt, 0;
			for j = 1, n do
				local byte = string_byte(stream:sub(iterator, iterator));
				if (endianness) then val = val + byte * (2 ^ ((j - 1) * 8));
				else val = val + byte * (2 ^ ((n - j) * 8));
				end;
				iterator = iterator + 1;
			end;
			if (signed and val >= 2 ^ (n * 8 - 1)) then
				val = val - 2 ^ (n * 8);
			end;
			table_insert(vars, math_floor(val));
		elseif opt:find('[fd]') then
			local n = (opt == 'd') and 8 or 4;
			local x = stream:sub(iterator, iterator + n - 1);
			iterator = iterator + n;
			if not (endianness) then
				x = string_reverse(x);
			end;
			local sign, mantissa = 1, string_byte(x, (opt == 'd') and 7 or 3) % ((opt == 'd') and 16 or 128);
			for e = n - 2, 1, -1 do
				mantissa = mantissa * (2 ^ 8) + string_byte(x, e);
			end;
			if (string_byte(x, n) > 127) then
				sign = -1;
			end;
			local exponent = (string_byte(x, n) % 128) * ((opt == 'd') and 16 or 2) + math_floor(string_byte(x, n - 1) / ((opt == 'd') and 16 or 128));
			if (exponent == 0) then table_insert(vars, 0.0);
			else
				mantissa = (math_ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign;
				table_insert(vars, math_ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127)));
			end;
		elseif opt == 's' then
			local bytes = {};
			for j = iterator, stream:len() do
				if (stream:sub(j,j) == string_char(0) or  stream:sub(j) == '') then
					break;
				end;
				table_insert(bytes, stream:sub(j, j));
			end;
			local str = table_concat(bytes);
			iterator = iterator + str:len() + 1;
			table_insert(vars, str);
		elseif opt == 'c' then
			local n = format:sub(i + 1):match('%d+');
			local len = tonumber(n);
			if (len <= 0) then
				len = table_remove(vars);
			end;
			table_insert(vars, stream:sub(iterator, iterator + len - 1));
			iterator = iterator + len;
			i = i + n:len();
		end;
	end;
	return unpack(vars);
end;

return struct;