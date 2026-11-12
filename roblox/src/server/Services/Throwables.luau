--!strict
--[[
	Throwables (2.0 batch 5): grenades and molotovs on a Fog Run, server-authoritative.

	CombatThrow (x, y, z): the client sends where it aims; everything else is decided here.
	- The throwable must be in the active hand of a living survivor on a run (Combat.throwHand),
	  and its interval since the last throw must have passed.
	- The aim is pulled inside the throwable's range ring (Domain/Throw.landing) and dropped
	  onto the ground there; the arc is checked segment by segment, so a wall or a tree trunk in
	  the way stops it where it hits.
	- One is spent from the stack as the hand lets go: the throw clip's release frame
	  (HoldRules.strikeDelay("throw")), so the model leaves the hand with the arm.
	- A "blast" goes off on its fuse (never in the air): every Hollow inside its radius with a
	  clear line from the centre takes Throw.blastDamage by its distance, and is knocked back.
	- A "fire" bursts on landing and burns its area: a tick every burnTickSeconds hurts every
	  Hollow standing in it.
	- Both make noise (Hollow.noise "blast" at the throwable's noiseRadius), so a grenade pulls
	  the map toward it. Survivors take no damage: PvP is M2, as with guns.

	Clients draw it from the "throw", "blast" and "fire" effects (Controllers/Throwing).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local HoldRules = require(ReplicatedStorage.Shared.Domain.HoldRules)
local Plane = require(ReplicatedStorage.Shared.Domain.Plane)
local Throw = require(ReplicatedStorage.Shared.Domain.Throw)
local ArcCast = require(ReplicatedStorage.Shared.Util.ArcCast)
local Net = require("../Net")
local Combat = require("./Combat")
local Hollow = require("./Hollow")
local Lobby = require("./Lobby")
local Sync = require("./Sync")

local Throwables = {}

local tuning = Content.Tuning
local Items: any = Content.Items
local HAND_HEIGHT = 1.8 -- studs over the root where the hand lets go
local HOLLOW_CHEST = 3.5
local SEGMENTS = 10
local STRIKE_TRANSIT = 0.05 -- as Combat's melee: the request's trip counts toward the wind-up

local lastThrowAt: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function point(v: Vector3): Throw.Point
	return Throw.point(v.X, v.Y, v.Z)
end

local function vector(p: Throw.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- What a throwable can hit on its way: the world, not survivors or loose effects.
local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true -- through tree crowns, as rounds go (Combat)
	return params
end

local function broadcast(run: Lobby.Run, kind: string, payload: any)
	for player in run.hosted.players do
		Sync.fx(player, kind, payload)
	end
end

-- Where the throw comes down: on the ground under the clamped aim, or on the first thing the
-- arc meets (Util/ArcCast, the cast the client's preview makes). Returns the landing, the
-- flight time to it and what stopped it short (nil when nothing did).
local function flightOf(
	origin: Vector3,
	aim: Vector3,
	stats: Types.ThrowStats,
	facing: number
): (Vector3, number, string?)
	local params = worldParams()
	local target = Throw.landing(point(origin), point(aim), stats, facing)
	local top = Vector3.new(target.x, origin.Y + 30, target.z)
	local floor = ArcCast.cast(top, top - Vector3.new(0, 120, 0), params)
	target.y = if floor then floor.Position.Y else origin.Y - 3
	local flight = Throw.flightSeconds(point(origin), target, stats)
	local points = Throw.points(point(origin), target, stats, SEGMENTS)
	for i = 1, #points - 1 do
		local a, b = vector(points[i]), vector(points[i + 1])
		local hit = ArcCast.cast(a, b, params)
		if hit then
			-- It stops on what it hit and drops to the ground there.
			local stop = hit.Position - (b - a).Unit * 0.3
			local under = ArcCast.cast(stop + Vector3.new(0, 1, 0), stop - Vector3.new(0, 59, 0), params)
			local land = if under then under.Position else stop
			local share = (i - 1 + (hit.Position - a).Magnitude / math.max((b - a).Magnitude, 1e-3)) / SEGMENTS
			return land, math.max(0.2, flight * share), ArcCast.describe(hit)
		end
	end
	return vector(target), flight, nil
end

-- Every living Hollow inside `radius` of `at` with a clear line from it, nearest first.
local function caught(run: Lobby.Run, at: Vector3, radius: number): { Hollow.Candidate }
	local params = worldParams()
	local list: { Hollow.Candidate } = {}
	for _, candidate in Hollow.inArc(run.hosted, at, 0, radius, 360) do
		local standing = Hollow.positionOf(run.hosted, candidate.id)
		if standing then
			local from = at + Vector3.new(0, 1, 0)
			local chest = Vector3.new(standing.X, standing.Y + HOLLOW_CHEST, standing.Z)
			if workspace:Raycast(from, chest - from, params) == nil then
				table.insert(list, candidate)
			end
		end
	end
	return list
end

local function blast(player: Player, run: Lobby.Run, stats: Types.ThrowStats, at: Vector3, itemId: string)
	if Lobby.hosted(run.hosted.id) == nil then
		return
	end
	broadcast(run, "blast", { at = at, radius = stats.radius, itemId = itemId })
	Hollow.noise(run.hosted, "blast", at, nil, `u{player.UserId}`, nil, stats.noiseRadius)
	for _, candidate in caught(run, at, stats.radius) do
		local amount = Throw.blastDamage(stats, candidate.distance)
		local standing = Hollow.positionOf(run.hosted, candidate.id) or at
		local away = Plane.yawTo(Plane.point(at.X, at.Z), Plane.point(standing.X, standing.Z))
		local dealt = Hollow.damage(run.hosted, candidate.id, amount, player, {
			knockbackStuds = (stats.knockbackStuds or 0) * Throw.falloff(stats, candidate.distance),
			fromYaw = away,
		})
		if dealt > 0 then
			broadcast(run, "hit", { id = candidate.id, damage = dealt, crit = false })
		end
	end
end

local function fire(player: Player, run: Lobby.Run, stats: Types.ThrowStats, at: Vector3, itemId: string)
	if Lobby.hosted(run.hosted.id) == nil then
		return
	end
	local burn = Throw.fire(stats)
	broadcast(run, "fire", {
		at = at,
		radius = stats.radius,
		seconds = burn.ticks * burn.tickSeconds,
		itemId = itemId,
	})
	Hollow.noise(run.hosted, "blast", at, nil, `u{player.UserId}`, nil, stats.noiseRadius)
	task.spawn(function()
		for _ = 1, burn.ticks do
			if Lobby.hosted(run.hosted.id) == nil then
				return
			end
			for _, candidate in caught(run, at, stats.radius) do
				local dealt = Hollow.damage(run.hosted, candidate.id, burn.perTick, player, nil)
				if dealt > 0 then
					broadcast(run, "hit", { id = candidate.id, damage = dealt, crit = false })
				end
			end
			task.wait(burn.tickSeconds)
		end
	end)
end

-- One throw at `aim`. Returns where it will land and when it goes off (for scripted checks),
-- or nil and why it didn't go.
local function throw(player: Player, x: number, y: number, z: number): (any, string?)
	local run = Lobby.runOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local itemId, key = Combat.throwHand(player)
	if run == nil or root == nil or itemId == nil or key == nil then
		return nil, "no throwable in hand"
	end
	local stats: Types.ThrowStats = Items[itemId].throw
	local stamp = now()
	if not Throw.canThrow(stats, lastThrowAt[player], stamp) then
		return nil, "too soon"
	end
	lastThrowAt[player] = stamp
	local look = root.CFrame.LookVector
	local facing = math.atan2(look.X, look.Z)
	local release = math.max(0, HoldRules.strikeDelay("throw", false) - STRIKE_TRANSIT)
	-- The swing starts now for everyone; the throwable leaves the hand on its release frame.
	broadcast(run, "swing", { userId = player.UserId, itemId = itemId, heavy = false })
	local origin = root.Position + Vector3.new(0, HAND_HEIGHT, 0)
	local landing, flight, blocker = flightOf(origin, Vector3.new(x, y, z), stats, facing)
	local goesOff = Throw.detonatesAfter(stats, flight)
	task.delay(release, function()
		-- Still in hand on the release frame (a swap or a death in the wind-up cancels it).
		if Lobby.hosted(run.hosted.id) == nil or Combat.throwHand(player) ~= itemId then
			return
		end
		local from = root.Position + Vector3.new(0, HAND_HEIGHT, 0)
		-- The effect goes out before the stack is spent, so clients still find the model in
		-- the hand to send flying when it was the last one.
		broadcast(run, "throw", {
			userId = player.UserId,
			itemId = itemId,
			from = from,
			to = landing,
			flight = flight,
			apex = stats.apex,
			goesOff = goesOff,
		})
		if Combat.spendThrown(player, key, itemId) then
			task.delay(goesOff, if stats.kind == "blast" then blast else fire, player, run, stats, landing, itemId)
		end
	end)
	return { landing = landing, flight = flight, goesOff = release + goesOff, blocker = blocker }, nil
end

-- Scripted playtests (Diagnostics "throw"): the same throw the remote makes, and the arc alone
-- (where a throw from a root at `origin` at `aim` would land and what would stop it).
Throwables.dev = {
	throw = throw,
	arc = function(origin: Vector3, aim: Vector3, itemId: string): (Vector3, number, string?)
		return flightOf(origin + Vector3.new(0, HAND_HEIGHT, 0), aim, Items[itemId].throw, 0)
	end,
}

function Throwables.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("CombatThrow", function(player: Player, x: number, y: number, z: number)
		throw(player, x, y, z)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastThrowAt[player] = nil
	end)
end

return Throwables
