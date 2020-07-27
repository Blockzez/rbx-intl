--[=[
	Version 2.4.0
	This is intended for Roblox ModuleScripts
	BSD 2-Clause Licence
	Copyright ©, 2020 - Blockzez (devforum.roblox.com/u/Blockzez and github.com/Blockzez)
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:
	
	1. Redistributions of source code must retain the above copyright notice, this
	   list of conditions and the following disclaimer.
	
	2. Redistributions in binary form must reproduce the above copyright notice,
	   this list of conditions and the following disclaimer in the documentation
	   and/or other materials provided with the distribution.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
	FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
	DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
	SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
	OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]=]--
local private = { };
local modules = { };

local checker = require(script:WaitForChild("_checker"));
local localedata = require(script:WaitForChild("_localedata"));

local function r(name)
	local module_table = require(script:WaitForChild(name));
	private[name] = module_table._private;
	modules[name] = setmetatable({ }, {
		__index = function(self, index)
			if type(index) == "string" and index:sub(1, 1) == '_' then
				return nil;
			end;
			return module_table[index];
		end,
		__metatable = "The metatable is locked",
		__readonly = function()
			error("Attempt to modify a readonly table", 2);
		end
	});
end;

r("Locale");
r("NumberFormat");
r("PluralRules");
r("RelativeTimeFormat");
r("DisplayNames");
r("DateTimeFormat");
r("ListFormat");
r("Segmenter");

function modules.testFormat(locale)
	return ("%s\n%s\n%s    %s"):format(
		modules.DateTimeFormat.new(locale, { timeStyle = "short" }):Format{year = 1, month = 1, day = 1, hour = 0, min = 34},
		modules.DateTimeFormat.new(locale, { dateStyle = "full" }):Format{year = 2012, month = 3, day = 4},
		modules.NumberFormat.new(locale, { style = "currency", currency = "EUR" }):Format('1234.56'),
		modules.NumberFormat.new(locale):Format('4567.89')
	);
end;

function modules.extendedTestFormat(locale)
	return ('%s\n%s\n%s      %s\n%s\n%s   %s   %s\n%s   %s\n%s      %s   %s\n%s   %s\n%s    %s\n%s   %s'):format(
		modules.DisplayNames.new(locale, { type = "language" }):Of(locale),
		
		modules.ListFormat.new(locale, { type = "conjunction" }):Format { modules.DisplayNames.new(locale, { type = "region" }):Of('CN'),
			modules.DisplayNames.new(locale, { type = "region" }):Of('JP'), modules.DisplayNames.new(locale, { type = "region" }):Of('KR') },
		
		modules.DateTimeFormat.new(locale, { timeStyle = "medium" }):Format{ year = 1, month = 1, day = 1, hour = 13, min = 34, sec = 45 },
		modules.DateTimeFormat.new(locale, { dateStyle = "medium" }):Format{ year = 2012, month = 3, day = 4 },
		
		modules.DateTimeFormat.new(locale, { dateStyle = "full", timeStyle = "medium" }):Format{ year = 1987, month = 6, day = 5, hour = 16, min = 53, sec = 32 },
		
		modules.RelativeTimeFormat.new(locale, { numeric = "auto" }):Format(1, 'year'),
		modules.RelativeTimeFormat.new(locale, { numeric = "auto" }):Format(0, 'year'),
		modules.RelativeTimeFormat.new(locale, { numeric = "auto" }):Format(-1, 'year'),
		
		modules.RelativeTimeFormat.new(locale):Format(5, 'hour'),
		modules.RelativeTimeFormat.new(locale):Format(-5, 'hour'),
		
		modules.NumberFormat.new(locale, { style = "currency", currency = 'EUR' }):Format(1234.56),
		modules.NumberFormat.new(locale, { style = "currency", currency = 'JPY' }):Format(98765),
		
		modules.NumberFormat.new(locale):Format(4567.89),
		modules.NumberFormat.new(locale, { notation = "compact" }):Format(7654321),
		modules.NumberFormat.new(locale, { notation = "compact", minimumSignificantDigits = 3, maximumSignificantDigits = 3 }):Format(23456),
		
		modules.NumberFormat.new(locale, { style = "percent", maximumSignificantDigits = 3 }):Format(2 / 3),
		modules.NumberFormat.new(locale):Format(76543456765876),
		
		modules.NumberFormat.new(locale, { style = 'unit', unit = "inch", unitDisplay = "long" }):Format(1),
		modules.NumberFormat.new(locale, { style = "unit", unit = "inch", unitDisplay = "long", notation = "compact", compactDisplay = "long" }):Format(1234)
	);
