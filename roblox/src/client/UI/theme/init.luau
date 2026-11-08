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

-- Minimum tap target in pixels (mobile first).
Theme.tapTarget = 44

Theme.slotSize = 64

-- The layout's design size; the App scales it to fit the screen (PC first, 16:9).
Theme.designSize = Vector2.new(1366, 768)

return Theme
