-- Z-fighting scan (checklist 6.11): pairs of visible box faces that face the same way,
-- lie in the same plane (within EPS) and overlap in area. Covers Parts (block faces,
-- cylinder end caps skipped) and MeshPart bounding boxes are ignored (internal faces
-- can't be read through the API).
local EPS = 0.01
local AREA_EPS = 0.02
local CELL = 16
local root = workspace:FindFirstChild("World")
local parts = {}
for _, d in root:GetDescendants() do
	if d:IsA("Part") and d.Transparency < 0.95 and d.Size.Magnitude > 0.05 then
		table.insert(parts, d)
	end
end
local function faces(p)
	local cf, s = p.CFrame, p.Size / 2
	local list = {}
	local axes = {
		{ cf.RightVector, s.X, cf.UpVector, s.Y, cf.LookVector, s.Z },
		{ cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z },
		{ cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y },
	}
	for i, a in axes do
		if p.Shape == Enum.PartType.Cylinder and i ~= 1 then
			continue -- cylinder sides are curved; only the end caps are flat
		end
		if p.Shape == Enum.PartType.Ball then
			continue
		end
		for _, sign in { 1, -1 } do
			local n = a[1] * sign
			local c = cf.Position + n * a[2]
			table.insert(list, { n = n, c = c, d = n:Dot(c), u = a[3], hu = a[4], v = a[5], hv = a[6] })
		end
	end
	return list
end
local function overlap(f, g)
	for _, axis in { f.u, f.v, g.u, g.v } do
		local function span(h)
			local r = math.abs(h.u:Dot(axis)) * h.hu + math.abs(h.v:Dot(axis)) * h.hv
			local m = h.c:Dot(axis)
			return m - r, m + r
		end
		local a0, a1 = span(f)
		local b0, b1 = span(g)
		if math.min(a1, b1) - math.max(a0, b0) <= AREA_EPS then
			return false
		end
	end
	return true
end
local grid = {}
local function keys(p)
	local cf, s = p.CFrame, p.Size
	local half = (s / 2).Magnitude
	local lo, hi = cf.Position - Vector3.one * half, cf.Position + Vector3.one * half
	local out = {}
	for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
		for y = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
			for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				table.insert(out, x .. "," .. y .. "," .. z)
			end
		end
	end
	return out
end
for i, p in parts do
	for _, k in keys(p) do
		grid[k] = grid[k] or {}
		table.insert(grid[k], i)
	end
end
local cache = {}
local function facesOf(i)
	cache[i] = cache[i] or faces(parts[i])
	return cache[i]
end
local hits, checked = {}, {}
local count = 0
for _, bucket in grid do
	for a = 1, #bucket do
		for b = a + 1, #bucket do
			local i, j = bucket[a], bucket[b]
			local pk = math.min(i, j) .. ":" .. math.max(i, j)
			if checked[pk] then
				continue
			end
			checked[pk] = true
			for _, f in facesOf(i) do
				for _, g in facesOf(j) do
					if f.n:Dot(g.n) > 0.999 and math.abs(f.d - g.d) < EPS and overlap(f, g) then
						count += 1
						if #hits < 40 then
							table.insert(hits, parts[i]:GetFullName():gsub("Workspace.World.", "") .. " | " .. parts[j]:GetFullName():gsub("Workspace.World.", "") .. string.format(" n=(%.0f,%.0f,%.0f)", f.n.X, f.n.Y, f.n.Z))
						end
					end
				end
			end
		end
	end
end
return string.format("parts=%d hits=%d\n", #parts, count) .. table.concat(hits, "\n")
