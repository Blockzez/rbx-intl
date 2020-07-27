-- https://github.com/tc39/proposal-intl-segmenter
-- https://unicode.org/reports/tr29/

local localedata = require(script.Parent:WaitForChild("_localedata"));
local checker = require(script.Parent:WaitForChild("_checker"));
local sg = { };
local intl_proxy = setmetatable({ }, checker.weaktable);

local data = require(script:WaitForChild("data"));
local dictionaries = data.dictionaries;
local properties = data.properties;

local propertyNames = { 'Emoji' };

local function getproperty(name, c)
	for i = 0, 1 do
		if i > 0 or name then
			for t, v0 in next, properties[i == 0 and name or propertyNames[i]] do
				for _, v1 in ipairs(v0) do
					if type(v1) == "table" and (c >= v1[1] and c <= v1[2]) or v1 == c then
						return t;
					end;
				end;
			end;
		end;
	end;
	return 'Other';
end;

--print(getproperty('Word_Break', utf8.codepoint('ฆัง')));

local function isproperty(name, c, prop)
	if c then
		for i = 0, 1 do
			if i > 0 or name then
				if properties[i == 0 and name or propertyNames[i]][prop] then
					for _, v in ipairs(properties[i == 0 and name or propertyNames[i]][prop]) do
						if type(v) == "table" and (c >= v[1] and c <= v[2]) or v == c then
							return true;
						end;
					end;
				end;
			end;
		end;
	end;
	return false;
end;

local dict_len = math.max(dictionaries.CJ.max_length, dictionaries.Thai.max_length,
	dictionaries.Khmer.max_length, dictionaries.Lao.max_length, dictionaries.Burmese.max_length);
local function iter(self, text)
	local i, codes = 0, { };
	for i, v in utf8.codes(text) do
		table.insert(codes, v);
	end;
	return function()
		local ret = { };
		local no_break = true;
		local index = i + 1;
		
		while no_break do
			i = i + 1;
			local suppressed = false;
			if codes[i] then
				table.insert(ret, utf8.char(codes[i]));
				-- Suppressions of sentence
				if self.granularity == "sentence" and self.suppressions then
					for _, sup_txt in ipairs(self.suppressions) do
						local check = '';
						for i1 = 1, #sup_txt do
							if not codes[i + i1] then
								break;
							end;
							check = check .. utf8.char(codes[i + i1]);
							if check == sup_txt then
								suppressed = true;
								table.insert(ret, check);
								i = i + i1 + 1;
								table.insert(ret, utf8.char(codes[i]));
								break;
							end;
						end;
					end;
				elseif self.granularity == "word" then
					-- Don't break before format (expect after line break)
					if not (isproperty('Word_Break', codes[i], 'Newline') or isproperty('Word_Break', codes[i], 'CR') or isproperty('Word_Break', codes[i], 'LF')) and (isproperty('Word_Break', codes[i + 1], 'Format') or isproperty('Word_Break', codes[i + 1], 'Extend')) then
						suppressed = true;
					end;
				end;
				if not suppressed then
					local match, boundary = false, false;
					for i1, tkn in ipairs(self.ruletoken) do
						local tkn_match, tkn_boundary = tkn(codes, i);
						if tkn_match then
							match, boundary = true, tkn_boundary;
							break;
						end;
					end;
					if match then
						if boundary then
							no_break = false;
						end;
					-- Otherwise, break everywhere. GB999 & WB999
					-- Otherwise, do not break. SB998
					else
						no_break = (self.granularity == "sentence");
					end;
				end;
				-- Break CJ and Thai words via dictionary
				-- This is trickter then I thought
				-- TODO: Only include this for CJK, Thai, Khmer, Burmese and Lao character
				if (not no_break) and self.granularity == "word" and #ret <= dict_len then
					local highest_i, freq, rcount = 0, 0, 0;
					for i1 = 1, dict_len do
						if not codes[i + i1] then
							break;
						end;
						table.insert(ret, utf8.char(codes[i + i1]));
						local check = table.concat(ret);
						if dictionaries.CJ.data[check] or dictionaries.Thai.data[check]
							or dictionaries.Lao.data[check] or dictionaries.Khmer.data[check] or dictionaries.Burmese.data[check] then
							highest_i = i1;
							freq = dictionaries.CJ.data[check] or 0;
							rcount = 0;
						else
							rcount = rcount + 1;
						end;
					end;
					for _ = 1, rcount do
						table.remove(ret);
					end;
					i = i + highest_i;
					if highest_i > 0 then
						local check = '';
						local i1_len = #ret;
						-- Revert the process if higher frequncy/length is found
						for i1 = 0, dict_len - 1 do
							if not codes[i + i1] then
								break;
							end;
							check = check .. utf8.char(codes[i + i1]);
							if (i1 > i1_len and dictionaries.CJ.data[check]) or (i1 == i1_len and (dictionaries.CJ.data[check] or 0) > freq)
								or (i1 >= i1_len and (dictionaries.Thai[check] or dictionaries.Lao.data[check] or dictionaries.Khmer.data[check] or dictionaries.Burmese.data[check])) then
								i = i - highest_i;
								for _ = 1, highest_i do
									table.remove(ret);
								end;
								break;
							end;
						end;
					end;
				end;
			else
				no_break = false;
			end;
		end;
		
		if #ret == 0 then
			return nil;
		end;
		return index, table.concat(ret);
	end;
