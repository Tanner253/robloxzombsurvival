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
Art.FLOOR_HEIGHT = 2.2
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
	["node.pine_tree"] = { names = { "PineTree", "Tree", "DeadTree" }, height = 16 },
	["node.boulder"] = { names = { "Boulder", "RockClump", "Rocks" }, height = 4.5 },
	["node.loose_stones"] = { names = { "Gen_pebbles", "Pebbles" }, height = 1.2 },
	["node.fallen_branches"] = { names = { "Firewood", "Branches" }, height = 1.4 },
	["node.reed_patch"] = { names = { "Gen_grass", "GrassClump", "Reeds" }, height = 3.2 },
	["node.ember_bush"] = { names = { "EmberBush", "Bush" }, height = 3.4 },
	["node.spring_pool"] = { names = { "SpringPool" }, height = 1 },
	["node.fatwood_stump"] = { names = { "Stump" }, height = 2.4 },
	["node.scrap_heap"] = { names = { "ScrapHeap", "Rubble" }, height = 3.5 },
	["node.ashroot_mound"] = { names = { "AshrootMound" }, height = 1.6 },
} :: { [string]: { names: { string }, height: number } }

-- Items -> kit names for the model held in hand and the rendered 3D icon.
Art.items = {
	["item.stone_hatchet"] = { "Axe", "Hatchet" },
	["item.stone_pick"] = { "Pickaxe", "Pick" },
	["item.timber"] = { "Firewood" },
	["item.satchel"] = { "Gen_backpack", "EO_Backpack" },
	["item.pack_frame"] = { "EO_Backpack", "Gen_backpack" },
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

return Art
