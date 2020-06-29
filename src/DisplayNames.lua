local checker = require(script.Parent:WaitForChild("_checker"));
local localedata = require(script.Parent:WaitForChild("_localedata"));
local Locale = require(script.Parent:WaitForChild("Locale"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local dn = { };
dn._private =
{
	intl_proxy = intl_proxy,
};

local function negotiate_table(tbl, index, style)
	return (style == "narrow" and tbl[index .. '-alt-narrow']) or ((style == "short" or style == "narrow") and tbl[index .. '-alt-short']) or tbl[index]
end;

local function checkvalid(code, type)
	if type == "script" then
		code = code:match("^%a%a%a%a$") and (code:sub(1, 1):upper() .. code:sub(2):lower());
	elseif type == "region" then
		code = (code:match("^%a%a$") or code:match("^%d%d%d$")) and code:upper();
	elseif type == "variant" then
		code = (code:match("^%d%w%w%w$") or code:match("^%w%w%w%w%w%w?%w?%w?$")) and code:upper();
	elseif type == "currency" then
		code = code:match("^%a%a%a$") and code:upper();
	end;
	if not code then
		error("'" .. code .. "' is not a valid " .. type, 5);
	end;
	return code;
end;

local function parselangugage(displaynames, pattern, code, style, fallback)
	local language, script, region, variant = localedata.getlocaleparts(code);
	if not language then
		error("'" .. code .. "' is not a valid locale identifier", 5);
	end;
	local pattern0;
	if script and region
		and negotiate_table(displaynames.languages, language .. '-' .. script .. '-' .. region, style) then
		pattern0 = negotiate_table(displaynames.languages, language .. '-' .. script .. '-' .. region, style);
		script = nil;
		region = nil;
	elseif script and negotiate_table(displaynames.languages, language .. '-' .. script, style) then
		pattern0 = negotiate_table(displaynames.languages, language .. '-' .. script, style);
		script = nil;
	elseif region and negotiate_table(displaynames.languages, language .. '-' .. region, style) then
		pattern0 = negotiate_table(displaynames.languages, language .. '-' .. region, style);
		region = nil;
	else
		pattern0 = displaynames.languages[language];
	end;
	if not pattern0 then
		if not fallback then
			return nil;
		end;
		pattern0 = language;
	end;
	if not fallback then
		if script and not displaynames.scripts[script] then
			return nil;
		elseif region and not displaynames.territories[region] then
			return nil;
		elseif variant and not displaynames.variants[variant] then
			return nil;
		end;
	end;
	local pattern1;
	for _, v in ipairs {
			negotiate_table(displaynames.scripts, script, style) or script or false,
			displaynames.territories[region] or region or false,
			displaynames.variants[variant] or variant or false } do
		if v then
			if pattern1 then
				pattern1 = pattern.localeSeparator:gsub('{0}', pattern1):gsub('{1}', v);
			else
				pattern1 = v;
			end;
		end;
	end;
	return pattern1 and pattern.localePattern:gsub('{0}', pattern0):gsub('{1}', pattern1) or pattern0;
end;

local function of(self, code)
	if self.type == "language" then
		if type(code) ~= "string" and not Locale._private.intl_proxy[code] then
			error("invalid argument #3 (string expected got " .. typeof(code) .. ')', 4);
		end;
		return parselangugage(self.data, self.pattern, code, self.style, self.fallback == "code");
	end;
	local ret = negotiate_table(self.data, code, self.style) or (self.fallback == "code" and code) or nil;
	if self.type == "currency" then
		return ret.displayName;
	end;
	return ret;
end;

local methods = checker.initalize_class_methods(intl_proxy);
function methods:Of(...)
	if select('#', ...) == 0 then
		error("missing argument #1 (string expected)", 3);
	end;
	return of(self, (...));
end;
function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.type = self.type;
	ret.style = self.style;
	
	return ret;
end;

function dn.new(...)
	local option = checker.options('dn', ...);
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('DisplayNames', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

return dn;