end;

local function tokenize1(str)
	if str == '' then
		return nil;
	else
		local str_tkn = str:match("%(%s*(.*)%s*%)");
		if str_tkn then
			str = { };
			for sp0, sp1 in str_tkn:gmatch('\\p{([%a_]*)=?([%a_]*)}') do
				table.insert(str, sp1 == '' and { nil, sp1 } or { sp0, sp1 });
			end;
		else
			local sp0, sp1 = str:match('\\p{([%a_]*)=?([%a_]*)}');
			str = { sp1 == '' and { nil, sp1 } or { sp0, sp1 } };
		end;
	end;
	return str;
end;

local function tokenize(id, rule)
	if rule:find("%$Format") then
		return nil;
	end;
	if id == "GB11" or id == "WB15" then
		return function(codes, i)
			-- Do not break within emoji zwj sequences.
			return isproperty('Grapheme_Cluster_Break', codes[i], 'ZWJ'), false;
		end;
	elseif id == "GB12" then
		-- Do not break within emoji flag sequences. That is, do not break between regional indicator (RI) symbols if there is an odd number of RI characters before the break point.
		return function(codes, i)
			if not isproperty('Grapheme_Cluster_Break', codes[i], 'Regional_Indicator') then
				return false, false;
			end;
			local no_of_r = 1;
			while codes[i - no_of_r] do
				if not isproperty('Grapheme_Cluster_Break', codes[i - no_of_r], 'Regional_Indicator') then
					break;
				end;
				no_of_r = no_of_r - 1;
			end;
			return true, no_of_r % 2 == 0;
		end;
	elseif id == "WB4" then
		--  Ignore Format and Extend characters, except after sot, CR, LF, and Newline. (See Section 6.2, Replacing Ignore Rules.) This also has the effect of: Any × (Format | Extend)
		return function(codes, i)
			return (isproperty('Word_Break', codes[i - 1], 'Newline') or isproperty('Word_Break', codes[i - 1], 'CR') or isproperty('Word_Break', codes[i - 1], 'LF')) and (isproperty('Word_Break', codes[i], 'Format') or isproperty('Word_Break', codes[i], 'Extend')), false;
		end;
	elseif id == "WB6" then
		return function(codes, i)
			return isproperty('Word_Break', codes[i], 'ALetter') and isproperty('Word_Break', codes[i + 2], 'ALetter')
				and isproperty('Word_Break', codes[i + 1], 'MidLetter') and isproperty('Word_Break', codes[i + 1], 'MidNumLet'), false;
		end;
	elseif id == "WB7" then
		return function(codes, i)
			return isproperty("Word_Break", codes[i - 1], 'ALetter') and  isproperty("Word_Break", codes[i + 1], 'ALetter')
				and isproperty('Word_Break', codes[i], 'MidLetter') and isproperty('Word_Break', codes[i], 'MidNumLet'), false;
		end;
	elseif id == "WB11" then
		-- Do not break within sequences, such as “3.2” or “3,456.789”.
		return function(codes, i)
			if (isproperty('Word_Break', codes[i], 'MidNum') or isproperty('Word_Break', codes[i], 'MidNumLetQ'))
				and (isproperty('Word_Break', codes[i - 1], 'Numeric') and isproperty('Word_Break', codes[i + 1], 'Numeric')) then
				return true, false;
			end;
			return false, false;
		end;
	elseif id == "SB7" then
		return function(codes, i)
			return isproperty('Sentence_Break', codes[i - 1], 'Upper') and isproperty('Sentence_Break', codes[i], 'ATerm') and isproperty('Sentence_Break', codes[i + 1], 'Upper'), false;
		end;
	elseif id == "SB8" then
		return function(codes, i)
			if (isproperty('Sentence_Break', codes[i], 'ATerm') or (isproperty('Sentence_Break', codes[i - 1], 'ATerm') and (isproperty('Sentence_Break', codes[i], 'Close') or isproperty('Sentence_Break', codes[i], 'ATerm')))
				or (isproperty('Sentence_Break', codes[i - 2], 'ATerm') and isproperty('Sentence_Break', codes[i - 1], 'Close') and isproperty('Sentence_Break', codes[i], 'Sp')))
				and (isproperty('Sentence_Break', codes[i + 2], 'Lower')) then
				return true, false;
			end;
			return false, false;
		end;
	elseif id == "SB8.1" then
		return function(codes, i)
			if ((isproperty('Sentence_Break', codes[i], 'STerm') or isproperty('Sentence_Break', codes[i], 'ATerm'))
				or ((isproperty('Sentence_Break', codes[i - 1], 'STerm') or isproperty('Sentence_Break', codes[i - 1], 'ATerm')) and (isproperty('Sentence_Break', codes[i], 'Close') or isproperty('Sentence_Break', codes[i], 'Sp')))
				or ((isproperty('Sentence_Break', codes[i - 1], 'STerm') or isproperty('Sentence_Break', codes[i - 1], 'ATerm')) and isproperty('Sentence_Break', codes[i - 1], 'Close') and isproperty('Sentence_Break', codes[i], 'Sp')))
				and (isproperty('Sentence_Break', codes[i + 1], 'SContinue') or isproperty('Sentence_Break', codes[i + 1], 'STerm') or isproperty('Sentence_Break', codes[i + 1], 'ATerm')) then
				return true, false;
			end;
			return false, false;
		end;
	elseif id == "SB9" then
		-- Break after sentence terminators, but include closing punctuation, trailing spaces, and any paragraph separator. [See note below.] Include closing punctuation, trailing spaces, and (optionally) a paragraph separator.
		return function(codes, i)
			if ((isproperty('Sentence_Break', codes[i], 'STerm') or isproperty('Sentence_Break', codes[i], 'ATerm'))
				or ((isproperty('Sentence_Break', codes[i - 1], 'STerm') or isproperty('Sentence_Break', codes[i - 1], 'ATerm')) and isproperty('Sentence_Break', codes[i], 'Close')))
				and (isproperty('Sentence_Break', codes[i + 1], 'Close') or isproperty('Sentence_Break', codes[i + 1], 'Sp') or isproperty('Sentence_Break', codes[i + 1], 'Sep') or isproperty('Sentence_Break', codes[i + 1], 'CR') or isproperty('Sentence_Break', codes[i + 1], 'LF')) then
				return true, false;
			end;
			return false, false;
		end;
	elseif id == "SB10" then
		-- A fix for SB9 according to Unicode
		return function(codes, i)
			if ((isproperty('Sentence_Break', codes[i], 'STerm') or isproperty('Sentence_Break', codes[i], 'ATerm'))
				or ((isproperty('Sentence_Break', codes[i - 1], 'STerm') or isproperty('Sentence_Break', codes[i - 1], 'ATerm'))
					and (isproperty('Sentence_Break', codes[i], 'Close') or isproperty('Sentence_Break', codes[i], 'Sp')))
				or ((isproperty('Sentence_Break', codes[i - 2], 'STerm') or isproperty('Sentence_Break', codes[i - 2], 'ATerm'))
					and isproperty('Sentence_Break', codes[i - 1], 'Close') and isproperty('Sentence_Break', codes[i], 'Sp')))
				and (isproperty('Sentence_Break', codes[i + 1], 'Sp') or isproperty('Sentence_Break', codes[i + 1], 'Sep') or isproperty('Sentence_Break', codes[i + 1], 'CR') or isproperty('Sentence_Break', codes[i + 1], 'LF')) then
				return true, false;
			end;
			return false, false;
		end;
	elseif id == "SB11" then
		return function(codes, i)
			if ((isproperty('Sentence_Break', codes[i], 'STerm') or isproperty('Sentence_Break', codes[i], 'ATerm'))
				or ((isproperty('Sentence_Break', codes[i - 1], 'STerm') or isproperty('Sentence_Break', codes[i - 1], 'ATerm'))
					and (isproperty('Sentence_Break', codes[i], 'Close') or isproperty('Sentence_Break', codes[i], 'Sp') or isproperty('Sentence_Break', codes[i], 'Sep') or isproperty('Sentence_Break', codes[i], 'CR') or isproperty('Sentence_Break', codes[i], 'LF')))
				or ((isproperty('Sentence_Break', codes[i - 2], 'STerm') or isproperty('Sentence_Break', codes[i - 2], 'ATerm')) and isproperty('Sentence_Break', codes[i - 1], 'Close')
					and (isproperty('Sentence_Break', codes[i], 'Sp') or isproperty('Sentence_Break', codes[i], 'Sep') or isproperty('Sentence_Break', codes[i], 'CR') or isproperty('Sentence_Break', codes[i], 'LF')))
				or ((isproperty('Sentence_Break', codes[i - 2], 'STerm') or isproperty('Sentence_Break', codes[i - 2], 'ATerm')) and isproperty('Sentence_Break', codes[i - 1], 'Sp')
					and (isproperty('Sentence_Break', codes[i], 'Sep') or isproperty('Sentence_Break', codes[i], 'CR') or isproperty('Sentence_Break', codes[i], 'LF')))
				or ((isproperty('Sentence_Break', codes[i - 3], 'STerm') or isproperty('Sentence_Break', codes[i - 3], 'ATerm')) and isproperty('Sentence_Break', codes[i - 2], 'Close') and isproperty('Sentence_Break', codes[i - 1], 'Sp')
					and (isproperty('Sentence_Break', codes[i], 'Sep') or isproperty('Sentence_Break', codes[i], 'CR') or isproperty('Sentence_Break', codes[i], 'LF')))) then
				return true, true;
			end;
			return false, false;
		end;
	end;
	
	-- Some rules ignored for now
	if id == "GB13" or id == "GB11" or id == "GB9.3"
		or id == "WB7.1" or id == "WB7.2" or id == "WB7.3" or id == "WB12" or id == "WB16"
		or id == "SB5" or id == "SB10" or id == "SB11" or id == "SB998" then
		return nil;
	end;
	-- Best guess
	local op = rule:find("×") and "×" or "÷";
	local left, right = rule:match("%s*(.*)%s*" .. op .. "%s*(.*)%s*");
	left, right = tokenize1(left), tokenize1(right);

	return function(codes, i)
		local l, r = codes[i], codes[i + 1];
		if not (l and r) then
			return false, false;
		end;
		local is_l, is_r = false, false;
		if left then
			for _, v in ipairs(left) do
				if isproperty(v[1], l, v[2]) then
					is_l = true;
					break;
				end;
			end;
		else
			is_l = true;
		end;
		if right then
			for _, v in ipairs(right) do
				if isproperty(v[1], r, v[2]) then
					is_r = true;
					break;
				end;
			end;
		else
			is_r = true;
		end;
		return is_l and is_r, op == '÷';
	end;
