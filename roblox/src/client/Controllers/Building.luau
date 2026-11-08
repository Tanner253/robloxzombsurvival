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
local current: { target: Grid.Target, valid: boolean, reason: string? }? = nil
local hoveredUid: string? = nil
local armed: { uid: string, at: number }? = nil
local painting = false
local lastPaint = 0
local lastPaintKey = ""
local touchPoint: Vector2? = nil

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
		cachedLayout = Grid.deserialize(saved)
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
	return {
		level = if p then p.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
	}
end

local function inventory(): any
	local inv = State.get("inventory")
	return if inv then { pockets = inv.pockets, backpack = inv.backpack } else nil
end

-- The hint text for the cursor: why it is invalid, or what it costs.
local function costText(cost: { { itemId: string, count: number } }): string
	local parts = {}
	for _, stack in cost do
		local def = Content.Items[stack.itemId]
		table.insert(parts, `{stack.count} {if def then def.name else stack.itemId}`)
	end
	return table.concat(parts, " · ")
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

local function targetFor(def: Types.BuildPieceDef, px: number, pz: number): Grid.Target
	local layer = Grid.layerOf(def)
	if layer == "frame" or layer == "fill" then
		local axis, x, z = Grid.edgeNear(px, pz)
		local edge: Grid.Target = { x = x, z = z, axis = axis :: Grid.Axis }
		return edge
	end
	local x, z = Grid.cellAt(px, pz)
	local cell: Grid.Target = { x = x, z = z, rot = if layer == "object" then rotation else nil }
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

local function step(dt: number)
	local ui = State.ui()
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
		if ui.buildMode == "upgrade" then
			local ok, nextDef, reason = BuildRules.canUpgrade(currentLayout, uid, ctx, progress(), inventory())
			if ok and nextDef then
				setHint(`Upgrade to {nextDef.name}: {costText(nextDef.cost)}`)
			else
				setHint(BuildRules.REASON_TEXT[(reason :: string?) or ""] or "Can't upgrade")
			end
		else
			local refund = Grid.refundFor(piece, ctx)
			local confirm = armed and armed.uid == uid and os.clock() - armed.at < CONFIRM_SECONDS
			setHint(
				if confirm
					then "Click again to demolish"
					else `Demolish {Pieces[piece.pieceId].name} · refund {if #refund > 0
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
	local ok, reason = BuildRules.canPlace(currentLayout, pieceId, target, ctx, progress(), inventory())
	current = { target = target, valid = ok, reason = reason }
	local onFloor = Grid.pieceAt(currentLayout, "floor", target.x, target.z) ~= nil
	local goal = PlotSpace.target(info.origin, Grid.layerOf(def), target, onFloor)
	ghostCFrame = if ghostCFrame then (ghostCFrame :: CFrame):Lerp(goal, 1 - math.exp(-GHOST_RATE * dt)) else goal
	model:PivotTo(ghostCFrame :: CFrame)
	if highlight then
		highlight.FillColor = if ok then VALID else INVALID
		highlight.OutlineColor = if ok then VALID else INVALID
	end
	setHint(
		if ok
			then `{def.name}: {costText(def.cost)}`
			else BuildRules.REASON_TEXT[(reason :: string?) or ""] or "Can't build there"
	)

	if painting and ok and (def.kind == "foundation" or def.kind == "wall") then
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
		if pieceId == nil or pending == nil then
			return
		end
		if not pending.valid then
			Sfx.play("uiError")
			State.notify(BuildRules.REASON_TEXT[pending.reason or ""] or "Can't build there")
			return
		end
		local target = pending.target
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
