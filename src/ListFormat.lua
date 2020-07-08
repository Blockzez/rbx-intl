local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local lf = { };
lf._private =
{
	intl_proxy = intl_proxy,
};

local function format_to_parts(self, value)
	local ret, pret = nil, checker.checker.initializepart();
	for _, v in ipairs((#value == 2) and self.t or self.s) do
		if v == 0 then
			pret = pret .. { type = "element", value = value[1] };
		elseif v == 1 then
			pret = pret .. { type = "element", value = value[2] };
		else
			pret = pret .. { type = "literal", value = v };
		end;
	end;
	if #value > 2 then
		for i0 = 3, #value do
			ret = checker.checker.initializepart();
			for i1, v1 in ipairs((i0 == #value and self.e) or self.m) do
				if v1 == 0 then
					ret = ret .. pret;
				elseif v1 == 1 then
					ret = ret .. { type = "element", value = value[i0] };
				else
					ret = ret .. { type = "literal", value = v1 };
				end;
			end;
			pret = ret;
		end;
	else
		pret = ret
	end;
	
	return setmetatable(ret, nil);
end;

local function format(self, value)
	local len = #value;
	if type(value[1]) ~= "string" then
		error("yielded " .. tostring(value[1]) .. " which is not a string", 4);
	elseif type(value[len]) ~= "string" then
		error("yielded " .. tostring(value[len]) .. " which is not a string", 4);
	elseif len > 1 and type(value[len - 1]) ~= "string" then
		error("yielded " .. tostring(value[len - 1]) .. " which is not a string", 4);
	elseif len > 1 and type(value[2]) ~= "string" then
		error("yielded " .. tostring(value[2]) .. " which is not a string", 4);
	end;
	if len == 0 then
		return '';
	elseif len == 1 then
		return tostring(value[1]);
	elseif len == 2 then
		return self.pattern['2']:gsub("{0}", value[1]):gsub("{1}", value[2]);
	end;
	local ret = self.pattern['start']:gsub('{0}', value[1]);
	for i = 2, len - 2 do
		if len > 1 and type(value[i]) ~= "string" then
			error("yielded " .. tostring(value[i]) .. " which is not a string", 4);
		end;
		ret = ret:gsub('{1}', self.pattern['middle']:gsub('{0}', value[i], self.locale, self.options));
	end;
	return ret:gsub('{1}', self.pattern['end']:gsub('{0}', value[len - 1]):gsub('{1}', value[len]));
end;


local methods = checker.initalize_class_methods(intl_proxy);
function methods:Format(...)
	local len = select('#', ...);
	if len < 1 then
		error("missing argument #1 (table expected)", 3);
	end;
	return (format(self, (...), { }));
end;
function methods:FormatToParts(...)
	local len = select('#', ...);
	if len < 1 then
		error("missing argument #1 (table expected)", 3);
	end;
	return (format_to_parts(self, (...), { }));
end;
function methods:ResolvedOptions()
	local ret = { };
	ret.locale = self.locale;
	ret.type = self.type;
	ret.style = self.style;
	return ret;
end;

function lf.new(...)
	local option = checker.options('lf', ...);
	
	local pointer = newproxy(true);
	local pointer_mt = getmetatable(pointer);
	intl_proxy[pointer] = option;
	
	pointer_mt.__index = methods;
	pointer_mt.__tostring = checker.tostring('ListFormat', pointer);
	pointer_mt.__newindex = checker.readonly;
	pointer_mt.__metatable = checker.lockmsg;
	return pointer;
end;

return lf;
