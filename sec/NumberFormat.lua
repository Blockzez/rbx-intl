local PluralRules = require(script.Parent:WaitForChild("PluralRules"));
local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local nf = { };
nf._private =
{
	intl_proxy = intl_proxy,
};

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
local function scale(val, exp)
	val = ('0'):rep(-exp) .. val .. ('0'):rep(exp);
	local unscaled = (val:gsub("[.,]", ''));
	local len = #val;
	local dpos = (val:find("[.,]") or (len + 1)) + exp;
	return unscaled:sub(1, dpos - 1) .. '.' .. unscaled:sub(dpos);
end;
local function compact(val, size)
	val = (val:gsub('%.', ''));
	return val:sub(1, size) .. '.' .. val:sub(size + 1);
end;
local function exp(val)
	local negt, intg, frac = val:match('(-?)([%d%a()]*)%.?(%d*)');
	if intg:match('%D') then
		return val;
	end;
	if #intg == 0 then
		local fsize = #frac:gsub('[^0]*$', '');
		return negt .. (frac:sub(fsize + 1, fsize + 1) == '' and '0' or frac:sub(fsize + 1, fsize + 1)) 
			.. ('.' .. frac:sub(fsize + 2)):gsub('%.0*$', '') .. ('E-' .. fsize + 1):gsub('-0+$', '0');
	end;
	return negt .. (intg:sub(1, 1) == '' and '0' or intg:sub(1, 1)) .. ('.' .. intg:sub(2) .. frac):gsub('%.0*$', '') .. 'E' .. (#intg - 1);
end;

local function format_pattern(self, start, value, pattern, negt, compact)
	local ret = start;
	for i, v in ipairs(pattern) do
		if v == 0 then
			ret = ret .. value;
		elseif v == 1 then
			ret = checker.addpart(ret, negt and "minusSign" or "plusSign", negt and self.symbols.minusSign or self.symbols.plusSign);
		elseif v == 2 then
			ret = checker.addpart(ret, "exponentSeparator", self.symbols.exponential);
		elseif v == 3 then
			ret = checker.addpart(ret, "plusSign", self.symbols.plusSign);
		elseif v == 4 then
			ret = checker.addpart(ret, "percentSign", self.symbols.percentSign);
		elseif v == 5 then
			ret = ret .. self.symbols.perMille;
		elseif v == 6 then
			if self.currencyData then
				ret = checker.addpart(ret, "currency", (self.currencyDisplay == "narrowSymbol" and self.currencyData['symbol-alt-narrow']) or self.currencyData.symbol or self.currency);
			else
				ret = checker.addpart(ret, "currency", (self.currency and self.currency:upper() or '¤'));
			end;
		else
			if compact then
				if type(ret) == "string" then
					ret = ret .. v;
				else
					local prefix, compact, suffix = checker.spacestoparts(v);
					ret = checker.addpart(ret, "literal", prefix);
					ret = checker.addpart(ret, "compact", compact);
					ret = checker.addpart(ret, "literal", suffix);
				end;
			else
				ret = checker.addpart(ret, "literal", v);
			end;
		end;
	end;
	return ret;
end;

--[=[ Formatter ]=]--
function format(self, parts, value)
	local value_type = typeof(value);
	if value_type == "number" then
		value = (('%.11f'):format(value):gsub('0+$', ''):gsub('%.$', ''));
		if self.style == "percent" then
			value = scale(value, 2);
		end;
	else
		value = tostring(value);
		if self.style == "percent" then
			value = scale(value, 2);
		end;
		value = checker.parse_exp(value) or value:lower();
	end;
	
	--[=[ Non-unit ]=]--
	local selectedPattern;
	local standardPattern = self.standardPattern;
	local standardDecimalPattern;
	local expt;
	local negt, post = value:match("([+%-]?)(.+)");
	if post:match("^[%d.]*$") then
		local minfrac, maxfrac = self.minimumFractionDigits, self.maximumFractionDigits;
		if self.isSignificant then
			post = checker.raw_format_sig(post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.midpointRounding);
		else
			post = checker.raw_format(post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.midpointRounding);
		end;
		
		if self.notation == "compact" then
			--[=[ Compact decimal formatting ]=]--
			-- The sizes of the value in different plurals rules shouldn't be different
			-- If there is, that would one tricky code to deal with.
			local intlen = #post:gsub('^0+$', ''):gsub('%..*', '') - 3;
			-- Just in case, that pattern is '0'
			if self.compactPattern.other[math.min(intlen, 12)] then
				post = compact(post, self.compactPattern.other[math.min(intlen, 12)].size + math.max(intlen - 12, 0));
				intlen = math.min(intlen, 12);
			-- The '0' pattern indicates no compact number available
			elseif (self.style == "currency" and self.currencyDisplay == "symbol") or self.style == "percent" then
				standardPattern = self.standardNPattern;
			end;
			if not (minfrac or maxfrac) then
				maxfrac = ((#post:gsub('%.%d*$', '') < 2) and 1 or 0);
			end;
			
			if self.isSignificant then
				post = checker.raw_format_sig(post, self.minimumSignificantDigits, self.maximumSignificantDigits, self.midpointRounding);
			else
				post = checker.raw_format(post, self.minimumIntegerDigits, self.maximumIntegerDigits, minfrac, maxfrac, self.midpointRounding);
			end;
			
			if self.compactPattern.other[intlen] then
				selectedPattern = checker.negotiate_plural_table(self.compactPattern, '', '', self.pluralRule, post)[intlen];
			end;
		elseif self.notation ~= "standard" then
			post, expt = exp(post):match("^(%d*%.?%d*)E(%d*)$");
			if not (minfrac or maxfrac) then
				maxfrac = 3;
			end;
		end;
	elseif post == "nan" or post == "nan(ind)" then
		post = 'nan';
		negt = '';
	elseif (post ~= "inf") and (post ~= "infinity") and (value_type ~= "number") then
		if value_type == "string" then
			error("'" .. value .. "' is not a valid value", 4);
		end;
		error("invalid argument #2 (number expected, got " .. value_type .. ')', 4);
	end;
	
	--[=[ Special values ]=]--
	negt = (negt == '-') and (self.signDisplay ~= 'never');
	if post == "nan" then
		post = parts and { type = "nan", value = self.symbols.nan } or self.symbols.nan;
	elseif post == 'inf' then
		post = parts and { type = "infinity", value = self.symbols.infinity } or self.symbols.infinity;
	elseif self.notation == "standard" or self.notation == "compact" then
		--[=[ Standard formatting ]=]--
		local intg, frac = post:match("^(%d*)%.?(%d*)$");
		local gs = (self.standardNPattern or standardPattern).metadata.integerGroupSize;
		if (self.useGrouping) and (gs) and (#intg >= gs[1] + self.minimumGroupingDigits) then
			local sym = ((self.style == "currency" and self.symbols.currencyGroup) or self.symbols.group);
			local ret, rem =
				parts
					and checker.initializepart{ { type = "group", value = sym }, { type = "integer", value = checker.substitute(intg:sub(-gs[1]), self.numberingSystem) }, }
					or sym .. checker.substitute(intg:sub(-gs[1]), self.numberingSystem),
				intg:sub(1, -(gs[1] + 1));
			while #rem > gs[2] do
				ret, rem =
					checker.addtofirstpart('group', sym,
						checker.addtofirstpart("integer", checker.substitute(rem:sub(-gs[1]), self.numberingSystem), ret)),
					rem:sub(1, -(gs[1] + 1));
			end;
			intg = checker.addtofirstpart("integer", checker.substitute(rem, self.numberingSystem), ret);
		elseif parts then
			intg = { type = "integer", value = checker.substitute(intg, self.numberingSystem) };
		else
			intg = checker.substitute(intg, self.numberingSystem);
		end;
		
		if frac == '' then
			post = intg;
		elseif parts then
			post = checker.addpart(intg, 'decimal', ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal));
			checker.addpart(post, 'fraction', checker.substitute(frac, self.numberingSystem));
		else
			post = intg .. ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal) .. checker.substitute(frac, self.numberingSystem);
		end;
	else
		local intg, frac = post:match("^(%d*)%.?(%d*)$");
		if parts then
			post = {
				{ type = "integer", value = checker.substitute(intg, self.numberingSystem) },
				frac ~= '' and { type = "decimal", value = ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal) },
				frac ~= '' and { type = "fraction", value = checker.substitute(frac, self.numberingSystem) },
				{ type = "exponentSeparator", value = self.symbols.exponential },
				{ type = "exponentInteger", value = checker.substitute(expt, self.numberingSystem) },
			};
			if not post[2] then
				table.remove(post, 2);
				table.remove(post, 2);
			end;
		else
			post = checker.substitute(post, intg)
				.. ((self.style == "currency" and self.symbols.currencyDecimal) or self.symbols.decimal)
				.. checker.substitute(post, frac)
				.. self.symbols.exponential
				.. checker.substitute(expt, self.numberingSystem);
		end;
	end;
	
	local start = parts and checker.initializepart() or '';
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
	local standard = format_pattern(self, selectedPattern and (parts and checker.initializepart() or '') or start, post, pattern, negt, false);
	
	if selectedPattern then
		standard = format_pattern(self, start, standard, selectedPattern.postoken or selectedPattern, negt, parts);
	end;
	
	--[=[ Unit ]=]--
	if self.style ~= "unit" and (self.style ~= "currency" or self.currencyDisplay == "symbol" or self.currencyDisplay == "narrowSymbol") then
		return parts and setmetatable(standard, nil) or standard;
	end;
	local unitPattern = checker.negotiate_plural_table(self.unitPattern, 'unitPattern-count-', '', self.pluralRule, standard);
	local currencyName = (self.currencyDisplay == "name") and (self.currencyData and checker.negotiate_plural_table(self.currencyData, 'displayName-count-', '', self.pluralRule, standard)) or self.currency;
	if parts then
		return setmetatable(checker.formattoparts(self.style == "unit" and "unit", checker.initializepart(), unitPattern, nil, standard, currencyName and { type = "currency", value = currencyName }));
	end;
	return (unitPattern:gsub('{0}', standard):gsub('{1}', currencyName or '{1}'));
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
	ret.midpointRounding = self.midpointRounding;
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

return nf;
