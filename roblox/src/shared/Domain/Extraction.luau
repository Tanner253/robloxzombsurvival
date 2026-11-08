--!strict
--[[
	Extraction: getting out of a Fog Run alive (GAME_DESIGN "Rules by fog tier";
	checklist 12.5).

	- Light fog (ExtractionDef kind "edge"): walk out of any edge. A short fog-out
	  (Tuning.extraction.edgeSeconds) like leaving the Neighbourhood.
	- Dense and Black (kind "points"): 2-3 marked points. `closeCount` of them are
	  shut for the whole lobby, chosen by the lobby seed, so every lobby is a little
	  different but everyone in it sees the same exits.
	- Point channels take pointSeconds and break on damage, on death, or on leaving
	  radiusStuds of where they started.
	- Black fog's flare extract: fire a flare and survive flareSeconds. Damage does
	  not break it (surviving is the test); dying or walking off does.

	A channel is a plain record; `summarize` builds the results panel. Pure.
]]

local Types = require("../Types")
local Plane = require("./Plane")
local Rng = require("./Rng")

local Extraction = {}

export type Config = Types.ExtractionTuning
export type Kind = "edge" | "point" | "flare"
export type Event = "damage" | "moved" | "death"
export type Reason = "unknown" | "closed" | "noEdge" | "noFlare"

-- The point IDs an "edge" location and the flare extract answer to.
Extraction.EDGE = "edge"
Extraction.FLARE = "flare"

export type Channel = {
	userId: number,
	pointId: string,
	kind: Kind,
	startedAt: number,
	endsAt: number,
	anchor: Plane.Point,
}

export type Outcome = "extracted" | "died" | "lost" | "left"

export type RunStats = {
	outcome: Outcome,
	fogTier: number,
	enteredAt: number,
	endedAt: number,
	kills: number,
	containersSearched: number,
	carriedOut: { Types.ItemStack }, -- what came home (empty unless extracted)
}

export type Result = {
	outcome: Outcome,
	seconds: number,
	kills: number,
	containersSearched: number,
	carriedOut: { Types.ItemStack },
	xp: number,
}

-- The open point IDs for a lobby seed, in data order. Edge locations have none.
function Extraction.openPoints(def: Types.ExtractionDef, seed: number): { string }
	if def.kind ~= "points" then
		return {}
	end
	local ids: { string } = {}
	for _, point in def.points do
		table.insert(ids, point.id)
	end
	-- Shut closeCount of them: a seeded partial shuffle picks which.
	local rng = Rng.new(seed)
	local closed: { [string]: boolean } = {}
	local pool = table.clone(ids)
	for _ = 1, math.min(def.closeCount, #pool - 1) do
		local index = rng:NextInteger(1, #pool)
		closed[pool[index]] = true
		table.remove(pool, index)
	end
	local open: { string } = {}
	for _, id in ids do
		if not closed[id] then
			table.insert(open, id)
		end
	end
	return open
end

function Extraction.isOpen(def: Types.ExtractionDef, seed: number, pointId: string): boolean
	for _, id in Extraction.openPoints(def, seed) do
		if id == pointId then
			return true
		end
	end
	return false
end

local function known(def: Types.ExtractionDef, pointId: string): boolean
	if def.kind ~= "points" then
		return false
	end
	for _, point in def.points do
		if point.id == pointId then
			return true
		end
	end
	return false
end

--[[
	Starts a channel at `pointId` ("edge" in Light fog, "flare" for Black fog's
	flare extract, else a point ID). The service checks the player stands at the
	point (or the edge) first. Returns the channel, or nil and a reason.
]]
function Extraction.begin(
	def: Types.ExtractionDef,
	seed: number,
	pointId: string,
	userId: number,
	position: Plane.Point,
	now: number,
	config: Config
): (Channel?, Reason?)
	local kind: Kind
	local seconds: number
	if def.kind == "edge" then
		if pointId ~= Extraction.EDGE then
			return nil, "unknown"
		end
		kind, seconds = "edge", config.edgeSeconds
	elseif pointId == Extraction.EDGE then
		return nil, "noEdge"
	elseif pointId == Extraction.FLARE then
		if not def.flare then
			return nil, "noFlare"
		end
		kind, seconds = "flare", config.flareSeconds
	elseif not known(def, pointId) then
		return nil, "unknown"
	elseif not Extraction.isOpen(def, seed, pointId) then
		return nil, "closed"
	else
		kind, seconds = "point", config.pointSeconds
	end
	return {
		userId = userId,
		pointId = pointId,
		kind = kind,
		startedAt = now,
		endsAt = now + seconds,
		anchor = { x = position.x, z = position.z },
	},
		nil
end

-- Whether `event` breaks the channel. Damage spares only the flare extract.
function Extraction.breaks(channel: Channel, event: Event): boolean
	if event == "damage" then
		return channel.kind ~= "flare"
	end
	return true
end

-- Whether the player has wandered off the spot they channel from.
function Extraction.outOfRange(channel: Channel, position: Plane.Point, config: Config): boolean
	return Plane.distance(channel.anchor, position) > config.radiusStuds
end

function Extraction.isDone(channel: Channel, now: number): boolean
	return now >= channel.endsAt
end

function Extraction.progress(channel: Channel, now: number): number
	local length = channel.endsAt - channel.startedAt
	if length <= 0 then
		return 1
	end
	return math.clamp((now - channel.startedAt) / length, 0, 1)
end

function Extraction.remaining(channel: Channel, now: number): number
	return math.max(0, channel.endsAt - now)
end

-- The results panel for one run. XP is paid only for getting out alive.
function Extraction.summarize(stats: RunStats, config: Config): Result
	local xp = 0
	if stats.outcome == "extracted" then
		xp = config.xpByTier[stats.fogTier] or 0
	end
	return {
		outcome = stats.outcome,
		seconds = math.max(0, stats.endedAt - stats.enteredAt),
		kills = stats.kills,
		containersSearched = stats.containersSearched,
		carriedOut = if stats.outcome == "extracted" then stats.carriedOut else {},
		xp = xp,
	}
end

return Extraction
