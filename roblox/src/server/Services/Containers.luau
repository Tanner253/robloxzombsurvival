--!strict
--[[
	Containers (ContainerService): searchable crates, lockers, trunks and cabinets
	on a Fog Run, plus the loot piles the Hollow leave (checklist 12.4, 13.10). Off
	until Tuning.features.fogRuns.

	- Layout: when a lobby opens, the location's containers (Data/Locations) go on
	  the map's "container" markers by kind, seeded by the lobby (Containers.layout).
	  Each marker gets a ContainerId attribute, and Opened once searched, for the
	  client's open-lid look.
	- ContainerSearch from within reach starts the search (a little noise); damage
	  or walking off cancels it. On completion the loot is rolled with the Fog
	  meter's band (more opens, band tables), per player in Light fog and shared in
	  Dense and Black (Domain/Containers), then shown in the loot panel.
	- ContainerTake and ContainerTakeAll move stacks into the bag; whatever doesn't
	  fit stays in the container.
	- `spawnPile` drops loot on the ground: a Hollow's drop (the killer's own in
	  Light fog), or a recovered arrow.

	Pity counters are kept per player per run in Phase A; Phase B saves them with
	the profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local Features = require(ReplicatedStorage.Shared.Features)
local Types = require(ReplicatedStorage.Shared.Types)
local Domain = ReplicatedStorage.Shared.Domain
local ContainersMath = require(Domain.Containers)
local Loot = require(Domain.Loot)
local Rng = require(Domain.Rng)
local Net = require("../Net")
local Map = require("../FogRuns/Map")
local Props = require("../FogRuns/Props")
local Hollow = require("./Hollow")
local Inventory = require("./Inventory")
local Lobby = require("./Lobby")
local Sync = require("./Sync")
local Signal = require(ReplicatedStorage.Packages.Signal)

local Containers = {}

-- (player) a search started: looting breaks sneak (LDOE_PARITY #44).
Containers.searched = Signal.new()
-- (player, hosted, source): a search finished and it opened. `source` is "container" (a
-- placed container), "hollowDrop" (the pile a Hollow left) or "pile" (any other pile).
Containers.looted = Signal.new()

local tuning = Content.Tuning
local config = tuning.containers
local Items: any = Content.Items
local Tables: any = Content.LootTables
local TICK_SECONDS = 0.2

type World = {
	hosted: Lobby.Hosted,
	states: { [string]: ContainersMath.State },
	positions: { [string]: Vector3 },
	markers: { [string]: BasePart },
	piles: { [string]: Model }, -- the visible loot piles (FogRuns/Props)
	hollowDrops: { [string]: boolean }, -- the piles a Hollow left (the trail's "lootBody")
	rng: Rng.Source,
	pity: { [number]: Loot.PityState },
	seq: number,
}

type Active = { search: ContainersMath.Search, world: World }

local worlds: { [string]: World } = {}
local searching: { [Player]: Active } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function inReach(player: Player, position: Vector3): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= config.reachStuds + tuning.combat.lagToleranceStuds
end

local function nextId(world: World): string
	world.seq += 1
	return `c{world.seq}`
end

local function open(hosted: Lobby.Hosted)
	local world: World = {
		hosted = hosted,
		states = {},
		positions = {},
		markers = {},
		piles = {},
		hollowDrops = {},
		rng = Rng.new(hosted.state.seed + 1),
		pity = {},
		seq = 0,
	}
	worlds[hosted.id] = world
	local markers = Map.markers(hosted.map, "container")
	local spots: { ContainersMath.Spot } = {}
	for _, marker in markers do
		local kind = marker:GetAttribute("Kind")
		table.insert(spots, { kind = if type(kind) == "string" then kind else nil })
	end
	local location = hosted.location
	for _, placement in ContainersMath.layout(location.containers, spots, world.rng) do
		local entry = location.containers[placement.entry]
		local marker = markers[placement.spot]
		local id = nextId(world)
		world.states[id] = ContainersMath.new({
			id = id,
			kind = entry.kind,
			lootTableId = entry.lootTableId,
			searchSeconds = entry.searchSeconds,
			position = Map.plane(marker.Position),
		}, location.fogTier, config)
		world.positions[id] = marker.Position
		world.markers[id] = marker
		marker:SetAttribute("ContainerId", id)
		marker:SetAttribute("Opened", false)
	end
end

local function show(player: Player, id: string, items: { Types.ItemStack }?)
	Sync.fx(player, "container", { id = id, items = items or {} })
end

--[[
	Puts loot on the ground at `position` as a ready-to-open pile. In Light fog a
	pile meant for one player (their kill) is theirs alone; elsewhere it is shared.
]]
function Containers.spawnPile(
	hosted: Lobby.Hosted,
	position: Vector3,
	stacks: { Types.ItemStack },
	ownerUserId: number?,
	fromHollow: boolean?
): string?
	local world = worlds[hosted.id]
	if world == nil or #stacks == 0 then
		return nil
	end
	local id = nextId(world)
	local state = ContainersMath.new({
		id = id,
		kind = "pile",
		lootTableId = "",
		searchSeconds = 0,
		position = Map.plane(position),
	}, hosted.location.fogTier, config)
	if state.mode == "personal" and ownerUserId then
		state.personal[ownerUserId] = table.clone(stacks)
	else
		state.mode = "shared"
		state.shared = table.clone(stacks)
	end
	world.states[id] = state
	world.positions[id] = position
	if fromHollow then
		world.hollowDrops[id] = true
	end
	local model =
		Props.pile(hosted.map or workspace, position, id, if state.mode == "personal" then ownerUserId else nil)
	if model then
		world.piles[id] = model
	end
	for player in hosted.players do
		Sync.fx(
			player,
			"pile",
			{ id = id, at = { position.X, position.Y, position.Z }, mine = ownerUserId == player.UserId }
		)
	end
	return id
end

local function cancel(player: Player, reason: string?)
	local active = searching[player]
	if active then
		searching[player] = nil
		Sync.fx(player, "searchCancelled", { id = active.search.containerId, reason = reason })
	end
end

local function search(player: Player, id: string)
	local run = Lobby.runOf(player)
	local world = run and worlds[run.hosted.id]
	local state = world and world.states[id]
	if run == nil or world == nil or state == nil or not inReach(player, world.positions[id]) then
		return
	end
	cancel(player)
	local started, reason = ContainersMath.beginSearch(state, player.UserId, now())
	if started == nil then
		if reason == "searched" then
			show(player, id, ContainersMath.view(state, player.UserId))
		end
		return
	end
	searching[player] = { search = started, world = world }
	Containers.searched:Fire(player)
	Hollow.noise(run.hosted, "search", world.positions[id], nil, `u{player.UserId}`)
	Sync.fx(player, "search", { id = id, endsAt = started.endsAt, kind = state.kind })
end

local function complete(player: Player, active: Active)
	local world = active.world
	local id = active.search.containerId
	local state = world.states[id]
	if state == nil then
		return
	end
	local band, def = Lobby.band(world.hosted)
	local loot, pity = ContainersMath.complete(state, active.search, now(), {
		tables = Tables,
		rng = world.rng,
		items = Items,
		pity = world.pity[player.UserId],
		scaling = {
			lootMultiplier = def.lootMultiplier,
			bandTableIds = ContainersMath.bandTables(world.hosted.location.run.bandLoot, band),
		},
	})
	if loot == nil then
		return
	end
	world.pity[player.UserId] = pity
	Lobby.recordSearch(player)
	local source = if state.kind ~= "pile" then "container" elseif world.hollowDrops[id] then "hollowDrop" else "pile"
	Containers.looted:Fire(player, world.hosted, source)
	local marker = world.markers[id]
	if marker then
		marker:SetAttribute("Opened", true)
	end
	show(player, id, loot)
end

local function giveFrom(player: Player, id: string, stacks: { Types.ItemStack })
	local run = Lobby.runOf(player)
	local world = run and worlds[run.hosted.id]
	local state = world and world.states[id]
	if state == nil or #stacks == 0 then
		return
	end
	local given, leftover = Inventory.give(player, stacks, "FogRunLoot")
	ContainersMath.putBack(state, player.UserId, leftover)
	if #given > 0 then
		Sync.fx(player, "items", { items = given, source = "container" })
	end
	if #leftover > 0 then
		Sync.notice(player, "Your bag is full")
	end
	local left = ContainersMath.view(state, player.UserId) or {}
	show(player, id, left)
	-- An emptied loot pile is gone (a personal one empties for its owner).
	local home = world :: World
	local pile = home.piles[id]
	if pile and #left == 0 then
		pile:Destroy()
		home.piles[id] = nil
	end
end

local function takeOne(player: Player, id: string, index: number)
	local run = Lobby.runOf(player)
	local world = run and worlds[run.hosted.id]
	local state = world and world.states[id]
	if world == nil or state == nil or not inReach(player, world.positions[id]) then
		return
	end
	local stack = ContainersMath.take(state, player.UserId, index)
	if stack then
		giveFrom(player, id, { stack })
	end
end

local function takeAll(player: Player, id: string)
	local run = Lobby.runOf(player)
	local world = run and worlds[run.hosted.id]
	local state = world and world.states[id]
	if world == nil or state == nil or not inReach(player, world.positions[id]) then
		return
	end
	giveFrom(player, id, ContainersMath.takeAll(state, player.UserId))
end

function Containers.init()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Net.onEvent("ContainerSearch", search)
	Net.onEvent("ContainerCancel", function(player: Player)
		cancel(player, "cancelled")
	end)
	Net.onEvent("ContainerTake", takeOne)
	Net.onEvent("ContainerTakeAll", takeAll)
end

function Containers.start()
	if not Features.on(tuning, "fogRuns") then
		return
	end
	Lobby.opened:Connect(open)
	Lobby.closed:Connect(function(hosted: Lobby.Hosted)
		local world = worlds[hosted.id]
		if world then
			for _, pile in world.piles do
				pile:Destroy()
			end
		end
		worlds[hosted.id] = nil
		for player, active in searching do
			if active.world.hosted == hosted then
				searching[player] = nil
			end
		end
	end)
	Lobby.hurt:Connect(function(player: Player, _damage: number, cause: string)
		if cause == "fog" then
			return -- the slow seep of the Fog never pins you in place (#37)
		end
		cancel(player, "hit") -- damage interrupts a search (checklist 12.4)
	end)
	Lobby.exited:Connect(function(player: Player)
		searching[player] = nil
	end)
	Hollow.killed:Connect(function(hosted: Lobby.Hosted, position: Vector3, enemy: Types.EnemyDef, killer: Player?)
		local world = worlds[hosted.id]
		if world == nil then
			return
		end
		local result = Loot.roll(Tables, enemy.lootTableId, world.rng, { items = Items })
		Containers.spawnPile(hosted, position, result.items, if killer then killer.UserId else nil, true)
	end)
	Lobby.addRunState("search", function(player: Player): any
		local active = searching[player]
		return if active then { id = active.search.containerId, endsAt = active.search.endsAt } else nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local stamp = now()
			for player, active in searching do
				local position: Vector3? = active.world.positions[active.search.containerId]
				if position == nil or not inReach(player, position) then
					cancel(player, "moved")
				elseif ContainersMath.isDone(active.search, stamp) then
					searching[player] = nil
					local ok, err = pcall(complete :: any, player, active)
					if not ok then
						warn(`Containers: search failed: {err}`)
					end
				end
			end
		end
	end)
end

return Containers
