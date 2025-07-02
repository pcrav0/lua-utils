-- used for 5.2 jit only

local sbuffer = require("string.buffer")

default = {}

function switch(case)
	return function (cases)
		return match(case)(cases)()
	end
end

function match(case)
	return function (cases)
		return cases[case] or cases[default]
	end
end

function printf(fmt, ...)
	print(fmt:format(...))
end

function errorf_level(level, fmt, ...)
	error(fmt:format(...), 1 + level)
end

function errorf(fmt, ...)
	error(fmt:format(...), 3)
end

function trufy()
	return true
end

function falsy()
	return false
end

function negate(f)
	return function (...)
		return not f(...)
	end
end

function object(tbl)
	local meta = {}

	meta.__index = meta

	function meta:copy()
		return table.copy(tbl)
	end

	function meta:hash()
		return table.hash(tbl)
	end

	function meta:__tostring()
		return string.format('object(%s)', table.tostring(tbl))
	end

	return setmetatable(tbl, meta)
end

function struct(name)
	return function(tbl)
		local obj = object(tbl)
		local metaobj = getmetatable(obj)

		local data, methods = table.filter(
			tbl,
			function(v)
				return type(v) ~= 'function'
			end
		)

		table.merge(metaobj, methods)

		if #data > 0 then
			errorf_level(3, 'invalid table `%s` for `%s` struct', table.tostring(data), name)
		end

		local meta = {}
		meta.__index = metaobj.__index

		function meta.__newindex(...)
			errorf_level(2, 'cant create a new index for `%s` struct', name)
		end

		function meta:__tostring()
			return name .. table.tostring(self)
		end

		return setmetatable(data, meta)
	end
end

function const(tbl)
	if type(tbl) ~= 'table' then return end

	local meta = {}
	local old_tostring = (getmetatable(tbl) or {}).__tostring
	if not old_tostring then
		local s = table.tostring(tbl)
		old_tostring = function (self)
			return s
		end
	end

	function meta.__index(self, k)
		local v = tbl[k]

		if type(v) == 'table' then
			v = const(v)
		end

		return v
	end

	function meta.__newindex()
		error("table is constant", 2)
	end

	function meta.__tostring()
		return 'const('..old_tostring(tbl)..')'
	end

	return setmetatable({}, meta)
end

function list(tbl)
	local meta = {}

	tbl = table.copy(tbl)

	meta.__index = table

	function meta:__newindex(key, value)
		if type(key) ~= 'number' then
			errorf_level(
				2,
				'cant insert a key `%s` of type `%s` in a list',
				tostring(key), type(key)
			)
		end

		return rawset(self, key, value)
	end

	function meta:__tostring()
		return 'list' .. table.tostring(self)
	end

	if type(tbl) ~= 'table' then return end

	do
		local tbl_meta = getmetatable(tbl)

		if tbl_meta and tbl_meta.__index ~= meta.__index then
			errorf_level(3, 'cant create a list with `%s`', tostring(tbl))
		end
	end

	for k, v in pairs(tbl) do
		if type(k) ~= 'number' then
			errorf_level(3, 'cant create a list with key %q', k)
		end
	end

	return setmetatable(tbl, meta)
end

function curry(f, ...)
	local args = {...}

	return function (first)
		return f(first, table.unpack(args))
	end
end

function pipe(init, ...)
	return table.reduce(
		{...},
		init,
		function (last, current)
			if type(current) == 'function' then
				return current(last)
			elseif type(current) == 'string' then
				return last[current](last)
			elseif type(current) == 'table' then
				if type(current[1]) ~= 'function' then
					current[1] = function(...)
						return last[current[1]](...)
					end
				end
				return curry(table.unpack(current))(last)
			end
		end
	)
end

function optional(parameter, default)
	if type(parameter) == 'nil' then
		return default
	end

	return parameter
end

function table:tostring(seen, deep, i)
	seen = optional(seen, {})
	deep = optional(deep, 1)
	i = optional(i, 1)

	if table.contains(seen, self) then
		return '{...}'
	end


	local strs = table.foreach(
		self,
		function (v, k)
			local function quote_string(any)
				local t = type(any)

				return switch(t) {
					['string'] = function()
						return ('%q'):format(any)
					end,
					['table'] = function()
						table.insert(seen, any)
						return table.tostring(any, seen, deep + 1)
					end,
					['function'] = function()
						return ('%s()'):format(k)
					end,
					[default] = function()
						return tostring(any)
					end,
				}
			end

			if type(k) == 'number' and k == i then
				i = i + 1
				return quote_string(v)
			end

			return ('[%s] = %s'):format(quote_string(k), quote_string(v))
		end
	)

	local infix = ', '
	local sum = strs:map(
		function(v)
			return string.len(v..infix)
		end
	):sum()

	local tab_size = 8
	local screen_width = 80
	if sum > (screen_width - tab_size * deep) then
		strs = strs:map(
			function(v)
				return '\n' .. ('\t'):rep(deep) .. v
			end
		)
		table.insert(strs, '\n' .. ('\t'):rep(deep - 1))
	end

	return strs:concat(infix):map(
		function (r)
			return '{'..r..'}'
		end
	)
end


function table:copy(deep, seen)
    seen = seen or {}

    if self == nil then return nil end
    if seen[self] then return seen[self] end

    local result = {}
    for k, v in pairs(self) do
        if deep and type(v) == 'table' then
            result[k] = table.copy(v, deep, seen)
        else
            result[k] = v
        end
    end

    setmetatable(result, table.copy(getmetatable(self), deep, seen))
    seen[self] = result

    return result
end

function table:sum()
	return table.reduce(
		self,
		0,
		function (last, current)
			return last + current
		end
	)
end

