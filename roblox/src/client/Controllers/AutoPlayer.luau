--!strict
--[[
	AutoPlayer: a Studio-only AI player that plays the game as a person would, in real time,
	so the grind can be watched and its bugs found (2026-11-12, the developer: "play the game
	legit and natural like a real person would ... simple ai"). Off unless the Workspace
	attribute `AutoPlayer` is true, and never outside Studio (`RunService:IsStudio()`;
	held by tests/AutoPlan.spec).

	It plays only through a player's inputs:
	- moving: PathfindingService paths walked with Humanoid:MoveTo, each waypoint chained
	  before the last is reached, turning toward what it uses; never a teleport;
	- acting: the same calls clicks and keys make (Interaction's swing and E, Actions'
	  attack, travel and loot buttons, and the remotes the HUD's buttons fire: HandCraft,
	  InventoryMove, UseItem, StationPutInput/Fuel/TakeOutput, BuildPlace/Upgrade,
	  StorageOpen, InventoryTransfer, InboxTakeAll, WeaponSelect, DeathChoice), with the
	  game's own cooldowns and timers. No dev commands, no god mode.
	The decisions are Domain/AutoPlan's (pure, specced); this controller reads the synced
	state into its Context and carries the chosen step out.

	Progress is printed as "[AutoPlayer] mm:ss ..." lines and kept on the player's attributes
	(AutoPlayerStep, AutoPlayerLast, AutoPlayerMilestones). Setting the Workspace attribute
	`AutoPlayerDump` to a synced section's name prints that section once.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Content = require(ReplicatedStorage.Shared.Data)
local Flags = require(ReplicatedStorage.Shared.Flags)
local AutoPlan = require(ReplicatedStorage.Shared.Domain.AutoPlan)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Converter = require(ReplicatedStorage.Shared.Domain.Converter)
local Crafting = require(ReplicatedStorage.Shared.Domain.Crafting)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Quests = require(ReplicatedStorage.Shared.Domain.Quests)
local Slots = require(ReplicatedStorage.Shared.Domain.Slots)
local Unlocks = require(ReplicatedStorage.Shared.Domain.Unlocks)
local PlotSpace = require(ReplicatedStorage.Shared.PlotSpace)
local Actions = require("../Actions")
local Net = require("../Net")
local Pool = require("../Pool")
local State = require("../State")
local CombatControl = require("./CombatControl")
local HollowView = require("./HollowView")
local Interaction = require("./Interaction")

local AutoPlayer = {}

local player = Players.LocalPlayer
local Items: any = Content.Items
local Pieces: any = Content.BuildPieces

local THINK_SECONDS = 0.5
local WAYPOINT_AHEAD = 4 -- studs: the next waypoint is set this far before the current one
local STUCK_SECONDS = 1.6
local WALK_GIVE_UP = 45
local TRAILHEAD_STUDS = 28 -- inside Tuning.travel.departureStuds (40)
local SEARCH_WAIT = 9
local SKIP_SECONDS = 60

local enabled = false
local startedAt = 0
local milestones: { string } = {}
local seen: { [string]: boolean } = {}
local skipped: { [Instance]: number } = {}
local looted: { [string]: boolean } = {}
local front: { axis: string, x: number, z: number }? = nil -- the starter room's open side's middle edge
local room: { x0: number, z0: number, x1: number, z1: number }? = nil

-- Log ----------------------------------------------------------------------------------------------

local function clock(): string
	local t = math.max(0, os.clock() - startedAt)
	return string.format("%02d:%02d", t // 60, t % 60)
end

local recent: { string } = {}
local function log(text: string)
	local line = `{clock()} {text}`
	print(`[AutoPlayer] {line}`)
	player:SetAttribute("AutoPlayerLast", line)
	-- The last 40 lines, for a cheap read of what it has been doing.
	table.insert(recent, line)
	if #recent > 40 then
		table.remove(recent, 1)
	end
	player:SetAttribute("AutoPlayerLog", table.concat(recent, "\n"))
end

local function milestone(key: string, text: string)
	if seen[key] then
		return
	end
	seen[key] = true
	table.insert(milestones, `{clock()} {text}`)
	player:SetAttribute("AutoPlayerMilestones", table.concat(milestones, " | "))
	log(`MILESTONE {text}`)
end

-- State reads --------------------------------------------------------------------------------------

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function flat(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function inventory(): any
	local inv = State.get("inventory")
	return if type(inv) == "table" then inv else nil
end

local function onRun(): boolean
	local run = State.get("run")
	return type(run) == "table" and run.locationId ~= nil
end

-- Every carried slot: { ref, index, slot }.
local function carriedSlots(): { { ref: string, index: number, slot: any } }
	local list = {}
	local inv = inventory()
	if inv == nil then
		return list
	end
	for _, ref in { "pockets", "backpack" } do
		for index, slot in inv[ref] or {} do
			if slot.count > 0 then
				table.insert(list, { ref = ref, index = index, slot = slot })
			end
		end
	end
	return list
end

local function freeSlots(): number
	local inv = inventory()
	if inv == nil then
		return 0
	end
	local free = 0
	for _, ref in { "pockets", "backpack" } do
		for _, slot in inv[ref] or {} do
			if slot.count <= 0 then
				free += 1
			end
		end
	end
	return free
end

-- The carried stack of `itemId` (the biggest).
local function findSlot(itemId: string): (string?, number?, any)
	local bestRef, bestIndex, bestSlot = nil, nil, nil
	for _, entry in carriedSlots() do
		if entry.slot.itemId == itemId and (bestSlot == nil or entry.slot.count > bestSlot.count) then
			bestRef, bestIndex, bestSlot = entry.ref, entry.index, entry.slot
		end
	end
	return bestRef, bestIndex, bestSlot
end

local function countsOf(view: any): AutoPlan.Counts
	local counts: AutoPlan.Counts = {}
	if view == nil then
		return counts
	end
	for _, ref in { "pockets", "backpack" } do
		for _, slot in view[ref] or {} do
			if slot.count > 0 then
				counts[slot.itemId] = (counts[slot.itemId] or 0) + slot.count
			end
		end
	end
	return counts
end

local function progress(): any
	local p = State.get("progression")
	local unlocks = State.get("unlocks")
	local quests = State.get("quests")
	return {
		level = if type(p) == "table" then p.level else 1,
		unlocks = if type(unlocks) == "table" then unlocks else { recipes = {}, blueprints = {} },
		quests = if type(quests) == "table" then quests else nil,
	}
end

local function layout(): any
	local saved = State.get("layout")
	return if saved then Grid.deserialize(saved, Pieces) else nil
end

local function plotInfo(): any
	local info = State.get("plot")
	return if type(info) == "table" then info else nil
end

local function stationModel(uid: string): Model?
	for _, model in CollectionService:GetTagged("EO_Station") do
		if model:IsA("Model") and model:GetAttribute("Uid") == uid and model:IsDescendantOf(workspace) then
			return model
		end
	end
	return nil
end

local function stationViews(): { [string]: AutoPlan.StationView }
	local views: { [string]: AutoPlan.StationView } = {}
	local stations = State.get("stations")
	if type(stations) ~= "table" then
		return views
	end
	local now = os.time()
	for uid, saved in stations do
		local def = Content.Stations[saved.stationId]
		if def == nil or views[saved.stationId] then
			continue
		end
		local ctx = { def = def, recipes = Content.Recipes, items = Items }
		local ok, state = pcall(function()
			local advanced = Converter.advance(saved, ctx :: any, now)
			return advanced
		end)
		local current: any = if ok then state else saved
		local status = Converter.status(current, ctx :: any)
		local ready: AutoPlan.Counts = {}
		for _, slot in current.output or {} do
			if slot.count > 0 then
				ready[slot.itemId] = (ready[slot.itemId] or 0) + slot.count
			end
		end
		views[saved.stationId] = {
			uid = uid,
			stationId = saved.stationId,
			busy = status.activity == "working",
			inputItemId = current.input.itemId,
			inputCount = current.input.count,
			ready = ready,
			fuelSeconds = status.fuelSeconds,
			fuelled = (def :: any).fuel ~= nil or (def :: any).fuelled == true,
		}
	end
	return views
end

local function standingNodes(): AutoPlan.Counts
	local counts: AutoPlan.Counts = {}
	for _, model in CollectionService:GetTagged("EO_Node") do
		if
			model:IsA("Model")
			and model:GetAttribute("Standing") == true
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:IsDescendantOf(workspace)
		then
			local id = model:GetAttribute("NodeId") :: string
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

-- Energy now (the synced value plus what regenerated since).
local function energyNow(): number
	local energy = State.get("energy")
	if type(energy) ~= "table" or type(energy.value) ~= "number" then
		return 0
	end
	local regen = if type(energy.secondsPerPoint) == "number" and energy.secondsPerPoint > 0
		then (os.time() - (energy.updatedAt or os.time())) / energy.secondsPerPoint
		else 0
	return math.min(energy.cap or math.huge, energy.value + math.max(0, regen))
end

local function runCost(locationId: string): number
	local location = Content.Locations[locationId] :: any
	return if location and type(location.energyCost) == "number" then location.energyCost else 15
end

local function context(): AutoPlan.Context
	local inv = inventory()
	local carried = countsOf(inv)
	local home = if onRun() then carried else countsOf(Pool.inventory(inv))
	local tools: AutoPlan.Counts = {}
	for itemId in carried do
		local def = Items[itemId]
		if def and def.tool then
			tools[def.tool.kind] = math.max(tools[def.tool.kind] or 0, def.tool.tier or 1)
		end
	end
	local equipped: { [string]: boolean } = {}
	for _, slot in (if inv then inv.equipment else nil) or {} do
		if slot.count > 0 then
			equipped[slot.itemId] = true
		end
	end
	local survival = State.get("survival")
	local p = progress()
	local recipeOpen: { [string]: boolean } = {}
	for id, recipe in Content.Recipes do
		recipeOpen[id] = Crafting.isUnlocked(recipe, p)
	end
	local pieceOpen: { [string]: boolean } = {}
	for id, def in Pieces do
		pieceOpen[id] = Unlocks.isMet(def.unlock, p)
	end
	return {
		carried = carried,
		home = home,
		equipped = equipped,
		tools = tools,
		health = if type(survival) == "table" then survival.health else 100,
		hunger = if type(survival) == "table" then survival.hunger else 100,
		thirst = if type(survival) == "table" then survival.thirst else 100,
		recipeOpen = recipeOpen,
		pieceOpen = pieceOpen,
		stations = stationViews(),
		standing = standingNodes(),
		canRun = energyNow() >= runCost("loc.pine_hollow"),
		recipes = Content.Recipes :: any,
		items = Items,
		nodes = Content.Nodes :: any,
		pieces = Pieces,
	}
end

-- The tracker's top objective: (objective, have, need).
local function questObjective(): (any, number, number)
	local state = State.get("quests")
	if type(state) ~= "table" then
		return nil, 0, 0
	end
	local rows = Quests.tracker(state, Content.Quests :: any, Flags.snapshot(), 1)
	local row = rows[1]
	if row == nil or row.nextIndex == nil then
		return nil, 0, 0
	end
	for _, entry in row.objectives do
		if entry.index == row.nextIndex then
			return entry.objective, entry.have, entry.need
		end
	end
	return nil, 0, 0
end

-- Movement -----------------------------------------------------------------------------------------

local function stop()
	local hum, here = humanoid(), root()
	if hum and here then
		hum:MoveTo(here.Position)
	end
end

local function faceToward(position: Vector3)
	local here = root()
	local hum = humanoid()
	if here and hum then
		-- A step's turn, as a player nudges the stick: the Humanoid turns the body.
		local look = Vector3.new(position.X - here.Position.X, 0, position.Z - here.Position.Z)
		if look.Magnitude > 0.2 then
			hum:Move(look.Unit * 0.01, false)
		end
	end
end

local function computePath(from: Vector3, goal: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 5.5,
		AgentCanJump = true,
		WaypointSpacing = 5,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

--[[
	Walks to within `within` studs (flat) of `goal`, chaining waypoints so the stride never
	stops at one. Re-paths when stuck; gives up after WALK_GIVE_UP seconds. `interrupt`
	(checked every step) stops the walk early. True when it arrived.
]]
local function walkTo(
	goal: Vector3,
	within: number,
	interrupt: (() -> boolean)?,
	via: Vector3?, -- where the path goes (a stand point beside `goal`); default `goal`
	path: { PathWaypoint }?
): boolean
	local hum, here = humanoid(), root()
	if hum == nil or here == nil then
		return false
	end
	if flat(here.Position, goal) <= within then
		return true
	end
	local target = via or goal
	local began = os.clock()
	local repaths = 0
	local waypoints = path
		or computePath(here.Position, target)
		or { { Position = target, Action = Enum.PathWaypointAction.Walk } :: any }
	local index = math.min(2, #waypoints)
	local lastPos, lastProgress = here.Position, os.clock()
	while enabled and os.clock() - began < WALK_GIVE_UP do
		here = root()
		hum = humanoid()
		if not here or not hum or hum.Health <= 0 then
			return false
		end
		if flat(here.Position, goal) <= within then
			stop()
			return true
		end
		if interrupt and interrupt() then
			stop()
			return false
		end
		local point = waypoints[index]
		while point and index < #waypoints and flat(here.Position, point.Position) < WAYPOINT_AHEAD do
			index += 1
			point = waypoints[index]
		end
		if point then
			if point.Action == Enum.PathWaypointAction.Jump then
				hum.Jump = true
			end
			hum:MoveTo(point.Position)
		end
		if (here.Position - lastPos).Magnitude > 1 then
			lastPos, lastProgress = here.Position, os.clock()
		elseif os.clock() - lastProgress > STUCK_SECONDS then
			repaths += 1
			if repaths > 4 then
				stop()
				return false
			end
			hum.Jump = true
			waypoints = computePath(here.Position, target) or waypoints
			index = math.min(2, #waypoints)
			lastProgress = os.clock()
		end
		task.wait(0.1)
	end
	stop()
	return false
end

--[[
	Walks to a model's edge, within its use reach: to the nearest of eight stand points
	around it that a path reaches (a station against a wall can only be stood at from the
	room's side; a path to its own centre ends inside it).
]]
local function approach(model: Model, kind: string, interrupt: (() -> boolean)?): boolean
	local reach = Interaction.reach(kind, model)
	local centre = model:GetPivot().Position
	local here = root()
	if here == nil then
		return false
	end
	local within = math.max(2, reach - 1.2)
	if flat(here.Position, centre) <= within then
		faceToward(centre)
		return true
	end
	local stands = {}
	for i = 0, 7 do
		local angle = i * math.pi / 4
		table.insert(stands, centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.max(1.5, reach - 1.8))
	end
	table.sort(stands, function(a, b)
		return flat(a, here.Position) < flat(b, here.Position)
	end)
	local via, path = nil, nil
	for _, stand in stands do
		local found = computePath(here.Position, stand)
		if found then
			via, path = stand, found
			break
		end
	end
	local ok = walkTo(centre, within, interrupt, via, path)
	if ok then
		faceToward(centre)
	end
	return ok
end

-- Survival (runs alongside everything: a player drinks while walking) ---------------------------

local lastUse = 0
local function useItem(itemId: string, why: string): boolean
	local ref, index = findSlot(itemId)
	if ref == nil or index == nil or os.clock() - lastUse < 1.2 then
		return false
	end
	lastUse = os.clock()
	Net.fire("UseItem", ref, index)
	log(`use {itemId} ({why})`)
	return true
end

local function surviveTick()
	local step = AutoPlan.survive(context())
	if step and step.itemId then
		useItem(step.itemId, step.why)
	end
end

-- Popups a player clicks away -------------------------------------------------------------------

local deathSince: number? = nil
local resultSince: number? = nil
local function popupsTick()
	local death = State.get("death")
	if type(death) == "table" and death.held == true then
		deathSince = deathSince or os.clock()
		if os.clock() - (deathSince :: number) > 3 then
			deathSince = nil
			log("died: Continue")
			milestone("death1", "first death")
			Net.fire("DeathChoice", "continue")
		end
	else
		deathSince = nil
	end
	local result = State.get("result")
	if result then
		resultSince = resultSince or os.clock()
		if os.clock() - (resultSince :: number) > 4 then
			resultSince = nil
			log("results card: Continue")
			State.set("result", false)
		end
	else
		resultSince = nil
	end
	if State.ui().offerCard then
		log("offer card: Later")
		State.clear("offerCard") -- LATER
	end
end

-- Home actions -------------------------------------------------------------------------------------

local function nearestNode(nodeIds: { string }): Model?
	local here = root()
	if here == nil then
		return nil
	end
	local wanted: { [string]: boolean } = {}
	for _, id in nodeIds do
		wanted[id] = true
	end
	local best, bestDistance = nil, math.huge
	local now = os.clock()
	for _, model in CollectionService:GetTagged("EO_Node") do
		if
			model:IsA("Model")
			and wanted[model:GetAttribute("NodeId") :: string]
			and model:GetAttribute("Standing") == true
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:IsDescendantOf(workspace)
			and not ((skipped[model] or 0) > now)
		then
			local distance = flat(model:GetPivot().Position, here.Position)
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

local function gather(step: AutoPlan.Step)
	local node = nearestNode(step.nodeIds or {})
	if node == nil then
		log(`gather {step.itemId}: no node in reach`)
		task.wait(1)
		return
	end
	if not approach(node, "node") then
		skipped[node] = os.clock() + SKIP_SECONDS
		log(`gather: couldn't reach {node:GetAttribute("NodeId")}`)
		return
	end
	local began = os.clock()
	local swings, idle = 0, 0
	local hits = node:GetAttribute("HitsLeft")
	while enabled and node:GetAttribute("Standing") == true and os.clock() - began < 25 do
		if freeSlots() <= 0 and (findSlot(step.itemId or "") == nil) then
			break
		end
		if Interaction.swingAt(node) then
			swings += 1
		end
		task.wait(Content.Tuning.gathering.swingSeconds + 0.05)
		-- Swings that land nothing (the tool broke, the bag is full): stop and think again,
		-- as a player reading the toast would.
		local now = node:GetAttribute("HitsLeft")
		if now == hits then
			idle += 1
			if idle >= 3 then
				local notices = State.ui().notices
				local last = notices[#notices]
				log(`gather stalled at {node:GetAttribute("NodeId")}: {if last then last.text else "no notice"}`)
				break
			end
		else
			hits, idle = now, 0
		end
	end
	log(`gathered at {node:GetAttribute("NodeId")} ({swings} swings)`)
end

local function craft(step: AutoPlan.Step)
	local count = math.clamp(step.count or 1, 1, 10)
	Net.fire("HandCraft", step.recipeId, count)
	log(`craft {step.recipeId} x{count}`)
	task.wait(0.8)
	local itemId = step.itemId or ""
	local def = Items[itemId]
	if def and def.tool then
		milestone("tool", `first tool: {def.name}`)
	end
end

local function equip(itemId: string)
	local def = Items[itemId]
	local ref, index = findSlot(itemId)
	if def == nil or ref == nil or index == nil then
		return
	end
	local slotName = def.equipSlot or (if def.tool or def.weapon then "weapon" else nil)
	local slotIndex = slotName and table.find(Slots.EQUIP_ORDER, slotName)
	if slotIndex == nil then
		return
	end
	Net.fire("InventoryMove", ref, index, "equipment", slotIndex)
	log(`equip {itemId}`)
	task.wait(0.6)
end

local function openStation(uid: string): Model?
	local model = stationModel(uid)
	if model == nil then
		return nil
	end
	if not approach(model, "station") then
		return nil
	end
	Interaction.useModel(model, "station") -- E: the station's pane opens
	task.wait(0.6)
	return model
end

local function closePanels()
	local ui = State.ui()
	if ui.panel ~= "none" then
		State.toggle(ui.panel, ui.stationUid) -- the X: a station's toggle names its uid
	end
end

local function loadStation(step: AutoPlan.Step, ctx: AutoPlan.Context)
	local station = ctx.stations[step.stationId or ""]
	if station == nil then
		return
	end
	if openStation(station.uid) == nil then
		log(`load: couldn't reach {step.stationId}`)
		return
	end
	if station.inputItemId ~= "" and station.inputItemId ~= step.itemId and not station.busy then
		Net.fire("StationTakeInput", station.uid)
		task.wait(0.5)
	end
	local recipe = Content.Recipes[step.recipeId or ""]
	local per = if recipe then recipe.inputs[1].count else 1
	local ref, index, slot = findSlot(step.itemId or "")
	if ref and index and slot then
		local want = math.min(slot.count, per * math.max(1, step.count or 1))
		Net.fire("StationPutInput", station.uid, ref, index, want)
		log(`load {step.stationId}: {want} {step.itemId}`)
	end
	if station.fuelled and station.fuelSeconds <= 30 then
		for _, fuelId in { "item.fatwood", "item.timber", "item.sticks" } do
			local fref, findex, fslot = findSlot(fuelId)
			if fref and findex and fslot then
				task.wait(0.4)
				Net.fire("StationPutFuel", station.uid, fref, findex, math.min(fslot.count, 4))
				log(`fuel {step.stationId}: {fuelId}`)
				break
			end
		end
	end
	task.wait(0.8)
	closePanels()
end

local function collect(step: AutoPlan.Step, ctx: AutoPlan.Context)
	local station = ctx.stations[step.stationId or ""]
	if station == nil then
		return
	end
	if openStation(station.uid) == nil then
		return
	end
	Net.fire("StationTakeOutput", station.uid, 0)
	log(`collect from {step.stationId}`)
	task.wait(0.8)
	closePanels()
end

-- Building -----------------------------------------------------------------------------------------

local function buildContext(): any
	local info = plotInfo()
	if info == nil then
		return nil
	end
	return {
		plot = { ownerUserId = player.UserId, width = info.cells, depth = info.cells },
		actorUserId = player.UserId,
		pieces = Pieces,
		now = os.time(),
		config = Content.Tuning.building,
	}
end

-- The starter room: its 3 x 3 floor and the middle edge of its open side (the doorway).
local function findRoom(current: any)
	if room ~= nil or current == nil then
		return
	end
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, piece in current.pieces do
		if piece.layer == "floor" and piece.placedAt == Grid.STARTER_AT then
			x0, z0 = math.min(x0, piece.x), math.min(z0, piece.z)
			x1, z1 = math.max(x1, piece.x), math.max(z1, piece.z)
		end
	end
	if x0 == math.huge then
		return
	end
	room = { x0 = x0, z0 = z0, x1 = x1, z1 = z1 }
	-- The open side has no starter wall at all.
	local sides: { any } = {
		{ axis = "h", x = 0, z = z0, along = "x" },
		{ axis = "h", x = 0, z = z1 + 1, along = "x" },
		{ axis = "v", x = x0, z = 0, along = "z" },
		{ axis = "v", x = x1 + 1, z = 0, along = "z" },
	}
	for _, side in sides do
		local walls = 0
		local from, to = if side.along == "x" then x0 else z0, if side.along == "x" then x1 else z1
		for i = from, to do
			local x = if side.along == "x" then i else side.x
			local z = if side.along == "x" then side.z else i
			if Grid.pieceAt(current, "frame", x :: number, z :: number, side.axis :: any) then
				walls += 1
			end
		end
		if walls == 0 then
			local middle = (from + to) // 2
			front = {
				axis = side.axis,
				x = if side.along == "x" then middle else side.x :: number,
				z = if side.along == "x" then side.z :: number else middle,
			}
			break
		end
	end
	log(`room {x0},{z0}-{x1},{z1}; doorway at {front and `{front.axis} {front.x},{front.z}` or "?"}`)
end

-- The room's perimeter edges.
local function perimeter(): { { axis: string, x: number, z: number } }
	local list = {}
	if room == nil then
		return list
	end
	for x = room.x0, room.x1 do
		table.insert(list, { axis = "h", x = x, z = room.z0 })
		table.insert(list, { axis = "h", x = x, z = room.z1 + 1 })
	end
	for z = room.z0, room.z1 do
		table.insert(list, { axis = "v", x = room.x0, z = z })
		table.insert(list, { axis = "v", x = room.x1 + 1, z = z })
	end
	return list
end

local function isFront(edge: { axis: string, x: number, z: number }): boolean
	return front ~= nil and front.axis == edge.axis and front.x == edge.x and front.z == edge.z
end

local BASE_STATIONS = { "build.woodworking_bench", "build.stonecutter", "build.workbench", "build.smelter" }

-- The starter base's pieces still to place, in order: walls round the room, the doorway and
-- its door, then the first stations.
local function baseGoals(current: any): { string }
	local goals = {}
	if current == nil or room == nil then
		return goals
	end
	local doorway = front and Grid.pieceAt(current, "frame", front.x, front.z, front.axis :: any)
	if doorway == nil then
		table.insert(goals, "build.doorway_wood")
	elseif front and not Grid.pieceAt(current, "fill", front.x, front.z, front.axis :: any) then
		table.insert(goals, "build.door_wood")
	end
	for _, edge in perimeter() do
		if not isFront(edge) and Grid.pieceAt(current, "frame", edge.x, edge.z, edge.axis :: any) == nil then
			table.insert(goals, "build.wall_wood")
			break
		end
	end
	local have: { [string]: boolean } = {}
	for _, piece in current.pieces do
		have[piece.pieceId] = true
	end
	for _, pieceId in BASE_STATIONS do
		if not have[pieceId] then
			table.insert(goals, pieceId)
		end
	end
	return goals
end

local function baseDone(current: any): boolean
	return #baseGoals(current) == 0 and room ~= nil
end

-- A valid target for `pieceId`, preferring the room: its gaps for walls, its open side's
-- middle for the doorway, the floor along the walls for stations, beside it for floors.
local function chooseTarget(pieceId: string, current: any, ctx: any, inv: any): any
	local def = Pieces[pieceId]
	if def == nil or room == nil then
		return nil
	end
	local p = progress()
	local info = plotInfo()
	local layer = Grid.layerOf(def)
	local function ok(target: any): boolean
		local valid = BuildRules.canPlace(current, pieceId, target, ctx, p, inv, info and info.pieceSlots)
		return valid
	end
	if layer == "frame" or layer == "fill" then
		if def.kind == "doorway" or def.kind == "door" then
			if front and ok({ x = front.x, z = front.z, axis = front.axis }) then
				return { x = front.x, z = front.z, axis = front.axis }
			end
		end
		for _, edge in perimeter() do
			if not isFront(edge) and ok(edge) then
				return edge
			end
		end
		return nil
	elseif layer == "floor" then
		-- Beside the room on its back or a side, nearest its middle.
		local best, bestScore = nil, math.huge
		local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
		for x = room.x0 - 2, room.x1 + 2 do
			for z = room.z0 - 2, room.z1 + 2 do
				local target = { x = x, z = z }
				local score = math.abs(x - cx) + math.abs(z - cz)
				local frontSide = front
					and (
						(
							front.axis == "h"
							and ((front.z > room.z1 and z > room.z1) or (front.z <= room.z0 and z < room.z0))
						)
						or (
							front.axis == "v"
							and ((front.x > room.x1 and x > room.x1) or (front.x <= room.x0 and x < room.x0))
						)
					)
				if frontSide then
					score += 10
				end
				if score < bestScore and ok(target) then
					best, bestScore = target, score
				end
			end
		end
		return best
	end
	-- Objects: quarter cells on the room's floor, nearest its walls (the middle stays clear).
	local sub = Grid.SUB
	local best, bestScore = nil, math.huge
	local qx0, qz0 = room.x0 * sub, room.z0 * sub
	local qx1, qz1 = (room.x1 + 1) * sub, (room.z1 + 1) * sub
	for rot = 0, 3 do
		local w, d = Grid.footprint(def, rot)
		for qx = qx0 - 2 * sub, qx1 + 2 * sub - w do
			for qz = qz0 - 2 * sub, qz1 + 2 * sub - d do
				local inside = qx >= qx0 and qz >= qz0 and qx + w <= qx1 and qz + d <= qz1
				local wallGap = math.min(qx - qx0, qz - qz0, qx1 - (qx + w), qz1 - (qz + d))
				local score = if inside then wallGap else 20 + math.abs(qx - qx0) + math.abs(qz - qz0)
				if score < bestScore then
					local target = { x = qx, z = qz, rot = rot }
					if ok(target) then
						best, bestScore = target, score
					end
				end
			end
		end
	end
	return best
end

local function build(step: AutoPlan.Step)
	local pieceId = step.pieceId or ""
	local current = layout()
	local ctx = buildContext()
	local info = plotInfo()
	local inv = Pool.inventory(inventory())
	if current == nil or ctx == nil or info == nil then
		task.wait(1)
		return
	end
	findRoom(current)
	local target = chooseTarget(pieceId, current, ctx, inv)
	if target == nil then
		log(`build {pieceId}: no valid spot`)
		task.wait(2)
		return
	end
	local def = Pieces[pieceId]
	local where = PlotSpace.target(info.origin, current, Grid.layerOf(def), target, def).Position
	walkTo(where, 10)
	local before = 0
	for _ in current.pieces do
		before += 1
	end
	Net.fire("BuildPlace", pieceId, target.x, target.z, target.axis, target.rot)
	log(`build {pieceId} at {target.x},{target.z}{if target.axis then " " .. target.axis else ""}`)
	task.wait(1.2)
	local after = 0
	for _ in (layout() or current).pieces do
		after += 1
	end
	if after <= before then
		local notices = State.ui().notices
		local last = notices[#notices]
		log(`build refused: {if last then last.text else "no notice"}`)
		task.wait(2)
		return
	end
	if def.kind == "wall" then
		milestone("wall", "first wall")
	end
	if baseDone(layout()) then
		milestone("base", "starter base done (room walled, door, stations)")
	end
end

local function upgrade(step: AutoPlan.Step)
	local current = layout()
	local ctx = buildContext()
	local info = plotInfo()
	if current == nil or ctx == nil or info == nil then
		return
	end
	local inv = Pool.inventory(inventory())
	for uid, piece in current.pieces do
		local def = Pieces[piece.pieceId]
		if def and def.upgradesTo == step.pieceId then
			local ok = BuildRules.canUpgrade(current, uid, ctx, progress(), inv)
			if ok then
				local where = PlotSpace.piece(info.origin, current, piece, def).Position
				walkTo(where, 10)
				Net.fire("BuildUpgrade", uid)
				log(`upgrade {piece.pieceId} -> {step.pieceId}`)
				task.wait(1)
				milestone("tier2", `TIER-2 GOAL: {Pieces[step.pieceId].name}`)
				return
			end
		end
	end
	log(`upgrade {step.pieceId}: nothing upgradable`)
	task.wait(2)
end

-- Crates: the bag's materials go into the nearest crate when it fills -------------------------------

local function nearestCrate(): Model?
	local here = root()
	if here == nil then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in CollectionService:GetTagged("EO_Storage") do
		if
			model:IsA("Model")
			and model:IsDescendantOf(workspace)
			and model:GetAttribute("OwnerUserId") == player.UserId
		then
			local distance = flat(model:GetPivot().Position, here.Position)
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

local function stash()
	local crate = nearestCrate()
	if crate == nil or not approach(crate, "storage") then
		log("bag full: no crate reached")
		task.wait(2)
		return
	end
	Interaction.useModel(crate, "storage") -- E: the crate and the bag open side by side
	task.wait(0.8)
	Net.fire("InventoryTransfer", "putAll")
	log("bag full: put all into the crate")
	task.wait(0.8)
	closePanels()
end

-- The first empty bag slot: (ref, index).
local function emptySlot(): (string?, number?)
	local inv = inventory()
	if inv == nil then
		return nil, nil
	end
	for _, ref in { "pockets", "backpack" } do
		for index, slot in inv[ref] or {} do
			if slot.count <= 0 then
				return ref, index
			end
		end
	end
	return nil, nil
end

-- Takes `itemId` out of the crate it sits in into the bag (a station's input must be
-- carried to drag it in), as dragging it from the crate's pane.
local function fetch(itemId: string)
	for _, model in CollectionService:GetTagged("EO_Storage") do
		if
			model:IsA("Model")
			and model:IsDescendantOf(workspace)
			and model:GetAttribute("OwnerUserId") == player.UserId
		then
			if not approach(model, "storage") then
				continue
			end
			Interaction.useModel(model, "storage")
			task.wait(0.8)
			local storage = State.get("storage")
			local slots = if type(storage) == "table" then storage.slots else nil
			for index, slot in slots or {} do
				if slot.itemId == itemId and slot.count > 0 then
					local ref, free = emptySlot()
					if ref and free then
						Net.fire("InventoryMove", "storage", index, ref, free)
						log(`fetch {itemId} from the crate`)
						task.wait(0.6)
					end
					closePanels()
					return
				end
			end
			closePanels()
		end
	end
	-- Not in a crate: maybe the inbox (Take all when there's room).
	if freeSlots() > 0 then
		Net.fire("InboxTakeAll")
	end
	task.wait(1)
end

-- Fog Runs -----------------------------------------------------------------------------------------

local function trailhead(): Vector3?
	local world = workspace:FindFirstChild("World")
	local head = world and world:FindFirstChild("Trailhead")
	local sign = head and head:FindFirstChild("Sign")
	if sign == nil then
		return nil
	end
	return if sign:IsA("Model") then sign:GetPivot().Position elseif sign:IsA("BasePart") then sign.Position else nil
end

local runStartedAt = 0
local runCount = 0

local function goRun(step: AutoPlan.Step)
	local at = trailhead()
	if at == nil then
		task.wait(2)
		return
	end
	local locationId = step.locationId or "loc.pine_hollow"
	local have = energyNow()
	if have < runCost(locationId) then
		log(`run {locationId}: waiting for Energy ({math.floor(have)})`)
		milestone("energyWait", `first wait on Energy ({math.floor(have)})`)
		task.wait(5)
		return
	end
	if not walkTo(at, TRAILHEAD_STUDS) then
		log("run: couldn't reach the Trailhead")
		return
	end
	log(`Run to {locationId} ({step.why})`)
	Actions.travel(locationId, "run")
	local waited = 0
	while enabled and waited < 30 and not onRun() do
		waited += task.wait(0.5)
	end
	if onRun() then
		runCount += 1
		runStartedAt = os.clock()
		looted = {}
		milestone("run", "first Fog Run")
		log(`arrived on run {runCount}`)
	else
		log("run: never arrived")
	end
end

local function nearestHollow(): HollowView.Target?
	local here = root()
	if here == nil then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, target in HollowView.targets() do
		local distance = flat(target.position, here.Position)
		if target.alive and distance < bestDistance then
			best, bestDistance = target, distance
		end
	end
	return best
end

local function containers(): { Model }
	local list = {}
	for _, model in CollectionService:GetTagged("EO_RunContainer") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local id = model:GetAttribute("ContainerId")
			if type(id) == "string" and not looted[id] and not ((skipped[model] or 0) > os.clock()) then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function nearest(models: { Model }): (Model?, number?)
	local here = root()
	if here == nil then
		return nil, nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in models do
		local distance = flat(model:GetPivot().Position, here.Position)
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best, if best then bestDistance else nil
end

local function exits(): { Model }
	local list = {}
	for _, model in CollectionService:GetTagged("EO_RunExit") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			table.insert(list, model)
		end
	end
	return list
end

local lastAttack = 0
local function fight(target: HollowView.Target)
	local here = root()
	local inv = inventory()
	if here == nil or inv == nil then
		return
	end
	-- 1: the first weapon slot in hand, as the 1 key.
	if (inv.hand or "") == "" and inv.equipment and inv.equipment.weapon and inv.equipment.weapon.count > 0 then
		Net.fire("WeaponSelect", 1)
	end
	local itemId = inv.hand or ""
	local def = Items[itemId]
	local ranged = def and def.weapon and def.weapon.kind == "ranged"
	local range = if ranged then 18 else 3.6
	local distance = flat(target.position, here.Position)
	if distance > range then
		local hum = humanoid()
		if hum then
			hum:MoveTo(target.position)
		end
	else
		stop()
	end
	CombatControl.devAim(target.position) -- the mouse on the Hollow
	if distance <= range + 0.5 and os.clock() - lastAttack > 0.45 then
		lastAttack = os.clock()
		Actions.attack()
	end
end

local function lootContainer(model: Model)
	local id = model:GetAttribute("ContainerId") :: string
	if
		not approach(model, "container", function()
			local hollow = nearestHollow()
			local here = root()
			return hollow ~= nil and here ~= nil and flat(hollow.position, here.Position) < 10
		end)
	then
		skipped[model] = os.clock() + 30
		return
	end
	if not Interaction.useModel(model, "container") then
		looted[id] = true
		return
	end
	local waited = 0
	while enabled and waited < SEARCH_WAIT do
		local loot = State.get("loot")
		if type(loot) == "table" and loot.id == id then
			break
		end
		local hollow = nearestHollow()
		local here = root()
		if hollow and here and flat(hollow.position, here.Position) < 8 then
			Net.fire("ContainerCancel")
			return
		end
		waited += task.wait(0.25)
	end
	task.wait(0.4)
	Actions.takeLoot() -- TAKE ALL
	looted[id] = true
	log(`looted {model:GetAttribute("Kind") or "container"}`)
	task.wait(0.6)
	closePanels()
	State.set("loot", false)
end

local function extract()
	local exit = nearest(exits())
	if exit == nil then
		log("extract: no exit seen")
		task.wait(2)
		return
	end
	if
		not approach(exit, "exit", function()
			local hollow = nearestHollow()
			local here = root()
			return hollow ~= nil and here ~= nil and flat(hollow.position, here.Position) < 6
		end)
	then
		return
	end
	Interaction.useModel(exit, "exit")
	log(`extracting at {exit:GetAttribute("ExitName") or "exit"}`)
	local waited = 0
	while enabled and onRun() and waited < 25 do
		local hollow = nearestHollow()
		local here = root()
		if hollow and here and flat(hollow.position, here.Position) < 5 then
			fight(hollow)
		end
		waited += task.wait(0.25)
	end
	if not onRun() then
		milestone("extract", "first extraction")
		log("home from the run")
	end
end

local function explore()
	-- Walk toward the farthest exit's side of the map to find more containers.
	local here = root()
	local far, farDistance = nil, 0
	for _, model in exits() do
		if here then
			local distance = flat(model:GetPivot().Position, here.Position)
			if distance > farDistance then
				far, farDistance = model, distance
			end
		end
	end
	if far and here then
		local goal = here.Position:Lerp(far:GetPivot().Position, 0.4)
		walkTo(goal, 4, function()
			return #containers() > 0 or nearestHollow() ~= nil
		end)
	else
		task.wait(1)
	end
end

-- A run's standing nodes that yield what home needs, with the tool for them carried.
local function runNodes(ctx: AutoPlan.Context): { Model }
	local wanted: { [string]: boolean } = {}
	for _, itemId in AutoPlan.RUN_GATHER do
		wanted[itemId] = true
	end
	local list = {}
	for _, model in CollectionService:GetTagged("EO_Node") do
		local owner = model:GetAttribute("OwnerUserId")
		if
			model:IsA("Model")
			and model:IsDescendantOf(workspace)
			and model:GetAttribute("Standing") == true
			and (owner == nil or owner == player.UserId)
			and not ((skipped[model] or 0) > os.clock())
		then
			local def = Content.Nodes[model:GetAttribute("NodeId") :: string] :: any
			local usable = def ~= nil and (def.tool == nil or (ctx.tools[def.tool.kind] or 0) >= def.tool.tier)
			if usable then
				for _, entry in def.yields do
					if wanted[entry.itemId] and entry.chance == nil then
						table.insert(list, model)
						break
					end
				end
			end
		end
	end
	return list
end

local function hollowNear(studs: number): () -> boolean
	return function()
		local hollow = nearestHollow()
		local here = root()
		return hollow ~= nil and here ~= nil and flat(hollow.position, here.Position) < studs
	end
end

local function gatherRunNode(node: Model)
	if not approach(node, "node", hollowNear(9)) then
		skipped[node] = os.clock() + 30
		return
	end
	local began = os.clock()
	while enabled and node:GetAttribute("Standing") == true and os.clock() - began < 15 do
		if hollowNear(7)() or freeSlots() <= 0 then
			break
		end
		Interaction.swingAt(node)
		task.wait(Content.Tuning.gathering.swingSeconds + 0.05)
	end
	if node:GetAttribute("Standing") == true then
		skipped[node] = os.clock() + 20
	end
	log(`run: gathered {node:GetAttribute("NodeId")}`)
end

local function runTick()
	local ctx = context()
	local hollow = nearestHollow()
	local here = root()
	local container, containerDistance = nearest(containers())
	local node, nodeDistance = nearest(runNodes(ctx))
	local exit, exitDistance = nearest(exits())
	local hollowDistance = if hollow and here then flat(hollow.position, here.Position) else nil
	local count = 0
	for _, target in HollowView.targets() do
		if here and flat(target.position, here.Position) < 30 then
			count += 1
		end
	end
	local run = State.get("run")
	local minutesLeft = nil
	if type(run) == "table" and type(run.closesAt) == "number" and type(run.serverTime) == "number" then
		minutesLeft = (run.closesAt - run.serverTime) / 60
	end
	local kind, why = AutoPlan.onRun(ctx, {
		hollowDistance = hollowDistance,
		hollowCount = count,
		containerDistance = containerDistance,
		nodeDistance = nodeDistance,
		exitDistance = exitDistance,
		bagFree = freeSlots(),
		minutesLeft = minutesLeft,
		armed = true,
		goalsMet = false,
		elapsed = os.clock() - runStartedAt,
	})
	player:SetAttribute("AutoPlayerStep", `run:{kind} {why}`)
	if kind == "fight" and hollow then
		fight(hollow)
	elseif kind == "flee" and hollow and here then
		local away = (here.Position - hollow.position) * Vector3.new(1, 0, 1)
		walkTo(here.Position + (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 20, 3)
	elseif kind == "loot" and container then
		lootContainer(container)
	elseif kind == "gather" and node then
		gatherRunNode(node)
	elseif kind == "extract" then
		extract()
	elseif kind == "explore" then
		explore()
	end
	local _ = exit
end

-- Home tick ----------------------------------------------------------------------------------------

local lastStepText = ""
local function homeTick()
	-- The inbox's rows into the bag, as TAKE ALL.
	local inbox = State.get("inbox")
	if type(inbox) == "table" and #inbox > 0 and freeSlots() >= 2 then
		Net.fire("InboxTakeAll")
		log(`inbox: take all ({#inbox} rows)`)
		task.wait(0.8)
	end
	if freeSlots() <= 0 then
		stash()
		return
	end
	local current = layout()
	findRoom(current)
	local objective, have, need = questObjective()
	local ctx = context()
	local step = AutoPlan.atHome(ctx, {
		objective = objective,
		have = have,
		need = need,
		base = baseGoals(current),
		upgrade = "build.foundation_scrap",
	})
	local text = `{step.kind} {step.why}`
	player:SetAttribute("AutoPlayerStep", text)
	if text ~= lastStepText then
		lastStepText = text
		log(`-> {text}`)
	end
	for itemId in ctx.home do
		if itemId == "item.scrap_plate" or itemId == "item.ironstone" or itemId == "item.iron_ingot" then
			milestone("t2mat", `first tier-2 material: {Items[itemId].name}`)
		end
	end
	if step.kind == "gather" then
		gather(step)
	elseif step.kind == "craft" then
		craft(step)
	elseif step.kind == "equip" then
		equip(step.itemId or "")
	elseif step.kind == "use" or step.kind == "drink" or step.kind == "eat" or step.kind == "heal" then
		useItem(step.itemId or "", step.why)
		task.wait(1)
	elseif step.kind == "load" then
		loadStation(step, ctx)
	elseif step.kind == "collect" then
		collect(step, ctx)
	elseif step.kind == "build" then
		build(step)
	elseif step.kind == "upgrade" then
		upgrade(step)
	elseif step.kind == "run" then
		goRun(step)
	elseif step.kind == "wait" and step.itemId and (ctx.home[step.itemId] or 0) > (ctx.carried[step.itemId] or 0) then
		fetch(step.itemId) -- it's in a crate or the inbox: take it out
	else
		-- Waiting on a timer: look again shortly.
		task.wait(3)
	end
end

-- Loop ---------------------------------------------------------------------------------------------

local function dumpSection()
	local name = workspace:GetAttribute("AutoPlayerDump")
	if type(name) ~= "string" or name == "" then
		return
	end
	workspace:SetAttribute("AutoPlayerDump", nil)
	local value = if name == "ui" then State.ui() else State.get(name)
	local ok, text = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	print(`[AutoPlayer] dump {name}: {if ok then string.sub(text, 1, 3000) else tostring(value)}`)
	player:SetAttribute("AutoPlayerDumpOut", if ok then string.sub(text, 1, 3000) else tostring(value))
end

local function think(): any
	dumpSection()
	popupsTick()
	local hum = humanoid()
	local death = State.get("death")
	if not hum or hum.Health <= 0 or (type(death) == "table" and death.held == true) then
		task.wait(1)
	elseif onRun() then
		runTick()
	else
		homeTick()
	end
	return nil
end

local function loop()
	while enabled do
		local ok, err = pcall(think)
		if not ok then
			log(`error: {err}`)
			task.wait(2)
		end
		task.wait(THINK_SECONDS)
	end
end

local function sideLoop()
	while enabled do
		pcall(surviveTick)
		pcall(popupsTick)
		task.wait(1)
	end
end

local function setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	if on then
		startedAt = os.clock()
		log("on")
		task.spawn(loop)
		task.spawn(sideLoop)
	else
		stop()
		log("off")
	end
end

function AutoPlayer.start()
	-- Studio only: a live game never runs it, whatever the attribute says.
	if not RunService:IsStudio() then
		return
	end
	workspace:GetAttributeChangedSignal("AutoPlayer"):Connect(function()
		setEnabled(workspace:GetAttribute("AutoPlayer") == true)
	end)
	setEnabled(workspace:GetAttribute("AutoPlayer") == true)
end

return AutoPlayer
