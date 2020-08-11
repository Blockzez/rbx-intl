local localedata = require(script.Parent:WaitForChild("_localedata"));
local checker = require(script.Parent:WaitForChild("_checker"));
local p = { };
local intl_proxy = setmetatable({ }, checker.weaktable);
p._private = {
	intl_proxy = intl_proxy
};

local function is_in_range(value, range)
	if type(value) ~= "number" then
		value = tonumber(value);
	end;
	if type(range) == "number" then
		return value == range;
	end;
	if range[2] == '..' then
		return (value >= range[1]) and (value <= range[3]);
	end;
	return not not table.find(range, value);
end;


local function cldr_mod(left, right)
	-- Java modulus
	if type(left) == "string" and #left > 15 then
		if math.log10(right) % 1 == 0 then
			return left:sub(-math.log10(right));
		end;
	end;
	return math.fmod(tonumber(left), right);
end;

local index_plural_mod =
{
	__index = function(self, ind)
		if type(ind) == "table" then
			return cldr_mod(self[ind[1]], ind[2]);
		end;
	end;
};

-- https://www.unicode.org/reports/tr35/tr35-numbers.html#Operands
local function getoperand(value)
	local n, i, v, w, f, t;
	n = value:gsub('-', ''):gsub('%.$', '');
	i = n:gsub('%.%d*', '');
	if n:find('%.') then
		local frac_t = value:gsub('%d*%.', '');
		local frac_nt = frac_t:gsub('0+$', '');
		v = #frac_t;
		w = #frac_nt;
		f = frac_t == '' and '0' or frac_t;
		t = frac_nt == '' and '0' or frac_nt;
	end;
	return setmetatable({ n = n, i = i, v = v or '0', w = w or '0', f = f or '0', t = t or '0' }, index_plural_mod);
end;

local function tokenize(rule)
	local ret0 = { };
	-- This is the sample
	rule = rule:split('@')[1]:gsub('%s+', ' ');
	local or_split = rule:split(' or ');
	for _, v0 in ipairs(or_split) do
		local ret1 = { };
		local and_split = v0:split(' and ');
		for _, v1 in ipairs(and_split) do
			local left, op, right = v1:match("([^!=]+)%s*(!?=)%s*([^!=]+)");
			if left:match('%%') then
				local left1, right1 = left:match('([nivwft])%s*%%%s*(%d+)');
				left = { left1, tonumber(right1) };
			else
				left = left:gsub('%s*$', '');
			end;
			if right:match('%d+[.][.]%d+') then
				local left1, right1 = right:match('(%d+)[.][.](%d+)');
				right = { tonumber(left1), '..', tonumber(right1) };
			else
				local ret2 = right:split(',');
				for k, v in ipairs(ret2) do
					ret2[k] = tonumber(v:gsub('^%s*', ''):gsub('%s*$', ''), 10);
				end;
				right = ret2;
			end;
			table.insert(ret1, { left, op == '=', right });
		end;
		table.insert(ret0, ret1);
	end;
	return ret0;
end;

-- https://www.unicode.org/reports/tr35/tr35-numbers.html#Language_Plural_Rules
local function generate(rule)
	if not rule then
		return nil;
	elseif rule:gsub('%s', '') == '' then
		return nil;
	end;
	rule = tokenize(rule);
	return function(value)
		for _, v0 in ipairs(rule) do
			local and_op = true;
			for _, v1 in ipairs(v0) do
				if is_in_range(getoperand(value)[v1[1]], v1[3]) ~= v1[2] then
					and_op = false;
					break;
				end;
			end;
			if and_op then
				return true;
			end;
		end;
		return false;
	end;
end;

--
local function pr_select(rules, val)
	if rules then
		if rules.zero and rules.zero(val) then
			return 'zero';
		elseif rules.one and rules.one(val) then
			return 'one';
		elseif rules.two and rules.two(val) then
			return 'two';
		elseif rules.few and rules.few(val) then
			return 'few';
		elseif rules.many and rules.many(val) then
			return 'many';
		end;
	end;
	return 'other';
end;

local function pselect(self, value)
	if not self.rule then
		return 'other';
	end;
	local negt;
	negt, value = checker.num_to_str(value):match("^([%+%-]?)(%d*%.?%d*)$");
	if not value then
		return 'other';
	end;
	if self.isSignificant then
		value = checker.raw_format_sig(negt, value, self.minimumSignificantDigits, self.maximumSignificantDigits, self.rounding);
	else
		value = checker.raw_format(negt, value, self.minimumIntegerDigits, self.maximumIntegerDigits, self.minimumFractionDigits, self.maximumFractionDigits, self.rounding);
	end;
	return pr_select(self.rule, value);
end;

local methods = checker.initalize_class_methods(intl_proxy);
function methods:Select(...)
	if select('#', ...) == 0 then
		error("missing argument #1 (number expected)", 3);
	end;
	return pselect(self, (...));
end;
function methods:SelectRange(...)
	local len = select('#', ...);
	if len == 0 then
		error("Missing argument #".. (len + 1) .." (number expected)", 3);
	end;
	local value0, value1 = ...;
	local count0, count1 = pselect(self, value0), pselect(self, value1);
	return (self.rangerule and self.rangerule[count0] and self.rangerule[count0][count1]) or count1;
end;
function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.type = self.type;
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
function methods:All()
	local ret = { 'other' };
	if self.data then
		for v in ipairs{ 'many', 'few', 'two', 'one', 'zero' } do
			if self.data[v] then
				table.insert(ret, 1, v);
			end;
		end;
	end;
	return ret;
end;
function p.new(...)
	local option = checker.options('pr', ...);
	
	local data = localedata.supplemental['plurals-type-' .. option.type];
	local minimized = localedata.minimizestr(option.locale.baseName);
	local pos = minimized;
	while (data[pos] == nil) and pos do
		pos = localedata.negotiateparent(pos);
	end;
	if data[pos] then
		local rule = {
			zero = generate(data[pos].zero),
			one = generate(data[pos].one),
			two = generate(data[pos].two),
			few = generate(data[pos].few),
			many = generate(data[pos].many),
		};
		option.rule = rule;
	end;
	
	local rangedata = localedata.supplemental['plurals-type-pluralRanges'];
	pos = minimized;
	while (not rangedata[pos]) and pos do
		pos = localedata.negotiateparent(pos);
	end;
	if rangedata[pos] then
		option.rangerule = rangedata[pos];
	end;
	
	local object = newproxy(true);
	local object_mt = getmetatable(object);
	intl_proxy[object] = option;
	
	object_mt.__index = methods;
	object_mt.__tostring = checker.tostring('PluralRules', object);
	object_mt.__newindex = checker.readonly;
	object_mt.__metatable = checker.lockmsg;
	return object;
end;

function p.SupportedLocalesOf(locales)
	return checker.supportedlocale('main', locales);
end;

return p;