function table:reduce(init, f)
	local result = init

	for k, v in pairs(self) do
		result = f(result, v, k)
	end

	return result
end

function table:map(f)
	local result = list{}

	for k, v in pairs(self) do
		result[k] = f(v, k)
	end

	return result
end

function table:imap(f)
	local result = list{}

	for i, v in ipairs(self) do
		result[i] = f(v, i)
	end

	return result
end

function table:foreach(f)
	local result = list{}

	for k, v in pairs(self) do
		local value = f(v, k)

		if value ~= nil then
			table.insert(result, value)
		end
	end

	return result
end

function table:iforeach(f)
	local result = list{}

	for i, v in ipairs(self) do
		local value = f(v, i)

		if value ~= nil then
			table.insert(result, value)
		end
	end

	return result
end

function table:filter(p, kind)
	kind = optional(kind, 'value')

	local result = {}
	local rest = {}

	for k, v in pairs(self) do
		local item = switch(kind) {
			['value'] = function() return v end,
			['key'] = function() return k end,
			['key-value'] = function() return {k, v} end,
		}

		if p(v, k) then
			result[k] = item
		else
			rest[k] = item
		end
	end

	return result, rest
end

function table:collect(p, kind)
	kind = kind or 'value'
	local result = list{}
	local rest = list{}

	for k, v in pairs(self) do
		local item = switch(kind) {
			['value'] = function() return v end,
			['key'] = function() return k end,
			['key-value'] = function() return {k, v} end,
		}

		if p(v, k) then
			table.insert(result, item)
		else
			table.insert(rest, item)
		end
	end

	return result, rest
end

function table:rest()
	return list{ table.unpack(self, 2) }
end

function table:contains(any)
	for k, v in pairs(self) do
		if v == any then return true end
	end

	return false
end

function table:search(value, seen, result)
	seen = optional(seen, list{})
	result = optional(result, list{})

	local keys = table.collect(self, function(v) return v == value end, 'key')

	if #keys > 0 then
		table.insert(result, keys[1])
		return result
	end

	local s = table.filter(
		self,
		function(v)
			return type(v) == 'table' and not table.contains(seen, v)
		end
	)

	for k, v in pairs(s) do
		table.insert(seen, v)
		table.insert(result, k) -- let try this key

		local r = table.search(v, value, seen, result)
		if r then
			return r -- i find it
		end

		table.remove(result, #result) -- we failed, backtrack
	end

	return nil
end

function table:flat()
	return table.collect(self, trufy, 'key-value')
end

function table:merge(other)
	local result = table.copy(self)

	table.foreach(
		other,
		function(v, k)
			result[k] = v
		end
	)

	return result
end

function table:eq(other)
	do -- check for __eq
		local self_meta = getmetatable(self)
		local other_meta = getmetatable(other)

		if self_meta and other_meta and self_meta.__eq and other_meta.__eq then
			return self == other
		end
	end

    if #self ~= #self then
		return false
	end

    for k, v in pairs(self) do
		local other_v = other[k]
		local t = type(v)

		if t ~= type(other_v) then
			return false
		end

		local check = match(t) {
			['table'] = table.eq,
			['function'] = function(a, b)
				return string.dump(a) == string.dump(b)
			end,
			[default] = function(a, b)
				return a == b
			end
		}

		if not check(v, other_v) then
			printf('%q\n%q', string.dump(v), string.dump(other_v))
			return false
		end
    end

    return true
end

function string:split(sep)
	sep = optional(sep, '[^%s]')

	local result = list{}

	for str in string.gmatch(self, '('..sep..')') do
		table.insert(result, str)
	end

	return result
end

function string:map(f)
	return f(self)
end

function debug.file()
	return debug.getinfo(2, 'S').source
end

function debug.line()
	return debug.getinfo(2, 'l').currentline
end

function debug.func()
	return debug.getinfo(2, 'n').name
end

function debug.locals(level)
	level = optional(level, 0)

	local result = {}
	local i = 1

	repeat
		local k, v = debug.getlocal(2 + level, i)

		if k then
			result[k] = v
			i = i + 1
		end
	until k == nil

	return result
end

rawtostring = tostring

function tostring(any)
	return switch(type(any)) {
		['table'] = function()
			local f = (getmetatable(any) or {}).__tostring or table.tostring
			return f(any)
		end,

		['function'] = function()
			local result = table.search(getfenv(), any)
			if not result then
				result = table.search(debug.locals(2), any)
			end

			if result then
				return table.concat(result, '.')
			end

			return rawtostring(any)

		end,
		[default] = function()
			return rawtostring(any)
		end,
	}
end

function serialize_one(any)
	return switch(type(any)) {
		['string'] = function()
			return ('%q'):format(any)
		end,
		['function'] = function()
			local success, dump = pcall(string.dump, any, true)

			if not success then -- just return the name of the function
				return tostring(any)
			end

			local upvalues = {}
			local i = 1

			while true do
				local name, value = debug.getupvalue(any, i)

				if not name then break end
				upvalues[i] = value
				i = i + 1
			end

			return ('loadclosure(%q, %s)'):format(
				dump,
				table.tostring(upvalues)
			)
		end,
		['table'] = function()
			return table.foreach(
				any,
				function(v, k)
					return ('[%s]=%s'):format(
						serialize_one(k),
						serialize_one(v)
					)
				end
			):concat(','):map(
				function(str)
					return '{'..str..'}'
				end
			)
		end,
		[default] = function()
			return tostring(any)
		end,
	}
end

function serialize(file, any)
	file:write(('return %s'):format(serialize_one(any)))
end

function loadclosure(bytecode, upvalues)
	local result = load(bytecode)

	for i, v in ipairs(upvalues) do
		debug.setupvalue(result, i, v)
	end

	return result
end

return M
