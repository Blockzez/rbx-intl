local LocalizationSvc = game:GetService("LocalizationService");
local localedata = require(script.Parent:WaitForChild("_localedata"));
local intl_proxy = setmetatable({ }, { __mode = 'k' });
local l = { };
l._private =
{
	intl_proxy = intl_proxy,
};

local u_alias =
{
	va = "variant",
	ca = "calendar",
	hc = "hourCycle",
	nu = "numberingSystem",
	co = "collation",
	cf = "caseFirst",
};

local u_extension_order = { };
for k, v in next, u_alias do
	table.insert(u_extension_order, { k, v });
end;
table.sort(u_extension_order, function(l, r)
	return l[1] < r[1];
end);

local validOptions = {
	region = true,
	script = true,
	variant = true,
	calendar = true,
	hourCycle = true,
	numberingSystem = true,
	collation = true,
	caseFirst = true,
};

-- https://www.unicode.org/reports/tr35/#Identifiers
-- We're not using the -t- extension

--[=[ Private methods ]=]--
local function title_case_gsub(first, other)
	return first:upper() .. other:lower();
end;
local function title_case(str)
	return str:gsub("^(.)(.*)$", title_case_gsub);
end;
local check = {
	language = function(str)
		return str and (str:match("^%a%a%a?%a?%a?%a?%a?%a?$") and #str ~= 4) and str:lower();
	end,
	script = function(str)
		return str and str:match("^%a%a%a%a$") and title_case(str);
	end,
	region = function(str)
		return str and (str:match("^%a%a$") or str:match("^%d%d%d$")) and str:upper();
	end,
	variant = function(str)
		return str and (str:match("^%d%w%w%w$") or str:match("^%w%w%w%w%w%w?%w?%w?$")) and str:upper();
	end,
	u = function(str)
		return str and str:match("^%w%w%w?%w?%w?%w?%w?%w?$") and str:lower();
	end,
	u_item = function(str)
		return str and str:match("^%w%w%w%w?%w?%w?%w?%w?$") and str:lower();
	end;
	x = function(str)
		return str and str:match("^%w%w?%w?%w?%w?%w?%w?%w?$");
	end,
};

local function parse_identifier(identifier)
	-- The -x- identifier, we don't need this.
	local x_ext, nil_check;
	identifier, x_ext, nil_check = unpack(identifier:split('-x-'));
	
	if nil_check then
		return nil;
	end;
	
	-- -x- extension
	if x_ext then
		local xparts = x_ext:split('-');
		
		if #xparts % 2 == 1 then
			-- Odd number indicate unfinished locale like nu-example-co
			return nil;
		end;
		
		for i = 1, #xparts, 2 do
			if not (check.x(xparts[i]) and check.x(xparts[i + 1])) then
				return nil;
			end;
		end;
	end;
	
	local lang_id, u_ext;
	lang_id, u_ext, nil_check = unpack(identifier:split('-u-'));
	-- Invalid language check or an extra -u-
	if nil_check then
		return nil;
	end;
	
	local parts = lang_id:split('-');
	
	-- https://www.unicode.org/reports/tr35/#Unicode_language_identifier
	local ret = { };
	local part;
	
	-- The language must have exactly 2 - 3 or 5 - 8 latin characters
	ret.language = check.language(table.remove(parts, 1));
	if ret.language then
		ret.language = ret.language:lower();
	else
		return nil;
	end;
	
	-- The script must have exactly 4 latin characters
	if check.script(parts[1]) then
		ret.script = title_case(table.remove(parts, 1));
	end;
	
	-- The region must only contain latin alphabets and must contain exactly 2 characters
	-- OR it must only contain western arabic numbers and must contain exactly 3 characters
	if check.region(parts[1]) then
		ret.region = table.remove(parts, 1):upper();
	end;
	
	-- The variant must only contain latin alphabets and must contain exactly 5-8 characters
	-- OR it must begin with a digit and must only contain alphanumeric characters and must contain exactly 4 character
	if check.variant(parts[1]) then
		ret.variant = table.remove(parts, 1):upper();
	end;
	
	-- An extra/invalid part
	if parts[1] then
		return nil;
	end;
	
	-- -u- extension
	if u_ext then
		local uparts = u_ext:split('-');
		
		if #uparts % 2 == 1 then
			-- Odd number indicate unfinished locale like nu-example-co
			return nil;
		end;
		
		for i = 1, #uparts, 2 do
			uparts[i], uparts[i + 1] = check.u(uparts[i]), check.u(uparts[i + 1]);
			if not (uparts[i] and uparts[i + 1]) then
				return nil;
			elseif u_alias[uparts[i]] then
				ret[u_alias[uparts[i]]] = uparts[i + 1];
			end;
		end;
	end;
	
	-- The table containing the information
	return ret;
end;

--[=[ Class methods ]=]--
local methods = setmetatable({ }, {
	__newindex = function(self, index, func)
		rawset(self, index, function(value, ...)
			if not intl_proxy[value] then
				error("Expected ':' not '.' calling member function " .. index, 2);
			end;
			return func(value, ...);
		end);
	end
});

function methods:Minimize()
	local language, script, region, variant = localedata.rawminimize(self);
	local ret = { script = script, region = region, variant = variant };
	for property, value in next, intl_proxy[self] do
		if property ~= "script" and property ~= "region" and property ~= "variant" and property ~= "baseName" then
			ret[property] = value;
		end;
	end;
	return l.new(language, ret);
end;
function methods:Maximize()
	local language, script, region, variant = localedata.rawmaximize(self);
	local ret = { script = script, region = region, variant = variant };
	for property, value in next, intl_proxy[self] do
		if property ~= "script" and property ~= "region" and property ~= "variant" and property ~= "baseName" then
			ret[property] = value;
		end;
	end;
	return l.new(language, ret);
end;
function methods:GetParent()
	self = intl_proxy[self];
	local ext = { };
	for property, value in next, self do
		if property ~= "script" and property ~= "region" and property ~= "variant" and property ~= "baseName" then
			ext[property] = value;
		end;
	end;
	local ret = localedata.negotiateparent(localedata.getlocalename(self));
	if ret == "root" then
		if self.language == "und" then
			return nil;
		end;
		return l.new('und', ext);
	end;
	return l.new(ret, ext);
end;

local function index(self, index)
	if methods[index] then
		return methods[index];
	elseif intl_proxy[self][index] then
		return intl_proxy[self][index];
	elseif (index:sub(1, 1) >= 'A' and index:sub(1, 1) <= 'Z') and (index:sub(2) == index:sub(2):lower()) then
		return intl_proxy[self][index:lower()];
	end;
	return nil;
end;

local function tostr(self)
	self = intl_proxy[self];
	local u_ext;
	for _, v in next, u_extension_order do
		if self[v[2]] then
			u_ext = (u_ext or '-u') .. '-' .. v[1] .. '-' .. self[v[2]];
		end;
	end;
	return (self.language)
		.. (self.script and ('-' .. self.script) or '')
		.. (self.region and ('-' .. self.region) or '')
		.. (self.variant and ('-' .. self.variant) or '')
		.. (u_ext or '');
end;

local function eq(self, other)
	local self, other = intl_proxy[self], intl_proxy[other];
	for k, v in next, self do
		if v ~= other[k] then
			return false;
		end;
	end;
	for k, v in next, other do
		if v ~= self[k] then
			return false;
		end;
	end;
	return true;
end;

--[=[ Constructor ]=]--
local function readonly(self, index, value)
	if type(index) ~= "string" and type(index) ~= "number" then
		error(typeof(index) .. " cannot be assigned to", 2);
	end;
	error(index .. " cannot be assigned to", 2);
end;
function l.new(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 2);
	end;
	
	local value, options = ...;
	local data;
	if type(value) == "string" then
		data = parse_identifier(value);
		if not data then
			error("Incorrect locale information provided", 2);
		end;
		if options then
			for key, value in next, options do
				value = ((key ~= 'x' and check[key]) or check.u)(value);
				if not value then
					error("Incorrect locale information provided", 2);
				end;
				if validOptions[key] then
					data[key] = value;
				end;
			end;
		end;
		data.baseName = (data.language)
			.. (data.script and ('-' .. data.script) or '')
			.. (data.region and ('-' .. data.region) or '')
			.. (data.variant and ((data.variant == 'POSIX' and '-u-va-' or '-') .. data.variant:lower()) or '');
	elseif intl_proxy[value] then
		-- Locale data, since this is immutible it doesn't matter whether it's passed by referenece or not
		data = intl_proxy[value];
	else
		-- As no valid Unicode BCP 47 locale contain only numbers
		-- There's no point converting it to string
		error("Incorrect locale information provided", 2);
	end;
	
	local object = newproxy(true);
	local mt = getmetatable(object);
	
	intl_proxy[object] = data;
	mt.__index = index;
	mt.__tostring = tostr;
	mt.__newindex = readonly;
	mt.__eq = eq;
	mt.__metatable = "The metatable is locked";
	return object;
end;

--[=[ Access values ]=]--
local function get_roblox_locale()
	return l.new(LocalizationSvc.RobloxLocaleId);
end;
local function get_system_locale()
	return l.new(LocalizationSvc.SystemLocaleId);
end;
local function update_roblox_locale_id()
	local success, locale = pcall(get_roblox_locale);
	l.RobloxLocale = (success and locale) or l.new('und-Zzzz-ZZ');
end;
local function update_system_locale_id()
	local success, locale = pcall(get_system_locale);
	l.SystemLocale = (success and locale) or l.new('und-Zzzz-ZZ');
end;
update_roblox_locale_id();
update_system_locale_id();
LocalizationSvc:GetPropertyChangedSignal("RobloxLocaleId"):Connect(update_roblox_locale_id);
LocalizationSvc:GetPropertyChangedSignal("SystemLocaleId"):Connect(update_system_locale_id);
local runtimeLocale;
function l.SetLocale(locale)
	if locale ~= nil and (not intl_proxy[locale]) then
		locale = locale.new(locale);
	end;
	runtimeLocale = locale;
end;
function l.GetLocale(locale)
	return runtimeLocale or l.RobloxLocale or l.SystemLocale or l.new('und-Zzzz-ZZ');
end;

return l;
