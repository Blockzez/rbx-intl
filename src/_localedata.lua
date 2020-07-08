local _data = script.Parent:WaitForChild("_data");
local _coredata = require(_data:WaitForChild("_core"));
local _cache = setmetatable({ }, { __mode = 'v' });
local d = { };

local function title_case_gsub(first, other)
	return first:upper() .. other:lower();
end;
local function title_case(str)
	return str:gsub("^(.)(.*)$", title_case_gsub);
end;

local aliases = _coredata.metadata.alias;
function d.getalias(key, val)
	return aliases[key][val] and aliases[key][val]._replacement:match("^%S+") or val;
end;
function d.getlocalename(locale)
	if type(locale) == "string" then
		return (locale:gsub('%-u%-.+', ''));
	end;
	return (locale.language)
		.. (locale.script and ('-' .. locale.script) or '')
		.. (locale.region and ('-' .. locale.region) or '')
		.. (locale.variant and ('-' .. locale.variant:upper()) or '');
end;
function d.getlocaleparts(locale)
	if type(locale) == "string" then
		local script, region, variant;
		local parts = locale:gsub('%-u%-.+', ''):split('-');
		if not (parts[1] and (parts[1]:match("^%a%a%a?%a?%a?%a?%a?%a?$") and #parts[1] ~= 4) or parts[1] == "root") then
			return nil;
		end;
		local language = d.getalias('languageAlias', table.remove(parts, 1):lower());
		if parts[1] and parts[1]:match('^%a%a%a%a$') then
			script = d.getalias('scriptAlias', title_case(table.remove(parts, 1)));
		end;
		if parts[1] and (parts[1]:match("^%a%a$") or parts[1]:match("^%d%d%d$")) then
			region = d.getalias('territoryAlias', table.remove(parts, 1):upper());
		end;
		if parts[1] and (parts[1]:match("^%d%w%w%w$") or parts[1]:match("^%w%w%w%w%w%w?%w?%w?$")) then
			variant = table.remove(parts, 1):upper();
		end;
		if #parts > 0 then
			return nil;
		end;
		return language, script, region, variant;
	end;
	return locale.language, locale.script, locale.region, locale.variant and locale.variant:upper();
end;
function d.rawmaximize(locale, exclude_und)
	local language, script, region, variant = d.getlocaleparts(locale);
	local language_script = script and (language .. '-' .. script);
	local ret0, ret1, ret2;
	if region then
		if script then
			ret0 = _coredata.likelySubtags[language_script .. '-' .. region];
		end;
		ret1 = _coredata.likelySubtags[language .. '-' .. region];
	end;
	if script then
		ret2 = _coredata.likelySubtags[language_script];
	end;
	local ret_language, ret_script, ret_region = d.getlocaleparts(ret0 or ret1 or ret2 or _coredata.likelySubtags[language] or locale);
	if language and (exclude_und or language ~= 'und') then
		ret_language = language;
	end;
	if script and (exclude_und or script ~= 'Zzzz') then
		ret_script = script;
	end;
	if region and (exclude_und or region ~= "ZZ") then
		ret_region = region;
	end;
	return ret_language, ret_script, ret_region, variant;
end;
function d.maximizestr(locale, exclude_und)
	local ret_language, ret_script, ret_region, variant = d.rawmaximize(locale, exclude_und);
	return (ret_language)
		.. ((ret_script and ('-' .. ret_script)) or '')
		.. ((ret_region and ('-' .. ret_region)) or '')
		.. ((variant and ('-' .. variant)) or '');
end;

local reverseLikelySubtags = { };
for k, v in next, _coredata.likelySubtags do
	if not k:match("^und%-") then
		reverseLikelySubtags[v] = k;
	end;
end;

function d.rawminimize(locale, exclude_und)
	local language, script, region, variant = d.getlocaleparts(locale);
	local ret0, ret1, ret2, ret3, ret4;
	local language_script = script and (language .. '-' .. script);
	local language_region = region and (language .. '-' .. region);
	if region then
		if script then
			ret0 = reverseLikelySubtags[language_script .. '-' .. region];
		else
			ret3 = reverseLikelySubtags[d.maximizestr(language_region)];
		end;
		ret1 = reverseLikelySubtags[language_region]
		if (not ret1) and script then
			ret1 = d.minimizestr(language_region);
			if ret1 == (language_region) then
				ret1 = nil;
			end;
		end;
	end;
	if script then
		ret2 = reverseLikelySubtags[language_script] or (region and d.minimizestr(language_region));
		if (not ret2) and region then
			ret2 = d.minimizestr(language_script);
			if ret2 == (language_script) then
				ret2 = nil;
			end;
		end;
		if not region then
			ret4 = reverseLikelySubtags[d.maximizestr(language_script)];
		end;
	end;
	local ret_language, ret_script, ret_region = d.getlocaleparts(ret0 or ret1 or ret2 or ret3 or ret4 or language);
	if ((not exclude_und) and ret_language == "und") then
		ret_language = language;
	end;
	if ((not ret_script) or ((not exclude_und) and ret_script == "Zzzz")) and (not (ret0 or ret2 or ret4)) then
		ret_script = script;
	end;
	if ((not ret_region) or ((not exclude_und) and ret_region == "ZZ")) and (not (ret0 or ret1 or ret3)) then
		ret_region = region;
	end;
	if ret_language == 'en' and (not ret_region) and variant == "POSIX" then
		return 'en', ret_script, 'US', 'POSIX';
	end;
	return ret_language, ret_script, ret_region, variant;
end;
function d.minimizestr(locale, exclude_und)
	local ret_language, ret_script, ret_region, variant = d.rawminimize(locale, exclude_und);
	return (ret_language)
		.. ((ret_script and ('-' .. ret_script)) or '')
		.. ((ret_region and ('-' .. ret_region)) or '')
		.. ((variant and ('-' .. variant)) or '');
end;

local parentlocale = _coredata.parentLocales.parentLocale;
function d.negotiateparent(locale)
	locale = d.getlocalename(locale);
	return parentlocale[locale] or (locale:match('%-') and locale:gsub("%-%w+$", ''));
end;

--[[
local function deepcopymerge(t0, t1, level)
	local copy = { };
	if t0 then
		-- Don't copy array and tokenised number/date format
		for k, v in next, t0 do
			if (type(v) == "table" and level ~= 0) and (#v == 0) and (not v.postoken) then
				copy[k] = deepcopymerge(v, nil, level and (level - 1));
			else
				copy[k] = v;
			end;
		end;
	elseif t1 then
		return deepcopymerge(t1);
	else
		return nil;
	end;
	if t1 then
		for k, v in next, t1 do
			if (type(v) == "table" and level ~= 0) and (#v == 0) and (not v.postoken) then
				if type(t0[k]) == "table" and (#t0[k] == 0) then
					copy[k] = deepcopymerge(t0[k], v, level and (level - 1));
				else
					copy[k] = deepcopymerge(v, nil, level and (level - 1));
				end;
			else
				copy[k] = v;
			end;
		end;
	end;
	return copy;
end;
]]

local localedataproxy = setmetatable({ }, { __mode = 'k' });
local function localedataindex(self, index)
	return localedataproxy[self][index];
end;
local function requireifnotnil(inst)
	if inst then
		local localedata = newproxy(true);
		localedataproxy[localedata] = require(inst);
		local localedata_mt = getmetatable(localedata);
		localedata_mt.__index = localedataindex;
		localedata_mt.__metatable = "The metatable is locked";
		return localedata;
	end;
	return nil;
end;

function d.getdata(locale)
	if locale == nil then
		return nil;
	end;
	locale = d.getlocalename(locale);
	
	local minimized, maximized = d.minimizestr(locale, true), d.maximizestr(locale, true);
	if _cache[locale] == nil then
		local ms = requireifnotnil(_data:FindFirstChild(minimized)) or requireifnotnil(_data:FindFirstChild(maximized));
		if ms then
			_cache[locale] = ms;
		else
			_cache[locale] = d.getdata(d.negotiateparent(minimized)) or requireifnotnil(_data:FindFirstChild(d.negotiateparent(maximized) or '')) or false;
		end;
	end;
	return _cache[locale];
end;

d.coredata = _coredata;

return d;
