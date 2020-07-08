local localedata = require(script.Parent:WaitForChild("_localedata"));
local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local dtf = { };

--[=[
	Since it's already tokenized, here's the token:
	{symbol, count, serial}
]=]--
-- I've reused some code from the previous version of International

-- Algorithmn: Gregorian
local months_to_days = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 };
local function is_leap(y)
	return (y % 4 == 0) and ((y % 100 ~= 0) or (y % 400 == 0));
end;

local function from_date(y, m, d)
	local mdr = (months_to_days[m] + ((m > 2 and is_leap(y)) and 1 or 0)) + (d - 1);
	y = y - 1;
	return (y * 365) + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + mdr;
end;

local function determine_weekdays(y, m, d)
	return (from_date(y, m, d) % 7) + 1;
end;

local function from_time(h, n, s, f)
	return (((h * 3600) + (n * 60) + s) * 1000) + f;
end;

local function compare_date(y0, m0, d0, y1, m1, d1)
	if not d0 then
		return compare_date(
			y0.Year or y0.year or y0[1], y0.Month or y0.month or y0[2], y0.Day or y0.day or y0[3],
			m0.Year or m0.year or m0[1], m0.Month or m0.month or m0[2], m0.Day or m0.day or m0[3]);
	end;
	y1, m1, d1 = tonumber(y1), tonumber(m1), tonumber(d1);
	local date0, date1 = from_date(y0, m0, d0), from_date(y1, m1, d1);
	if date0 < date1 then
		return -1;
	end;
	return (date0 == date1) and 0 or 1;
end;

local function compare_datetime_table(dt0, dt1)
	local y0, m0, d0, h0, n0, s0, f0 = dt0.Year or dt0.year, dt0.Month or dt0.month or 1, dt0.Day or dt0.day or 1, dt0.Hour or dt0.hour or 0, 
		dt0.Minute or dt0.min or 0, dt0.Second or dt0.sec or 0, dt0.Millisecond or 0;
	local y1, m1, d1, h1, n1, s1, f1 = dt1.Year or dt1.year, dt1.Month or dt1.month or 1, dt1.Day or dt1.day or 1, dt1.Hour or dt1.hour or 0, 
		dt1.Minute or dt1.min or 0, dt1.Second or dt1.sec or 0, dt1.Millisecond or 0;
		
	local date0, date1 = from_date(y0, m0, d0), from_date(y1, m1, d1);
	if date0 > date1 then
		return 1;
	elseif date0 < date1 then
		return -1;
	end;
	
	local time0, time1 = from_time(h0, n0, s0, f0), from_time(h1, n1, s1, f1);
	if time0 < time1 then
		return -1;
	end;
	return (time0 == time1) and 0 or 1;
end;

local function getoffset()
	-- I'm sure by 10'000 AD they'll figure it out
	return math.floor((os.time(os.date('*t')) - os.time(os.date('!*t'))) / 60);
end;

-- Algorithmn: Hijri, one day off in some cases
local year_cycles_hiriji = { 0, 354, 709, 1063, 1417, 1772, 2126, 2481, 2835, 3189, 3544, 3898, 4252, 4607, 4961, 5315, 5670, 6024, 6379, 6733, 7087, 7442, 7796, 8150, 8505, 8859, 9214, 9568, 9922, 10277 };
local days_in_months_hiriji = { 0, 30, 59, 89, 118, 148, 177, 207, 236, 266, 295, 325 };

local function is_leap_hirji(year)
	return (14 + (11 * year)) % 30 < 11;
end;

local function geterayearmonthdayhirji(days)
	-- 19 July 622 A.D.
	days = days - 227014;
	
	local cycle_number, day_of_cycle = math.floor(days / 10631), days % 10631;
	local year_in_cycle = math.floor(day_of_cycle / 356) + 1;
	if day_of_cycle >= (year_cycles_hiriji[year_in_cycle + 1] or math.huge) then
		year_in_cycle = year_in_cycle + 1;
	end;
	local day_of_year = day_of_cycle - year_cycles_hiriji[year_in_cycle];
	local month = math.floor(day_of_year / 31) + 1;
	if day_of_year >= (days_in_months_hiriji[month + 1] or math.huge) then
		month = month + 1;
	end;
	if day_of_year < 0 then
		day_of_year = (is_leap_hirji((cycle_number * 30) + year_in_cycle) and 355 or 354);
	end
	return 1, (cycle_number * 30) + year_in_cycle, month, ((day_of_year - (days_in_months_hiriji[month] or 0)) + 1);
