--!strict
--[[
	UiAudit: the rules of the automated UI overlap gate (PLAYER_EXPERIENCE_CHECKLIST 4.19,
	4.18). Pure, so the rules are unit-tested; client/UI/Gate collects the nodes from the
	live PlayerGui and prints what this returns.

	Flags, per screen state and resolution:
	- overlap: two drawn elements whose rectangles intersect, unless one is an ancestor of
	  the other or either is declared an overlay (a badge on its button, a tooltip) or
	  decor (a panel's shadow). Touching edges don't count.
	- clipped: text that doesn't fit its box (TextFits false), or an element cut off by
	  an ancestor that clips its descendants (outside a scrolling frame).
	- outside: an element not wholly inside the safe area (Roblox's CoreUI insets).
	- zone: an element intruding on a reserved zone (Roblox's chat window, the mobile
	  thumbstick and jump areas, the leaderboard).
	- missingGlyph: an icon that resolved to no image.
]]

local UiAudit = {}

export type Rect = { x: number, y: number, w: number, h: number }

export type Node = {
	id: number,
	path: string, -- for the report, e.g. "App.HUD.Cluster.Meds"
	rect: Rect,
	ancestors: { [number]: boolean }, -- ids of every ancestor node
	draws: boolean, -- has visible text, an image or a background
	decor: boolean?, -- a shadow or backplate behind its siblings
	overlay: boolean?, -- meant to sit on top of others (badges, tooltips, toasts)
	-- A full-screen translucent backdrop behind a panel: it may run under Roblox's top bar
	-- and reserved zones (they draw above it), so only those two checks skip it.
	backdrop: boolean?,
	textFits: boolean?, -- nil for non-text
	clip: Rect?, -- the nearest clipping ancestor's rect (not a scrolling frame)
	missingGlyph: boolean?,
}

export type Zone = { name: string, rect: Rect }

export type Kind = "overlap" | "clipped" | "outside" | "zone" | "missingGlyph"

export type Flag = {
	kind: Kind,
	path: string,
	other: string?, -- the other element or zone
	detail: string?,
}

-- Rectangles closer than this are treated as touching, not overlapping (sub-pixel layout).
UiAudit.TOLERANCE = 1

local function intersects(a: Rect, b: Rect, tolerance: number): boolean
	return a.x + a.w - tolerance > b.x
		and b.x + b.w - tolerance > a.x
		and a.y + a.h - tolerance > b.y
		and b.y + b.h - tolerance > a.y
end

local function inside(inner: Rect, outer: Rect, tolerance: number): boolean
	return inner.x >= outer.x - tolerance
		and inner.y >= outer.y - tolerance
		and inner.x + inner.w <= outer.x + outer.w + tolerance
		and inner.y + inner.h <= outer.y + outer.h + tolerance
end

function UiAudit.intersects(a: Rect, b: Rect): boolean
	return intersects(a, b, UiAudit.TOLERANCE)
end

local function addFlag(flags: { Flag }, kind: Kind, path: string, other: string?, detail: string?)
	table.insert(flags, { kind = kind, path = path, other = other, detail = detail })
end

local NO_ZONES: { Zone } = {}

-- Every flag for one screen state. `safe` is the safe area; `zones` the reserved zones.
function UiAudit.audit(nodes: { Node }, safe: Rect, zones: { Zone }): { Flag }
	local flags: { Flag } = {}
	local tolerance = UiAudit.TOLERANCE
	local drawn: { Node } = {}
	for _, node in nodes do
		if node.rect.w <= 0 or node.rect.h <= 0 then
			continue
		end
		if node.missingGlyph then
			addFlag(flags, "missingGlyph", node.path)
		end
		if node.textFits == false then
			addFlag(flags, "clipped", node.path, nil, "text doesn't fit")
		end
		if node.clip and not inside(node.rect, node.clip, tolerance) then
			addFlag(flags, "clipped", node.path, nil, "cut off by a clipping parent")
		end
		if node.draws then
			if not node.backdrop and not inside(node.rect, safe, tolerance) then
				addFlag(flags, "outside", node.path, nil, "outside the safe area")
			end
			local checked: { Zone } = if node.backdrop then NO_ZONES else zones
			for _, zone in checked do
				if intersects(node.rect, zone.rect, tolerance) then
					addFlag(flags, "zone", node.path, zone.name)
				end
			end
			if not node.decor and not node.overlay then
				table.insert(drawn, node)
			end
		end
	end
	for i = 1, #drawn do
		local a = drawn[i]
		for j = i + 1, #drawn do
			local b = drawn[j]
			if a.ancestors[b.id] or b.ancestors[a.id] then
				continue
			end
			if intersects(a.rect, b.rect, tolerance) then
				addFlag(flags, "overlap", a.path, b.path)
			end
		end
	end
	return flags
end

-- One line per flag, for the console report.
function UiAudit.describe(flag: Flag): string
	local text = `{flag.kind}: {flag.path}`
	if flag.other then
		text ..= ` x {flag.other}`
	end
	if flag.detail then
		text ..= ` ({flag.detail})`
	end
	return text
end

-- Roblox's reserved touch zones for a screen size (TouchGui's thumbstick and jump button
-- layout: small screens are those whose shorter side is at most 500 px).
function UiAudit.touchZones(width: number, height: number): { Zone }
	local small = math.min(width, height) <= 500
	local jump = if small
		then { x = width - 95, y = height - 90, w = 70, h = 70 }
		else { x = width - 170, y = height - 210, w = 120, h = 120 }
	-- The dynamic thumbstick appears wherever the left thumb lands in the lower left.
	local stick = { x = 0, y = height * 0.5, w = width * 0.32, h = height * 0.5 }
	return {
		{ name = "Roblox jump button", rect = jump },
		{ name = "Roblox thumbstick", rect = stick },
	}
end

return UiAudit
