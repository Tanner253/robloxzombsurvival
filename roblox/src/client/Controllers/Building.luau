--!strict
--[[
	Building (client): build mode (B). The ghost preview is the real piece model
	(ReplicatedStorage.Assets.Pieces), snapped with Shared/PlotSpace and checked
	with the same Domain/BuildRules the server runs, against the synced layout,
	level, unlocks and inventory. Green means the server will accept it.

	Modes: place (LMB, drag to paint foundations and walls, R rotates objects),
	upgrade (U, hover a piece) and demolish (X, click twice to confirm). On touch,
	the ghost follows the last tap and the build menu's Place button confirms.
	A faint grid overlay shows the plot's cells while building.

	LDoE build mode (LDOE_PARITY #25, #27): with no piece picked, clicking a placed piece
	selects it for its floating actions (move, demolish, upgrade); Move lifts an object
	(station, crate) and the ghost carries it to its new spot, keeping what it holds. The
	"hide upper walls" toggle fades walls and doors so the rooms below stay readable.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Content = require(ReplicatedStorage.Shared.Data)
local PlotSpace = require(ReplicatedStorage.Shared.PlotSpace)
local Types = require(ReplicatedStorage.Shared.Types)
local Grid = require(ReplicatedStorage.Shared.Domain.Grid)
local BuildRules = require(ReplicatedStorage.Shared.Domain.BuildRules)
local Net = require("../Net")
local Sfx = require("../Sfx")
local Pool = require("../Pool")
local State = require("../State")
local Theme = require("../UI/theme")

local Building = {}

local player = Players.LocalPlayer
local Pieces = Content.BuildPieces

local GHOST_TRANSPARENCY = 0.35
local GHOST_RATE = 28
local PAINT_SECONDS = 0.18
local CONFIRM_SECONDS = 2.5
local GRID_COLOR = Theme.colors.highlight
local VALID = Theme.colors.durability
local INVALID = Theme.colors.threat
local UPGRADE = Theme.colors.accentSoft
local DEMOLISH = Theme.colors.accent

local ghost: Model? = nil
local ghostPiece: string? = nil
local ghostCFrame: CFrame? = nil
local highlight: Highlight? = nil
local overlay: Folder? = nil
local rotation = 0
-- How close (studs) the cursor must be to a wall for an object to snap against it.
local WALL_SNAP_STUDS = 4.5
local current: { target: Grid.Target, valid: boolean, reason: string? }? = nil
local hoveredUid: string? = nil
local armed: { uid: string, at: number }? = nil
local painting = false
local lastPaint = 0
local lastPaintKey = ""
local touchPoint: Vector2? = nil
local moving: string? = nil -- the uid of the object being moved
local wallsFaded = false
local furnitureGhosted = false
local FURNITURE_GHOST = Color3.fromHex("7FE3F0") -- LDoE's translucent cyan (rec2_07)

local cachedSaved: any = nil
local cachedLayout: Grid.Layout? = nil

-- Synced state ------------------------------------------------------------------------------------

local function layout(): Grid.Layout?
	local saved = State.get("layout")
	if not saved then
		return nil
	end
	if saved ~= cachedSaved then
		cachedSaved = saved
		cachedLayout = Grid.deserialize(saved, Pieces :: any)
	end
	return cachedLayout
end

local function plot(): { origin: Vector3, cells: number, index: number }?
	local info = State.get("plot")
	return if info then info else nil
end

local function context(): Grid.Context?
	local info = plot()
	if info == nil then
		return nil
	end
	return {
		plot = { ownerUserId = player.UserId, width = info.cells, depth = info.cells },
		actorUserId = player.UserId,
		pieces = Pieces,
		now = os.time(),
		config = Content.Tuning.building :: any,
	}
end

local function progress(): BuildRules.Progress
	local p = State.get("progression")
	local unlocks = State.get("unlocks")
	local quests = State.get("quests")
	return {
		level = if p then p.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
		quests = if type(quests) == "table" then quests else nil,
	}
end

-- What costs are checked against: carried items plus the home pool (5.13).
local function inventory(): any
	return Pool.inventory(State.get("inventory"))
end

-- The hint text for the cursor: why it is invalid, or what it costs.
local function costText(cost: { { itemId: string, count: number } }): string
	return BuildRules.costText(cost, inventory(), Content.Items :: any)
end

-- Why something can't be built or upgraded, with have/need and unlock details.
local function why(reason: string?, def: any): string
	return BuildRules.explain(reason, def, inventory(), Content.Items :: any, Pieces :: any, Content.Quests :: any)
end

-- Ghost -------------------------------------------------------------------------------------------

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostPiece, ghostCFrame, highlight = nil, nil, nil, nil
end

local function makeGhost(pieceId: string)
	clearGhost()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Pieces")
	local source = folder and folder:FindFirstChild(pieceId)
	if source == nil or not source:IsA("Model") then
		return
	end
	local model = source:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = math.max(descendant.Transparency, GHOST_TRANSPARENCY)
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = math.max(descendant.Transparency, GHOST_TRANSPARENCY)
		end
	end
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 0.6
	glow.OutlineTransparency = 0.1
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = model
	model.Parent = workspace
	ghost, ghostPiece, highlight = model, pieceId, glow
end

local function clearOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function makeOverlay(origin: Vector3, cells: number)
	clearOverlay()
	local folder = Instance.new("Folder")
	folder.Name = "BuildGrid"
	local length = cells * Grid.CELL_STUDS
	for index = 0, cells do
		for _, alongX in { true, false } do
			local line = Instance.new("Part")
			line.Anchored = true
			line.CanCollide = false
			line.CanQuery = false
			line.CastShadow = false
			line.Material = Enum.Material.Neon
			line.Color = GRID_COLOR
			line.Transparency = if index == 0 or index == cells then 0.45 else 0.8
			local offset = index * Grid.CELL_STUDS
			line.Size = if alongX then Vector3.new(length, 0.05, 0.12) else Vector3.new(0.12, 0.05, length)
			line.Position = origin
				+ (if alongX then Vector3.new(length / 2, 0.12, offset) else Vector3.new(offset, 0.12, length / 2))
			line.Parent = folder
		end
	end
	folder.Parent = workspace
	overlay = folder
end

-- The Pieces folder of plot `index` in Workspace.World, if it exists.
function Building.piecesFolder(index: number): Instance?
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	local model = plots and plots:FindFirstChild(`Plot{index}`)
	return model and model:FindFirstChild("Pieces")
end

-- Cursor --------------------------------------------------------------------------------------------

local function cursorRay(): Ray?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local point = if State.ui().touch then touchPoint else UserInputService:GetMouseLocation()
	if point == nil then
		return nil
	end
	return camera:ViewportPointToRay(point.X, point.Y)
end

local function cursorLocal(origin: Vector3): (number?, number?)
	local ray = cursorRay()
	if ray == nil or math.abs(ray.Direction.Y) < 1e-4 then
		return nil, nil
	end
	local t = (origin.Y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil, nil
	end
	local hit = ray.Origin + ray.Direction * t
	return PlotSpace.toLocal(origin, hit)
end

local function pieceUnderCursor(): string?
	local ray = cursorRay()
	local info = plot()
	local pieces = Building.piecesFolder(if info then info.index else 0)
	if ray == nil or pieces == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { pieces }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local instance: Instance? = if hit then hit.Instance else nil
	while instance and instance.Parent ~= pieces do
		instance = instance.Parent
	end
	return if instance then instance:GetAttribute("Uid") :: string? else nil
end

-- An object's target under the cursor: its footprint centred on the cursor and
-- snapped to the quarter-cell grid. Near a wall it snaps flush with its back to the
-- wall, facing into the room (LDoE puts stations against walls); otherwise R rotates.
local function objectTarget(def: Types.BuildPieceDef, px: number, pz: number): Grid.Target
	local sub, quarter = Grid.SUB, Grid.SUB_STUDS
	local placed = layout()
	if placed then
		local axis, ex, ez = Grid.edgeNear(px, pz)
		if Grid.pieceAt(placed, "frame", ex, ez, axis :: Grid.Axis) then
			local lineStuds = (if axis == "h" then ez else ex) * Grid.CELL_STUDS
			local offset = (if axis == "h" then pz else px) - lineStuds
			if math.abs(offset) <= WALL_SNAP_STUDS then
				-- The wall is behind the object: on the cursor's far side of the line.
				local rot = if axis == "h" then (if offset > 0 then 2 else 0) else (if offset > 0 then 3 else 1)
				local w, d = Grid.footprint(def, rot)
				local line = (if axis == "h" then ez else ex) * sub
				if axis == "h" then
					local qz = if offset > 0 then line else line - d
					return { x = math.round(px / quarter - w / 2), z = qz, rot = rot }
				end
				local qx = if offset > 0 then line else line - w
				return { x = qx, z = math.round(pz / quarter - d / 2), rot = rot }
			end
		end
	end
	local w, d = Grid.footprint(def, rotation)
	return { x = math.round(px / quarter - w / 2), z = math.round(pz / quarter - d / 2), rot = rotation }
end

local function targetFor(def: Types.BuildPieceDef, px: number, pz: number): Grid.Target
	local layer = Grid.layerOf(def)
	if layer == "frame" or layer == "fill" then
		local axis, x, z = Grid.edgeNear(px, pz)
		local edge: Grid.Target = { x = x, z = z, axis = axis :: Grid.Axis }
		return edge
	elseif layer == "object" then
		return objectTarget(def, px, pz)
	end
	local x, z = Grid.cellAt(px, pz)
	local cell: Grid.Target = { x = x, z = z }
	return cell
end

local function targetKey(target: Grid.Target): string
	return `{target.x},{target.z},{target.axis or ""},{target.rot or 0}`
end

local function setHint(text: string?)
	if State.ui().buildHint ~= text then
		if text then
			State.patch({ buildHint = text })
		else
			State.clear("buildHint")
		end
	end
end

-- Hover highlight for upgrade and demolish modes.
local hoverHighlight: Highlight? = nil
local function hover(uid: string?, color: Color3?)
	hoveredUid = uid
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	local info = plot()
	if uid == nil or info == nil or color == nil then
		return
	end
	local pieces = Building.piecesFolder(info.index)
	local piece = pieces and pieces:FindFirstChild(uid)
	if piece then
		local glow = Instance.new("Highlight")
		glow.FillColor = color
		glow.OutlineColor = color
		glow.FillTransparency = 0.7
		glow.Parent = piece
		hoverHighlight = glow
	end
end

-- Hide upper walls (#25): fades every wall, doorway, window and door on my plot.
local function fadeWalls(hidden: boolean)
	wallsFaded = hidden
	local info = plot()
	local pieces = Building.piecesFolder(if info then info.index else 0)
	if pieces == nil then
		return
	end
	for _, model in pieces:GetChildren() do
		local layer = model:GetAttribute("Layer")
		if layer == "frame" or layer == "fill" then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if hidden then 0.85 else 0
				end
			end
		end
	end
end

-- Furniture as translucent cyan ghosts while building (#28), so floors and walls read
-- clearly and every object shows where it stands.
local function ghostFurniture(on: boolean)
	furnitureGhosted = on
	local info = plot()
	local pieces = Building.piecesFolder(if info then info.index else 0)
	if pieces == nil then
		return
	end
	for _, model in pieces:GetChildren() do
		if model:GetAttribute("Layer") ~= "object" then
			continue
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if on then 0.55 else 0
			end
		end
		local glow = model:FindFirstChild("EO_BuildGhost")
		if on and glow == nil then
			local made = Instance.new("Highlight")
			made.Name = "EO_BuildGhost"
			made.FillColor = FURNITURE_GHOST
			made.OutlineColor = FURNITURE_GHOST
			made.FillTransparency = 0.55
			made.OutlineTransparency = 0.3
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.Parent = model
		elseif not on and glow then
			glow:Destroy()
		end
	end
end

-- The model of a placed piece on my plot (the floating piece actions sit on it).
function Building.pieceModel(uid: string): Model?
	local info = plot()
	local pieces = Building.piecesFolder(if info then info.index else 0)
	if pieces == nil then
		return nil
	end
	for _, model in pieces:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Uid") == uid then
			return model
		end
	end
	return nil
end

-- Move (#27): lifts an object so the ghost carries it; confirm puts it down.
function Building.beginMove(uid: string)
	local placed = layout()
	local piece = placed and placed.pieces[uid]
	if piece == nil or piece.layer ~= "object" then
		return
	end
	moving = uid
	rotation = piece.rot
	State.patch({ buildPiece = piece.pieceId, buildMode = "place" })
	State.clear("pieceActions")
end

function Building.cancelMove()
	if moving then
		moving = nil
		State.clear("buildPiece")
	end
end

local function step(dt: number)
	local ui = State.ui()
	local fade = ui.panel == "build" and ui.hideUpperWalls == true
	if fade ~= wallsFaded then
		fadeWalls(fade)
	end
	local ghosts = ui.panel == "build"
	if ghosts ~= furnitureGhosted then
		ghostFurniture(ghosts)
	end
	local info = plot()
	local currentLayout = layout()
	local ctx = context()
	if ui.panel ~= "build" or info == nil or currentLayout == nil or ctx == nil then
		if ghost or overlay or hoveredUid then
			clearGhost()
			clearOverlay()
			hover(nil)
			current = nil
		end
		moving = nil
		return
	end
	if overlay == nil then
		makeOverlay(info.origin, info.cells)
	end

	if ui.buildMode ~= "place" then
		clearGhost()
		current = nil
		local uid = pieceUnderCursor()
		local color = if ui.buildMode == "upgrade" then UPGRADE else DEMOLISH
		if uid ~= hoveredUid then
			hover(uid, color)
		end
		if uid == nil then
			setHint(
				if ui.buildMode == "upgrade"
					then "Point at a piece to upgrade it"
					else "Point at a piece to demolish it"
			)
			return
		end
		local piece = currentLayout.pieces[uid]
		if piece == nil then
			return
		end
		-- Hovering a piece shows its HP (checklist 6.5).
		local health = `HP {math.ceil(piece.hp)}/{Pieces[piece.pieceId].hp}`
		if ui.buildMode == "upgrade" then
			local ok, nextDef, reason = BuildRules.canUpgrade(currentLayout, uid, ctx, progress(), inventory())
			if ok and nextDef then
				setHint(`Upgrade to {nextDef.name}: {costText(nextDef.cost)}. {health}`)
			else
				local def = Pieces[piece.pieceId]
				setHint(`{why(reason, if def.upgradesTo then Pieces[def.upgradesTo] else def)}. {health}`)
			end
		else
			local refund = Grid.refundFor(piece, ctx)
			local confirm = armed and armed.uid == uid and os.clock() - armed.at < CONFIRM_SECONDS
			setHint(
				if confirm
					then "Click again to demolish"
					else `Demolish {Pieces[piece.pieceId].name}. {health}. Refund {if #refund > 0
						then costText(refund)
						else "nothing"}`
			)
		end
		return
	end

	hover(nil)
	local pieceId = ui.buildPiece
	if pieceId == nil then
		clearGhost()
		setHint("Pick a piece from the menu")
		return
	end
	if ghostPiece ~= pieceId then
		makeGhost(pieceId)
	end
	local def = Pieces[pieceId]
	local px, pz = cursorLocal(info.origin)
	local model = ghost
	if px == nil or pz == nil or model == nil then
		return
	end
	local target = targetFor(def, px, pz)
	local ok: boolean, reason: string?
	if moving then
		ok, reason = BuildRules.canMove(currentLayout, moving, target, ctx)
	else
		ok, reason = BuildRules.canPlace(currentLayout, pieceId, target, ctx, progress(), inventory())
	end
	current = { target = target, valid = ok, reason = reason }
	local goal = PlotSpace.target(info.origin, currentLayout, Grid.layerOf(def), target, def)
	ghostCFrame = if ghostCFrame then (ghostCFrame :: CFrame):Lerp(goal, 1 - math.exp(-GHOST_RATE * dt)) else goal
	model:PivotTo(ghostCFrame :: CFrame)
	if highlight then
		highlight.FillColor = if ok then VALID else INVALID
		highlight.OutlineColor = if ok then VALID else INVALID
	end
	local placeText = if moving then `Move the {def.name} here` else `{def.name}: {costText(def.cost)}`
	setHint(if ok then placeText else why(reason, def))

	if painting and ok and not moving and (def.kind == "foundation" or def.kind == "wall") then
		local key = targetKey(target)
		if key ~= lastPaintKey and os.clock() - lastPaint >= PAINT_SECONDS then
			lastPaint, lastPaintKey = os.clock(), key
			Net.fire("BuildPlace", pieceId, target.x, target.z, target.axis, target.rot)
		end
	end
end

-- Actions ----------------------------------------------------------------------------------------------

-- Places, upgrades or demolishes under the cursor (LMB, or the touch Place button).
function Building.confirm()
	local ui = State.ui()
	if ui.panel ~= "build" then
		return
	end
	if ui.buildMode == "place" then
		local pieceId = ui.buildPiece
		local pending = current
		if pieceId == nil then
			-- Nothing picked: a click on a placed piece selects it for its actions (#27).
			local uid = pieceUnderCursor()
			if uid then
				State.patch({ pieceActions = uid })
				Sfx.play("uiClick")
			else
				State.clear("pieceActions")
			end
			return
		end
		if pending == nil then
			return
		end
		if not pending.valid then
			Sfx.play("uiError")
			State.notify(why(pending.reason, Pieces[pieceId]))
			return
		end
		local target = pending.target
		if moving then
			Net.fire("BuildMove", moving, target.x, target.z, target.rot or 0)
			moving = nil
			State.clear("buildPiece")
			return
		end
		lastPaintKey = targetKey(target)
		lastPaint = os.clock()
		Net.fire("BuildPlace", pieceId, target.x, target.z, target.axis, target.rot)
	elseif hoveredUid then
		if ui.buildMode == "upgrade" then
			Net.fire("BuildUpgrade", hoveredUid)
		elseif armed and armed.uid == hoveredUid and os.clock() - armed.at < CONFIRM_SECONDS then
			armed = nil
			Net.fire("BuildDemolish", hoveredUid)
		else
			armed = { uid = hoveredUid, at = os.clock() }
		end
	end
end

-- LMB held: paint foundations and walls along the cursor.
function Building.setPainting(held: boolean)
	painting = held
	if held then
		Building.confirm()
	end
end

function Building.rotate()
	rotation = (rotation + 1) % 4
end

function Building.setMode(mode: State.BuildMode)
	armed = nil
	State.patch({ buildMode = if State.ui().buildMode == mode then "place" else mode })
end

-- Touch: the ghost follows the last tap on the world.
function Building.setTouchPoint(point: Vector2)
	touchPoint = point
end

function Building.start()
	RunService.RenderStepped:Connect(step)
end

return Building
