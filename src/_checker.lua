local Locale = require(script.Parent:WaitForChild("Locale"));
local localedata = require(script.Parent:WaitForChild("_localedata"));
local c = { };

c.emptyreference = { };

c.lockmsg = "The metatable is locked";

function c.initalize_class_methods(proxy)
	return setmetatable({ }, {
		__newindex = function(self, index, func)
			rawset(self, index, function(value, ...)
				if not proxy[value] then
					error("Expected ':' not '.' calling member function " .. index, 2);
				end;
				return func(proxy[value], ...);
			end);
		end
	});
end;

function c.readonly(self, index, value)
	if type(index) ~= "string" and type(index) ~= "number" then
		error(typeof(index) .. " cannot be assigned to", 2);
	end;
	error(index .. " cannot be assigned to", 2);
end;

c.weaktable = { __mode = 'k' };
local address_name = setmetatable({ }, c.weaktable);
local function mt_tostring(self)
	return address_name[self];
end;
function c.tostring(name, self)
	address_name[self] = name .. ': ' .. tostring(self):sub(11);
	return mt_tostring;
end;

local valid_value_property =
{
	["%display0"] = { "full", "long", "medium", "short" },
	["%display1"] = { "long", "short", "narrow" },
	["%display2"] = { "long", "short" },
	
	["%numeric2digit"] = { "numeric", "2-digit" },
	
	["g/localeMatcher"] = { "lookup", "best fit" },
	-- Thankfully none of these are algorithmic
	["g/numberingSystem"] = { "arab", "arabext", "bali", "beng", "deva", "fullwide", "gujr", "guru", "hanidec", "khmr", "knda", "laoo", "latn", "limb", "mlym", "mong", "mymr", "orya", "tamldec", "telu", "thai", "tibt" },
	["g/calendar"] = { "buddhist", "chinese", "coptic", "ethiopia", "ethiopic", "gregory", "hebrew", "indian", "islamic", "iso8601", "japanese", "persian", "roc" },
	["g/hourCycle"] = { "h11", "h12", "h23", "h24" },
	
	["dn/style"] = "%display1",
	["dn/type"] = { "language", "region", "script", "variant", "currency" },
	['dn/fallback'] = { "code", "none" },
	
	["nu/compactDisplay"] = "%display2",
	["nu/currencyDisplay"] = { "symbol", "narrowSymbol", "code", "name" },
	["nu/currencySign"] = { "standard", "accounting" },
	["nu/notation"] = { "standard", "compact", "scientific", "engineering" },
	["nu/signDisplay"] = { "auto", "never", "always", "exceptZero" },
	["nu/style"] = { "decimal", "currency", "percent", "unit" },
	["nu/unitDisplay"] = "%display1",
	["nu/useGrouping"] = "f/bool",
	["nu/minimumIntegerDigits"] = "f/1..",
	["nu/maximumIntegerDigits"] = "f/minimumIntegerDigits..",
	["nu/minimumFractionDigits"] = "f/0..",
	["nu/maximumFractionDigits"] = "f/minimumFractionDigits..",
	["nu/minimumSignificantDigits"] = "f/1..",
	["nu/maximumSignificantDigits"] = "f/minimumSignificantDigits..",
	["nu/currency"] = "lp/^%a%a%a$",
	["nu/unit"] = "f/str",
	["nu/midpointRounding"] = { 'toEven', 'awayFromZero', 'toZero', 'toNegativeInfinity', 'toPositiveInfinity' },
	
	["pr/type"] = { 'cardinal', 'ordinal' },
	
	["dt/dateStyle"] = "%display0",
	["dt/timeStyle"] = "%display0",
	["dt/dayPeriod"] = "%display1",
	["dt/hour12"] = "f/bool",
	["dt/weekday"] = "%display1",
	["dt/era"] = "%display1",
	["dt/year"] = "%numeric2digit",
	["dt/month"] = { "numeric", "2-digit", "long", "short", "narrow" },
	["dt/day"] = "%numeric2digit",
	["dt/hour"] = "%numeric2digit",
	["dt/minute"] = "%numeric2digit",
	["dt/second"] = "%numeric2digit",
	
	["rt/numeric"] = { "always", "auto" },
	["rt/style"] = "%display1",
	
	["lf/type"] = { "conjunction", "disjunction", "unit" },
	["lf/style"] = "%display1",
};
local function check_property(tbl_out, tbl_to_check, property, default)
	local check_values = valid_value_property[property];
	if type(check_values) == "string" then
		check_values = valid_value_property[check_values] or check_values;
	end;
	
	property = property:match("%a+/(%w+)");
	local value = rawget(tbl_to_check, property);
	local valid = false;
	if type(check_values) == "table" then
		valid = table.find(check_values, value);
	elseif check_values == 'f/bool' then
		valid = (type(value) == "boolean");
	elseif check_values == 'f/str' then
		valid = (type(value) == "string");
	elseif not check_values then
		valid = true;
	elseif check_values:match('^lp/') then
		valid = (type(value) == "string") and (value:match(check_values:match("lp/(.+)")));
	elseif type(value) == "number" and (value == value) and (value % 1 == 0) then
		local min, max = check_values:match("f/(%w*)%.%.(%w*)");
		valid = (value >= (tbl_out[min] or tonumber(min) or 0)) and (max == '' or (value <= tonumber(max)));
	end;
	if valid then
		tbl_out[property] = value;
		return;
	elseif value == nil then
		if type(default) == "string" and (default:sub(1, 7) == 'error: ') then
			error(default:sub(8), 4);
		end;
		tbl_out[property] = default;
		return;
	end;
	error(property .. " value is out of range.", 4);