end;

local function isdate(v)
	return v.Year or v.year, v;
end;
local function isbigint(v)
	local str = tostring(v);
	return str:match("^[nN][aA][nN]$")
		or str:match("^-?[iI][nN][fF]$") or str:match("^-?[iI][nN][fF][iI][nN][iI][tT][yY]$")
		or (str:find('[eE]') and str:match("^%d*%.?%d*[eE][-+]?%d+$"))
		or str:match("^-?%d+%.?%d*$"),
		str;
end;

local function gettype(v)
	local t = modules.getType(v) or typeof(v);
	if (t == "table" or t == "userdata") then
		local success, value = pcall(isdate, v);
		if success and value then
			return 'date', v;
		end;
		success, value = pcall(isbigint, v);
		if success and value then
			return 'number', value;
		end;
		if (t == "table") then
			return 'list', v;
		end;
	elseif t == "DateTime" then
		t = 'date';
	end;
	return t, v;
end;

function modules.toLocaleString(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	local value, locale, options = ...;
	if type(getmetatable(value)) == "table" then
		local tolocalestring_method = getmetatable(value).__tolocalestring;
		if tolocalestring_method ~= nil then
			local ret = tolocalestring_method(value, checker.negotiatelocale(locale), options);
			if type(ret) == 'number' then
				return modules.toLocaleString(ret);
			elseif type(ret) ~= 'string' then
				error("__tolocalestring must return a string", 2);
			end;
			return ret;
		end;
	end;
	
	local type;
	type, value = gettype(value);
	if type == 'number' then
		local option = checker.options('nu', locale, options);
		option.pluralRule = modules.PluralRules.new(option.locale, { type = "cardinal" });
		return private.NumberFormat.format(option, false, value);
	elseif type == 'date' then
		local option = checker.options('dt/datetime', locale, options);
		option.format = private.DateTimeFormat.find_format(option, false);
		return private.DateTimeFormat.format(option, false, value);
	elseif type == 'list' then
		return (private.NumberFormat.format(checker.options('lf', locale, options), false, value));
	elseif type == 'function' or type == 'thread' or type == "userdata" then
		return '';
	end;
	return tostring(value);
end;

function modules.toLocaleDateString(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, locale, options = ...;
	if type(getmetatable(value)) == "table" then
		local tolocaledatestring_method = getmetatable(value).__tolocaledatestring;
		if tolocaledatestring_method ~= nil then
			local ret = tolocaledatestring_method(value, checker.negotiatelocale(locale), options);
			if type(ret) == "string" then
				return ret;
			end;
			return modules.toLocaleDateString(ret);
		end;
	end;
	
	local option = checker.options('dt/date', locale, options);
	option.format = private.DateTimeFormat.find_format(option, false);
	return private.DateTimeFormat.format(option, false, value);
end;

function modules.toLocaleTimeString(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, locale, options = ...;
	if type(getmetatable(value)) == "table" then
		local tolocaletimestring_method = getmetatable(value).__tolocaletimestring;
		if tolocaletimestring_method ~= nil then
			local ret = tolocaletimestring_method(value, checker.negotiatelocale(locale), options);
			if type(ret) == "string" then
				return ret;
			end;
			return modules.toLocaleTimeString(ret);
		end;
	end;
	
	local option = checker.options('dt/time', locale, options);
	option.format = private.DateTimeFormat.find_format(option, false);
	return private.DateTimeFormat.format(option, false, (...));
end;

--
local function concat_utf8(self)
	for i, v in ipairs(self) do
		self[i] = utf8.char(v);
	end;
	return table.concat(self);
end;

local function code_utf8(self)
	local ret = { };
	for _, c in utf8.codes(self) do
		table.insert(ret, c);
	end;
	return ret;
end;

local casing = localedata.casing;

local function replace(copy, self, old, new, max, i, j)
	old, new = type(old) == "table" and old or { old }, type(new) == "table" and new or { new };
	local ret = copy and table.move(self, 1, #self, 1, table.create(#self)) or self;
	local i0 = i and (i - 1) or 0;
	local count = 0;
	while i0 do
		i0 = table.find(ret, old[1], i0 + 1);
		if i0 then
			if j and (i0 > j) then
				break;
			end;
			local match = true;
			if type(old) == "table" then
				for i1, v in ipairs(old) do
					if ret[i0 + i1 - 1] ~= v then
						match = false;
						break;
					end;
				end;
			end;
			if match then
				local repl_len = math.min(#new, #old);
				for i1 = 0, repl_len - 1 do
					ret[i0 + i1] = new[i1 + 1];
				end;
				local i1 = i0 + repl_len;
				if #old > #new then
					for i2 = 1, (#old - #new) do
						table.remove(ret, i1);
					end;
				elseif #new > #old then
					for i2 = 1, (#new - #old) do
						table.insert(ret, i1 + i2 - 1, new[repl_len + i2]);
					end;
				end;
				count += 1;
				if max and max > 0 and count >= max then
					break;
				end;
			end;
		end;
	end;
	return ret;
end;

local function is_latin(c)
	return c and ((c >= 0x0041 and c <= 0x005A) or (c >= 0x0061 and c <= 0x007A) or (c == 0x00AA) or (c == 0x00BA) or (c >= 0x00C0 and c <= 0x00D6)
		or (c >= 0x00D8 and c <= 0x00F6) or (c >= 0x00F8 and c <= 0x02B8) or (c >= 0x02E0 and c <= 0x02E4) or (c >= 0x1D00 and c <= 0x1D25)
		or (c >= 0x1D2C and c <= 0x1D5C) or (c >= 0x1D62 and c <= 0x1D65) or (c >= 0x1D6B and c <= 0x1D77) or (c >= 0x1D79 and c <= 0x1DBE)
		or (c >= 0x1E00 and c <= 0x1EFF) or (c == 0x2071) or (c == 0x207F) or (c >= 0x2090 and c <= 0x209C) or (c >= 0x212A and c <= 0x212B)
		or (c == 0x2132) or (c == 0x214E) or (c >= 0x2160 and c <= 0x2188) or (c >= 0x2C60 and c <= 0x2C7F) or (c >= 0xA722 and c <= 0xA787)
		or (c >= 0xA78B and c <= 0xA78E) or (c >= 0xA790 and c <= 0xA793) or (c >= 0xA7A0 and c <= 0xA7AA) or (c >= 0xA7F8 and c <= 0xA7FF)
		or (c >= 0xFB00 and c <= 0xFB06) or (c >= 0xFF21 and c <= 0xFF3A) or (c >= 0xFF41 and c <= 0xFF5A));
end;

local function toupper(self)
	for i, v in ipairs(self) do
		self[i] = casing.caseMapping.upper[v] or v;
	end;
	for old_value, new_value in next, casing.specialCasing.upper do
		replace(false, self, old_value, new_value);
	end;
	return concat_utf8(self);
end;

local whitespaces = { 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x0085, 0x00A0, 0x1680, 0x2000, 0x2001,
	0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000 };
local function tolower(self)
	for i, v in ipairs(self) do
		-- Final form of sigma
		if self[i] == 0x03A3 and is_latin(self[i - 1]) and ((not self[i + 1]) or table.find(whitespaces, self[i + 1])) then
			self[i] = 0x03C2;
		else
			self[i] = casing.caseMapping.lower[v] or v;
		end;
	end;
	for old_value, new_value in next, casing.specialCasing.lower do
		replace(false, self, old_value, new_value);
	end;
	return concat_utf8(self);
end

function modules.toLocaleUpper(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, locale = ...;
	if type(value) ~= "string" and type(value) ~= "number" then
		error("invalid argument #1 (string expected, got " .. typeof(value) .. ')');
	end;
	local language = checker.negotiatelocale('casing', locale):Minimize().language;
	local self = code_utf8(value);
	
	-- Lithuanian
	if language == "lt" then
		-- Remove the dot after "i"
		replace(false, self, { 0x0069, 0x0307 }, nil);
	-- Turkish and Azeri
	elseif language == 'tr' or language == "az" then
		-- When uppercasing, i turns into a dotted capital I
		replace(false, self, 0x0069, 0x0130);
	end;
	
	return toupper(self);
end;

function modules.toLocaleLower(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, locale = ...;
	if type(value) ~= "string" and type(value) ~= "number" then
		error("invalid argument #1 (string expected, got " .. typeof(value) .. ')');
	end;
	local language = checker.negotiatelocale('casing', locale):Minimize().language;
	local self = code_utf8(value);
	
	-- Lithuanian
	if language == 'lt' then
		-- Introduce an explicit dot above when lowercasing capital I's and J's whenever there are more accents above.
		for _, v in ipairs{ { 0x0049, 0x0069 }, { 0x004A, 0x006A }, { 0x012E, 0x012F } } do
			local i0 = 0;
			while i0 do
				i0 = table.find(self, v[1], i0 + 1);
				if i0 and casing.moreAbove[self[i0 + 1]] then
					self[i0] = v[2];
					table.insert(self, i0 + 1, 0x0307);
				end;
			end;
		end;
		
		replace(false, self, 0x00CC, { 0x0069, 0x0307, 0x0300 });
		replace(false, self, 0x00CD, { 0x0069, 0x0307, 0x0301 });
		replace(false, self, 0x0128, { 0x0069, 0x0307, 0x0303 });
	-- Turkish and Azeri
	elseif language == 'tr' or language == "az" then
		-- LATIN CAPITAL LETTER I WITH DOT ABOVE
		replace(false, self, 0x0130, 0x0069);
		
		-- When lowercasing, unless an I is before a dot_above, it turns into a dotless i.
		local i0 = 0;
		while i0 do
			i0 = table.find(self, 0x0049, i0 + 1);
			if i0 and (self[i0 + 1] ~= 0x0307) then
				self[i0] = 0x0131;
			end;
		end;
		
		-- Remove dot above with sequence i
		replace(false, self, { 0x0049, 0x0307 }, 0x0049);
	end;
	
	return tolower(self);
end;

--

function modules.getCanonicalLocales(locales)
	if type(locales) == "table" then
		local ret = { };
		for _, v in next, ipairs(locales) do
			if type(v) == "string" or private.Locale.intl_proxy[v] then
				table.insert(ret, tostring(private.Locale.intl_proxy[locales] and locales or modules.Locale.new(locales)));
			elseif v ~= nil then
				error("Language ID should be string or Locale", 2);
			end;
		end;
		return ret;
	elseif type(locales) == "string" or private.Locale.intl_proxy[locales] then
		return { tostring(private.Locale.intl_proxy[locales] and locales or modules.Locale.new(locales)) };
	elseif locales == nil then
		return { };
	end;
	error("Incorrect locale information provided", 2);
end;

function modules.getType(intldata)
	if private.Locale.intl_proxy[intldata] then
		return "Locale";
	elseif private.PluralRules.intl_proxy[intldata] then
		return "PluralRules";
	elseif private.NumberFormat.intl_proxy[intldata] then
		return "NumberFormat";
	elseif private.DisplayNames.intl_proxy[intldata] then
		return "DisplayNames";
	elseif private.DateTimeFormat.intl_proxy[intldata] then
		return "DateTimeFormat";
	elseif private.RelativeTimeFormat.intl_proxy[intldata] then
		return "RelativeTimeFormat";
	elseif private.ListFormat.intl_proxy[intldata] then
		return "ListFormat";
	elseif private.Segmenter.intl_proxy[intldata] then
		return "Segmenter";
	end;
	return nil;
end;

return setmetatable({ }, {
	__index = modules,
	__metatable = "The metatable is locked",
	__readonly = function()
		error("Attempt to modify a readonly table", 2);
	end
});
