local PluralRules = require(script.Parent:WaitForChild("PluralRules"));
local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local nf = { };
local ipairs = ipairs;

--[=[
	https://unicode.org/reports/tr35/tr35-numbers.html#Number_Format_Patterns
	Since it's already tokenised, here's the token
	Number:
	It contains two keys, postoken, negtoken and metadata
	String are literals
	0 is the arbitary value
	1 is -
	2 is E
	3 is +
	4 is %
	5 is ‰
	6 is ¤
	
	Compact:
	If it's a `nil` then it means there isn't any available compact pattern
	
	Parser for these can be found on International Core. There's simply no use for parser here.
]=]--

--[=[ Functions, can't rely on double just in case a BigInt was inputted ]=]--
local function compact(val, size)
	val = (val:gsub('%.', ''));
	return val:sub(1, size) .. '.' .. val:sub(size + 1);
end;
local function exp(val, engineering)
	local negt, intg, frac = val:match('(-?)(%d*)%.?(%d*)');
	intg = intg:gsub('^0+', '');
	if #intg == 0 then
		local fsize = (frac:find('[^0]') or (#frac + 1)) - 1;
		local size = engineering and (3 - (fsize % 3)) or 1;
		return negt .. (frac:sub(fsize + 1, fsize + size) .. ('0'):rep(math.max((fsize + size) - #frac, 0))) 
			.. ('.' .. frac:sub(fsize + size + 1)):gsub('%.0*$', '') .. ('E-' .. fsize + size):gsub('-0+$', '0');
	end;
	local size = engineering and (((#intg - 1) % 3) + 1) or 1;
	return negt .. (('0'):rep(math.max(size - #intg, 0)) .. intg:sub(1, size)) .. ('.' .. intg:sub(size + 1) .. frac):gsub('%.0*$', '') .. 'E' .. (#intg - size);
end;

local function format_pattern(self, start, value, pattern, negt, compact, source)
	local ret = start;
	for i, v in ipairs(pattern) do
		if v == 0 then
			ret = ret .. value;
		elseif v == 1 then
			ret = checker.addpart(ret, negt and "minusSign" or "plusSign", negt and self.symbols.minusSign or self.symbols.plusSign, source);
		elseif v == 2 then
			ret = checker.addpart(ret, "exponentSeparator", self.symbols.exponential, source);
		elseif v == 3 then
			ret = checker.addpart(ret, "plusSign", self.symbols.plusSign, source);
		elseif v == 4 then
			ret = checker.addpart(ret, "percentSign", self.symbols.percentSign, source);
		elseif v == 5 then
			ret = checker.addpart(ret, 'perMille', self.symbols.perMille, source);
		elseif v == 6 then
			if self.currencyDisplay ~= "hidden" then
				local symbol = (self.currencyData and ((self.currencyDisplay == "narrowSymbol" and self.currencyData['symbol-alt-narrow'])
					or (self.currencyDisplay == "symbol" and self.currencyData.symbol)))
					or (self.currency or '¤');
				-- Not sure how currency spacing works, apologies but I'm going to assume, currency match is "[:^S:]" and surrounding match is "[:digit:]"
				-- If anyone can tell me how the pattern works, please tell me.
				if (pattern[i + 1] == 0) and symbol:match("%a$") then
					symbol = symbol .. (self.currencySpacing and self.currencySpacing.afterCurrency.insertBetween or " ");
				end;
				if (pattern[i - 1] == 0) and symbol:match("^%a") then
					symbol = (self.currencySpacing and self.currencySpacing.beforeCurrency.insertBetween or " ") .. symbol;
				end;
				ret = checker.addpart(ret, "currency", symbol, source);
			end;
		elseif compact then
			local prefix, compact, suffix = checker.spacestoparts(v);
			if prefix then
				ret = checker.addpart(ret, "literal", prefix, source);
			end;
			ret = checker.addpart(ret, "compact", compact, source);
			if suffix then
				ret = checker.addpart(ret, "literal", suffix, source);
			end;
		else
			ret = checker.addpart(ret, "literal", v, source);
		end;
	end;
	return ret;
end;

--[=[ Formatter ]=]--
function format(self, parts, value0, value1)
	value0 = checker.num_to_str(value0);
	value1 = value1 and checker.num_to_str(value1);
	
	local range = value1 ~= nil;
	local ret0, ret1, rawvalue0, rawvalue1;
	
	--[=[ Non-unit ]=]--
	for i = 0, range and 1 or 0 do
		local value = i == 0 and value0 or value1;
		local selectedPattern;
		local standardPattern = self.standardPattern;
		local standardDecimalPattern;
		local expt;
		local negt, post = value:match("^([+%-]?)(.+)$");
		local rawvalue;
		if post:match("^[%d.]*$") and select(2, post:gsub('%.', '')) < 2 then
			if self.style == "percent" then
				post = checker.scale(post, 2);
			end;
			local minfrac, maxfrac = self.minimumFractionDigits, self.maximumFractionDigits;
			if self.notation == "compact" then
				--[=[ Compact decimal formatting ]=]--
				if self.isSignificant then
					rawvalue = negt .. checker.raw_format_sig(negt, post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
				else
					rawvalue = negt .. checker.raw_format(negt, post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
				end;
				post = post:gsub('^0+', '');
				local intlen = #post:gsub('%..*', '') - 3;
				local compact_val = post;
				-- Just in case, that pattern is '0'
				-- Why max math.min 12? because 12 is the highest compact digits CLDR supports (trillion)
				-- But if this changes, I might use #self.compactPattern.other
				if self.compactPattern.other[math.min(intlen, 12)] then
					compact_val = compact(post, self.compactPattern.other[math.min(intlen, 12)].size + math.max(intlen - 12, 0));
				-- The '0' pattern indicates no compact number available
				elseif (self.style == "currency" and (self.currencyDisplay ~= "name")) or self.style == "percent" then
					standardPattern = self.standardNPattern;
				end;
				if not (minfrac or maxfrac) then
					maxfrac = math.max(2 - ((compact_val:find('%.') or (#compact_val + 1)) - 1) + #compact_val:gsub('%.', ''):match("^0*"), 0);
				end;
				
				local formatted_compact_val;
				if self.isSignificant then
					formatted_compact_val = checker.raw_format_sig(negt, compact_val, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
				else
					formatted_compact_val = checker.raw_format(negt, compact_val, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
				end;
				
				-- Check if 9's are rounded through 10 via length, remove decimals
				if #formatted_compact_val:gsub("%.%d*$", ''):gsub('^0+', '') == #compact_val:gsub("%.%d*$", '') then
					post = formatted_compact_val;
				else
					intlen = intlen + 1;
					if self.compactPattern.other[math.min(intlen, 12)] then
						compact_val = compact(post, self.compactPattern.other[math.min(intlen, 12)].size + math.max(intlen - 12, 0) - 1);
					end;
					if self.isSignificant then
						post = checker.raw_format_sig(negt, compact_val, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
					else
						post = checker.raw_format(negt, compact_val, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
					end;
				end;
				
				intlen = math.min(intlen, 12);
				if self.compactPattern.other[intlen] then
					selectedPattern = checker.negotiate_plural_table(self.compactPattern, self.pluralRule, post)[intlen];
				end;
			elseif self.notation == "standard" then
				if self.isSignificant then
					post = checker.raw_format_sig(negt, post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
				else
					post = checker.raw_format(negt, post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
				end;
				rawvalue = negt .. post;
			else
				if self.isSignificant then
					rawvalue = negt .. checker.raw_format_sig(negt, post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
				else
					rawvalue = negt .. checker.raw_format(negt, post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
				end;
				post, expt = exp(post, self.notation == "engineering"):match("^(%d*%.?%d*)E(-?%d*)$");
				
				if self.isSignificant then
					post = checker.raw_format_sig(negt, post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
				else
					post = checker.raw_format(negt, post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
				end;
				if #post:gsub("%.%d*$", '') > (self.notation == "engineering" and 3 or 1) then
					post = checker.scale(post, self.notation == "engineering" and -3 or -1);
					if self.isSignificant then
						post = checker.raw_format_sig(negt, post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
					else
						post = checker.raw_format(negt, post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.rounding);
					end;
					expt = tostring(expt + (self.notation == "engineering" and 3 or 1));
				end;
			end;
		elseif (post ~= "inf") and (post ~= "infinity") then
			post, rawvalue, negt = 'nan', 'nan', '';
		else
			rawvalue = negt .. 'inf';
		end;
		if i == 0 then
			rawvalue0 = rawvalue;
		elseif rawvalue == rawvalue0 then
			break;
		else
			rawvalue1 = rawvalue;
		end;
		
		--[=[ Special values ]=]--
		local source = parts and range and (i == 0 and 'startRange' or 'endRange') or nil;
		negt = (negt == '-') and (self.signDisplay ~= 'never');
		if post == "nan" then
			post = parts and { type = "nan", value = self.symbols.nan, source = source } or self.symbols.nan;
		elseif post == 'inf' then
			post = parts and { type = "infinity", value = self.symbols.infinity, source = source } or self.symbols.infinity;
		elseif self.notation == "standard" or self.notation == "compact" then
			--[=[ Standard formatting ]=]--
			local intg, frac = post:match("^(%d*)%.?(%d*)$");
			local gs =  ((self.useGrouping ~= "never" and self.useGrouping ~= "thousands") and (self.standardNPattern or standardPattern).metadata.integerGroupSize) or ((self.useGrouping == "always" or self.useGrouping == "thousands") and { 3, 3 });
			if gs and (#intg >= gs[1] + self.minimumGroupingDigits) then
				local sym = ((self.style == "currency" and self.symbols.currencyGroup) or self.symbols.group);
				if parts or (sym:match("[%%%d]")) then
					local ret, rem;
					if gs[1] == gs[2] then
						ret, rem = parts and checker.initializepart() or checker.initializestringbuilder{}, intg:reverse();
					else
						ret, rem = intg:reverse():match(("^(%s)(.+)$"):format(("%d"):rep(gs[1])));
						ret = parts
								and checker.initializepart{ { type = "group", value = sym, source = source }, { type = "integer", value = checker.substitute(ret:reverse(), self.numberingSystem), source = source }, }
								or checker.initializestringbuilder{ sym, checker.substitute(ret:reverse(), self.numberingSystem) };
					end;
					for r in rem:gmatch('%d' .. ('%d?'):rep(gs[2] - 1)) do
						ret = checker.addtofirstpart('group', sym, source,
								checker.addtofirstpart("integer", checker.substitute(r:reverse(), self.numberingSystem), source, ret));
					end;
					table.remove(ret, 1);
					intg = ret;
				elseif gs[1] == gs[2] then
					intg = checker.substitute(intg:reverse():gsub(('%d'):rep(gs[1]), "%1" .. sym:reverse(), (#intg - 1) / gs[1]):reverse(), self.numberingSystem);
				else
					local ret, rem = intg:reverse():match(("^(%s)(.+)$"):format(("%d"):rep(gs[1])));
					intg = checker.initializestringbuilder{
						checker.substitute(rem:gsub(('%d'):rep(gs[2]), "%1" .. sym:reverse(), (#rem - 1) / gs[2]):reverse(), self.numberingSystem),
						sym, checker.substitute(ret:reverse(), self.numberingSystem)
					};
				end;
			elseif parts then
				intg = { type = "integer", value = checker.substitute(intg, self.numberingSystem), source = source };
			else
				intg = checker.substitute(intg, self.numberingSystem);
			end;
			
			if frac == '' then
				post = intg;
			elseif parts then
				post = checker.addpart(intg, 'decimal', ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal), source);
				checker.addpart(post, 'fraction', checker.substitute(frac, self.numberingSystem), source);
			else
				post = intg .. ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal) .. checker.substitute(frac, self.numberingSystem);
			end;
		else
			local intg, frac = post:match("^(%d*)%.?(%d*)$");
			if parts then
				post = {
					{ type = "integer", value = checker.substitute(intg, self.numberingSystem), source = source },
					frac ~= '' and { type = "decimal", value = ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal), source = source },
					frac ~= '' and { type = "fraction", value = checker.substitute(frac, self.numberingSystem), source = source },
					{ type = "exponentSeparator", value = self.symbols.exponential, source = source },
					{ type = "exponentInteger", value = checker.substitute(expt, self.numberingSystem), source = source },
				};
				if not post[2] then
					table.remove(post, 2);
					table.remove(post, 2);
				end;
			else
				post = checker.initializestringbuilder{
					checker.substitute(intg, self.numberingSystem),
					(frac == '' and '' or ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal)),
					(frac == '' and '' or checker.substitute(frac, self.numberingSystem)),
					self.symbols.exponential,
					checker.substitute(expt, self.numberingSystem)
				}
			end;
		end;
		
		local start = parts and checker.initializepart() or checker.initializestringbuilder{};
		local pattern = (negt and standardPattern.negtoken) or standardPattern.postoken;
		local negative_unavailable;
		if selectedPattern then
			negative_unavailable = not selectedPattern.negtoken;
		else
			negative_unavailable = not standardPattern.negtoken;
		end;
		if negt and negative_unavailable then
			start = checker.addpart(start, "minusSign", self.symbols.minusSign);
		elseif (self.signDisplay == 'always') or (self.signDisplay == 'exceptZero' and (post:gsub('0', '') ~= '')) then
			if negative_unavailable then
				start = checker.addpart(start, "plusSign", self.symbols.plusSign);
			elseif selectedPattern then
				selectedPattern = selectedPattern.negtoken;
			else
				standardPattern = standardPattern.negtoken;
			end;
		end;
		local standard = format_pattern(self, selectedPattern and (parts and checker.initializepart() or checker.initializestringbuilder{}) or start, post, pattern, negt, false, source);
		
		if selectedPattern then
			standard = format_pattern(self, start, standard, (negt and selectedPattern.negtoken) or selectedPattern.postoken or selectedPattern, negt, true, source);
		end;
		if i == 0 then
			ret0 = standard;
		else
			ret1 = standard;
		end;
	end;
	
	--[=[ Unit ]=]--
	-- Strip spaces
	if ret0[1] and table.find(checker.spaces, ret0[1].value or ret0[1]) then
		table.remove(ret0, 1);
	end;
	if ret0[#ret0] and table.find(checker.spaces, ret0[#ret0].value or ret0[#ret0]) then
		table.remove(ret0);
	end;
	if ret1 then
		if ret1[1] and table.find(checker.spaces, ret1[1].value or ret1[1]) then
			table.remove(ret1, 1);
		end;
		if ret1[#ret1] and table.find(checker.spaces, ret1[#ret1].value or ret1[#ret1]) then
			table.remove(ret1);
		end;
	end;
	--
	local ret = ret1 and (parts and checker.formattoparts(nil, checker.initializepart(), self.rangePattern, 'shared', ret0, ret1)
			or self.rangePattern:gsub('{0}', table.concat(ret0)):gsub('{1}', table.concat(ret1)))
		or (parts and ret0 or table.concat(ret0));
	if self.style ~= "unit" and (self.style ~= "currency" or self.currencyDisplay ~= "name") then
		return parts and setmetatable(ret, nil) or ret;
	end;
	local unitPattern = checker.negotiate_plural_table(self.unitPattern, self.pluralRule, rawvalue0, rawvalue1);
	local currencyName = (self.currencyData and checker.negotiate_plural_table(self.currencyData, self.pluralRule, rawvalue0, rawvalue1));
	local unit0 = parts and checker.formattoparts(self.style == "unit" and "unit", checker.initializepart(), unitPattern, range and 'shared' or nil, ret, currencyName and { type = "currency", value = currencyName })
		or (unitPattern:gsub('{0}', ret):gsub('{1}', currencyName or self.currency or ''));
	if self.compoundUnitPattern then
		if self.unitPattern1.perUnitPattern then
			return parts and setmetatable(checker.formattoparts("unit", checker.initializepart(), unitPattern, range and 'shared' or nil, unit0), nil) or (self.unitPattern1.perUnitPattern:gsub('{0}', unit0 or ''));
		end;
		local unit1 = checker.negotiate_plural_table(self.unitPattern1, self.pluralRule, 1):gsub('%s*{0}%s*', '');
		return parts and setmetatable(checker.formattoparts("unit", checker.initializepart(), unitPattern, range and 'shared' or nil, unit0, unit1), nil) or (self.compoundUnitPattern:gsub('{0}', unit0 or ''):gsub('{1}', unit1 or ''));
	end;
	return parts and setmetatable(unit0, nil) or unit0;
end;

local methods = checker.initalize_class_methods(intl_proxy);
function methods:Format(...)
	if select('#', ...) == 0 then
		error("missing argument #1 (number expected)", 3);
	end;
	return format(self, false, (...));
end;
function methods:FormatToParts(...)
	if select('#', ...) == 0 then
		error("missing argument #1 (number expected)", 3);
	end;
	return format(self, true, (...));
end;
function methods:FormatRange(...)
	local len = select('#', ...);
	if len < 2 then
		error("Missing argument #".. (len + 1) .." (number expected)", 3);
	end;
	local value0, value1 = ...;
	if value1 == nil then
		value1 = 'nan';
	end;
	return format(self, false, value0, value1);
end;
function methods:FormatRangeToParts(...)
	local len = select('#', ...);
	if len < 2 then
		error("Missing argument #".. (len + 1) .." (number expected)", 3);
	end;
	local value0, value1 = ...;
	if value1 == nil then
		value1 = 'nan';
	end;
	return format(self, true, value0, value1);
end;
function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.notation = self.notation;
	ret.numberingSystem = self.numberingSystem;
	ret.signDisplay = self.signDisplay;
	ret.style = self.style;
	ret.useGrouping = self.useGrouping;
	if self.style == "currency" then
		ret.currency = self.currency;
		ret.currencyDisplay = self.currencyDisplay;
		ret.currencySign = self.currencySign;
	elseif self.style == "unit" then
		ret.unit = self.unit;
		ret.unitDisplay = self.unitDisplay;
	end;
	if self.notation == "compact" then
		ret.compactDisplay = self.compactDisplay;
	end;
	if self.isSignificant then
		ret.minimumSignificantDigits = self.minimumSignificantDigits;
		ret.maximumSignificantDigits = self.maximumSignificantDigits;
	else
		ret.minimumIntegerDigits = self.minimumIntegerDigits;
		ret.minimumFractionDigits = self.minimumFractionDigits;
		ret.maximumFractionDigits = self.maximumFractionDigits;
	end;
	ret.rounding = self.rounding;
	return ret;
end;

function nf.new(...)
	local option = checker.options('nu', ...);
	option.pluralRule = PluralRules.new(option.locale, { type = "cardinal" });
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('NumberFormat', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

function nf.SupportedLocalesOf(locales)
	return checker.supportedlocale('main', locales);
end;

nf._private = {
	intl_proxy = intl_proxy,
	format = format,
};
return nf;
