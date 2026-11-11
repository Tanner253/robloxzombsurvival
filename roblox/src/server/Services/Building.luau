--!strict
--[[
	Building: places, upgrades and demolishes pieces on the owner's plot
	(Domain/Grid + Domain/BuildRules; M1 step 5). The client's ghost preview
	runs the same BuildRules, so what looks valid is valid.

	Grid never touches items: this service charges BuildPieceDef.cost on place,
	the upgrade price on upgrade, and grants the refund on demolish (refused when
	the refund would not fit). Placing a station or crate creates its record
	(Stations, PlayerData.storage); a crate with items or a station with jobs
	can't be demolished, so nothing is ever lost.

	Piece models carry attributes (Uid, PieceId, Layer, Kind, OwnerUserId,
	PlacedAt) and tags (EO_Piece, plus EO_Station, EO_Storage, EO_Door) for the
	client's prompts and effects.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local PlotSpace = require(ReplicatedStorage.Shared.PlotSpace)
local Domain = ReplicatedStorage.Shared.Domain
local Grid = require(Domain.Grid)
local BuildRules = require(Domain.BuildRules)
local InventoryMath = require(Domain.Inventory)
local Net = require("../Net")
local Events = require("../Events")
local Models = require("../World/Models")
local Seams = require("../World/Seams")
local Analytics = require("./Analytics")
local Inbox = require("./Inbox")
local Inventory = require("./Inventory")
local Materials = require("./Materials")
local PlayerData = require("./PlayerData")
local Plots = require("./Plots")
local Quests = require("./Quests")
local Stations = require("./Stations")
local Sync = require("./Sync")

local Building = {}

Building.TAGS = {
	piece = "EO_Piece",
	station = "EO_Station",
	storage = "EO_Storage",
	door = "EO_Door",
}

local Pieces = Content.BuildPieces

local function progressOf(player: Player): BuildRules.Progress?
	local data = PlayerData.get(player)
	if data == nil then
		return nil
	end
	return Quests.progress(data)
end

-- The last refusal per player, so Studio dev commands can report why a build failed.
Building.lastDenied = {} :: { [Player]: string }

local function deny(player: Player, reason: string?)
	Building.lastDenied[player] = reason or "unknown"
	Sync.notice(player, BuildRules.REASON_TEXT[reason or ""] or "Can't build there")
	Sync.fx(player, "buildDenied", { reason = reason })
end

-- Rendering ---------------------------------------------------------------------------------------

local function render(plot: Plots.Plot, piece: Grid.Piece, fresh: boolean)
	local old = plot.pieceModels[piece.uid]
	if old then
		old:Destroy()
	end
	local def = Pieces[piece.pieceId]
	local model = Models.piece(def)
	if model == nil then
		return -- no approved model yet: a saved piece of this type stays invisible
	end
	model.Name = piece.uid
	model:PivotTo(PlotSpace.piece(plot.origin, plot.layout, piece, def))
	model:SetAttribute("Uid", piece.uid)
	model:SetAttribute("PieceId", piece.pieceId)
	model:SetAttribute("Layer", piece.layer)
	model:SetAttribute("Kind", def.kind)
	model:SetAttribute("OwnerUserId", if plot.owner then plot.owner.UserId else 0)
	model:SetAttribute("Hp", piece.hp)
	model:SetAttribute("MaxHp", def.hp)
	model:SetAttribute("PlacedAt", if fresh then workspace:GetServerTimeNow() else 0)
	CollectionService:AddTag(model, Building.TAGS.piece)
	if def.kind == "station" then
		model:SetAttribute("StationId", def.stationId)
		CollectionService:AddTag(model, Building.TAGS.station)
	elseif def.kind == "storage" then
		CollectionService:AddTag(model, Building.TAGS.storage)
	elseif def.kind == "door" or def.kind == "gate" then
		CollectionService:AddTag(model, Building.TAGS.door)
	end
	model.Parent = plot.pieces
	plot.pieceModels[piece.uid] = model
	if def.kind == "storage" and plot.owner then
		local data = PlayerData.get(plot.owner)
		Plots.setCrateIcon(plot.owner, piece.uid, data and data.storage[piece.uid])
	end
end

-- Objects stand on their foundations and off the walls behind them; re-seat every
-- object after the floor or walls change.
local function reseatObjects(plot: Plots.Plot)
	for uid, piece in plot.layout.pieces do
		local model = plot.pieceModels[uid]
		if piece.layer == "object" and model then
			model:PivotTo(PlotSpace.piece(plot.origin, plot.layout, piece, Pieces[piece.pieceId]))
		end
	end
end

-- Rebuilds the trim and corner posts that depend on neighbouring pieces (World/Seams).
local function renderSeams(plot: Plots.Plot)
	local old = plot.pieces:FindFirstChild("Seams")
	if old then
		old:Destroy()
	end
	Seams.build(plot.origin, plot.layout, Pieces).Parent = plot.pieces
end

local function renderAll(player: Player, plot: Plots.Plot)
	for _, piece in plot.layout.pieces do
		render(plot, piece, false)
	end
	renderSeams(plot)
	local data = PlayerData.get(player)
	if data then
		for uid, piece in plot.layout.pieces do
			local def = Pieces[piece.pieceId]
			if def.kind == "station" and def.stationId then
				Stations.create(player, uid, def.stationId)
				Stations.refresh(player, uid)
			elseif def.kind == "storage" and data.storage[uid] == nil then
				data.storage[uid] = InventoryMath.newContainer(def.storageSlots or 0)
			elseif def.kind == "storage" and #data.storage[uid] > (def.storageSlots or 0) then
				-- The crate got smaller (v7: LDoE's 15-slot Small Box): the extra slots'
				-- items wait in the inbox, never lost.
				local crate = table.clone(data.storage[uid])
				local spill: { Types.Slot } = {}
				for index = #crate, (def.storageSlots or 0) + 1, -1 do
					if crate[index].count > 0 then
						table.insert(spill, crate[index])
					end
					crate[index] = nil :: any
				end
				data.storage[uid] = crate
				Inbox.grant(player, spill, "Update", true)
			end
		end
	end
end

-- Handlers --------------------------------------------------------------------------------------------

local function place(player: Player, pieceId: string, x: number, z: number, axis: string?, rot: number?)
	local plot = Plots.of(player)
	local data = PlayerData.get(player)
	local progress = progressOf(player)
	local view = Inventory.view(player)
	if plot == nil or data == nil or progress == nil or view == nil then
		return
	end
	local target: Grid.Target = { x = x, z = z, axis = axis :: Grid.Axis?, rot = rot }
	local ctx = Plots.context(plot, player)
	local pool = Materials.virtual(player) or view -- have/need counts the whole home pool (5.13)
	local slots = BuildRules.pieceSlots(Content.Products, data.purchases.counts)
	local ok, reason = BuildRules.canPlace(plot.layout, pieceId, target, ctx, progress, pool, slots)
	if not ok then
		deny(player, reason)
		return
	end
	local layout, piece, why = Grid.place(plot.layout, pieceId, target, ctx)
	if layout == nil or piece == nil then
		deny(player, why)
		return
	end
	local def = Pieces[pieceId]
	if not Art.pieceReady(pieceId, def.kind) then
		deny(player, "notReady") -- hidden until its model is graded A (checklist §0)
		return
	end
	if not Materials.take(player, def.cost, "Building") then
		deny(player, "cantAfford")
		return
	end
	Plots.setLayout(player, layout)
	if def.kind == "station" and def.stationId then
		Stations.create(player, piece.uid, def.stationId)
	elseif def.kind == "storage" then
		data.storage[piece.uid] = InventoryMath.newContainer(def.storageSlots or 0)
		Sync.mark(player, "pool")
	end
	render(plot, piece, true)
	renderSeams(plot)
	if piece.layer == "floor" or piece.layer == "frame" then
		reseatObjects(plot)
	end
	if def.kind == "station" then
		Stations.refresh(player, piece.uid)
	end
	Analytics.custom(player, "BuildPlace", 1, { pieceId })
	Sync.fx(player, "built", { uid = piece.uid, pieceId = pieceId })
	Events.played:Fire(player, { kind = "build", pieceId = pieceId, count = 1 })
end

local function upgrade(player: Player, uid: string)
	local plot = Plots.of(player)
	local data = PlayerData.get(player)
	local progress = progressOf(player)
	local view = Inventory.view(player)
	if plot == nil or data == nil or progress == nil or view == nil then
		return
	end
	local ctx = Plots.context(plot, player)
	local ok, nextDef, reason =
		BuildRules.canUpgrade(plot.layout, uid, ctx, progress, Materials.virtual(player) or view)
	if not ok or nextDef == nil then
		deny(player, reason)
		return
	end
	local layout, cost, why = Grid.upgrade(plot.layout, uid, ctx)
	if layout == nil or cost == nil then
		deny(player, why)
		return
	end
	if not Materials.take(player, cost, "Building") then
		deny(player, "cantAfford")
		return
	end
	Plots.setLayout(player, layout)
	local piece = layout.pieces[uid]
	if nextDef.kind == "storage" and data.storage[uid] then
		local crate = table.clone(data.storage[uid])
		for index = #crate + 1, nextDef.storageSlots or #crate do
			crate[index] = InventoryMath.emptySlot()
		end
		data.storage[uid] = crate
		Sync.mark(player, "storage")
	end
	render(plot, piece, true)
	renderSeams(plot)
	Analytics.custom(player, "BuildUpgrade", 1, { nextDef.id })
	Sync.fx(player, "upgraded", { uid = uid, pieceId = nextDef.id })
	Events.played:Fire(player, { kind = "build", pieceId = nextDef.id, count = 1 })
end

-- Move (LDOE_PARITY #27): an object moves or turns, keeping its uid, so a station keeps its
-- converter and a crate its items.
local function move(player: Player, uid: string, x: number, z: number, rot: number)
	local plot = Plots.of(player)
	if plot == nil then
		return
	end
	local piece = plot.layout.pieces[uid]
	if piece == nil then
		deny(player, "notFound")
		return
	end
	local target: Grid.Target = { x = x, z = z, rot = rot }
	local ctx = Plots.context(plot, player)
	local ok, reason = BuildRules.canMove(plot.layout, uid, target, ctx)
	if not ok then
		deny(player, reason)
		return
	end
	local layout, why = Grid.move(plot.layout, uid, target, ctx)
	if layout == nil then
		deny(player, why)
		return
	end
	Plots.setLayout(player, layout)
	render(plot, layout.pieces[uid], true)
	reseatObjects(plot)
	Analytics.custom(player, "BuildMove", 1, { piece.pieceId })
	Sync.fx(player, "moved", { uid = uid, pieceId = piece.pieceId })
end

local function isEmptyContainer(container: Types.Container?): boolean
	if container == nil then
		return true
	end
	for _, slot in container do
		if slot.count > 0 then
			return false
		end
	end
	return true
end

local function demolish(player: Player, uid: string)
	local plot = Plots.of(player)
	local data = PlayerData.get(player)
	if plot == nil or data == nil then
		return
	end
	local piece = plot.layout.pieces[uid]
	if piece == nil then
		deny(player, "notFound")
		return
	end
	local def = Pieces[piece.pieceId]
	if def.kind == "storage" and not isEmptyContainer(data.storage[uid]) then
		Sync.notice(player, "Empty the crate first")
		return
	end
	if def.kind == "station" and Stations.isBusy(player, uid) then
		Sync.notice(player, "Take everything out of the station first")
		return
	end
	local layout, removal, reason = Grid.demolish(plot.layout, uid, Plots.context(plot, player))
	if layout == nil or removal == nil then
		deny(player, reason)
		return
	end
	Plots.setLayout(player, layout)
	-- What doesn't fit the bag waits in the inbox (4.15).
	local _, leftover = Inventory.give(player, removal.refund, "Demolish")
	Inbox.grant(player, leftover :: any, "Overflow")
	local debris = {}
	for _, gone in removal.removed do
		local model = plot.pieceModels[gone.uid]
		if model then
			table.insert(debris, { cframe = model:GetPivot(), pieceId = gone.pieceId, size = model:GetExtentsSize() })
			model:Destroy()
			plot.pieceModels[gone.uid] = nil
		end
		local goneDef = Pieces[gone.pieceId]
		if goneDef.kind == "station" then
			Stations.remove(player, gone.uid)
		elseif goneDef.kind == "storage" then
			data.storage[gone.uid] = nil
			data.storageLabels[gone.uid] = nil
		end
	end
	renderSeams(plot)
	reseatObjects(plot)
	Net.fireAllClients("Fx", "debris", { pieces = debris })
	Analytics.custom(player, "BuildDemolish", 1, { piece.pieceId })
	Sync.fx(player, "items", { items = removal.refund, source = "refund" })
end

-- Lifecycle ---------------------------------------------------------------------------------------------

-- Places a piece exactly as the BuildPlace remote would (Studio dev commands).
Building.place = place
Building.upgrade = upgrade
Building.demolish = demolish

function Building.init()
	Net.onEvent("BuildPlace", place)
	Net.onEvent("BuildUpgrade", upgrade)
	Net.onEvent("BuildDemolish", demolish)
	Net.onEvent("BuildMove", move)
end

function Building.start()
	Plots.claimed:Connect(renderAll)
	Plots.releasing:Connect(function(_player: Player, plot: Plots.Plot)
		plot.pieces:ClearAllChildren()
		plot.pieceModels = {}
	end)
end

return Building
