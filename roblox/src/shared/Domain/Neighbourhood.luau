--!strict
--[[
	Neighbourhood: where everything stands in a Neighbourhood server (MVP_LAUNCH): Haven
	Square in the middle, the 8 plots around it (two rows facing the road through the
	square, two plots each side of it), and the Trailhead just off the square's north
	side. Offsets are in studs from the World origin. Shared by Services/Plots,
	Services/Scenery and World/Haven so they always agree.
]]

local Neighbourhood = {}

export type Tuning = {
	count: number,
	columns: number,
	spacingStuds: number,
	rowGapStuds: number,
	marginStuds: number,
	plazaHalfStuds: number,
	plazaDepthStuds: number,
}

-- Plot `index`'s centre (x, z) and which way its front faces (+1 north row, -1 south).
function Neighbourhood.plotCentre(tuning: Tuning, gridStuds: number, index: number): (number, number, number)
	local perSide = tuning.columns // 2
	local column = (index - 1) % tuning.columns
	local row = (index - 1) // tuning.columns
	local side = if column < perSide then -1 else 1
	local fromSquare = if side < 0 then perSide - 1 - column else column - perSide -- 0 = beside the square
	local inner = tuning.plazaHalfStuds + tuning.marginStuds + gridStuds / 2
	local x = side * (inner + fromSquare * tuning.spacingStuds)
	local offset = tuning.rowGapStuds / 2 + tuning.marginStuds + gridStuds / 2
	local z = if row == 0 then -offset else offset
	return x, z, if row == 0 then 1 else -1
end

-- Half the Neighbourhood's width and depth, past the outer plots' margins.
function Neighbourhood.halfWidth(tuning: Tuning, gridStuds: number): number
	local perSide = tuning.columns // 2
	local inner = tuning.plazaHalfStuds + tuning.marginStuds + gridStuds / 2
	return inner + (perSide - 1) * tuning.spacingStuds + gridStuds / 2 + tuning.marginStuds
end

function Neighbourhood.halfDepth(tuning: Tuning, gridStuds: number): number
	return tuning.rowGapStuds / 2 + tuning.marginStuds * 2 + gridStuds
end

-- Whether (x, z) is on Haven Square (the safe zone's paved middle).
function Neighbourhood.inSquare(tuning: Tuning, x: number, z: number): boolean
	return math.abs(x) <= tuning.plazaHalfStuds and math.abs(z) <= tuning.plazaDepthStuds
end

-- The VIP Lounge in the square's south-east corner: its fenced rectangle (x0..x1, z0..z1)
-- and the gate in the middle of its north side, facing the road. World/Haven fences it,
-- Services/Haven keeps non-members out.
Neighbourhood.lounge = { x0 = 14, x1 = 40, z0 = 24, z1 = 54, gateWidth = 8 }

function Neighbourhood.inLounge(x: number, z: number): boolean
	local lounge = Neighbourhood.lounge
	return x > lounge.x0 and x < lounge.x1 and z > lounge.z0 and z < lounge.z1
end

-- The Trailhead: just off the square's north side, at the Neighbourhood's edge.
function Neighbourhood.trailhead(tuning: Tuning, gridStuds: number): (number, number)
	return 0, -(Neighbourhood.halfDepth(tuning, gridStuds) + 40)
end

return Neighbourhood
