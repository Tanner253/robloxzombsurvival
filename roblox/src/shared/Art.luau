--!strict
--[[
	Art: presentation data shared by the server (spawning world models) and the
	client (ghost previews, icons, sounds). Not gameplay content: nothing here
	is saved or validated, and changing it never changes a rule.

	Kit names are looked up in ServerStorage.EO_Kit first, then ServerStorage.LT_Gen
	(the v1 generated meshes), in list order. When none exists the server builds
	the fallback shape in server/World/Models. Pieces with no kit master yet are
	marked "art gap" and listed in the slice report.
]]

local Art = {}

-- Height of a foundation's top above the ground. Kit foundations pivot at their
-- top centre, walls and props at their bottom centre (look-test v2 conform pass).
-- Low enough to walk onto: characters can't jump (Survival turns jumping off),
-- so the rest of each foundation sits in the ground.
Art.FLOOR_HEIGHT = 1
-- Wall height for fallback walls (kit walls are 8.2 to 8.9 studs).
Art.WALL_HEIGHT = 8.6

-- Build pieces -> kit master names.
Art.pieces = {
	["build.foundation_wood"] = { "FoundWood" },
	["build.foundation_scrap"] = { "FoundScrap" },
	["build.foundation_reinforced"] = { "FoundReinforced" },
	["build.wall_wood"] = { "WallWood" },
	["build.wall_scrap"] = { "WallScrap" },
	["build.wall_reinforced"] = { "WallReinforced" },
	["build.window_scrap"] = { "WindowScrap" },
	-- art gap: doorways, doors, wood and reinforced windows (kit door is merged into its doorway)
	["build.workbench"] = { "Workbench" },
	["build.campfire"] = { "Campfire" }, -- art gap
	["build.recycler"] = { "Recycler", "Generator" }, -- art gap: Generator stands in
	["build.crate_wood"] = { "Crate" },
	["build.crate_banded"] = { "CrateBanded", "Crate" },
} :: { [string]: { string } }

-- Resource nodes -> kit names and the height (studs) the model is scaled to.
Art.nodes = {
	["node.pine_tree"] = { names = { "PineTree", "Gen_tree" }, height = 15 },
	["node.boulder"] = { names = { "Boulder", "RockClump" }, height = 4.4 },
	["node.loose_stones"] = { names = { "Gen_pebbles", "Pebbles" }, height = 1.9 },
	["node.fallen_branches"] = { names = { "Branches", "Gen_firewood" }, height = 2.6 },
	["node.reed_patch"] = { names = { "Reeds", "GrassClump" }, height = 3.4 },
	["node.ember_bush"] = { names = { "EmberBush", "Bush" }, height = 3.4 },
	["node.spring_pool"] = { names = { "SpringPool" }, height = 1 },
	["node.fatwood_stump"] = { names = { "Stump" }, height = 2.4 },
	["node.scrap_heap"] = { names = { "ScrapHeap", "Rubble" }, height = 3.5 },
	["node.ashroot_mound"] = { names = { "AshrootMound" }, height = 1.6 },
} :: { [string]: { names: { string }, height: number } }

-- Items -> kit names for the model held in hand and the rendered 3D icon.
Art.items = {
	["item.stone_hatchet"] = { "Hatchet", "Gen_axe" },
	["item.stone_pick"] = { "Pickaxe", "Pick" },
	["item.timber"] = { "Gen_firewood" },
	["item.satchel"] = { "Gen_backpack" },
	["item.pack_frame"] = { "Raw_Backpack", "Gen_backpack" },
} :: { [string]: { string } }

-- Sound IDs. PLACEHOLDER: every "" is still to be chosen in Studio (Phase 2);
-- the client's Sfx skips empty IDs, so nothing plays until one is set.
Art.sounds = {
	uiOpen = "", -- PLACEHOLDER: soft cloth whoosh
	uiClose = "", -- PLACEHOLDER
	uiClick = "", -- PLACEHOLDER: wooden tick
	uiError = "", -- PLACEHOLDER: dull thunk
	pickup = "", -- PLACEHOLDER: item into bag
	reward = "", -- PLACEHOLDER: warm chime
	levelUp = "", -- PLACEHOLDER: ember swell + chime
	chop = "", -- PLACEHOLDER: axe into wood
	mine = "", -- PLACEHOLDER: pick on stone
	pluck = "", -- PLACEHOLDER: hand gather rustle
	nodeBreak = "", -- PLACEHOLDER: tree fall / rock crumble
	place = "", -- PLACEHOLDER: heavy wooden thud
	upgrade = "", -- PLACEHOLDER: metal clank
	demolish = "", -- PLACEHOLDER: splintering
	craftStart = "", -- PLACEHOLDER
	collect = "", -- PLACEHOLDER: satisfying pop
	fuel = "", -- PLACEHOLDER: fire whoosh
	eat = "", -- PLACEHOLDER
	drink = "", -- PLACEHOLDER
} :: { [string]: string }

-- Fallback icon glyphs (emoji) for items with no rendered icon model yet. Placeholder
-- until every item has a 3D icon; kept to emoji Roblox renders everywhere.
Art.glyphs = {
	["item.timber"] = "🌲",
	["item.stone"] = "🗿",
	["item.scrap"] = "🔧",
	["item.fiber"] = "🌾",
	["item.fatwood"] = "🔥",
	["item.murky_water"] = "💧",
	["item.plank"] = "📏",
	["item.rope"] = "➰",
	["item.cloth"] = "🧵",
	["item.stone_block"] = "🧱",
	["item.scrap_plate"] = "🛡",
	["item.pitch_glue"] = "🍯",
	["item.rivets"] = "🔩",
	["item.coil_spring"] = "🌀",
	["item.brass_gear"] = "⚙",
	["item.broken_lantern"] = "🏮",
	["item.snarled_wire"] = "➿",
	["item.seized_motor"] = "🔋",
	["item.stone_hatchet"] = "🔨",
	["item.stone_pick"] = "⛏",
	["item.spiked_club"] = "🏏",
	["item.scrapblade"] = "🗡",
	["item.shortbow"] = "🏹",
	["item.arrow"] = "➶",
	["item.padded_hood"] = "🎓",
	["item.padded_vest"] = "👕",
	["item.satchel"] = "👜",
	["item.pack_frame"] = "🎒",
	["item.emberberry"] = "🍒",
	["item.ashroot"] = "🥔",
	["item.roasted_ashroot"] = "🍠",
	["item.sealed_tin"] = "🥫",
	["item.hearth_stew"] = "🍲",
	["item.boiled_water"] = "🍶",
	["item.ember_tea"] = "🍵",
	["item.field_dressing"] = "🩹",
	["item.ember_tonic"] = "🧪",
	["item.bp_pack_frame"] = "📜",
	["item.bp_reinforced"] = "📜",
} :: { [string]: string }

-- HUD meter glyphs (placeholder until the icon set exists).
Art.meterGlyphs = {
	health = "❤",
	hunger = "🍖",
	thirst = "💧",
	energy = "⚡",
	xp = "★",
} :: { [string]: string }

return Art
