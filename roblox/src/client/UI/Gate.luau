--!strict
--[[
	Gate: collects the live UI for the overlap gate (PLAYER_EXPERIENCE_CHECKLIST 4.19).
	Walks our ScreenGuis (the App and every "EO_" layer), turns each visible GuiObject
	into a Domain/UiAudit node and returns the audit's flags. The rules live in UiAudit
	(pure, unit-tested); the Controllers/UiGate driver opens every screen and state at
	every resolution and prints the report.

	Components declare intent with attributes:
	- Decor = true: a shadow or backplate drawn behind its siblings on purpose;
	- Overlay = true: meant to sit on top (badges, tooltips, toasts, the drag ghost);
	- Glyph = "<name>": an icon from the glyph set (an empty image is flagged).
	- Composite = true: one graphic made of overlapping parts (the minimap, item slots,
	  round buttons): checked as one element; its insides are skipped.
	Decor and Overlay apply to the element's whole subtree.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiAudit = require(ReplicatedStorage.Shared.Domain.UiAudit)

local Gate = {}

-- AbsoluteSize ignores Rotation; a quarter-turned element (the CLOSE strip's label)
-- covers its box turned around its centre.
local function rectOf(object: GuiObject): UiAudit.Rect
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	if math.abs((object.Rotation % 180) - 90) < 1 then
		local cx, cy = position.X + size.X / 2, position.Y + size.Y / 2
		return { x = cx - size.Y / 2, y = cy - size.X / 2, w = size.Y, h = size.X }
	end
	return { x = position.X, y = position.Y, w = size.X, h = size.Y }
end

local function intersection(a: UiAudit.Rect, b: UiAudit.Rect): UiAudit.Rect?
	local x0, y0 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x1, y1 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	if x1 - x0 <= 0 or y1 - y0 <= 0 then
		return nil
	end
	return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

local function strokeVisible(object: Instance): boolean
	for _, child in object:GetChildren() do
		if child:IsA("UIStroke") and child.Enabled and child.Thickness > 0 and child.Transparency < 1 then
			return true
		end
	end
	return false
end

-- Whether the element puts anything on screen itself (children aside).
local function draws(object: GuiObject): boolean
	if object.BackgroundTransparency < 1 or strokeVisible(object) then
		return true
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		return object.Text ~= "" and object.TextTransparency < 1
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return object.Image ~= "" and object.ImageTransparency < 1
	end
	return object:IsA("ViewportFrame")
end

local function textFits(object: GuiObject): boolean?
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		if object.Text == "" or object.TextTransparency >= 1 then
			return nil
		end
		return (object :: any).TextFits
	end
	return nil
end

-- Our layers: the App and every "EO_" ScreenGui that is enabled.
function Gate.screens(): { ScreenGui }
	local result: { ScreenGui } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return result
	end
	for _, child in playerGui:GetChildren() do
		if
			child:IsA("ScreenGui")
			and child.Enabled
			and (child.Name == "App" or string.sub(child.Name, 1, 3) == "EO_")
		then
			table.insert(result, child)
		end
	end
	return result
end

-- Every visible GuiObject under `screens`, as audit nodes.
function Gate.collect(screens: { ScreenGui }): { UiAudit.Node }
	local nodes: { UiAudit.Node } = {}
	local nextId = 0
	local function visit(
		parent: Instance,
		path: string,
		ancestors: { [number]: boolean },
		clip: UiAudit.Rect?,
		view: UiAudit.Rect?, -- the visible part of a scrolling frame we are inside
		decor: boolean,
		overlay: boolean
	)
		for _, child in parent:GetChildren() do
			if not child:IsA("GuiObject") or not child.Visible then
				continue
			end
			nextId += 1
			local id = nextId
			local rect: UiAudit.Rect? = rectOf(child)
			if view then
				rect = intersection(rect :: UiAudit.Rect, view)
			end
			local childPath = `{path}.{child.Name}`
			local isDecor = decor or child:GetAttribute("Decor") == true
			local isOverlay = overlay or child:GetAttribute("Overlay") == true
			if rect then
				local glyph = child:GetAttribute("Glyph")
				table.insert(nodes, {
					id = id,
					path = childPath,
					rect = rect,
					ancestors = table.clone(ancestors),
					draws = draws(child),
					decor = isDecor,
					overlay = isOverlay,
					textFits = textFits(child),
					clip = if view then nil else clip,
					missingGlyph = glyph ~= nil and child:IsA("ImageLabel") and child.Image == "",
				})
			end
			if child:GetAttribute("Composite") == true then
				-- Checked as one element; only its icons are still checked for missing glyphs.
				for _, inner in child:GetDescendants() do
					if
						inner:IsA("ImageLabel")
						and inner.Visible
						and inner:GetAttribute("Glyph") ~= nil
						and inner.Image == ""
					then
						nextId += 1
						table.insert(nodes, {
							id = nextId,
							path = `{childPath}.{inner.Name}`,
							rect = rectOf(inner),
							ancestors = {},
							draws = false,
							missingGlyph = true,
						})
					end
				end
				continue
			end
			local below = table.clone(ancestors)
			below[id] = true
			local childClip, childView = clip, view
			if child:IsA("ScrollingFrame") then
				local own = rectOf(child)
				childView = if view then intersection(own, view) else own
				childClip = nil
			elseif child.ClipsDescendants then
				childClip = rectOf(child)
			end
			if childView == nil and view ~= nil then
				continue -- scrolled wholly out of view
			end
			visit(child, childPath, below, childClip, childView, isDecor, isOverlay)
		end
	end
	for _, screen in screens do
		visit(screen, screen.Name, {}, nil, nil, false, false)
	end
	return nodes
end

-- Audits what is on screen now against a safe area and reserved zones.
function Gate.audit(safe: UiAudit.Rect, zones: { UiAudit.Zone }): ({ UiAudit.Flag }, number)
	local nodes = Gate.collect(Gate.screens())
	return UiAudit.audit(nodes, safe, zones), #nodes
end

return Gate
