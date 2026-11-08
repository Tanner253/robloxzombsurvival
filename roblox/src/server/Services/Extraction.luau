--!strict
--[[
	Extraction (ExtractionService): getting out of a Fog Run alive (checklist 12.5;
	GAME_DESIGN "Rules by fog tier"). Off until Tuning.features.fogRuns.

	- Light fog: ExtractStart("edge") near the edge of the map's bounds starts the
	  short fog-out.
	- Dense and Black: the lobby seed shuts some points (Domain/Extraction). Each
	  point's marker gets an Open attribute so the client and minimap show which
	  exits work. ExtractStart(pointId) within radiusStuds starts the 8 s channel.
	- Black fog's flare extract: ExtractStart("flare") burns a Signal Flare from the
	  bag where you stand (lighting it for everyone and making noise), then you
	  must survive flareSeconds.
	- Damage breaks point channels (not the flare), as do death and walking off.
	  A finished channel hands the player to Lobby.extract (results and home).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Domain = ReplicatedStorage.Shared.Domain
local ExtractionMath = require(Domain.Extraction)
local Net = require("../Net")
local Map = require("../FogRuns/Map")
local Hollow = require("./Hollow")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local Sync = require("./Sync")

local Extraction = {}

local tuning = Content.Tuning
local config = tuning.extraction
local Items: any = Content.Items
local FLARE_ITEM = "item.flare"
local TICK_SECONDS = 0.2

type Active = { channel: ExtractionMath.Channel, run: Lobby.Run }

local openPoints: { [string]: { string } } = {}
local channels: { [Player]: Active } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function onOpened(hosted: Lobby.Hosted)
	local def = hosted.location.run.extraction
	local open = ExtractionMath.openPoints(def, hosted.state.seed)
	openPoints[hosted.id] = open
	for _, marker in Map.markers(hosted.map, "extract") do
		local pointId = marker:GetAttribute("PointId")
		marker:SetAttribute("Open", type(pointId) == "string" and table.find(open, pointId) ~= nil)
	end
end

local function cancel(player: Player, reason: string)
	local active = channels[player]
	if active then
		channels[player] = nil
		Sync.fx(player, "extractCancelled", { pointId = active.channel.pointId, reason = reason })
	end
end

-- Whether the player stands where `pointId` can be used.
local function inPlace(hosted: Lobby.Hosted, pointId: string, root: BasePart): boolean
	if pointId == ExtractionMath.EDGE then
		local bounds = Map.bounds(hosted.map)
		return bounds ~= nil and Map.insideBy(bounds, root.Position) <= config.radiusStuds
	elseif pointId == ExtractionMath.FLARE then
		return true -- anywhere: that's the gamble
	end
	local marker = Map.point(hosted.map, pointId)
	return marker ~= nil and (marker.Position - root.Position).Magnitude <= config.radiusStuds
end

local REASONS: { [string]: string } = {
	unknown = "That's no way out",
	closed = "The Fog has closed this exit",
	noEdge = "Dense fog has no edge to walk out of: find an extraction point",
	noFlare = "There's no flare extract here",
}

local function start(player: Player, pointId: string)
	local run = Lobby.runOf(player)
	local root = rootOf(player)
	if run == nil or root == nil or channels[player] then
		return
	end
	local hosted = run.hosted
	if not inPlace(hosted, pointId, root) then
		Sync.notice(
			player,
			if pointId == ExtractionMath.EDGE then "Walk to the edge of the fog to leave" else "Get closer"
		)
		return
	end
	local def = hosted.location.run.extraction
	local channel, reason =
		ExtractionMath.begin(def, hosted.state.seed, pointId, player.UserId, Map.plane(root.Position), now(), config)
	if channel == nil then
		Sync.notice(player, REASONS[reason or ""] or "You can't leave from here")
		return
	end
	if channel.kind == "flare" then
		local flare = Items[FLARE_ITEM]
		if
			flare == nil
			or flare.flare == nil
			or not Inventory.take(player, { { itemId = FLARE_ITEM, count = 1 } }, "FlareExtract")
		then
			Sync.notice(player, "You need a Signal Flare to signal for extraction")
			return
		end
		Hollow.flare(hosted, flare.flare, root.Position, `u{player.UserId}`)
		Hollow.noise(hosted, "flare", root.Position, nil, `u{player.UserId}`)
		for other in hosted.players do
			Sync.fx(other, "flareExtract", { userId = player.UserId, at = { root.Position.X, root.Position.Z } })
		end
	end
	channels[player] = { channel = channel, run = run }
	Sync.fx(player, "extracting", { pointId = pointId, kind = channel.kind, endsAt = channel.endsAt })
end

function Extraction.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("ExtractStart", start)
	Net.onEvent("ExtractCancel", function(player: Player)
		cancel(player, "cancelled")
	end)
end

function Extraction.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Lobby.opened:Connect(onOpened)
	Lobby.closed:Connect(function(hosted: Lobby.Hosted)
		openPoints[hosted.id] = nil
	end)
	Lobby.hurt:Connect(function(player: Player, _damage: number, cause: string)
		if cause == "fog" then
			return -- full fog exposure must never block the way out (#37)
		end
		local active = channels[player]
		if active and ExtractionMath.breaks(active.channel, "damage") then
			cancel(player, "hit")
		end
	end)
	Lobby.exited:Connect(function(player: Player)
		channels[player] = nil
	end)
	Lobby.addRunState("extraction", function(player: Player, run: Lobby.Run): any
		local def = run.hosted.location.run.extraction
		local active = channels[player]
		return {
			kind = def.kind,
			open = openPoints[run.hosted.id] or {},
			flare = def.kind == "points" and def.flare == true,
			channel = if active
				then { pointId = active.channel.pointId, kind = active.channel.kind, endsAt = active.channel.endsAt }
				else nil,
		}
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local stamp = now()
			for player, active in channels do
				local root = rootOf(player)
				if root == nil or Lobby.runOf(player) ~= active.run then
					channels[player] = nil
				elseif ExtractionMath.outOfRange(active.channel, Map.plane(root.Position), config) then
					cancel(player, "moved")
				elseif ExtractionMath.isDone(active.channel, stamp) then
					channels[player] = nil
					Lobby.extract(player)
				end
			end
		end
	end)
end

return Extraction