end;

-- Algorithmn: Solar calendars
local caldata = localedata.coredata.calendarData;
local function geterayearmonthday(cal, year, month, day)
	if not caldata[cal] then
		return (year < 1 and '0' or '1'), year, month, day;
	elseif cal == "islamic" then
		return geterayearmonthdayhirji(from_date(year, month, day));
	end;
	for c = #caldata[cal].eras, 1, -1 do
		local era = caldata[cal].eras[c];
		local offset = era._start or era._end;
		
		local compare = compare_date(year, month, day, offset[1], offset[2], offset[3]);
		if c == 1 or (era._start and compare >= 0) or (era._end and compare <= 0) then
			return c, year - ((offset[1]) - 1), month, day;
		end;
	end;
end;

local function zero_pad_substitute(value, length, nu)
	-- Just a sugar syntax
	return checker.substitute(('%0' .. length .. 'd'):format(value), nu);
end;
local dayperiods = localedata.coredata.dayPeriods;
local function get_dayperiod(data, flexible)
	local data1 = data.self.dayPeriodRule;
	if data1 then
		for k, v in next, data1 do
			if flexible == (not v._from) then
				continue;
			end;
			if flexible then
				-- No data have a minute over 0
				local hour_from = tonumber(v._from:split(':')[1]);
				local hour_before = tonumber(v._before:split(':')[1]);
				if data.hour >= hour_from or data.hour < hour_before then
					return k;
				end;
			else
				if ('%02d:%02d'):format(data.hour, data.minute) == v._at then
					return k;
				end;
			end;
		end;
	end;
	-- Fallback
	return data.hour >= 12 and 'pm' or 'am';
end;
local function empty_format()
	return '';
end;
local function offset_to_string(offset, sep, include_sign)
	local o_h, o_m = math.floor(offset / 60), math.floor(offset % 60);
	if o_h == 0 and o_m == 0 and sep:match('^iso') then
		return 'Z';
	end;
	return (o_h >= 0 and "+%02d%s%02d" or "%02d%s%02d"):format(o_h, sep:match('^iso') and sep:sub(4) or sep, o_m);
end;

