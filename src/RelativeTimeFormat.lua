local PluralRules = require(script.Parent:WaitForChild("PluralRules"));
local NumberFormat = require(script.Parent:WaitForChild("NumberFormat"));
local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local rtf = { };
rtf._private =
{
	intl_proxy = intl_proxy,
};

local allowed_unit =
{
	year = "year", years = "year", quarter = "quarter", quarters = "quarter",
	month = "month", months = "month", week = "week", weeks = "week",
	day = "day", days = "day", hour = "hour", hours = "hour",
	minute = "minute", minutes = "minute", second = "second", seconds = "second",
	monday = "mon", mondays = "mon", tuesday = "tue", tuesdays = "tue",
	wednesday = "wed", wednesdays = "wed", thursday = "thu", thursdays = "thu",
	friday = "fri", fridays = "fri", saturday = "sat", saturdays = "sat",
	sunday = "sun", sundays = "sun", mon = "mon", tue = "tue",
	wed = "wed", thu = "thu", fri = "fri", sat = "sat", sun = "sun",
};

function format(self, parts, value, unit)
	if not tonumber(value) then
		error("invalid argument #1 (number expected, got " .. typeof(value) .. ')', 4)
	end;
	value = tonumber(value);
	local absvalue = math.abs(value);
	if value ~= value then
		error("Value must not be NaN", 4);
	end
	if type(unit) ~= "string" then
		error("invalid argument #2 (string expected, got " .. typeof(unit) .. ")", 4);
	elseif not allowed_unit[unit] then
		error("Invalid unit argument '" .. unit .. "'", 4);
	end;
	local pattern = self.fields[allowed_unit[unit] .. (self.style == "long" and '' or ('-' .. self.style))];
	pattern = (self.numeric == "auto" and pattern[tostring(value)])	
		or checker.negotiate_plural_table(pattern[value < 0 and "past" or "future"], self.pluralRule, absvalue);
	if parts then
		local number_parts = self.numberFormat:FormatToParts(absvalue);
		for _, v in ipairs(number_parts) do
			v.unit = unit;
		end;
		return setmetatable(checker.formattoparts(nil, checker.initializepart(), pattern, nil, number_parts), nil);
	end;
	return (pattern:gsub('{0}', self.numberFormat:Format(absvalue)));
end;

local methods = checker.initalize_class_methods(intl_proxy);
function methods:Format(...)
	local len = select('#', ...);
	if len < 2 then
		error(len == 1 and "missing argument #1 (number expected)" or "missing argument #2 (string unit expected)", 3);
	end;
	return format(self, false, ...);
end;
function methods:FormatToParts(...)
	local len = select('#', ...);
	if len < 2 then
		error(len == 1 and "missing argument #1 (number expected)" or "missing argument #2 (string unit expected)", 3);
	end;
	return format(self, true, ...);
end;
function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.numeric = self.numeric;
	ret.style = self.style;
	ret.numberingSystem = self.numberingSystem;
	ret.useGrouping = self.useGrouping
	ret.signDisplay = self.signDisplay;
	ret.compactDisplay = self.compactDisplay;
	ret.notation = self.notation;
	if self.isSignificant then
		ret.minimumSignificantDigits = self.minimumSignificantDigits;
		ret.maximumSignificantDigits = self.maximumSignificantDigits;
	else
		ret.minimumIntegerDigits = self.minimumIntegerDigits;
		ret.minimumFractionDigits = self.minimumFractionDigits;
		ret.maximumFractionDigits = self.maximumFractionDigits;
	end;
	ret.midpointRounding = self.midpointRounding;
	return ret;
end;

function rtf.new(...)
	local option = checker.options('rt', ...);
	option.pluralRule = PluralRules.new(option.locale, { type = "cardinal" });
	option.numberFormat = NumberFormat.new(option.locale, option.numberOptions);
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('RelativeTimeFormat', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

function rtf.SupportedLocalesOf(locales)
	return checker.supportedlocale('main', locales);
end;

return rtf;
