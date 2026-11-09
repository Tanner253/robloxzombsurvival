--!strict
--[[
	Plots: the Neighbourhood's home plots (GAME_DESIGN.md "Structure").

	Tuning.plots.count plots sit in two rows facing a shared road under
	Workspace.World.Plots. Each player claims the first free plot once their
	profile loads and keeps it until they leave. The outpost (Domain/OutpostSchema: the
	Grid layout, its finite home nodes and projects) is saved separately from the
	profile (ARCHITECTURE.md §6) in the "Outposts" store, one profile per player, so a
	big base never hits the profile limit. A brand-new outpost starts with the damaged
	starter shelter (Domain/Shelter, LDOE_PARITY #56), laid once and never again.

	The Studio place owns the world: when Workspace.World or its plots exist
	there, their `Origin` attributes are used. A missing folder or plot is created
	here from Tuning so a bare place still plays; the ground is Scenery's terrain.

	Other services listen to `claimed` (render pieces, spawn nodes) and
	`releasing` (clean up) and change the layout only through `setLayout`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Content = require(ReplicatedStorage.Shared.Data)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Migrations = require(ReplicatedStorage.Shared.Domain.Migrations)
local OutpostSchema = require(ReplicatedStorage.Shared.Domain.OutpostSchema)
local Shelter = require(ReplicatedStorage.Shared.Domain.Shelter)
local Stores = require("../Stores")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")
local Teleport = require("../FogRuns/Teleport")

local Plots = {}

export type Plot = {
	index: number,
	origin: Vector3, -- world position of grid corner (0, 0) at ground level
	model: Model,
	pieces: Folder,
	nodes: Folder,
	owner: Player?,
	layout: Grid.Layout,
	profile: any?, -- the owner's Outposts profile
	readOnly: boolean, -- a layout that failed to load is never saved over
	pieceModels: { [string]: Model }, -- uid -> model, kept by the Building service
	front: number, -- +1 when the road is on the +Z side, -1 on the -Z side
}

-- Fires (player, plot) once a plot is claimed and its layout loaded.
Plots.claimed = Signal.new()
-- Fires (player, plot) as the owner leaves, before the layout is saved. Must not yield.
Plots.releasing = Signal.new()

local STORE_NAME = "Outposts"
-- Where the neighbourhood goes when the place has no Workspace.World "Origin":
-- well clear of the look-test scenes around the world origin.
local DEFAULT_ORIGIN = Vector3.new(0, 0, 900)

local building = Content.Tuning.building
local tuning = Content.Tuning.plots
local GRID_STUDS = building.plotCells * Grid.CELL_STUDS

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local store: any

local function template(): OutpostSchema.Data
	return OutpostSchema.template()
end

-- World layout ---------------------------------------------------------------------------

local function worldFolder(): Folder
	local world = workspace:FindFirstChild("World")
	if world == nil then
		world = Instance.new("Folder")
		world.Name = "World"
		world:SetAttribute("Origin", DEFAULT_ORIGIN)
		world.Parent = workspace
	end
	return world :: Folder
end

local function child(parent: Instance, name: string, className: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

-- Grid corner of plot `index` from Tuning: two rows of `columns`, a road between.
local function defaultOrigin(worldOrigin: Vector3, index: number): (Vector3, number)
	local column = (index - 1) % tuning.columns
	local row = (index - 1) // tuning.columns
	local x = (column - (tuning.columns - 1) / 2) * tuning.spacingStuds
	local offset = tuning.rowGapStuds / 2 + tuning.marginStuds + GRID_STUDS / 2
	local z = if row == 0 then -offset else offset
	local front = if row == 0 then 1 else -1
	return worldOrigin + Vector3.new(x - GRID_STUDS / 2, 0, z - GRID_STUDS / 2), front
end

-- A sign at the road edge showing who lives here.
local function makeSign(plot: Plot)
	local sign = plot.model:FindFirstChild("Sign")
	if sign == nil then
		local part = Instance.new("Part")
		part.Name = "Sign"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		local edge = if plot.front > 0 then GRID_STUDS + tuning.marginStuds * 0.35 else -tuning.marginStuds * 0.35
		part.CFrame = CFrame.new(plot.origin + Vector3.new(GRID_STUDS / 2, 7, edge))
		local gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.fromOffset(240, 40)
		gui.MaxDistance = 140
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold)
		label.TextColor3 = Color3.fromHex("F2EBDD")
		label.TextStrokeTransparency = 0.4
		label.TextSize = 24
		label.Text = ""
		label.Parent = gui
		gui.Parent = part
		part.Parent = plot.model
		sign = part
	end
	local label = (sign :: Instance):FindFirstChild("Text", true) :: TextLabel?
	if label then
		label.Text = if plot.owner then `{plot.owner.DisplayName}'s Outpost` else "Free plot"
	end
end

-- A spawn on the neighbourhood road, so players never start far away (with
-- streaming) from their plot. The place's other spawns are left alone.
local function roadSpawn(world: Instance, worldOrigin: Vector3): SpawnLocation
	local existing = world:FindFirstChild("RoadSpawn")
	if existing and existing:IsA("SpawnLocation") then
		return existing
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RoadSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CFrame = CFrame.new(worldOrigin + Vector3.new(0, 0.1, 0))
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = world
	return spawn
end

local spawnPoint: SpawnLocation? = nil

local function buildWorld()
	local world = worldFolder()
	local worldOrigin = world:GetAttribute("Origin")
	if typeof(worldOrigin) ~= "Vector3" then
		worldOrigin = DEFAULT_ORIGIN
	end
	local plotsFolder = child(world, "Plots", "Folder")
	for index = 1, tuning.count do
		local model = plotsFolder:FindFirstChild(`Plot{index}`) :: Model?
		local origin, front = defaultOrigin(worldOrigin :: Vector3, index)
		if model == nil then
			local made = Instance.new("Model")
			made.Name = `Plot{index}`
			made.Parent = plotsFolder
			model = made
		end
		local m = model :: Model
		local savedOrigin = m:GetAttribute("Origin")
		if typeof(savedOrigin) == "Vector3" then
			origin = savedOrigin
			local savedFront = m:GetAttribute("Front")
			front = if type(savedFront) == "number" then savedFront else front
		end
		m:SetAttribute("PlotIndex", index)
		m:SetAttribute("Origin", origin)
		m:SetAttribute("Front", front)
		m:SetAttribute("Cells", building.plotCells)
		m:SetAttribute("OwnerUserId", 0)
		local plot: Plot = {
			index = index,
			origin = origin,
			model = m,
			pieces = child(m, "Pieces", "Folder") :: Folder,
			nodes = child(m, "Nodes", "Folder") :: Folder,
			owner = nil,
			layout = Grid.new(),
			profile = nil,
			readOnly = false,
			pieceModels = {},
			front = front,
		}
		plots[index] = plot
		makeSign(plot)
	end
	spawnPoint = roadSpawn(world, worldOrigin :: Vector3)
end

-- Spawning --------------------------------------------------------------------------------------

-- Where the owner appears: the middle of the road edge, facing the plot.
function Plots.spawnCFrame(plot: Plot): CFrame
	local edge = if plot.front > 0 then GRID_STUDS + tuning.marginStuds * 0.5 else -tuning.marginStuds * 0.5
	local at = plot.origin + Vector3.new(GRID_STUDS / 2, 3, edge)
	local centre = plot.origin + Vector3.new(GRID_STUDS / 2, 3, GRID_STUDS / 2)
	return CFrame.lookAt(at, centre)
end

local function moveToPlot(player: Player, character: Model)
	local plot = byPlayer[player]
	if plot == nil then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and byPlayer[player] == plot then
		local spawn = Plots.spawnCFrame(plot)
		-- Streaming is on: load the plot around the player before moving them there.
		pcall(player.RequestStreamAroundAsync, player, spawn.Position, 5)
		if byPlayer[player] == plot and character.Parent then
			character:PivotTo(spawn)
		end
	end
end

-- Claim and release ------------------------------------------------------------------------------

local function release(player: Player)
	local plot = byPlayer[player]
	if plot == nil then
		return
	end
	byPlayer[player] = nil
	Plots.releasing:Fire(player, plot)
	local profile = plot.profile
	if profile then
		if not plot.readOnly then
			profile.Data.layout = Grid.serialize(plot.layout)
		end
		profile:EndSession()
	end
	plot.owner = nil
	plot.profile = nil
	plot.readOnly = false
	plot.layout = Grid.new()
	plot.pieceModels = {}
	plot.model:SetAttribute("OwnerUserId", 0)
	makeSign(plot)
end

local function claim(player: Player)
	if byPlayer[player] then
		return
	end
	local plot: Plot? = nil
	for _, candidate in plots do
		if candidate.owner == nil then
			plot = candidate
			break
		end
	end
	if plot == nil then
		warn(`Plots: no free plot for {player.Name}`)
		return
	end
	local p = plot :: Plot
	p.owner = player
	byPlayer[player] = p

	local profile = store:StartSessionAsync(`Outpost_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if player.Parent ~= Players or byPlayer[player] ~= p then
		if profile then
			profile:EndSession()
		end
		if byPlayer[player] == p then
			byPlayer[player] = nil
			p.owner = nil
		end
		return
	end
	if profile == nil then
		p.owner = nil
		byPlayer[player] = nil
		player:Kick("Your outpost could not be loaded. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	-- Migrate before Reconcile, which would stamp the template's version on old data.
	OutpostSchema.prepare(profile.Data)
	local migrated, why = Migrations.run(profile.Data, OutpostSchema.migrations, OutpostSchema.VERSION)
	if not migrated then
		-- Like PlayerData: never reconcile or play on half-migrated data; end and retry later.
		warn(`Plots: outpost {player.UserId} could not migrate ({why})`)
		profile:EndSession()
		p.owner = nil
		byPlayer[player] = nil
		player:Kick("Your outpost needs a newer server. Please rejoin.")
		return
	end
	profile:Reconcile()
	local layout, reason = Grid.deserialize(profile.Data.layout, Content.BuildPieces)
	if layout == nil then
		warn(`Plots: layout for {player.UserId} failed to load ({reason}); it will not be saved over`)
		p.readOnly = true
		layout = Grid.new()
	end
	-- A brand-new outpost gets the damaged starter shelter, once.
	if not p.readOnly and profile.Data.seeded ~= true then
		local gridPlot: Grid.Plot =
			{ ownerUserId = player.UserId, width = building.plotCells, depth = building.plotCells }
		local shelter, failed = Shelter.build(Content.StarterShelter, Content.BuildPieces, gridPlot, p.front, os.time())
		if failed then
			warn(`Plots: starter shelter failed ({failed})`)
		else
			layout = shelter
			profile.Data.layout = Grid.serialize(shelter)
		end
		profile.Data.seeded = true
	end
	p.profile = profile
	p.layout = layout :: Grid.Layout
	p.model:SetAttribute("OwnerUserId", player.UserId)
	makeSign(p)

	profile.OnSessionEnd:Connect(function()
		if byPlayer[player] == p and p.profile == profile then
			player:Kick("Your outpost was opened on another server. Please rejoin.")
		end
	end)

	Plots.claimed:Fire(player, p)
	Sync.mark(player, "plot")
	Sync.mark(player, "layout")
	if player.Character then
		task.spawn(moveToPlot, player, player.Character)
	end
end

-- API ----------------------------------------------------------------------------------------------

function Plots.of(player: Player): Plot?
	return byPlayer[player]
end

function Plots.all(): { Plot }
	return plots
end

-- The Domain/Grid plot description for the owner.
function Plots.gridPlot(plot: Plot): Grid.Plot
	return {
		ownerUserId = if plot.owner then plot.owner.UserId else 0,
		width = building.plotCells,
		depth = building.plotCells,
	}
end

-- A Grid context for `player` acting on `plot` right now.
function Plots.context(plot: Plot, player: Player): Grid.Context
	return {
		plot = Plots.gridPlot(plot),
		actorUserId = player.UserId,
		pieces = Content.BuildPieces,
		now = os.time(),
		config = building,
	}
end

-- The owner's saved outpost (OutpostSchema.Data: nodes, projects...), or nil.
function Plots.outpost(player: Player): OutpostSchema.Data?
	local plot = byPlayer[player]
	local profile = plot and plot.profile
	return if profile then profile.Data else nil
end

-- Replaces the owner's layout and saves it with their Outposts profile.
function Plots.setLayout(player: Player, layout: Grid.Layout)
	local plot = byPlayer[player]
	assert(plot, "player has no plot")
	plot.layout = layout
	if plot.profile and not plot.readOnly then
		plot.profile.Data.layout = Grid.serialize(layout)
	end
	Sync.mark(player, "layout")
end

-- The world position of a placed piece's model (for reach checks), or nil.
function Plots.piecePosition(player: Player, uid: string): Vector3?
	local plot = byPlayer[player]
	local model = plot and plot.pieceModels[uid]
	return if model then model:GetPivot().Position else nil
end

-- Marks a storage crate's model with the item it holds most of (MainItem), so the
-- client can show that icon over it (checklist 4.13); empty crates show nothing.
function Plots.setCrateIcon(player: Player, uid: string, slots: { any }?)
	local plot = byPlayer[player]
	local model: Model? = if plot then plot.pieceModels[uid] else nil
	if not model then
		return
	end
	local data = PlayerData.get(player)
	local pinned = data and (data :: any).storageLabels and (data :: any).storageLabels[uid]
	if type(pinned) == "string" then
		model:SetAttribute("MainItem", pinned) -- the player's brush choice (LDOE_PARITY #16)
		return
	end
	local totals: { [string]: number } = {}
	local best: string?, bestCount = nil, 0
	local list: { any } = slots or {}
	for _, slot in list do
		if slot.count > 0 then
			totals[slot.itemId] = (totals[slot.itemId] or 0) + slot.count
			if totals[slot.itemId] > bestCount then
				best, bestCount = slot.itemId, totals[slot.itemId]
			end
		end
	end
	model:SetAttribute("MainItem", best)
end

-- Whether the player's character stands within `reach` studs (flat) of `position`.
function Plots.inReach(player: Player, position: Vector3, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	local offset = root.Position - position
	return Vector2.new(offset.X, offset.Z).Magnitude <= reach and math.abs(offset.Y) <= reach + 6
end

-- Whether the player stands within arm's reach of an object's edge (checklist 3.11):
-- `radius` is the object's footprint radius; the server adds a little tolerance.
function Plots.withinArm(player: Player, position: Vector3, radius: number): boolean
	local reach = Content.Tuning.interaction
	return Plots.inReach(player, position, radius + reach.reachStuds + reach.toleranceStuds)
end

-- The footprint radius of a placed piece (half its widest side), or 1 when it has no model.
function Plots.pieceRadius(player: Player, uid: string): number
	local plot = Plots.of(player)
	local model = plot and plot.pieceModels[uid]
	if model == nil then
		return 1
	end
	local size = model:GetExtentsSize()
	return math.max(size.X, size.Z) / 2
end

function Plots.init()
	store = Stores.open(STORE_NAME, template())
end

function Plots.start()
	-- A Fog Run lobby server (same place, reserved) builds its location instead (RunWorld).
	if Teleport.role() == "run" then
		return
	end
	buildWorld()
	Sync.provide("plot", function(player: Player)
		local plot = byPlayer[player]
		if plot == nil then
			return false
		end
		return { index = plot.index, origin = plot.origin, cells = building.plotCells, front = plot.front }
	end)
	Sync.provide("layout", function(player: Player)
		local plot = byPlayer[player]
		return if plot then Grid.serialize(plot.layout) else false
	end)

	PlayerData.loaded:Connect(function(player: Player)
		claim(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.RespawnLocation = spawnPoint :: any
		player.CharacterAdded:Connect(function(character)
			moveToPlot(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.RespawnLocation = spawnPoint :: any
		player.CharacterAdded:Connect(function(character)
			moveToPlot(player, character)
		end)
		if PlayerData.get(player) then
			task.spawn(claim, player)
		end
	end
	Players.PlayerRemoving:Connect(release)
end

return Plots
