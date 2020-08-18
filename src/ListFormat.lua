local checker = require(script.Parent:WaitForChild("_checker"));
local intl_proxy = setmetatable({ }, checker.weaktable);
local lf = { };

local function format(self, parts, value)
	local len = #value;
	if len == 0 then
		return parts and { } or '';
	elseif type(value[1]) ~= "string" then
		error("yielded " .. typeof(value[1]) .. " which is not a string", 4);
	elseif len == 1 then
		return parts and { { type = "element", value = value[1] } } or value[1];
	elseif type(value[2]) ~= "string" then
		error("yielded " .. typeof(value[2]) .. " which is not a string", 4);
	end;
	
	local ret, pret = nil, parts and checker.initializepart() or checker.initializestringbuilder{};
	for _, v in ipairs((len == 2) and self.t or self.s) do
		if v == 0 then
			checker.addpart(pret, "element", value[1]);
		elseif v == 1 then
			checker.addpart(pret, "element", value[2]);
		else
			checker.addpart(pret, "literal", v);
		end;
	end;
	if len > 2 then
		for i0 = 3, len do
			if type(value[i0]) ~= "string" then
				error("yielded " .. typeof(value[i0]) .. " which is not a string", 4);
			end;
			ret = parts and checker.initializepart() or checker.initializestringbuilder{};
			for i1, v1 in ipairs((i0 == len and self.e) or self.m) do
				if v1 == 0 then
					ret = ret .. pret;
				elseif v1 == 1 then
					checker.addpart(ret, "element", value[i0]);
				else
					checker.addpart(ret, "literal", v1);
				end;
			end;
			pret = ret;
		end;
	end;
	
	return parts and setmetatable(pret, nil) or table.concat(pret);
end;
local methods = checker.initalize_class_methods(intl_proxy);
function methods:Format(...)
	local len = select('#', ...);
	if len < 1 then
		error("missing argument #1 (table expected)", 3);
	end;
	return (format(self, false, (...)));
end;
function methods:FormatToParts(...)
	local len = select('#', ...);
	if len < 1 then
		error("missing argument #1 (table expected)", 3);
	end;
	return (format(self, true, (...)));
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

function lf.SupportedLocalesOf(locales)
	return checker.supportedlocale('main', locales);
end;

lf._private = {
	format = format,
	intl_proxy = intl_proxy,
};
return lf;
