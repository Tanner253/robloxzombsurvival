--!strict
--[[
	Theme tokens for the one UI kit (ART_DIRECTION.md §8). Components read every
	color, size and font from here; screens never style anything themselves.
]]

local Theme = {}

Theme.colors = {
	-- Panels: dark charcoal at 92% opacity.
	panel = Color3.fromHex("1C1F24"),
	panelTransparency = 0.08,
	panelRaised = Color3.fromHex("262A31"),

	-- Strokes: 2 px warm gray, ember for primary actions.
	-- strokeWarm is provisional (ART_DIRECTION gives no hex); confirm in the look test.
	strokeWarm = Color3.fromHex("6F675E"),
	accent = Color3.fromHex("FF8A3D"), -- ember
	accentSoft = Color3.fromHex("FFB547"), -- amber
	highlight = Color3.fromHex("FFE3A3"), -- candle

	-- Text: off-white and muted; never pure white.
	text = Color3.fromHex("F2EBDD"),
	textMuted = Color3.fromHex("A8A193"),
	textOnAccent = Color3.fromHex("1C1F24"),

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

Theme.radius = UDim.new(0, 8)
Theme.strokeThickness = 2
Theme.shadowOffset = 4

-- Builder Sans only: ExtraBold for headers, Medium for body.
Theme.fonts = {
	header = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold),
	body = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
}

Theme.textSize = {
	header = 28,
	title = 22,
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

return Theme
