--[[
	kit_detached: the Studio-side half of the floater gate (ART_DIRECTION 10a). Run it in
	Studio (Edit) through execute_luau: for every model in the kit folders, every part
	must touch another part of the same model (bounding boxes within 0.05 studs), so
	no piece of a model floats on its own. Mesh-internal islands are caught before
	upload by art/tools/glb_floaters.py. Returns "kit_detached: N models, M flags" and
	one line per detached part.
]]

local ServerStorage = game:GetService("ServerStorage")

local GAP = 0.05

local function box(part: BasePart): (Vector3, Vector3)
	local cf, size = part.CFrame, part.Size / 2
	local corners = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(corners, (cf * CFrame.new(size.X * sx, size.Y * sy, size.Z * sz)).Position)
			end
		end
	end
	local lo, hi = corners[1], corners[1]
	for _, c in corners do
		lo, hi = lo:Min(c), hi:Max(c)
	end
	return lo, hi
end

local function touches(aLo: Vector3, aHi: Vector3, bLo: Vector3, bHi: Vector3): boolean
	return aLo.X <= bHi.X + GAP
		and bLo.X <= aHi.X + GAP
		and aLo.Y <= bHi.Y + GAP
		and bLo.Y <= aHi.Y + GAP
		and aLo.Z <= bHi.Z + GAP
		and bLo.Z <= aHi.Z + GAP
end

local flags, models = {}, 0
for _, folderName in { "EO_Kit", "LT_Gen" } do
	local folder = ServerStorage:FindFirstChild(folderName)
	for _, model in (if folder then folder:GetDescendants() else {}) do
		if not model:IsA("Model") then
			continue
		end
		local parts = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Transparency < 1 then
				local lo, hi = box(child)
				table.insert(parts, { part = child, lo = lo, hi = hi })
			end
		end
		models += 1
		if #parts < 2 then
			continue
		end
		for i, a in parts do
			local ok = false
			for j, b in parts do
				if i ~= j and touches(a.lo, a.hi, b.lo, b.hi) then
					ok = true
					break
				end
			end
			if not ok then
				table.insert(flags, `{folderName}/{model:GetFullName()}: {a.part.Name} is detached`)
			end
		end
	end
end
return `kit_detached: {models} models, {#flags} flags\n` .. table.concat(flags, "\n")
