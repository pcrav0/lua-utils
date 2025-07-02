function Point2d(obj)
	return struct 'Point2d' {
		x = obj.x or 0,
		y = obj.y or 0,

		mag = function(self)
			return math.sqrt(self.x * self.x + self.y * self.y)
		end,
	}
end

print(pcall(errorf, 'a = %d', 3))

print(pcall(
	function()
		local l = const{1,2,3,4}

		l[6] = 2
	end
))

print(pcall(
	function()
		local l = const{1,2,3,4}

		l[1] = 69
	end
))

print(pcall(struct('notstruct'), {1,2,3}))
print(pcall(function() Point2d({x = 2, y = 3}).w = 5 end))

assert(
	pipe(2, math.sqrt, function(a) return a + 2 end),
	math.sqrt(2) + 2
)

do
	local p = Point2d{x = 6, y = 9}
	local s = tostring(p)

	assert(
		s == 'Point2d{["x"] = 6, ["y"] = 9}' or
		s == 'Point2d{["y"] = 9, ["x"] = 6}'
	)
end

print(pcall(list, {x = 5, y = 2}))
print(pcall(list, Point2d{x = -5, y = 0}))

do
	local l = list{1,2,5,6}

	l[1] = 5
	print(pcall(function() l['hi'] = 2 end))
	assert(tostring(l) == 'list{5, 2, 5, 6}')
end

do
	local l = const(list{1,2,3,4})

	assert(tostring(l) == 'const(list{1, 2, 3, 4})')
end


do
	local l = list{1, 2}
	l[5] = 'a'
	l[6] = 'b'

	assert(tostring(l) == 'list{1, 2, [5] = "a", [6] = "b"}')
end



print(pcall(list, const{1,2,3,4}))

do
	local p = const(Point2d{x = 3, y = 4})
	local s = tostring(p)

	assert(
		s == 'const(Point2d{["x"] = 3, ["y"] = 4})' or
		s == 'const(Point2d{["y"] = 4, ["x"] = 3})'
	)
end

assert(tostring(print) == 'print')

local s = [[fkjsdhfkjsdahfkjsdfh h kjfhds kjh hdska hk hfkhsd f]]
global_f = function() end
local f = function() end
local t = {2, {'a', 'b', [5] = 2, s}, {'b'}, 'c', 'd', f = function() end, s,s}

-- print(table.search(t, 'a'))
-- print(_G)
-- print(t)
-- print(table.search(t, 'a'))
-- print(table.search(t, 'b'))

-- print(print)
-- print(function() end)
-- print(t.f)
-- print(f)
-- print(global_f)

-- print(list({1,2,3}):map(function(v) return v * 2 end))

local g = function(x) return x - 2 end
local tmp_path = os.tmpname()
local tmp = io.open(tmp_path, 'w+')
serialize(tmp, t)
tmp:close()
local t1 = loadfile(tmp_path)()
-- print(t)
-- print(t1)
-- assert(table.eq(t, t1))

do
	local function f(a, b)
		return function()
			return a + b
		end
	end

	local a, b = 5, 3
	local file_path = os.tmpname()

	do
		local file = io.open(file_path, 'w+')
		serialize(file, f(a, b))
		file:close()
	end

	local f_from_file = loadfile(file_path)()
	assert(f_from_file() == a + b)
end