end;

local unit_types = { '', 'acceleration', 'angle', 'area', 'concentr', 'consumption', 'digital', 'duration', 'electric', 'energy', 'force', 'frequency', 'graphics', 'length', 'light', 'mass', 'power', 'pressure', 'speed', 'temperature', 'torque', 'volume' };

local day_period_rule = localedata.coredata.dayPeriodRuleSet;
local time_data = localedata.coredata.timeData;

function c.negotiatelocale(locales)
	-- Negotiate locales
	local data;
	if type(locales) == "table" then
		locales = table.move(locales, 1, #locales, 1, table.create(#locales));
		table.insert(locales, Locale.RobloxLocale);
		table.insert(locales, Locale.SystemLocale);
		table.insert(locales, 'en-Latn-US');
	elseif (type(locales) == "string" or Locale._private.intl_proxy[locales]) then
		locales = { locales, Locale.RobloxLocale, Locale.SystemLocale, 'en-Latn-US' };
	elseif locales == nil then
		locales = { Locale.RobloxLocale, Locale.SystemLocale, 'en-Latn-US' };
	else
		error("Incorrect locale information provided", 3);
	end;
	for _, locale in ipairs(locales) do
		if type(locale) ~= "string" and (not Locale._private.intl_proxy[locale]) and locale ~= nil then
			error("Incorrect locale information provided", 3);
		end;
		locale = Locale._private.intl_proxy[locale] and locale or Locale.new(locale);
		data = localedata.getdata(localedata.minimizestr(localedata.getlocalename(locale)));
		if data then
			locales = locale;
			break;
		end;
	end;
	if not data then
		return 'root', localedata.getdata('root');
	end;
	return locales, data;
end;

local calendar_alias = { gregory = "gregorian", japanese = "japanese", buddhist = "buddhist", roc = "roc", islamic = "islamic" };
function c.options(ttype, locales, options)
	local ret = { };
	if type(options) ~= "table" then
		options = c.emptyreference;
	end;
	local locale, data = c.negotiatelocale(locales);
	ret.locale = locale;
	local t, v = ttype:match("(%w+)/?(%w*)");
	if v == '' then
		v = nil;
	end;
	if t == "nu" or t == "dt" or t == "rt" then
		print()
		check_property(ret, options, 'g/numberingSystem', valid_value_property["g/numberingSystem"][table.find(valid_value_property["g/numberingSystem"], locale.numberingSystem)] or data.numbers.defaultNumberingSystem);
		if t ~= "dt" then
			ret.numberOptions = t == "nu" and ret or { style = "decimal" };
			check_property(ret.numberOptions, options, 'nu/useGrouping', true);
			check_property(ret.numberOptions, options, 'nu/signDisplay', 'auto');
			check_property(ret.numberOptions, options, 'nu/compactDisplay', 'short');
			check_property(ret.numberOptions, options, 'nu/notation', 'standard');
			if ret.numberOptions == ret then
				ret.numberOptions = nil;
			end;
		end;
	end;
	if t == "dn" then
		check_property(ret, options, 'dn/style', 'long');
		check_property(ret, options, 'dn/type', 'language');
		check_property(ret, options, 'dn/fallback', 'code');
		ret.data = (ret.type == "language") and data.localeDisplayNames
			or (ret.type == "region") and data.localeDisplayNames.territories
			or (ret.type == "script") and data.localeDisplayNames.scripts
			or (ret.type == "variant") and data.localeDisplayNames.variants
			or (ret.type == "currency") and data.numbers.currencies;
		ret.pattern = data.localeDisplayNames.localeDisplayPattern;
	elseif t == "nu" then
		check_property(ret, options, 'nu/style', 'decimal');
		
		if ret.style == "currency" then
			check_property(ret, options, 'nu/currency', 'error: Currency code is required with currency style.');
			check_property(ret, options, 'nu/currencyDisplay', 'symbol');
			check_property(ret, options, 'nu/currencySign', 'standard');
		elseif ret.style == "unit" then
			check_property(ret, options, 'nu/unit', 'error: The unit is required with unit style');
			check_property(ret, options, 'nu/unitDisplay', 'long');
		end;
		
		local numbers = data.numbers;
		ret.symbols = c.negotiate_numbering_system(numbers, 'symbols-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn');
		ret.minimumGroupingDigits = (ret.notation == "compact" and math.max(numbers.minimumGroupingDigits, 2) or numbers.minimumGroupingDigits);
		
		local decimalPattern = c.negotiate_numbering_system(numbers, ((ret.style == "percent" and ret.notation ~= "compact") and 'percent' or 'decimal') .. 'Formats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn');
		if ret.style == "currency" and (ret.currencyDisplay == "symbol" or ret.currencyDisplay == "narrowSymbol") then
			if ret.notation == "compact" then
				ret.standardPattern = decimalPattern.standard;
			end;
			local currencyFormat = c.negotiate_numbering_system(numbers, 'currencyFormats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn');
			ret[ret.notation == "compact" and 'standardNPattern' or 'standardPattern'] = currencyFormat[ret.currencySign] or currencyFormat.standard;
			ret.currencyData = numbers.currencies and numbers.currencies[ret.currency];
		else
			ret.standardPattern = decimalPattern.standard;
		end;
		if ret.style == "unit" or (ret.style == "currency" and ret.currencyDisplay ~= "symbol" and ret.currencyDisplay ~= "narrowSymbol") then
			if ret.style == "unit" then
				for _, unit_type in ipairs(unit_types) do
					ret.unitPattern = data.units[ret.unitDisplay][unit_type .. (unit_type == '' and '' or '-') .. ret.unit];
					if ret.unitPattern then
						break;
					end;
				end;
				if not ret.unitPattern then
					error("Invalid unit argument for this locale '" .. ret.unit .. "'", 3);
				end;
			else
				ret.standardNPattern = c.negotiate_numbering_system(numbers, 'currencyFormats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn').standard;
				ret.unitPattern = c.negotiate_numbering_system(numbers, 'currencyFormats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn');
				ret.currencyData = numbers.currencies and numbers.currencies[ret.currency];
			end;
		elseif ret.style == "percent" and ret.notation == "compact" then
			ret.standardNPattern = c.negotiate_numbering_system(numbers, 'percentFormats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn').standard;
		end;
		if ret.notation == "compact" then
			if ret.style == "currency" and (ret.currencyDisplay == "symbol" or ret.currencyDisplay == "narrowSymbol") then
				ret.compactPattern = c.negotiate_numbering_system_index('short', numbers, 'currencyFormats-numberSystem-', '', ret.numberingSystem, numbers.defaultNumberingSystem, 'latn').standard;
			else
				ret.compactPattern = decimalPattern[ret.compactDisplay].decimalFormat;
			end;
		end;
	elseif t == "pr" then
		check_property(ret, options, 'pr/type', 'cardinal');
	elseif t == "dt" then
		local calpref = localedata.coredata.calendarPreferenceData;
		local region = (select(3, localedata.rawmaximize(locale)));
		check_property(ret, options, 'g/calendar', valid_value_property["g/calendar"][table.find(valid_value_property["g/calendar"], locale.calendar)] or (calpref[region] or calpref['001']):gsub(' .*$', ''));
		ret.data = data.dates.calendars[calendar_alias[ret.calendar]] or data.dates.calendars.gregorian;
		check_property(ret, options, 'g/hourCycle', valid_value_property["g/hourCycle"][table.find(valid_value_property["g/hourCycle"], locale.hourCycle)]);
		ret.currentHourCycle = ret.hourCycle or (time_data[region] and time_data[region]._preferred) or 'H';
		
		check_property(ret, options, 'dt/dateStyle');
		check_property(ret, options, 'dt/timeStyle');
		check_property(ret, options, 'dt/dayPeriod');
		check_property(ret, options, 'dt/hour12');
		check_property(ret, options, 'dt/weekday');
		check_property(ret, options, 'dt/era');
		check_property(ret, options, 'dt/year');
		check_property(ret, options, 'dt/month');
		check_property(ret, options, 'dt/day');
		check_property(ret, options, 'dt/hour');
		check_property(ret, options, 'dt/minute');
		check_property(ret, options, 'dt/second');
		
		local pos = localedata.getlocalename(locale);
		local rule;
		while pos and not rule do
			if not rule then
				rule = day_period_rule[pos];
			end;
			pos = localedata.negotiateparent(pos);
		end;
		ret.dayPeriodRule = rule;
		if v == "time" and not (ret.era or ret.year or ret.month or ret.day or ret.weekday or ret.dateStyle) then
			ret.dateStyle = 'medium';
		elseif v == "time" and not (ret.hour or ret.minute or ret.second or ret.timeStyle) then
			ret.timeStyle = 'medium';
		end;
	elseif t == "rt" then
		check_property(ret, options, 'rt/numeric', 'always');
		check_property(ret, options, 'rt/style', 'long');
		ret.fields = data.dates.fields;
	elseif t == "lf" then
		check_property(ret, options, 'lf/type', 'conjunction');
		check_property(ret, options, 'lf/style', 'long');
		ret.numberOptions = options.numberOptions;
		ret.dateOptions = options.dateOptions;
		local p = data.listPatterns["listPattern-type-" .. (ret.type:gsub('disjunction', 'or'):gsub('conjunction', 'standard'))
			.. (ret.style == "long" and '' or ('-' .. ret.style))];
		ret.pattern = p;
		ret.t, ret.s, ret.m, ret.e = c.tokenizeformat(p['2']), c.tokenizeformat(p['start']), c.tokenizeformat(p['middle']), c.tokenizeformat(p['end'])
	end;
	if t == "nu" or t == "pr" or t == "rt" then
		check_property(ret, options, 'nu/midpointRounding', (ret.notation == "compact") and 'toNegativeInfinity' or 'toEven');
		ret.isSignificant = not not (rawget(options, 'minimumSignificantDigits') or rawget(options, 'maximumSignificantDigits'));
		if ret.isSignificant then
			check_property(ret, options, 'nu/minimumSignificantDigits', 1);
			check_property(ret, options, 'nu/maximumSignificantDigits');
		else
			check_property(ret, options, 'nu/minimumIntegerDigits', 1);
			check_property(ret, options, 'nu/maximumIntegerDigits');
			check_property(ret, options, 'nu/minimumFractionDigits');
			check_property(ret, options, 'nu/maximumFractionDigits');
			
			if not (ret.minimumFractionDigits or ret.maximumFractionDigits) then
				if (ret.currency and ret.notation ~= "compact") then
					local currencyDataFractions = localedata.coredata.currencyData.fractions;
					local digits = (currencyDataFractions[ret.currency] and currencyDataFractions[ret.currency]._digits) or 2;
					ret.minimumFractionDigits = digits;
					ret.maximumFractionDigits = digits;
				elseif ret.style == "percent" then
					ret.minimumFractionDigits = 0;
					ret.maximumFractionDigits = 0;
				elseif ret.notation ~= "compact" then
					ret.minimumFractionDigits = 0;
					ret.maximumFractionDigits = 3;
				end;
			end;
		end;
	end;
	return ret;
end;

-- Parts
local part_mt =
{
	__concat = function(self, other)
		if other.type then
			if other.value and other.value ~= '' then
				table.insert(self, other);
			end;
		elseif self.type then
			if self.value and self.value ~= '' then
				table.insert(other, 1, self);
			end;
			return other;
		else
			for _, v in ipairs(other) do
				table.insert(self, v);
			end;
		end;
		return self;
	end;
};
function c.initializepart(t)
	if getmetatable(t) == part_mt then
		return t;
	end;
	return setmetatable(t and (t.type and { t } or t) or { }, part_mt);
end;
function c.addpart(self, ttype, value, source)
	return (type(self) == "string" and self or c.initializepart(self)) .. (type(self) == "string" and value or { type = ttype, value = value, source = source });
end;
function c.addtofirstpart(ttype, value, self)
	return (type(self) == "string" and value or { type = ttype, value = value }) .. (type(self) == "string" and self or c.initializepart(self));
end;

-- I have yet to find a locale that uses '{' or '}' for list
-- If that's somewhere in the Unicode CLDR List Pattern, please let me know :)
function c.tokenizeformat(value)
	local i0 = 1;
	local ret = { };
	while i0 do
		local i1, i2 = value:find("{[01]}", i0);
		if i1 then
			if value:sub(i0, i1 - 1) ~= '' then
				table.insert(ret, value:sub(i0, i1 - 1));
			end;
			table.insert(ret, tonumber(value:sub(i1 + 1, i2 - 1)));
			i0 = i2 + 1;
		else
			if value:sub(i0) ~= '' then
				table.insert(ret, value:sub(i0));
			end;
			i0 = nil;
		end;
	end;
	return ret;
end;

function c.insertformat(value, ...)
	local args = { [0] = (...), select(2, ...) };
	local i0 = 1;
	local ret = { };
	while i0 do
		local i1, i2 = value:find("{[01]}", i0);
		if i1 then
			if value:sub(i0, i1 - 1) ~= '' then
				if type(ret[#ret]) == "string" and type(value:sub(i0, i1 - 1)) == "string" then
					ret[#ret] = ret[#ret] .. value:sub(i0, i1 - 1);
				else
					table.insert(ret, value:sub(i0, i1 - 1));
				end;
			end;
			for _, v in ipairs(args[tonumber(value:sub(i1 + 1, i2 - 1))]) do
				if type(ret[#ret]) == "string" and type(v) == "string" then
					ret[#ret] = ret[#ret] .. v;
				else
					table.insert(ret, v);
				end;
			end;
			i0 = i2 + 1;
		else
			if value:sub(i0) ~= '' then
				if type(ret[#ret]) == "string" and type(value:sub(i0)) == "string" then
					ret[#ret] = ret[#ret] .. value:sub(i0);
				else
					table.insert(ret, value:sub(i0));
				end;
			end;
			i0 = nil;
		end;
	end;
	return ret;
end;

function c.formattoparts(type, start, value, source, ...)
	local args = { [0] = (...), select(2, ...) };
	local i0 = 1;
	local ret = start;
	while i0 do
		local i1, i2 = value:find("{[01]}", i0);
		if i1 then
			if value:sub(i0, i1 - 1) ~= '' then
				if type then
					local prefix, value, suffix = c.spacestoparts(c.fixspace(value:sub(i0, i1 - 1)));
					ret = c.addpart(ret, "literal", prefix);
					ret = c.addpart(ret, type, value);
					ret = c.addpart(ret, "literal", suffix);
				else
					ret = ret .. { type = "literal", value = value:sub(i0, i1 - 1), source = source };
				end;
			end;
			ret = ret .. args[tonumber(value:sub(i1 + 1, i2 - 1))];
			i0 = i2 + 1;
		else
			if value:sub(i0) ~= '' then
				if type then
					local prefix, value, suffix = c.spacestoparts(c.fixspace(value:sub(i0)));
					ret = c.addpart(ret, "literal", prefix);
					ret = c.addpart(ret, type, value);
					ret = c.addpart(ret, "literal", suffix);
				else
					ret = ret .. { type = "literal", value = value:sub(i0), source = source };
				end;
			end;
			i0 = nil;
		end;
	end;
	return ret;
end;

-- Global functions
-- Lua doesn't recognise \xa0 as spaces.
local spaces = { utf8.char(0x0020), utf8.char(0x00A0), utf8.char(0x1680), utf8.char(0x180E), utf8.char(0x2000), utf8.char(0x2001), utf8.char(0x2002), utf8.char(0x2003), 
	utf8.char(0x2004), utf8.char(0x2005), utf8.char(0x2006), utf8.char(0x2007), utf8.char(0x2008), utf8.char(0x2009), utf8.char(0x200A), utf8.char(0x200B), utf8.char(0x202F), utf8.char(0x205F), utf8.char(0x3000), utf8.char(0xFEFF) };

function c.tospace(value)
	for _, v in ipairs(spaces) do
		value = value:gsub(v, ' ');
	end;
	return value;
end;
function c.spacestoparts(value)
	local left, right;
	for _, v in ipairs(spaces) do
		if value:sub(1, #v) == v then
			left, value = v, value:sub(#v + 1);
		end;
		if value:sub(-#v) == v then
			value, right = value:sub(1, -(#v + 1)), v;
		end;
	end;
	return left, value, right;
end;

--

function c.negotiate_plural_table(tbl, prefix, suffix, plural_rule, value)
	return tbl[prefix .. plural_rule:Select(value) .. suffix] or tbl[prefix .. 'other' .. suffix];
end;

function c.negotiate_numbering_system(tbl, prefix, suffix, ...)
	local args = { ... };
	for _, v in next, args do
		if v then
			local value = tbl[prefix .. v .. suffix];
			if value then
				return value;
			end;
		end;
	end;
	return nil;
end;

function c.negotiate_numbering_system_index(index, tbl, prefix, suffix, ...)
	local args = { ... };
	for _,v in next, args do
		if v then
			local value = tbl[prefix .. v .. suffix];
			if value and value[index] then
				return value[index];
			end;
		end;
	end;
	return nil;
end;

function c.literalize(str)
	return (str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"));
end;

function c.literalgsub(str, pattern, repl)
	return string.gsub(str, c.literalize(pattern), repl);
end;

local substitute_chars = { };
for ns, tbl in next, localedata.coredata.numberingSystems do
	if ns ~= "latn" then
		substitute_chars[ns] = function(d)
			return tbl._digits[tonumber(d) + 1];
		end;
	end;
end;
function c.substitute(str, nu)
	if substitute_chars[nu] then
		return (str:gsub('%d', substitute_chars[nu]));
	end;
	return str;
end;

local function quantize(val, exp, rounding)
	local negt, post = val:match("(-?)([%d.]*)");
	post = '0' .. post;
	local d, e = post:gsub('%.', ''), (post:find('%.') or (#post + 1));
	local pos = e + exp;
	if pos > #d then
		return negt .. post:sub(2);
	end;
	d = d:split('');
	local add = rounding == 'toPositiveInfinity';
	if rounding ~= "toPositiveInfinity" and rounding ~= "toNegativeInfinity" then
		add = d[pos]:match(((rounding == "toEven" and (d[pos - 1] or '0'):match('[02468]')) or rounding == "toFromZero") and '[6-9]' or '[5-9]');
	end;
	for p = pos, #d do
		d[p] = 0
	end;
	if add then
		repeat
			if d[pos] == 10 then
				d[pos] = 0;
			end;
			pos = pos - 1;
			d[pos] = tonumber(d[pos]) + 1;
		until d[pos] ~= 10;
	end;
	local int, dec, frac = (table.concat(d, '', 1, e - 1) .. '.' .. table.concat(d, '', e)):match("(%d*)([.]?)(%d*)");
	return negt .. (int:gsub('^0+', '') .. dec .. frac:gsub('0+$', '')):gsub('[.]$', '');
end;
local function scale(val, exp)
	val = ('0'):rep(-exp) .. val .. ('0'):rep(exp);
	local unscaled = (val:gsub("[.,]", ''));
	local len = #val;
	local dpos = (val:find("[.,]") or (len + 1)) + exp;
	return unscaled:sub(1, dpos - 1) .. '.' .. unscaled:sub(dpos);
end;
function c.raw_format(val, minintg, maxintg, minfrac, maxfrac, rounding)
	local intg, frac = ((maxfrac and maxfrac ~= math.huge and quantize(val, maxfrac, rounding)) or val):match("(%d*)%.?(%d*)");
	intg = intg:gsub('^0+', '');
	frac = frac:gsub('0+$', '');
	local intglen = #intg;
	local fraclen = #frac;
	if minintg and (intglen < minintg) then
		intg = ('0'):rep(minintg - intglen) .. intg;
	end;
	if minfrac and (fraclen < minfrac) then
		frac = frac .. ('0'):rep(minfrac - fraclen);
	end;
	if maxintg and (intglen > maxintg) then
		intg = intg:sub(-maxintg);
	end;
	return intg .. '.' .. frac;
end;
function c.raw_format_sig(val, min, max, rounding)
	if max and max ~= math.huge then
		val = quantize(val, max - ((val:find('%.') or (#val + 1)) - 1), rounding);
	end;
	local intg, frac = val:match("(%d*)%.?(%d*)");
	intg = intg:gsub('^0+', '');
	frac = frac:gsub('0+$', '');
	if min then
		min = math.max(min - #val:gsub('%.%d*$', ''), 0);
		if #frac < min then
			frac = frac .. ('0'):rep(min - #frac);
		end;
	end;
	return intg .. '.' .. frac;
end;
function c.parse_exp(val)
	local val, exp = val:match('(%d*[.,]?%d*)[eE]([-+]?%d+)');
	if val then
		exp = tonumber(exp);
		if not exp then
			return nil;
		end;
		if val == '' then
			return nil;
		end;
		val = scale(val, exp);
	end;
	return val;
end;

return c;
