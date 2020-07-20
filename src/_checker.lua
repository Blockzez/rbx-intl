local Locale = require(script.Parent:WaitForChild("Locale"));
local localedata = require(script.Parent:WaitForChild("_localedata"));
local c = { };

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
	["g/suppression"] = { "none", "standard" },
	
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
	["nu/useGrouping"] = { "min2", "auto", "always", "never" },
	["nu/minimumIntegerDigits"] = "f/1..",
	["nu/maximumIntegerDigits"] = "f/minimumIntegerDigits..inf",
	["nu/minimumFractionDigits"] = "f/0..",
	["nu/maximumFractionDigits"] = "f/minimumFractionDigits..inf",
	["nu/minimumSignificantDigits"] = "f/1..",
	["nu/maximumSignificantDigits"] = "f/minimumSignificantDigits..inf",
	["nu/currency"] = "lp/^%a%a%a$",
	["nu/unit"] = "f/str",
	["nu/rounding"] = { "halfUp", "halfEven", "halfDown", "ceiling", "floor" },
	
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
	
	["sg/granularity"] = { "grapheme", "word", "sentence" }
};
local function check_property(tbl_out, tbl_to_check, property, default)
	local check_values = valid_value_property[property];
	if type(check_values) == "string" then
		check_values = valid_value_property[check_values] or check_values;
	end;
	
	property = property:match("^%a+/(%w+)$");
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
		valid = (type(value) == "string") and (value:match(check_values:match("^lp/(.+)$")));
	elseif type(value) == "number" and (value % 1 == 0) or (value == math.huge) then
		local min, max = check_values:match("^f/(%w*)%.%.(%w*)$");
		valid = (value >= (tbl_out[min] or tonumber(min) or 0)) and ((max == '' and value ~= math.huge) or (value <= tonumber(max)));
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

local day_period_rule = localedata.supplemental.dayPeriodRuleSet;
local time_data = localedata.supplemental.timeData;