end;

local methods = checker.initalize_class_methods(intl_proxy);

function methods:Segment(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 3);
	end;
	if type((...)) ~= "string" then
		error("invalid argument #1 (string expected, got " .. typeof((...)) ..")", 3);
	end;
	return iter(self, ...)
end;

function methods:Split(...)
	if select('#', ...) == 0 then
		error("missing argument #1", 3);
	end;
	if type((...)) ~= "string" then
		error("invalid argument #1 (string expected, got " .. typeof((...)) ..")", 3);
	end;
	local ret = { };
	for _, v in iter(self, ...) do
		table.insert(ret, v);
	end;
	return ret;
end;

function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.granularity = self.granularity;
	ret.suppression = self.suppression;
	return ret;
end;

local granularity_to_id = {
	grapheme = "GB",
	word = "WB",
	sentence = "SB",
};

function sg.new(...)
	local option = checker.options('sg', ...);
	
	option.ruletoken = { };
	for _, v in ipairs(option.rules) do
		table.insert(option.ruletoken, tokenize(granularity_to_id[option.granularity] .. v[1], v[2]));
	end;
	-- Rule: Don't break between extender
	if option.granularity == "word" then
		table.insert(option.ruletoken, tokenize(nil, '×($Extend|$ZWJ)'));
	end;
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('Segmenter', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

function sg.SupportedLocalesOf(locales)
	return checker.supportedlocale('segments', locales);
end;

sg._private = {
	intl_proxy = intl_proxy
};
return sg;
