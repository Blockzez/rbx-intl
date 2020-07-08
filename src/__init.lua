--[=[
	Version 2.2.0
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
			return tolocalestring_method(value, checker.negotiatelocale(locale), options);
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
		option.formatRange, option.rangeFallback = private.DateTimeFormat.find_format(option, true);
		option.rangeFallbackPattern = option.data.dateTimeFormats.intervalFormats.intervalFormatFallback;
		option.rangeFallbackPatternToken = checker.tokenizeformat(option.rangeFallbackPattern);
		return private.DateTimeFormat.format(options, false, value);
	elseif type == 'Locale' then
		return modules.DisplayNames.new(locale, options):Format(value);
	elseif type == 'list' then
		return modules.ListFormat.new(locale, options):Format(value);
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
	if type(value) == "userdata" and type(getmetatable(value)) == "table" then
		local tolocaledatestring_method = getmetatable(value).__tolocaledatestring;
		if tolocaledatestring_method ~= nil then
			return tolocaledatestring_method(value, checker.negotiatelocale(locale), options);
		end;
	end;
	
	local option = checker.options('dt/date', locale, options);
	option.format = private.DateTimeFormat.find_format(option, false);
	option.formatRange, option.rangeFallback = private.DateTimeFormat.find_format(option, true);
	option.rangeFallbackPattern = option.data.dateTimeFormats.intervalFormats.intervalFormatFallback;
	option.rangeFallbackPatternToken = checker.tokenizeformat(option.rangeFallbackPattern);
	return private.DateTimeFormat.format(option, false, value);
end;

function modules.toLocaleTimeString(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, locale, options = ...;
	if type(value) == "userdata" and type(getmetatable(value)) == "table" then
		local tolocaletimestring_method = getmetatable(value).__tolocaletimestring;
		if tolocaletimestring_method ~= nil then
			return tolocaletimestring_method(value, checker.negotiatelocale(locale), options);
		end;
	end;
	
	local option = checker.options('dt/time', select(2, ...));
	option.format = private.DateTimeFormat.find_format(option, false);
	option.formatRange, option.rangeFallback = private.DateTimeFormat.find_format(option, true);
	option.rangeFallbackPattern = option.data.dateTimeFormats.intervalFormats.intervalFormatFallback;
	option.rangeFallbackPatternToken = checker.tokenizeformat(option.rangeFallbackPattern);
	return private.DateTimeFormat.format(option, false, (...));
end;

function modules.getCanonicalLocales(...)
	local len = select('#', ...);
	if len == 0 then
		error("missing argument #1", 2);
	end;
	local ret0 = { };
	for i = 1, len do
		local locales = select(i, ...);
		local ret1;
		if type(locales) == "table" then
			ret1 = { };
			for i, v in ipairs(locales) do
				if type(v) == "string" or private.Locale.intl_proxy[v] then
					ret1[i] = tostring(private.Locale.intl_proxy[locales] and locales or modules.Locale.new(locales));
				elseif v ~= nil then
					error("Language ID should be string or Locale", 2);
				end;
			end;
		elseif type(locales) == "string" or private.Locale.intl_proxy[locales] then
			ret1 = tostring(private.Locale.intl_proxy[locales] and locales or modules.Locale.new(locales));
		elseif locales ~= nil then
			error("Invalid argument #" .. i .. "(string, table or Locale expected, got " .. typeof(locales) .. ')', 2);
		end;
		ret0[i] = ret1;
	end;
	return unpack(ret0, 1, len);
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