function c.negotiatelocale(ttype, locales)
	-- Negotiate locales
	local data;
	if type(locales) == "table" then
		locales = table.move(locales, 1, #locales, 1, table.create(#locales));
		table.insert(locales, Locale.GetLocale());
		table.insert(locales, Locale.RobloxLocale);
		table.insert(locales, Locale.SystemLocale);
		table.insert(locales, 'en-Latn-US');
	elseif (type(locales) == "string" or Locale._private.intl_proxy[locales]) then
		locales = { locales, Locale.GetLocale(), Locale.RobloxLocale, Locale.SystemLocale, 'en-Latn-US' };
	elseif locales == nil then
		locales = { Locale.GetLocale(), Locale.RobloxLocale, Locale.SystemLocale, 'en-Latn-US' };
	else
		error("Incorrect locale information provided", 3);
	end;
	for _, locale in next, locales do
		if type(locale) ~= "string" and (not Locale._private.intl_proxy[locale]) and locale ~= nil then
			error("Language ID should be string or Locale", 3);
		end;
		locale = Locale._private.intl_proxy[locale] and locale or Locale.new(locale);
		if localedata.exists(ttype, locale) then
			data = localedata.getdata(ttype, locale);
			locales = locale;
			break;
		end;
	end;
	if not data then
		return 'root', localedata.getdata(ttype, 'root');
	end;
	return locales, data;
end;

function c.supportedlocale(ttype, locales)
	if type(locales) == "table" then
		local ret = { };
		for _, locale in next, locales do
			if type(locale) ~= "string" and (not Locale._private.intl_proxy[locale]) and locale ~= nil then
				error("Language ID should be string or Locale", 3);
			end;
			locale = Locale._private.intl_proxy[locale] and locale or Locale.new(locale);
			if localedata.exists('main', locale) then
				table.insert(ret, tostring(locale));
			end;
		end;
		return ret;
	elseif type(locales) == "string" or Locale._private.intl_proxy[locales] then
		return { localedata.exists('main', Locale._private.intl_proxy[locales] and locales or Locale.new(locales)) and tostring(locales) or nil };
	elseif locales == nil then
		return { };
	end;
	error("Incorrect locale information provided", 3);
end;

local calendar_alias = { gregory = "gregorian", japanese = "japanese", buddhist = "buddhist", roc = "roc", islamic = "islamic" };
local granularity_alias = { grapheme = "GraphemeClusterBreak", word = "WordBreak", sentence = "SentenceBreak" };

local function rules_lt(v0, v1)
	local v0_0, v0_1 = v0[1]:match("^(%d+)%.?(%d*)$");
	local v1_0, v1_1 = v1[1]:match("^(%d+)%.?(%d*)$");
	v0_0, v1_0 = tonumber(v0_0), tonumber(v1_0);
	if v0_0 ~= v1_0 then
		return v0_0 < v1_0;
	end;
	return (tonumber(v0_1) or 0) < (tonumber(v1_1) or 0);
end;

local function suppression_gt(s0, s1)
	return #s0 > #s1;
end;

function c.options(ttype, locales, options)
	local ret = { };
	if type(options) ~= "table" then
		options = { };
	end;
	local locale, data = c.negotiatelocale(ttype == "sg" and "segments" or 'main', locales);
	ret.locale = locale;
	local t, v = ttype:match("(%w+)/?(%w*)");
	if v == '' then
		v = nil;
	end;
	if t == "nu" or t == "dt" or t == "rt" then
		check_property(ret, options, 'g/numberingSystem', valid_value_property["g/numberingSystem"][table.find(valid_value_property["g/numberingSystem"], locale.numberingSystem)] or data.numbers.defaultNumberingSystem);
		if t ~= "dt" then
			ret.numberOptions = t == "nu" and ret or { style = "decimal" };
			check_property(ret.numberOptions, options, 'nu/signDisplay', 'auto');
			check_property(ret.numberOptions, options, 'nu/compactDisplay', 'short');
			check_property(ret.numberOptions, options, 'nu/notation', 'standard');
			
			check_property(ret.numberOptions, options, 'nu/useGrouping', (ret.notation == "compact") and "min2" or "auto");
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
			check_property(ret, options, 'nu/currency', 'error: Currency code is required with currency style');
			check_property(ret, options, 'nu/currencyDisplay', 'symbol');
			check_property(ret, options, 'nu/currencySign', 'standard');
			ret.currency = ret.currency:upper();
		elseif ret.style == "unit" then
			check_property(ret, options, 'nu/unit', 'error: The unit is required with unit style');
			check_property(ret, options, 'nu/unitDisplay', 'short');
		end;
		
		local numbers = data.numbers;
		ret.symbols = c.negotiate_numbering_system(numbers.symbols, ret.numberingSystem, numbers.defaultNumberingSystem);
		ret.minimumGroupingDigits = (ret.useGrouping == "min2" and 2) or (ret.useGrouping == "always" and 1) or (ret.useGrouping == "never" and 0) or numbers.minimumGroupingDigits;
		
		local decimalPattern = c.negotiate_numbering_system(numbers.formats[(ret.style == "percent" and ret.notation ~= "compact") and 'percent' or 'decimal'], ret.numberingSystem, numbers.defaultNumberingSystem);
		if ret.style == "currency" and (ret.currencyDisplay ~= "name") then
			if ret.notation == "compact" then
				ret.standardPattern = decimalPattern.standard;
			end;
			local currencyFormat = c.negotiate_numbering_system(numbers.formats.currency, ret.numberingSystem, numbers.defaultNumberingSystem);
			ret[ret.notation == "compact" and 'standardNPattern' or 'standardPattern'] = currencyFormat[ret.currencySign] or currencyFormat.standard;
			ret.currencyData = numbers.currencies and numbers.currencies[ret.currency];
			ret.currencySpacing = currencyFormat.currencySpacing;
		else
			ret.standardPattern = decimalPattern.standard;
		end;
		if ret.style == "unit" or (ret.style == "currency" and ret.currencyDisplay == "name") then
			if ret.style == "unit" then
				local availableUnits = data.units[ret.unitDisplay];
				ret.unitPattern = availableUnits[ret.unit];
				if not ret.unitPattern then
					local unit0, unit1 = unpack(ret.unit:split('-per-'));
					if availableUnits[unit1] then
						ret.unitPattern1 = availableUnits[unit1];
						if availableUnits[unit0] then
							ret.unitPattern = availableUnits[unit0];
						end;
					end;
					ret.compoundUnitPattern = availableUnits.per.compoundUnitPattern;
				end;
				if not ret.unitPattern then
					error("Invalid unit argument for this locale '" .. ret.unit .. "'", 3);
				end;
			else
				ret.standardNPattern = c.negotiate_numbering_system(numbers.formats.currency, ret.numberingSystem, numbers.defaultNumberingSystem).standard;
				ret.unitPattern = c.negotiate_numbering_system_index('unitPattern', numbers.formats.currency, ret.numberingSystem, numbers.defaultNumberingSystem);
				ret.currencyData = numbers.currencies and numbers.currencies[ret.currency];
			end;
		elseif ret.style == "percent" and ret.notation == "compact" then
			ret.standardNPattern = c.negotiate_numbering_system(numbers.formats.percent, ret.numberingSystem, numbers.defaultNumberingSystem).standard;
		end;
		if ret.notation == "compact" then
			if ret.style == "currency" and (ret.currencyDisplay ~= "name") then
				ret.compactPattern = c.negotiate_numbering_system_index('short', numbers.formats.currency, ret.numberingSystem, numbers.defaultNumberingSystem);
			else
				ret.compactPattern = decimalPattern[ret.compactDisplay];
			end;
		end;
		ret.rangePattern = c.negotiate_numbering_system_index('range', numbers.misc, ret.numberingSystem, numbers.defaultNumberingSystem);
	elseif t == "pr" then
		check_property(ret, options, 'pr/type', 'cardinal');
	elseif t == "dt" then
		local calpref = localedata.supplemental.calendarPreferenceData;
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
		if v == "date" and not (ret.era or ret.year or ret.month or ret.day or ret.weekday or ret.dateStyle) then
			ret.dateStyle = 'medium';
		elseif v == "time" and not (ret.hour or ret.minute or ret.second or ret.timeStyle) then
			ret.timeStyle = 'medium';
		elseif v == "datetime" and not (ret.era or ret.year or ret.month or ret.day or ret.weekday or ret.dateStyle
			or ret.hour or ret.minute or ret.second or ret.timeStyle) then
			ret.dateStyle, ret.timeStyle = 'medium', 'medium';
		end;
	elseif t == "rt" then
		check_property(ret, options, 'rt/numeric', 'always');
		check_property(ret, options, 'rt/style', 'long');
		ret.fields = data.dates.fields;
	elseif t == "lf" then
		check_property(ret, options, 'lf/type', 'conjunction');
		check_property(ret, options, 'lf/style', 'long');
		local p = data.listPatterns[(ret.type:gsub('disjunction', 'or'):gsub('conjunction', 'standard'))
			.. (ret.style == "long" and '' or ('-' .. ret.style))];
		ret.pattern = p;
		ret.t, ret.s, ret.m, ret.e = c.tokenizeformat(p['2']), c.tokenizeformat(p['start']), c.tokenizeformat(p['middle']), c.tokenizeformat(p['end']);
	elseif t == "sg" then
		check_property(ret, options, 'sg/granularity', 'grapheme');
		check_property(ret, options, 'g/suppression', valid_value_property["g/suppression"][table.find(valid_value_property["g/suppression"], locale.suppression) or 1]);
		local d = data[granularity_alias[ret.granularity]];
		if d then
			ret.variables = { };
			for _, v in ipairs(d.variables) do
				-- Ignore format and extend characters by default
				if not (v[2]:find("%$Extend") or v[2]:find("%$FE")) then
					ret.variables[v[1]] = v[2]:gsub('%$[%a_]+', ret.variables);
				end;
			end;
			ret.rules = { };
			for k, v in next, d.segmentRules do
				table.insert(ret.rules, { k, (v:gsub('%$[%a_]+', ret.variables)) })
			end;
			local suppressions = d.suppressions and d.suppressions[ret.suppression];
			if suppressions then
				ret.suppressions = table.move(suppressions, 1, #suppressions, 1, table.create(#suppressions));
				table.sort(ret.suppressions, suppression_gt);
			end;
		end;
	end;
	if t == "nu" or t == "pr" or t == "rt" then
		check_property(ret, options, 'nu/rounding', 'halfEven');
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
				if (ret.style == "currency" and ret.notation ~= "compact") then
					local currencyDataFractions = localedata.supplemental.currencyData.fractions;
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
			table.move(other, 1, #other, #self + 1, self);
		end;
		return self;
	end;
};
local string_builder_mt = {
	__concat = function(self, other)
		if type(self) == "string" then
			table.insert(other, 1, self);
			return other;
		elseif getmetatable(self) == getmetatable(other) then
			table.move(other, 1, #other, #self + 1, self);
			return self;
		end;
		table.insert(self, other);
		return self;
	end,
};
function c.initializepart(t)
	if getmetatable(t) == part_mt then
		return t;
	end;
	return setmetatable(t and (t.type and { t } or t) or { }, part_mt);
end;
function c.initializestringbuilder(t)
	return setmetatable(t, string_builder_mt);
end;
function c.addpart(self, ttype, value, source)
	return ((getmetatable(self) == string_builder_mt or type(self) == "string") and self or c.initializepart(self)) .. ((getmetatable(self) == string_builder_mt or type(self) == "string") and value or { type = ttype, value = value, source = source });
end;
function c.addtofirstpart(ttype, value, source, self)
	return ((getmetatable(self) == string_builder_mt or type(self) == "string") and value or { type = ttype, value = value, source = source }) .. ((getmetatable(self) == string_builder_mt or type(self) == "string") and self or c.initializepart(self));
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
					local prefix, value, suffix = c.spacestoparts(value:sub(i0, i1 - 1));
					ret = c.addpart(ret, "literal", prefix, source);
					ret = c.addpart(ret, type, value, source);
					ret = c.addpart(ret, "literal", suffix, source);
				else
					ret = ret .. { type = "literal", value = value:sub(i0, i1 - 1), source = source };
				end;
			end;
			ret = ret .. args[tonumber(value:sub(i1 + 1, i2 - 1))];
			i0 = i2 + 1;
		else
			if value:sub(i0) ~= '' then
				if type then
					local prefix, value, suffix = c.spacestoparts(value:sub(i0));
					ret = c.addpart(ret, "literal", prefix, source);
					ret = c.addpart(ret, type, value, source);
					ret = c.addpart(ret, "literal", suffix, source);
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
function c.negotiate_plural_table(tbl, plural_rule, value0, value1)
	local plural0, plural1 = plural_rule:Select(value0), value1 and plural_rule:Select(value1);
	local plural;
	if value1 then
		local data = localedata.supplemental['plurals-type-pluralRanges'];
		local pos = localedata.minimizestr(plural_rule:ResolvedOptions().locale.baseName);
		while (not data[pos]) and pos do
			pos = localedata.negotiateparent(pos);
		end;
		plural = (data[pos] and data[pos][plural0] and data[pos][plural0][plural1]) or plural1
	else
		plural = plural0;
	end;
	return (not value1 and (tbl[tostring(value0)] or tbl[tostring(value0)])) or tbl[plural] or tbl['other'];
end;

function c.negotiate_numbering_system(tbl, ...)
	local args = { ... };
	for _, v in next, args do
		if v then
			local value = tbl[v];
			if value then
				return value;
			end;
		end;
	end;
	return tbl.latn or tbl[false];
end;

function c.negotiate_numbering_system_index(index, tbl, ...)
	local args = { ... };
	for _,v in next, args do
		if v then
			local value = tbl[v];
			if value and value[index] then
				return value[index];
			end;
		end;
	end;
	return (tbl.latn and tbl.latn[index]) or (tbl[false] and tbl[false][index]);
end;

function c.literalize(str)
	return (str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"));
end;

function c.literalgsub(str, pattern, repl)
	return string.gsub(str, c.literalize(pattern), repl);
end;

local substitute_chars = { };
for ns, tbl in next, localedata.supplemental.numberingSystems do
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
	local d, e = ('0' .. val):gsub('%.', ''), (val:find('%.') or (#val + 1)) + 1;
	local pos = e + exp;
	if pos > #d then
		return val:match("^(%d*)%.?(%d*)$");
	end;
	d = d:split('');
	local add = rounding == 'ceiling';
	if rounding ~= "ceiling" and rounding ~= "floor" then
		add = d[pos]:match(((rounding == "halfEven" and (d[pos - 1] or '0'):match('[02468]')) or rounding == "halfDown") and '[6-9]' or '[5-9]');
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
	return table.concat(d, '', 1, e - 1), table.concat(d, '', e);
end;
local function scale(val, exp)
	val = ('0'):rep(-exp) .. val .. ('0'):rep(exp);
	local unscaled = (val:gsub("[.,]", ''));
	local len = #val;
	local dpos = (val:find("[.,]") or (len + 1)) + exp;
	return unscaled:sub(1, dpos - 1) .. '.' .. unscaled:sub(dpos);
end;
function c.raw_format(val, minintg, maxintg, minfrac, maxfrac, rounding)
	local intg, frac;
	if maxfrac and maxfrac ~= math.huge then
		intg, frac = quantize(val, maxfrac, rounding);
	else
		intg, frac = val:match("^(%d*)%.?(%d*)$");
	end;
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
	if frac == '' then
		return intg;
	end;
	return intg .. '.' .. frac;
end;
function c.raw_format_sig(val, min, max, rounding)
	local intg, frac;
	if max and max ~= math.huge then
		intg, frac = quantize(val, max - ((val:find('%.') or (#val + 1)) - 1), rounding);
	else
		intg, frac = val:match("^(%d*)%.?(%d*)$");
	end;
	intg = intg:gsub('^0+', '');
	frac = frac:gsub('0+$', '');
	if min then
		min = math.max(min - #val:gsub('%.%d*$', ''), 0);
		if #frac < min then
			frac = frac .. ('0'):rep(min - #frac);
		end;
	end;
	if frac == '' then
		return intg;
	end;
	return intg .. '.' .. frac;
end;
function c.parse_exp(val)
	if not val:find('[eE]') then
		return val;
	end;
	local negt, val, exp = val:match('^([+%-]?)(%d*%.?%d*)[eE]([+%-]?%d+)$');
	if val then
		exp = tonumber(exp);
		if not exp then
			return nil;
		end;
		if val == '' then
			return nil;
		end;
		return negt .. scale(val, exp);
	end;
	return nil;
end;
function c.num_to_str(value, scale_v)
	local value_type = typeof(value);
	if value_type == "number" then
		value = ('%.17f'):format(value);
	else
		value = tostring(value);
		value = c.parse_exp(value) or value:lower();
	end;
	if scale_v then
		value = scale(value, scale_v);
	end;
	return value;
end;

return c;
