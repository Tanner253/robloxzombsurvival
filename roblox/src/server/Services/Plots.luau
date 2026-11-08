--!strict
--[[
	Plots: the Neighbourhood's home plots (GAME_DESIGN.md "Structure").

	Tuning.plots.count plots sit in two rows facing a shared road under
	Workspace.World.Plots. Each player claims the first free plot once their
	profile loads and keeps it until they leave. The outpost layout (Domain/Grid)
	is saved separately from the profile (ARCHITECTURE.md §6) in the "Outposts"
	store, one profile per player, so a big base never hits the profile limit.

	The Studio place owns the world: when Workspace.World or its plots exist
	there, their `Origin` attributes are used. Missing pieces (the folder, plots,
	ground) are created here from Tuning so a bare place still plays.

	Other services listen to `claimed` (render pieces, spawn nodes) and
	`releasing` (clean up) and change the layout only through `setLayout`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Content = require(ReplicatedStorage.Shared.Data)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local Stores = require("../Stores")
local PlayerData = require("./PlayerData")
local Sync = require("./Sync")

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

local function template(): { layout: Grid.Saved }
	return { layout = Grid.serialize(Grid.new()) }
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

local function makeGround(world: Instance, worldOrigin: Vector3)
	if world:FindFirstChild("Ground") then
		return
	end
	local width = tuning.columns * tuning.spacingStuds + 2 * tuning.marginStuds
	local depth = 2 * (GRID_STUDS + 2 * tuning.marginStuds) + tuning.rowGapStuds + 2 * tuning.marginStuds
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(84, 92, 62)
	ground.Size = Vector3.new(width, 4, depth)
	ground.CFrame = CFrame.new(worldOrigin - Vector3.new(0, 2, 0))
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = world
	local road = Instance.new("Part")
	road.Name = "Road"
	road.Anchored = true
	road.Material = Enum.Material.Mud
	road.Color = Color3.fromRGB(92, 78, 62)
	road.Size = Vector3.new(width, 0.2, tuning.rowGapStuds * 0.7)
	road.CFrame = CFrame.new(worldOrigin + Vector3.new(0, 0.05, 0))
	road.Parent = world
end

local function makePad(model: Model, origin: Vector3)
	if model:FindFirstChild("Pad") then
		return
	end
	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.Material = Enum.Material.Ground
	pad.Color = Color3.fromRGB(96, 84, 66)
	pad.Size = Vector3.new(GRID_STUDS, 0.2, GRID_STUDS)
	pad.CFrame = CFrame.new(origin + Vector3.new(GRID_STUDS / 2, 0.06, GRID_STUDS / 2))
	pad.Parent = model
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

local function buildWorld()
	local world = worldFolder()
	local worldOrigin = world:GetAttribute("Origin")
	if typeof(worldOrigin) ~= "Vector3" then
		worldOrigin = DEFAULT_ORIGIN
	end
	local plotsFolder = child(world, "Plots", "Folder")
	local createdAny = false
	for index = 1, tuning.count do
		local model = plotsFolder:FindFirstChild(`Plot{index}`) :: Model?
		local origin, front = defaultOrigin(worldOrigin :: Vector3, index)
		if model == nil then
			local made = Instance.new("Model")
			made.Name = `Plot{index}`
			made.Parent = plotsFolder
			model = made
			createdAny = true
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
		makePad(m, origin)
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
	if createdAny then
		makeGround(world, worldOrigin :: Vector3)
	end
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
		character:PivotTo(Plots.spawnCFrame(plot))
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
	profile:Reconcile()
	local layout, reason = Grid.deserialize(profile.Data.layout)
	if layout == nil then
		warn(`Plots: layout for {player.UserId} failed to load ({reason}); it will not be saved over`)
		p.readOnly = true
		layout = Grid.new()
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

function Plots.init()
	store = Stores.open(STORE_NAME, template())
end

function Plots.start()
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
		player.CharacterAdded:Connect(function(character)
			moveToPlot(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
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
