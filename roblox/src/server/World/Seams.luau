--!strict
--[[
	Seams: the pieces of a base that depend on its neighbours, so adjacent tiles read
	as one continuous build (PLAYER_EXPERIENCE_CHECKLIST 6.9).

	- Foundations are exact 12 x 12 deck slabs whose tiling material lines up
	  across cells (Models.deck); here a trim beam runs only along edges with no
	  foundation beyond them, so a group of tiles gets one frame around the outside.
	- No two parts share a face (checklist 6.11, no z-fighting): each beam sits just
	  outside its deck edge and is exactly one cell long, so beams abut end to end.
	  At an inside corner the east/west beam owns the shared square and the
	  north/south beam stops short of it; an outside corner gets one corner block.
	- A corner post stands at every grid vertex a wall, doorway or window touches,
	  covering the joint where walls meet and the open end of a run.

	Rebuilt as one model per plot whenever the layout changes; it's cheap (a plot is
	10 x 10 cells).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Types = require(ReplicatedStorage.Shared.Types)

local Seams = {}

local CELL = Grid.CELL_STUDS
local BEAM_DEPTH = 0.6
local BEAM_HEIGHT = 1.2
local RIM = 0.18 -- the trim stands this far proud of the deck
local SINK = 0.05 -- detail layers sit at least this far off any surface they meet

type Trim = { material: Enum.Material, color: Color3, post: "log" | "box", postSize: number }

local TRIMS: { Trim } = {
	{ material = Enum.Material.Wood, color = Color3.fromRGB(112, 86, 62), post = "log", postSize = 1.7 },
	{ material = Enum.Material.Metal, color = Color3.fromRGB(96, 88, 80), post = "box", postSize = 1.3 },
	{ material = Enum.Material.Concrete, color = Color3.fromRGB(116, 114, 110), post = "box", postSize = 1.5 },
}
local CAP = { Color3.fromRGB(62, 44, 32), Color3.fromRGB(70, 72, 76), Color3.fromRGB(70, 72, 76) }
local CAP_MATERIAL = { Enum.Material.Wood, Enum.Material.DiamondPlate, Enum.Material.DiamondPlate }
local BAND = Color3.fromRGB(132, 108, 74) -- rope lashing on log posts

local function trimFor(tier: number): Trim
	return TRIMS[math.clamp(tier, 1, #TRIMS)]
end

local function add(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function cellKey(x: number, z: number): string
	return `{x},{z}`
end

-- The beam along one exposed side of a foundation cell (plot-local studs). It lies
-- outside the cell, flush against the deck's side; `trimStart` / `trimEnd` shorten a
-- north/south beam by one beam depth where an east/west beam already fills the corner.
local function beam(
	model: Model,
	origin: Vector3,
	x: number,
	z: number,
	side: string,
	trim: Trim,
	trimStart: boolean,
	trimEnd: boolean
)
	local x0, z0 = x * CELL, z * CELL
	local top = Art.FLOOR_HEIGHT + RIM
	local y = top - BEAM_HEIGHT / 2
	local from = if trimStart then BEAM_DEPTH else 0
	local to = CELL - (if trimEnd then BEAM_DEPTH else 0)
	local length = to - from
	local mid = (from + to) / 2
	local alongX = side == "n" or side == "s"
	local size = if alongX
		then Vector3.new(length, BEAM_HEIGHT, BEAM_DEPTH)
		else Vector3.new(BEAM_DEPTH, BEAM_HEIGHT, CELL)
	local centre = if side == "n"
		then Vector3.new(x0 + mid, y, z0 - BEAM_DEPTH / 2)
		elseif side == "s" then Vector3.new(x0 + mid, y, z0 + CELL + BEAM_DEPTH / 2)
		elseif side == "w" then Vector3.new(x0 - BEAM_DEPTH / 2, y, z0 + CELL / 2)
		else Vector3.new(x0 + CELL + BEAM_DEPTH / 2, y, z0 + CELL / 2)
	local part = add(model, size, CFrame.new(origin + centre), trim.material, trim.color)
	part.CanCollide = false
end

-- The square block that closes an outside corner of the frame, at plot-local (cx, cz).
local function corner(model: Model, origin: Vector3, cx: number, cz: number, trim: Trim)
	local y = Art.FLOOR_HEIGHT + RIM - BEAM_HEIGHT / 2
	local part = add(
		model,
		Vector3.new(BEAM_DEPTH, BEAM_HEIGHT, BEAM_DEPTH),
		CFrame.new(origin + Vector3.new(cx, y, cz)),
		trim.material,
		trim.color
	)
	part.CanCollide = false
end

local function post(model: Model, origin: Vector3, vx: number, vz: number, base: number, tier: number)
	local trim = trimFor(tier)
	local height = Art.WALL_HEIGHT + 0.3 -- caps just over the wall line
	local at = origin + Vector3.new(vx * CELL, base, vz * CELL)
	local s = trim.postSize
	if trim.post == "log" then
		-- A round log standing upright (cylinders run along X, so turn it up).
		local upright = CFrame.Angles(0, 0, math.rad(90))
		add(
			model,
			Vector3.new(height, s, s),
			CFrame.new(at + Vector3.new(0, height / 2, 0)) * upright,
			trim.material,
			trim.color,
			Enum.PartType.Cylinder
		)
		add(
			model,
			Vector3.new(0.5, s + 0.12, s + 0.12),
			CFrame.new(at + Vector3.new(0, height * 0.72, 0)) * upright,
			Enum.Material.Fabric,
			BAND,
			Enum.PartType.Cylinder
		)
		add(
			model,
			Vector3.new(0.5, s + 0.12, s + 0.12),
			CFrame.new(at + Vector3.new(0, 1.4, 0)) * upright,
			Enum.Material.Fabric,
			BAND,
			Enum.PartType.Cylinder
		)
		add(
			model,
			Vector3.new(0.35, s * 0.82, s * 0.82),
			CFrame.new(at + Vector3.new(0, height + 0.17, 0)) * upright,
			CAP_MATERIAL[1],
			CAP[1],
			Enum.PartType.Cylinder
		)
	else
		-- The body starts SINK below the floor so its base never shares a plane with the collar's.
		add(
			model,
			Vector3.new(s, height + SINK, s),
			CFrame.new(at + Vector3.new(0, (height - SINK) / 2, 0)),
			trim.material,
			trim.color
		)
		add(
			model,
			Vector3.new(s + 0.3, 0.4, s + 0.3),
			CFrame.new(at + Vector3.new(0, height + 0.2, 0)),
			CAP_MATERIAL[tier],
			CAP[tier]
		)
		add(
			model,
			Vector3.new(s + 0.3, 0.6, s + 0.3),
			CFrame.new(at + Vector3.new(0, 0.3, 0)),
			CAP_MATERIAL[tier],
			CAP[tier]
		)
	end
end

-- The seam model for a plot: trim along the outside of each group of foundations,
-- and a post at every vertex a wall-layer piece touches.
function Seams.build(origin: Vector3, layout: Grid.Layout, defs: { [string]: Types.BuildPieceDef }): Model
	local model = Instance.new("Model")
	model.Name = "Seams"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local floors: { [string]: number } = {}
	local vertices: { [string]: { x: number, z: number, tier: number } } = {}
	for _, piece in layout.pieces do
		local def = defs[piece.pieceId]
		if def == nil then
			continue
		end
		if piece.layer == "floor" then
			floors[cellKey(piece.x, piece.z)] = def.tier
		elseif piece.layer == "frame" then
			local ends: { { number } } = if piece.axis == "h"
				then { { piece.x, piece.z }, { piece.x + 1, piece.z } }
				else { { piece.x, piece.z }, { piece.x, piece.z + 1 } }
			for _, v in ends do
				local key = cellKey(v[1], v[2])
				local existing = vertices[key]
				vertices[key] = { x = v[1], z = v[2], tier = math.max(def.tier, if existing then existing.tier else 0) }
			end
		end
	end

	local function has(x: number, z: number): boolean
		return floors[cellKey(x, z)] ~= nil
	end
	for key, tier in floors do
		local x, z = string.match(key, "^(-?%d+),(-?%d+)$")
		local cx, cz = tonumber(x) :: number, tonumber(z) :: number
		local trim = trimFor(tier)
		local n, s, w, e = not has(cx, cz - 1), not has(cx, cz + 1), not has(cx - 1, cz), not has(cx + 1, cz)
		if n then
			beam(model, origin, cx, cz, "n", trim, has(cx - 1, cz - 1), has(cx + 1, cz - 1))
		end
		if s then
			beam(model, origin, cx, cz, "s", trim, has(cx - 1, cz + 1), has(cx + 1, cz + 1))
		end
		if w then
			beam(model, origin, cx, cz, "w", trim, false, false)
		end
		if e then
			beam(model, origin, cx, cz, "e", trim, false, false)
		end
		local x0, z0 = cx * CELL, cz * CELL
		local half = BEAM_DEPTH / 2
		if n and w and not has(cx - 1, cz - 1) then
			corner(model, origin, x0 - half, z0 - half, trim)
		end
		if n and e and not has(cx + 1, cz - 1) then
			corner(model, origin, x0 + CELL + half, z0 - half, trim)
		end
		if s and w and not has(cx - 1, cz + 1) then
			corner(model, origin, x0 - half, z0 + CELL + half, trim)
		end
		if s and e and not has(cx + 1, cz + 1) then
			corner(model, origin, x0 + CELL + half, z0 + CELL + half, trim)
		end
	end

	for _, v in vertices do
		-- A post stands on the floor when any of the four cells around its vertex has one.
		local onFloor = floors[cellKey(v.x, v.z)] ~= nil
			or floors[cellKey(v.x - 1, v.z)] ~= nil
			or floors[cellKey(v.x, v.z - 1)] ~= nil
			or floors[cellKey(v.x - 1, v.z - 1)] ~= nil
		post(model, origin, v.x, v.z, if onFloor then Art.FLOOR_HEIGHT else 0, v.tier)
	end
	return model
end

return Seams
