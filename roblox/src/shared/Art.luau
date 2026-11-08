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
	["node.pine_tree"] = { names = { "EO_PineTree", "Gen_tree" }, height = 17 },
	["node.boulder"] = { names = { "EO_Boulder", "RockClump" }, height = 4.6 },
	["node.loose_stones"] = { names = { "EO_LooseStones", "Gen_pebbles" }, height = 1.8 },
	["node.fallen_branches"] = { names = { "EO_FallenBranches", "Gen_firewood" }, height = 1.8 },
	["node.reed_patch"] = { names = { "EO_Reeds", "GrassClump" }, height = 4.2 },
	["node.ember_bush"] = { names = { "EO_EmberBush" }, height = 4 },
	["node.spring_pool"] = { names = { "SpringPool" }, height = 1 },
	["node.fatwood_stump"] = { names = { "EO_FatwoodStump" }, height = 3 },
	["node.scrap_heap"] = { names = { "EO_ScrapHeap" }, height = 3.8 },
	["node.ashroot_mound"] = { names = { "AshrootMound" }, height = 1.6 },
} :: { [string]: { names: { string }, height: number } }

-- Items -> kit names for the model held in hand and the rendered 3D icon.
Art.items = {
	["item.stone_hatchet"] = { "EO_StoneHatchet", "Gen_axe" },
	["item.spiked_club"] = { "EO_SpikedClub" },
	["item.scrapblade"] = { "EO_Scrapblade" },
	["item.stone_pick"] = { "EO_StonePick" },
	["item.timber"] = { "Gen_firewood" },
	["item.satchel"] = { "Gen_backpack" },
	["item.pack_frame"] = { "Raw_Backpack", "Gen_backpack" },
} :: { [string]: { string } }

-- How each held item sits in the fist and on the body (checklist 1.5, 1.5b).
-- `axis` is the butt-to-head direction and `edge` the blade-facing direction, both
-- in the kit model's own space (read from front and side renders); `grip` is how
-- far up the handle the fist holds (0 = butt end); `length` is the in-game size
-- in studs against the 5.6-stud survivor. `holster` picks the back or the belt.
export type HeldArt = {
	axis: Vector3,
	edge: Vector3,
	grip: number,
	length: number,
	holster: "back" | "belt",
}

Art.held = {
	["item.stone_hatchet"] = {
		axis = Vector3.new(0.75, 0.65, -0.13),
		edge = Vector3.new(0, 0, -1),
		grip = 0.18,
		length = 1.7,
		holster = "belt",
	},
	["item.stone_pick"] = {
		axis = Vector3.new(0.48, 0.88, -0.26),
		edge = Vector3.new(0, 0, -1),
		grip = 0.16,
		length = 2.2,
		holster = "belt",
	},
	["item.spiked_club"] = {
		axis = Vector3.new(0.36, 0.69, 0.67),
		edge = Vector3.new(1, 0, 0),
		grip = 0.14,
		length = 2.3,
		holster = "back",
	},
	["item.scrapblade"] = {
		axis = Vector3.new(0.35, 1, 1),
		edge = Vector3.new(0, -1, 1),
		grip = 0.12,
		length = 2,
		holster = "back",
	},
} :: { [string]: HeldArt }

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
	["item.sticks"] = "🥢",
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
