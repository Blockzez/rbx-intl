local _data = script.Parent:WaitForChild("_data");
local supplemental = require(_data:WaitForChild("supplemental"));
local Alias = require(_data:WaitForChild("Alias"));
local setinherit = require(_data:WaitForChild("setinherit"));

local commons = {
	main = _data:WaitForChild("main"),
	segments = _data:WaitForChild("segments"),
}

-- Threshold, exclues raw
local cache_threshold = 6;
local _cache = {
	data = { },
	locale = { },
};

local d = { };

local function title_case_gsub(first, other)
	return first:upper() .. other:lower();
end;
local function title_case(str)
	return str:gsub("^(.)(.*)$", title_case_gsub);
end;

local aliases = supplemental.metadata.alias;
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
		.. (#locale:GetVariants() > 0 and ('-' .. table.concat(locale:GetVariants(), '-'):upper()) or '');
end;
function d.getlocaleparts(locale)
	if type(locale) == "string" then
		local script, region;
		local variants = {};
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
		while parts[1] and (parts[1]:match("^%d%w%w%w$") or parts[1]:match("^%w%w%w%w%w%w?%w?%w?$")) do
			table.insert(variants, table.remove(parts, 1):upper());
		end;
		table.sort(variants);
		if #parts > 0 then
			return nil;
		end;
		return language, script, region, variants;
	end;
	return locale.language, locale.script, locale.region, locale:GetVariants();
end;
function d.rawmaximize(locale, exclude_und)
	local language, script, region, variant = d.getlocaleparts(locale);
	local language_script = script and (language .. '-' .. script);
	local ret0, ret1, ret2;
	if region then
		if script then
			ret0 = supplemental.likelySubtags[language_script .. '-' .. region];
		end;
		ret1 = supplemental.likelySubtags[language .. '-' .. region];
	end;
	if script then
		ret2 = supplemental.likelySubtags[language_script];
	end;
	local ret_language, ret_script, ret_region = d.getlocaleparts(ret0 or ret1 or ret2 or supplemental.likelySubtags[language] or locale);
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
		.. ((#variant > 0 and ('-' .. table.concat(variant, '-'))) or '');
end;

local reverseLikelySubtags = { };
for k, v in next, supplemental.likelySubtags do
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
	return ret_language, ret_script, ret_region, variant;
end;
function d.minimizestr(locale, exclude_und)
	local ret_language, ret_script, ret_region, variant = d.rawminimize(locale, exclude_und);
	return (ret_language)
		.. ((ret_script and ('-' .. ret_script)) or '')
		.. ((ret_region and ('-' .. ret_region)) or '')
		.. ((#variant > 0 and ('-' .. table.concat(variant, '-'))) or '');
end;

local parentlocale = supplemental.parentLocales.parentLocale;
function d.negotiateparent(locale)
	locale = d.getlocalename(locale);
	return parentlocale[locale] or (locale:match('%-') and locale:gsub("%-%w+$", '') or (locale ~= 'root' and 'root' or nil));
end;

local function deepcopymerge(t0, t1)
	local copy = { };
	if t0 then
		for k, v in next, t0 do
			if type(v) == "table" and setinherit[v] ~= 0 then
				copy[k] = deepcopymerge(v);
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
			if type(v) == "table" and setinherit[v] ~= 0 then
				if type(t0[k]) == "table" then
					if setinherit[v] == 1 then
						copy[k] = table.move(v, 1, #v, #t0[k] + 1, t0[k]);
					else
						copy[k] = deepcopymerge(t0[k], v);
					end;
				elseif Alias.isAlias(t0[k]) then
					copy[k] = Alias.new(t0[k], deepcopymerge(v));
				else
					copy[k] = deepcopymerge(v);
				end;
			else
				copy[k] = v;
			end;
		end;
	end;
	return copy;
end;

local function resolve_alias(tbl, org_table)
	for k, v in next, tbl do
		if Alias.isAlias(v) then
			tbl[k] = v:Resolve(org_table or tbl);
		elseif type(v) == "table" then
			tbl[k] = resolve_alias(v, org_table or tbl);
		end;
	end;
	return tbl;
end;

local function requireifnotnil(inst)
	return inst and require(inst);
end;

local function rawgetdata(ttype, locale)
	if locale == nil then
		return nil;
	end;
	locale = d.getlocalename(locale);
	
	return deepcopymerge(rawgetdata(ttype, d.negotiateparent(locale)), requireifnotnil(commons[ttype]:FindFirstChild(locale)));
end;

function d.getdata(ttype, locale)
	if locale == nil then
		return nil;
	end;
	locale = d.getlocalename(locale);
	if ttype == "casing" then
		local language = d.getlocaleparts(locale);
		if language == "lt" or language == "tr" or language == "az" then
			return language;
		end;
		return 'root';
	end;
	
	local localepos = table.find(_cache.locale, ttype .. '/' .. locale);
	if localepos then
		return _cache.data[localepos];
	end;
	
	local minimized, maximized = d.minimizestr(locale, true), d.maximizestr(locale, true);
	local ms = resolve_alias(deepcopymerge(rawgetdata(ttype, locale) or rawgetdata(ttype, d.negotiateparent(minimized)) or rawgetdata(ttype, d.negotiateparent(maximized)),
		requireifnotnil(commons[ttype]:FindFirstChild(locale)) or requireifnotnil(commons[ttype]:FindFirstChild(minimized)) or requireifnotnil(commons[ttype]:FindFirstChild(maximized))));
	
	-- Merge calendar
	if ms and ms.dates and ms.dates.calendars then
		local cals = ms.dates.calendars;
		local gregorian = cals.gregorian;
		for cal, ref in next, cals do
			if cal ~= "gregorian" and cal ~= "generic" then
				cals[cal] = deepcopymerge(gregorian, ref);
			end;
		end;
	end;
	
	table.insert(_cache.data, 1, ms or false);
	table.insert(_cache.locale, 1, ttype .. '/' .. locale);
	table.remove(_cache.data, cache_threshold);
	table.remove(_cache.locale, cache_threshold);
	return ms;
end;

function d.exists(ttype, locale)
	if locale == nil or locale == "root" then
		return false;
	elseif ttype == "casing" then
		return true;
	end;
	locale = d.getlocalename(locale);
	
	local minimized, maximized = d.minimizestr(locale, true), d.maximizestr(locale, true);
	return not not (d.exists(d.negotiateparent(minimized)) or d.exists(d.negotiateparent(maximized))
		or commons[ttype]:FindFirstChild(locale) or commons[ttype]:FindFirstChild(minimized) or commons[ttype]:FindFirstChild(maximized));
end;

d.supplemental = supplemental;

local casing = _data:WaitForChild("casing");
d.casing = {
	caseMapping = require(casing:WaitForChild("caseMapping")),
	moreAbove = require(casing:WaitForChild("moreAbove")),
	specialCasing = require(casing:WaitForChild("specialCasing")),
};

return d;
