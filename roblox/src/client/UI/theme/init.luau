--!strict
--[[
	Theme tokens for the one UI kit (ART_DIRECTION.md §8). Components read every
	color, size and font from here; screens never style anything themselves.
]]

local Theme = {}

Theme.colors = {
	-- Panels: dark charcoal, near-opaque so contrast holds over a bright scene (4.1).
	panel = Color3.fromHex("1C1F24"),
	panelTransparency = 0.03,
	panelRaised = Color3.fromHex("262A31"),

	-- Strokes: 2 px warm gray, ember for primary actions.
	-- strokeWarm is provisional (ART_DIRECTION gives no hex); confirm in the look test.
	strokeWarm = Color3.fromHex("6F675E"),
	accent = Color3.fromHex("FF8A3D"), -- ember
	accentSoft = Color3.fromHex("FFB547"), -- amber
	highlight = Color3.fromHex("FFE3A3"), -- candle

	-- Text: off-white and muted; never pure white. Secondary text is never darker
	-- than B8B2A6 so it holds contrast on the panel (checklist 4.1).
	text = Color3.fromHex("F2EEE6"),
	textMuted = Color3.fromHex("B8B2A6"),
	textOnAccent = Color3.fromHex("1C1F24"),

	-- Disabled controls are plainly grey (no half-transparent orange).
	disabled = Color3.fromHex("3A3E45"),
	disabledStroke = Color3.fromHex("4E535B"),
	disabledText = Color3.fromHex("A19C93"),

	-- Unlock conditions on locked recipes and pieces.
	locked = Color3.fromHex("EE8A72"),
	bonus = Color3.fromHex("FFC24D"), -- over-cap amounts, e.g. Energy above 100

	-- Cold palette: cyan means danger.
	threat = Color3.fromHex("9FE7FF"),
	fog = Color3.fromHex("6E8291"),

	-- LDoE's teal count badges (menu bar, station ready counts) and red NEW badges.
	badge = Color3.fromHex("1E9E8F"),
	badgeNew = Color3.fromHex("C8402E"),

	shadow = Color3.fromHex("0B0D10"),
	shadowTransparency = 0.55,
	track = Color3.fromHex("14161A"),
	durability = Color3.fromHex("7FBF5A"),
}

-- Loot rarity colors. UI and item glows only, never world materials.
Theme.rarity = {
	common = Color3.fromHex("D9D4C7"),
	uncommon = Color3.fromHex("7FBF5A"),
	rare = Color3.fromHex("4FA3E0"),
	epic = Color3.fromHex("A97BE0"),
	legendary = Color3.fromHex("FF8A3D"),
} :: { [string]: Color3 } -- indexed by Types.Rarity

-- HUD meters. Health is a warm red (never cyan: cyan is reserved for threats).
Theme.meters = {
	health = Color3.fromHex("D9573F"),
	hunger = Color3.fromHex("FFB547"),
	thirst = Color3.fromHex("4FA3E0"),
	energy = Color3.fromHex("FFE3A3"),
	xp = Color3.fromHex("FF8A3D"),
}

-- Item slot backplates by kind, so a glance at the bag sorts food from tools.
-- Subtle tints behind the icon; rarity still owns the border.
Theme.itemKind = {
	food = Color3.fromHex("C98A3C"),
	medical = Color3.fromHex("C9706A"),
	tool = Color3.fromHex("7A8A99"),
	gear = Color3.fromHex("7C8A5C"),
	material = Color3.fromHex("8C7F6E"),
	junk = Color3.fromHex("9A6A4A"),
	blueprint = Color3.fromHex("5C86B8"),
} :: { [string]: Color3 }

Theme.radius = UDim.new(0, 8)
Theme.strokeThickness = 2
Theme.shadowOffset = 4

-- Builder Sans only: ExtraBold for headers, Medium for body.
Theme.fonts = {
	header = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold),
	body = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
}

-- Design pixels; the App scales the 1366 x 768 layout to fit (x1.375 at 1080p), so
-- caption is 19 px and section 25 px on a 1080p screen (checklist 4.1: body >= 18,
-- headers >= 24).
Theme.textSize = {
	header = 28,
	title = 22,
	section = 18,
	body = 18,
	caption = 14,
}

Theme.spacing = {
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 24,
}

-- The App's current UI scale (set each render by UI/App), for converting Roblox's screen
-- pixel zones (the touch jump button) into design pixels.
Theme.currentScale = 1
-- The design frame's size (the safe area in design pixels), set with it: sheets clamp to it
-- so they fit a small phone's frame (about 1364 x 590 at 844 x 390).
Theme.currentFrame = Vector2.new(1366, 768)

-- Minimum tap target in pixels (mobile first).
Theme.tapTarget = 44

-- Upgrade arrows (LDoE's green), and the dim behind full-screen panels.
Theme.colors.upgrade = Color3.fromHex("3E9E4A")
Theme.colors.dim = Color3.fromHex("0B0D10")
Theme.colors.dimTransparency = 0.35
Theme.colors.chip = Color3.fromHex("1E6F66") -- the teal name chip on station and storage headers
Theme.colors.danger = Color3.fromHex("B8442F") -- demolish, trash

-- Draw order. Siblings never overlap (the UI gate, checklist 4.19), so these only
-- order separate layers: the HUD, full-screen panels, modals, toasts and tooltips.
Theme.layers = {
	hud = 1,
	panel = 20,
	modal = 40,
	toast = 60,
	tooltip = 80,
	drag = 100,
}

-- The LDoE HUD (LDOE_PARITY #1-12), in design pixels at 1366 x 768.
Theme.hud = {
	edge = 16, -- gap from the safe area's edge
	weaponBig = 96, -- the active-weapon circle, also the attack button
	weaponSmall = 64, -- the second weapon
	meds = 56,
	context = 84, -- the context button (hand, axe, pick...)
	sprint = 60,
	auto = 64,
	menuIcon = 44, -- bottom menu bar icons
	levelBar = 6, -- the level bar's track height
	minimap = 168,
	stripIcon = 44, -- the top-right event/offers/gift strip
	nameWidth = 240, -- top-left name and HP
	tracker = 260, -- quest tracker width
	trayHeight = 168, -- the build tray's card row
	closeStrip = 72, -- the CLOSE strip at the right edge of full-screen panels
	-- Touch: Roblox's dynamic thumbstick claims the lower-left share of the screen, and the
	-- jump button about this many screen pixels at the lower right (UiAudit.touchZones).
	touchStickShare = 0.32,
	touchJumpReserve = 110,
}

-- Full-screen panels (LDoE's two-pane screens, #11 and #13).
Theme.panel = {
	pane = 420, -- each pane's width
	gap = 32, -- between the panes
	header = 44,
	actionBar = 52,
	slot = 72, -- inventory slots in the two-pane screen
	slotGap = 6,
	columns = 5, -- LDoE: pockets 2 x 5, backpack and storage 5 wide
}

Theme.slotSize = 64

-- The layout's design size; the App scales it to fit the screen (PC first, 16:9).
Theme.designSize = Vector2.new(1366, 768)

return Theme
