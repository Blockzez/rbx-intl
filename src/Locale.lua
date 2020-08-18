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
	va = "variants",
	ca = "calendar",
	hc = "hourCycle",
	nu = "numberingSystem",
	co = "collation",
	cf = "caseFirst",
	ss = "suppression",
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
	calendar = true,
	hourCycle = true,
	numberingSystem = true,
	collation = true,
	caseFirst = true,
	suppression = true,
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
		return str and (#str ~= 4 and str:match("^%a%a%a?%a?%a?%a?%a?%a?$")) and localedata.getalias('languageAlias', str:lower());
	end,
	script = function(str, nomod)
		return str and str:match("^%a%a%a%a$") and (nomod and str or localedata.getalias('scriptAlias', title_case(str)));
	end,
	region = function(str, nomod)
		return str and (str:match("^%a%a$") or str:match("^%d%d%d$")) and (nomod and str or localedata.getalias('territoryAlias', str:upper()));
	end,
	variants = function(str, nomod)
		return str and (str:match("^%d%w%w%w$") or str:match("^%w%w%w%w%w%w?%w?%w?$")) and (nomod and str or str:lower());
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
	if not ret.language then
		return nil;
	end;
	
	-- The script must have exactly 4 latin characters
	if check.script(parts[1], true) then
		ret.script = localedata.getalias('scriptAlias', title_case(table.remove(parts, 1)));
	end;
	
	-- The region must only contain latin alphabets and must contain exactly 2 characters
	-- OR it must only contain western arabic numbers and must contain exactly 3 characters
	if check.region(parts[1], true) then
		ret.region = localedata.getalias('territoryAlias', table.remove(parts, 1):upper());
	end;
	
	-- The variant must only contain latin alphabets and must contain exactly 5-8 characters
	-- OR it must begin with a digit and must only contain alphanumeric characters and must contain exactly 4 character
	ret.variants = { };
	while check.variants(parts[1], true) do
		table.insert(ret.variants, table.remove(parts, 1):lower());
	end;
	table.sort(ret.variants);
	
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
			uparts[i], uparts[i + 1] = check.u(uparts[i]), check.u_item(uparts[i + 1]);
			if not (uparts[i] and uparts[i + 1]) then
				return nil;
			elseif u_alias[uparts[i]] and not ret[u_alias[uparts[i]]] then
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
	local language, script, region, variants = localedata.rawminimize(self);
	local ret = { script = script, region = region, variants = variants };
	for property, value in next, intl_proxy[self] do
		if property ~= "script" and property ~= "region" and property ~= "variants" and property ~= "baseName" then
			ret[property] = value;
		end;
	end;
	return l.new(language, ret);
end;
function methods:Maximize()
	local language, script, region, variants = localedata.rawmaximize(self);
	local ret = { script = script, region = region, variants = variants };
	for property, value in next, intl_proxy[self] do
		if property ~= "script" and property ~= "region" and property ~= "variants" and property ~= "baseName" then
			ret[property] = value;
		end;
	end;
	return l.new(language, ret);
end;
function methods:GetParent()
	self = intl_proxy[self];
	local ext = { };
	for property, value in next, self do
		if property ~= "script" and property ~= "region" and property ~= "variants" and property ~= "baseName" then
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
function methods:GetVariants()
	return table.move(intl_proxy[self].variants, 1, #intl_proxy[self].variants, 1, table.create(#intl_proxy[self].variants));
end;

local function index(self, index)
	if index == "variants" or index == "Variants" then
		return nil;
	end;
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
		if (v[2] ~= "variants" or (#self.variants == 1 and self.variants[1] == "posix")) and self[v[2]] then
			u_ext = (u_ext or '-u') .. '-' .. v[1] .. '-' .. (v[2] == "variants" and self[v[2]][1] or self[v[2]]);
		end;
	end;
	return (self.language)
		.. (self.script and ('-' .. self.script) or '')
		.. (self.region and ('-' .. self.region) or '')
		.. (self.variants[1] and (#self.variants > 1 or self.variants[1] ~= "posix") and ('-' .. table.concat(self.variants, '-')) or '')
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
			if type(options) ~= "table" then
				error("Incorrect locale information provided", 2);
			end;
			for key, value in next, options do
				if key == "variants" and type(value) == "table" then
					local copy = { };
					for i, v in ipairs(value) do
						if type(v) ~= "string" then
							error("Incorrect locale information provided", 2);
						end;
						v = check.variants(v);
						if not v then
							error("Incorrect locale information provided", 2);
						end;
						copy[i] = v;
					end;
					data[key] = copy;
				else
					if type(value) ~= "string" then
						error("Incorrect locale information provided", 2);
					end;
					value = ((key ~= 'x' and check[key]) or check.u_item)(value);
					if not value then
						error("Incorrect locale information provided", 2);
					end;
					if validOptions[key] then
						data[key] = key == "variants" and { value } or value;
					end;
				end;
			end;
		end;
		data.baseName = (data.language)
			.. (data.script and ('-' .. data.script) or '')
			.. (data.region and ('-' .. data.region) or '')
			.. (data.variants[1] and (#data.variants == 1 and data.variants[1] == "posix" and '-u-va-posix' or ('-' .. table.concat(data.variants, '-'))) or '');
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
		locale = l.new(locale);
	end;
	runtimeLocale = locale;
end;
function l.GetLocale(locale)
	return runtimeLocale or ((not l.RobloxLocale.baseName:match("^und")) and l.RobloxLocale) or l.SystemLocale;
end;


return l;