local getvalue =
	setmetatable({
		G = function(self, date, n)
			return self.data.eras['era' .. (n == 4 and 'Names' or (n == 5 and 'Narrow' or 'Abbr'))][date.era];
		end;
		y = function(self, date, n)
			if n == 2 then
				return zero_pad_substitute(date.year % 100, 2);
			end;
			return zero_pad_substitute(date.year, n, self.numberingSystem);
		end;
		Q = function(self, date, n)
			if n >= 3 then
				return self.data.months.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][math.ceil(date.month / 3)];
			end;
			return zero_pad_substitute(math.ceil(date.month / 3), n, self.numberingSystem);
		end;
		q = function(self, date, n)
			if n >= 3 then
				return self.data.months['stand-alone'][n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][math.ceil(date.month / 3)];
			end;
			return zero_pad_substitute(math.ceil(date.month / 3), n, self.numberingSystem);
		end;
		M = function(self, date, n)
			if n >= 3 then
				return self.data.months.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.month];
			end;
			return zero_pad_substitute(date.month, n, self.numberingSystem);
		end;
		L = function(self, date, n)
			if n >= 3 then
				return self.data.months['stand-alone'][n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.month];
			end;
			return zero_pad_substitute(date.month, n, self.numberingSystem);
		end;
		d = function(self, date, n)
			return zero_pad_substitute(date.day, n, self.numberingSystem);
		end;
		E = function(self, date, n)
			return self.data.days.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.weekday];
		end;
		e = function(self, date, n)
			if n < 3 then
				return zero_pad_substitute(((date.weekday - date.weekStart) % 7) + 1, n, self.numberingSystem);
			end;
			return self.data.days.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.weekday];
		end;
		c = function(self, date, n)
			if n < 3 then
				return zero_pad_substitute(((date.weekday - date.weekStart) % 7) + 1, n, self.numberingSystem);
			end;
			return self.data.days['stand-alone'][n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.weekday];
		end;
		a = function(self, date, n)
			return self.data.dayPeriods.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][date.hour > 12 and 'pm' or 'am'];
		end;
		b = function(self, date, n)
			return self.data.dayPeriods.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][get_dayperiod(date, true)];
		end;
		B = function(self, date, n)
			return self.data.dayPeriods.format[n == 5 and 'narrow' or (n == 4 and 'wide' or 'abbreviated')][get_dayperiod(date, true)];
		end;
		h = function(self, date, n)
			return zero_pad_substitute(((date.hour - 1) % 12) + 1, n, self.numberingSystem);
		end;
		H = function(self, date, n)
			return zero_pad_substitute(date.hour, n, self.numberingSystem);
		end;
		K = function(self, date, n)
			return zero_pad_substitute(date.hour % 12, n, self.numberingSystem);
		end;
		k = function(self, date, n)
			return zero_pad_substitute(((date.hour - 1) % 24) + 1, n, self.numberingSystem);
		end;
		m = function(self, date, n)
			return zero_pad_substitute(date.minute, n, self.numberingSystem);
		end;
		s = function(self, date, n)
			return zero_pad_substitute(date.second, n, self.numberingSystem);
		end;
		S = function(self, date, n)
			return zero_pad_substitute(date.millisecond, n, self.numberingSystem);
		end;
		Z = function(self, date, n)
			return (n == 4 and 'GMT' or '') .. offset_to_string(date.offset, n < 3 and '' or n == 4 and ':' or 'iso:', true);
		end;
		z = function(self, date, n)
			return 'GMT' .. (n == 1 and offset_to_string(date.offset, ':', true) or offset_to_string(date.offset, ':', true):gsub('^([+-])0', '%1'):gsub(':00$', ''));
		end;
		O = function(self, date, n)
			return 'GMT' .. (n == 1 and offset_to_string(date.offset, ':', true) or offset_to_string(date.offset, ':', true):gsub('^([+-])0', '%1'):gsub(':00$', ''));
		end;
		X = function(self, date, n)
			return (n == 1 and offset_to_string(date.offset, 'iso' .. ((n == 3 or n == 5) and ':' or ''), true):gsub('00$', ''));
		end;
		x = function(self, date, n)
			return (n == 1 and offset_to_string(date.offset, ((n == 3 or n == 5) and ':' or ''), true):gsub('00$', ''));
		end;
	}, { __index = function() return empty_format; end; });

local typename =
{
	G = 'era',
	y = "year", Y = 'year', u = "year", U = "year",
	Q = "quarter", q = "quarter",
	M = "month", L = "month", l = "month",
	w = "week", W = "week",
	d = "day", D = "day", f = "day", g = "day",
	E = "weekday", e = "weekday", c = "weekday",
	a = "dayPeriod", b = "dayPeriod", B = "dayPeriod",
	h = "hour", H = "hour", K = "hour", k = "hour", J = "hour", j = "hour", C = "hour",
	m = "minute",
	s = "second", S = "fractionalSecond",
};
--

local function find_closet_flexible(v0, available)
	if available[v0] then
		return available[v0];
	end;
	v0 = (v0:gsub('k', 'H'):gsub('K', 'h'));
	if available[v0] then
		return available[v0];
	end;
	local closest;
	local closestdelta = math.huge;
	for rf, rv in next, available do
		local v1 = v0;
		rf = rf:gsub('k', 'H'):gsub('K', 'h');
		local delta = math.abs(#rf - #v0) + (#rf > #v0 and 1 or 0);
		for chr in rf:gmatch(".") do
			rf = rf:gsub(chr .. '+', chr);
			v1 = v1:gsub(chr .. '+', chr);
		end;
		if (rf == v1) and (delta < closestdelta) then
			closest = rv;
			closestdelta = delta;
		end;
	end;
	if closest then
		return closest;
	end;
	return;
end;

local hourcycle_alias = { h12 = 'h', h23 = 'H', h11 = 'K', h24 = 'k', };

local char_pattern_flexible_find = { { 'G', 'y', 'M', 'd', 'E' }, { 'E', 'H', 'm', 's' } };
local flexible_find_size = { ['numeric'] = 1, ['2-digit'] = 2, ['long'] = 4, ['short'] = 3, ['narrow'] = 5 };
local smallest_diff_char = { { 'second', 's' }, { 'minute', 'm' }, { 'hour', 'H' }, { 'day', 'd' }, { 'month', 'M' }, { 'year', 'y' }, { 'era', 'G' } };

local function find_format(self, range)
	local data = self.data;
	local fallback = true;
	
	local date_flexible_find = '';
	if not self.dateStyle then
		for i, v in ipairs { self.era or false, self.year or false, self.month or false, self.day or false, self.weekday or false } do
			if v and (i ~= 5 or date_flexible_find ~= '') then
				date_flexible_find = date_flexible_find .. char_pattern_flexible_find[1][i]:rep(flexible_find_size[v]);
			end;
		end;
	end;
	
	local time_flexible_find = '';
	if not self.timeStyle then
		for i, v in ipairs { self.weekday or false, self.hour or false, self.minute or false, self.second or false } do
			if v then
				local retchar;
				if i ~= 1 or (not date_flexible_find:find('E')) then
					if i == 2 then
						if self.hourCycle ~= nil then
							retchar = hourcycle_alias[self.hourCycle];
						elseif self.hour12 ~= nil then
							retchar = self.hour12 and 'h' or 'H';
						else
							retchar = hourcycle_alias[self.currentHourCycle] or self.currentHourCycle or 'H';
						end;
					else
						retchar = char_pattern_flexible_find[2][i]:rep(flexible_find_size[v]);
					end;
					time_flexible_find = time_flexible_find .. retchar;
				end;
			end;
		end;
	end;
	
	local result_date_format = find_closet_flexible(date_flexible_find, (range and data.dateTimeFormats.intervalFormats) or data.dateTimeFormats.availableFormats);
	local result_time_format = find_closet_flexible(time_flexible_find, (range and data.dateTimeFormats.intervalFormats) or data.dateTimeFormats.availableFormats);
	
	local result_format;
	
	if not (result_date_format or result_time_format) then
		if self.timeStyle then
			local time_format = data.timeFormats[self.timeStyle];
			
			if (self.hourCycle ~= nil) or (self.hour12 ~= nil) then
				time_format = find_closet_flexible(((self.hourCycle == 'h11' or self.hourCycle == 'h12' or ((not self.hourCycle) and self.hour12)) and 'h' or 'H')
					.. (self.style == "short" and 'm' or 'ms'),
					data.dateTimeFormats.availableFormats);
			end;
			
			if self.dateStyle then
				result_format = checker.insertformat(data.dateTimeFormats[self.timeStyle or self.dateStyle or 'medium'], time_format, data.dateFormats[self.dateStyle or 'medium']);
			else
				result_format = time_format;
			end;
		else
			result_format = data.dateFormats[self.dateStyle or 'medium'];
		end;
	elseif not result_date_format then
		if self.dateStyle then
			result_format = checker.insertformat(data.dateTimeFormats[self.timeStyle or self.dateStyle], result_time_format, data.dateFormats[self.dateStyle]);
		else
			result_format = result_time_format;
		end;
		fallback = false;
	elseif not result_time_format then
		if self.timeStyle then
			result_format = checker.insertformat(data.dateTimeFormats[self.timeStyle or self.dateStyle], data.timeFormats[self.timeStyle], result_time_format);
		else
			result_format = result_date_format;
		end;
		fallback = false;
	else
		result_format = checker.insertformat(data.dateTimeFormats[self.timeStyle or 'medium'], result_time_format, result_date_format);
		fallback = false;
	end;
	return result_format, range and fallback;
end;

local function format_pattern(self, start, pattern, parts, info0, info1, source_override)
	local ret = start;
	local current_range = source_override or 0;
	for i, v in ipairs(pattern) do
		if type(v) == "table" then
			local dateunit = v[1];
			local size = v[2];
			local source = source_override or v[3];
			if parts then
				current_range = source;
			end;
			local value;
			if dateunit:match('[hHKk]') and self.hourCycle ~= nil then
				dateunit = hourcycle_alias[self.hourCycle];
			end;
			if dateunit == "G" and self.era then
				size = flexible_find_size[self.era];
			elseif dateunit == "y" and self.year then
				size = flexible_find_size[self.year];
			elseif dateunit == "M" and self.month then
				if ((flexible_find_size[self.month]) < 3) == (size < 3) then
					size = flexible_find_size[self.month];
					if type(pattern[i + 1]) == "string" and (flexible_find_size[self.month]) >= 3 then
						value = getvalue[dateunit](self, info0, size):gsub(checker.literalize(pattern[i + 1]) .. '$', '');
					end;
					if type(pattern[i - 1]) == "string" and (flexible_find_size[self.month]) >= 3 then
						value = getvalue[dateunit](self, info0, size):gsub('^' .. checker.literalize(pattern[i - 1]), '');
					end;
				end;
			elseif dateunit == "d" and self.day then
				size = flexible_find_size[self.day];
			elseif dateunit == "a" and self.dayPeriod then
				size = flexible_find_size[self.dayPeriod];
			elseif dateunit:match('[hHKk]') and self.hour then
				size = flexible_find_size[self.hour];
			elseif dateunit == "m" and self.minute then
				size = flexible_find_size[self.minute];
			elseif dateunit == "s" and self.second then
				size = flexible_find_size[self.second];
			end;
			ret = checker.addpart(ret, typename[dateunit], checker.substitute(value or getvalue[dateunit](self, source < 2 and info0 or info1, size), self.numberingSystem), parts and info1 and (source == 1 and 'shared' or (source == 0 and 'startRange' or 'endRange')));
		else
			ret = checker.addpart(ret, 'literal', v, parts and info1 and ((source_override or ((pattern[i + 1] and pattern[i + 1][3]) or current_range)) ~= current_range and 'shared' or (current_range == 0 and 'startRange' or 'endRange')));
		end;
	end;
	return ret;
end;

local function format(self, parts, date0, date1)
	if type(date0) == "number" then
		date0 = os.date('!*t', date0);
	elseif date0 == nil then
		date0 = os.date('!*t');
	elseif typeof(date0) == "DateTime" then
		date0 = date0:ToUniversalTime();
	elseif (typeof(date0) ~= "userdata" or getmetatable(date0) == nil) and type(date0) ~= "table" then
		error("invalid argument #2 (date expected, got " .. typeof(date0) .. ')', 4);
	end;
	if type(date1) == "number" then
		date1 = os.date('!*t', date1);
	elseif typeof(date1) == "DateTime" then
		date1 = date1:ToUniversalTime();
	elseif date1 ~= nil and (typeof(date1) ~= "userdata" or getmetatable(date0) == nil) and type(date1) ~= "table" then
		error("invalid argument #2 (date expected, got " .. typeof(date1) .. ')', 4);
	end;
	
	local range = false;
	if date1 and compare_datetime_table(date0, date1) ~= 0 then
		range = true;
	end;
	
	local rawyear0, rawmonth0, rawday0 = date0.Year or date0.year, date0.Month or date0.month or 1, date0.Day or date0.day or 1;
	local rawyear1, rawmonth1, rawday1;
	
	if date1 then
		rawyear1, rawmonth1, rawday1 = date1.Year or date1.year, date1.Month or date1.month or 1, date1.Day or date1.day or 1;
	end;
	
	local era0, year0, month0, day0, weekday0 = geterayearmonthday(self.calendar, rawyear0, rawmonth0, rawday0);
	local info0 =
	{
		era = era0,
		year = year0,
		month = month0,
		weekday = weekday0 or determine_weekdays(rawyear0, rawmonth0, rawday0),
		day = day0 or 1,
		hour = date0.Hour or date0.hour or 0,
		minute = date0.Minute or date0.min or 0,
		second = date0.Second or date0.sec or 0,
		millisecond = date0.Millisecond or 0,
		offset = date0.TimeZoneOffset or 0,
		
		weekStart = 1,
	};
	
	local info1;
	if range then
		local era1, year1, month1, day1, weekday1 = geterayearmonthday(self.calendar, rawyear1, rawmonth1, rawday1);
		info1 =
		{
			era = era1,
			year = year1,
			month = month1,
			weekday = weekday1 or determine_weekdays(rawyear1, rawmonth1, rawday1),
			day = day1 or 1,
			hour = date1.Hour or date1.hour or 0,
			minute = date1.Minute or date1.min or 0,
			second = date1.Second or date1.sec or 0,
			millisecond = date1.Millisecond or 0,
			offset = date0.TimeZoneOffset or 0,
			
			weekStart = 1,
		};
	end;
	
	local pattern;
	local fallback = range and self.rangeFallback;
	if range and not fallback then
		local smallest_diff = 0;
		for i = 1, 7 do
			if info0[smallest_diff_char[i][1]] ~= info1[smallest_diff_char[i][1]]
				and self.formatRange[smallest_diff_char[i][2]] then
				smallest_diff = i;
				break;
			end;
		end;
		if smallest_diff == 0 then
			fallback = true;
			pattern = self.format;
		else
			smallest_diff = smallest_diff_char[smallest_diff][2];
			pattern = self.formatRange[smallest_diff];
		end;
	else
		pattern = self.format;
	end;
	
	if fallback and not parts then
		return (self.rangeFallbackPattern
			:gsub('{0}', table.concat(format_pattern(self, checker.initializestringbuilder{}, pattern, parts, info0, true, 0)))
			:gsub('{1}', table.concat(format_pattern(self, checker.initializestringbuilder{}, pattern, parts, true, info1, 2))));
	elseif fallback then
		return checker.formattoparts(nil, checker.initializepart(), self.rangeFallbackPattern, 'shared',
			format_pattern(self, checker.initializepart(), pattern, parts, info0, true, 0),
			format_pattern(self, checker.initializepart(), pattern, parts, true, info1, 2));
	end;
	local ret = format_pattern(self, parts and checker.initializepart() or checker.initializestringbuilder{}, pattern, parts, info0, info1, nil);
	if parts then
		return setmetatable(ret, nil);
	end;
	return table.concat(ret);
end;

local methods = checker.initalize_class_methods(intl_proxy);
function methods:Format(...)
	if select('#', ...) == 0 then
		error("Missing argument #1 (date expected)", 2);
	end;
	return format(self, false, (...));
end;
function methods:FormatToParts(...)
	if select('#', ...) == 0 then
		error("Missing argument #1 (date expected)", 2);
	end;
	return setmetatable(format(self, true, (...)), nil);
end;
function methods:FormatRange(...)
	local len = select('#', ...);
	if len < 2 then
		error("Missing argument #".. (len + 1) .." (date expected)", 2);
	end;
	local date0, date1 = ...;
	return format(self, false, date0, (date1 == nil) and os.date('!*t') or date1);
end;
function methods:FormatRangeToParts(...)
	local len = select('#', ...);
	if len < 2 then
		error("Missing argument #".. (len + 1) .." (date expected)", 2);
	end;
	local date0, date1 = ...;
	return setmetatable(format(self, true, date0, (date1 == nil) and os.date('!*t') or date1), nil);
end;

function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.localeMatcher = self.localeMatcher;
	ret.calendar = self.calendar;
	ret.dayPeriod = self.dayPeriod;
	ret.numberingSystem = self.numberingSystem;
	ret.localeMatcher = self.localeMatcher;
	ret.hour12 = self.hour12;
	ret.hourCycle = self.hourCycle;
	if self.dateStyle then
		ret.dateStyle = self.dateStyle;
	else
		ret.weekday = self.weekday;
		ret.era = self.era;
		ret.year = self.year;
		ret.month = self.month;
		ret.day = self.day;
	end;
	if self.timeStyle then
		ret.timeStyle = self.timeStyle;
	else
		if self.dateStyle then
			ret.weekday = self.weekday;
		end;
		ret.hour = self.hour;
		ret.minute = self.minute;
		ret.second = self.second;
	end;
	return ret;
end;

function dtf.new(...)
	local option = checker.options('dt', ...);
	option.format = find_format(option, false);
	option.formatRange, option.rangeFallback = find_format(option, true);
	option.rangeFallbackPattern = option.data.dateTimeFormats.intervalFormats.intervalFormatFallback;
	option.rangeFallbackPatternToken = checker.tokenizeformat(option.rangeFallbackPattern);
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('DateTimeFormat', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

dtf._private = {
	intl_proxy = intl_proxy,
	format = format,
	find_format = find_format,
};
return dtf;
