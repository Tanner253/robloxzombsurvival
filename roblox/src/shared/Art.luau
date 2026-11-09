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
Art.FLOOR_HEIGHT = 0.5 -- deck tops sit 0.45 above the ground: a step, not a stage
-- Wall height for fallback walls (kit walls are 8.2 to 8.9 studs).
Art.WALL_HEIGHT = 8.6

-- Build pieces -> kit master names.
-- Foundations are not kit meshes: they are cell-sized deck slabs (Art.decks) with a
-- hairline seam between them; World/Seams adds trim and (scrap/reinforced) corner posts.
Art.pieces = {
	["build.fence_wood"] = { "WallWood" }, -- the kit palisade
	-- The LDoE station roster (LDOE_PARITY #19). The P2 carpentry bench (saw, chisels,
	-- vise) is the Saw Bench; the slice-1 kit bench serves as the parts Workbench until its
	-- own model passes the lineup (S1b Phase B checks it beside rec8). The Stonecutter and
	-- Smelter are required at launch (ECONOMY.md): the camp family's grinding-wheel bench and
	-- clay dome kiln (art/higgsfield/m1-launch, lineup L01-L03).
	["build.woodworking_bench"] = { "EO_WorkbenchP2" },
	["build.workbench"] = { "Workbench" },
	["build.stonecutter"] = { "EO_Stonecutter" },
	["build.smelter"] = { "EO_Smelter" },
	["build.campfire"] = { "EO_CampfireRing" }, -- the camp family's stone ring and charred teepee (B18)
	["build.recycler"] = { "EO_RecyclerStation", "Recycler" },
	["build.crate_wood"] = { "EO_StorageCrate", "Crate" },
	["build.crate_banded"] = { "CrateBanded", "Crate" },
	["build.ammo_press"] = { "EO_AmmoPress" }, -- press on a scrap bench (Studio mesh generator)
} :: { [string]: { string } }

-- Foundation decks per tier (1 wood, 2 scrap, 3 reinforced): a MaterialVariant on its
-- base material, and the tint it is multiplied by. The variants are PBR materials made
-- with Studio's material generator and live in the repo as Rojo model files
-- (place/materials -> MaterialService.EO_Materials); scripts can't create them at
-- runtime. Each slab stops DECK_SEAM short of its cell, so a thin dark seam marks the
-- 8-stud grid between foundations, the way LDoE's floor tiles read (rec8_base_017s).
Art.DECK_SEAM = 0.05 -- QA: at 0.1 the grid line was darker than the board gaps
Art.decks = {
	-- Wood: wide, calm honey-tan boards, low contrast, dark seams, one 8-stud tile per
	-- cell (benchmarked against rec8_base_017s; Roblox's planks read as laminate with
	-- grout lines, LT_Timber3 as loud cartoon streaks).
	{ base = Enum.Material.WoodPlanks, variant = "EO_Deck_Planks", tint = Color3.fromRGB(236, 214, 150) },
	{ base = Enum.Material.CorrodedMetal, variant = "EO_Deck_Scrap", tint = Color3.fromRGB(122, 116, 112) },
	{ base = Enum.Material.Concrete, variant = "EO_Deck_Reinforced", tint = Color3.fromRGB(200, 198, 194) },
} :: { { base: Enum.Material, variant: string, tint: Color3 } }

-- Ground (three layers, ART_DIRECTION §4): every terrain material the ground is painted
-- with wears a generated PBR variant (place/materials -> MaterialService.EO_Materials),
-- multiplied by its tint. The textures carry the small layer themselves: pebbles in the
-- earth, leaf litter in the leafy ground. Sand is the dead grass: the grass tile, straw-tinted.
Art.ground = {
	[Enum.Material.Grass] = { variant = "EO_Ground_Grass", tint = Color3.fromRGB(150, 148, 122) },
	[Enum.Material.LeafyGrass] = { variant = "EO_Ground_Leafy", tint = Color3.fromRGB(166, 164, 138) }, -- clover litter: no saturated red leaves, no diagonal banding
	[Enum.Material.Ground] = { variant = "EO_Ground_Earth", tint = Color3.fromRGB(132, 124, 112) },
	[Enum.Material.Mud] = { variant = "EO_Ground_Mud", tint = Color3.fromRGB(160, 154, 140) }, -- ruts toned to the dirt, not stains
	[Enum.Material.Sand] = { variant = "EO_Ground_DryGrass", tint = Color3.fromRGB(164, 156, 118) },
} :: { [Enum.Material]: { variant: string, tint: Color3 } }

-- Kit models whose texture sits off the shared palette, warmed or cooled by a multiply on
-- their SurfaceAppearance (QA: the workbench's blue-grey wood clashed with the deck).
Art.tints = {
	Workbench = Color3.fromRGB(255, 226, 192),
	WallWood = Color3.fromRGB(255, 226, 192), -- QA2: the palisade's blue-grey wood vs the deck
	EO_WallTimber = Color3.fromRGB(255, 226, 192),
	EO_PalisadeDoorway = Color3.fromRGB(255, 226, 192),
	EO_PalisadeWindow = Color3.fromRGB(255, 226, 192),
	EO_PalisadeDoor = Color3.fromRGB(255, 226, 192),
	EO_WindowTimber = Color3.fromRGB(255, 226, 192),
	EO_DoorwayTimber = Color3.fromRGB(255, 212, 168), -- its grey-blue sat further off the walls
	EO_BareBranches = Color3.fromRGB(150, 118, 92), -- weathered bark, not bleached bone
	EO_WorkbenchP2 = Color3.fromRGB(255, 232, 204), -- its grey wood warmed toward the deck
	EO_RockCluster = Color3.fromRGB(168, 150, 128), -- warm brown-grey, darker (concept palette)
	-- S1b: the camp family's stones were bleached light grey. The well takes the rock's warm
	-- grey (B25); the campfire a neutral soot grey, since warm went clay-brown on the deck
	-- (B28 vs B29), and its logs read charred.
	EO_CampfireRing = Color3.fromRGB(150, 146, 140),
	EO_SpringBasin = Color3.fromRGB(168, 150, 128),
	EO_ReedStubbleMesh = Color3.fromRGB(176, 150, 100), -- straw, not pale blue
	-- The fieldstones were the last bleached-white rock beside the warm boulders (B27): the
	-- boulder's own palette, so the small pickup and the big node read as one stone.
	EO_LooseStonesClean = Color3.fromRGB(168, 150, 128),
	-- Launch stations: the kiln's clay toward the family's warm stone (it came out bleached
	-- grey), the stonecutter's wood toward the Saw Bench's.
	EO_Smelter = Color3.fromRGB(190, 168, 144),
	EO_Stonecutter = Color3.fromRGB(255, 232, 204),
} :: { [string]: Color3 }

-- Resource nodes -> kit names and the height (studs) the model is scaled to.
Art.dropModels = { "EO_SupplySacksMesh", "EO_SupplySacks", "Gen_backpack", "EO_Satchel" }

-- `sink` (studs) settles a model into the ground; `clump` stems of a thin plant grow as
-- one bush, each turned and offset (CLUMP below), the way LDoE's bushes read round.
export type NodeArt = { names: { string }, height: number, sink: number?, clump: number? }
Art.nodes = {
	["node.pine_tree"] = { names = { "EO_PineTree", "Gen_tree" }, height = 22 },
	["node.boulder"] = { names = { "EO_RockCluster" }, height = 3.1, sink = 0.3 },
	["node.loose_stones"] = { names = { "EO_LooseStonesClean", "EO_LooseStones" }, height = 1.1 },
	["node.fallen_branches"] = { names = { "EO_BareBranches", "EO_FallenBranches" }, height = 0.94 },
	["node.reed_patch"] = { names = { "EO_ReedsClean" }, height = 4.2, clump = 2 },
	["node.ember_bush"] = { names = { "EO_EmberBushClean" }, height = 4.2, clump = 4 },
	-- The stone well: its basin stays when drained and only the water goes (Art.springWater).
	["node.spring_pool"] = { names = { "EO_SpringBasin" }, height = 4.4 },
	["node.fatwood_stump"] = { names = { "EO_FatwoodStump" }, height = 3 },
	["node.scrap_heap"] = { names = { "EO_ScrapHeapClean" }, height = 3.8 },
	["node.ashroot_mound"] = { names = { "AshrootMound" }, height = 1.6 },
} :: { [string]: NodeArt }

-- Clump stems: { x, z offset as a share of the stem's width, turn in degrees, scale }.
Art.CLUMP = {
	{ 0, 0, 0, 1 },
	{ 0.37, 0.16, 125, 0.86 },
	{ -0.29, 0.25, 240, 0.78 },
	{ 0.04, -0.33, 60, 0.7 },
} :: { { number } }

-- The well's water, in the conformed EO_SpringBasin's frame (9 studs across, pivot at its
-- base centre): a dark disc inside the stone ring, below the rim (capture S1b_B25).
Art.springWater = {
	offset = Vector3.new(-0.1, 1.55, -0.2),
	diameter = 5.2,
	color = Color3.fromRGB(24, 38, 34),
	reflectance = 0.04,
}

-- What a depleted node leaves behind until it regrows (LDoE leaves stumps and rubble):
-- a kit model scaled to `height`. Small pickups (branches, loose stones) leave nothing.
Art.remnants = {
	["node.pine_tree"] = { names = { "EO_FatwoodStump" }, height = 2.3 },
	["node.fatwood_stump"] = { names = { "EO_FatwoodStump" }, height = 0.55 },
	["node.boulder"] = { names = { "EO_LooseStonesClean" }, height = 1.1 },
	["node.scrap_heap"] = { names = { "EO_ScrapHeapClean" }, height = 0.9 },
	["node.reed_patch"] = { names = { "EO_ReedStubbleMesh" }, height = 0.9 },
	["node.ember_bush"] = { names = { "EO_BareBranches" }, height = 0.8 },
	["node.ashroot_mound"] = { names = { "EO_LooseStonesClean" }, height = 0.5 },
} :: { [string]: { names: { string }, height: number } }

-- Quality gate (PLAYER_EXPERIENCE_CHECKLIST §0): only kit models graded A may appear.
-- Everything else (fallback builds, look-test and generated stand-ins, models with
-- defects) stays out of the world, and the feature that needs it is hidden until its
-- model is graded A and added here. Grades: docs/briefs/m1-slice1-audit.md.
-- (Reeds, the ember bush and the scrap heap are the floater-free re-uploads
-- (art/tools/glb_floaters.py: 0 flags), named *Clean.)
Art.approved = {
	-- The developer liked the original pines: EO_PineTree is back (S1b leftover 1). The
	-- conifer (EO_PineConifer, capture 119) stays uploaded and unused; trees are not touched again.
	EO_PineTree = true,
	EO_FatwoodStump = true,
	WallWood = true, -- the outpost kit (the lineup's exemplars)
	WallScrap = true,
	WallReinforced = true,
	WindowScrap = true,
	Workbench = true,
	EO_StoneHatchet = true,
	EO_StonePick = true,
	EO_SpikedClub = true,
	EO_Scrapblade = true,
	-- Family conversions graded A in the lineup (captures 95-101):
	EO_LanternPost = true,
	EO_BareBranches = true,
	-- S1b home set, graded in the lineup beside approved models (captures S1b_B16-B25):
	-- the rock warm-tinted and sunk (the C was for light-grey popcorn lumps), the camp
	-- family's ring and well warm-tinted (the well holds water), reeds and the ember bush
	-- grown as clumps, the scrap heap and stubble as they are.
	EO_RockCluster = true,
	EO_CampfireRing = true,
	EO_SpringBasin = true,
	EO_ReedStubbleMesh = true,
	EO_ReedsClean = true,
	EO_EmberBushClean = true,
	EO_ScrapHeapClean = true,
	-- Batch 2 (captures 105-107):
	EO_StorageCrate = true,
	EO_RecyclerStation = true,
	EO_BarrelCluster = true,
	EO_SupplySacksMesh = true,
	EO_DeadTree = true,
	-- Workbench v2 (Tripo P2, the hard-surface A/B winner over Hunyuan3D v3; capture 115).
	EO_WorkbenchP2 = true,
	-- Loose fieldstones (floaters removed by the gate): the home stone source (capture 121).
	EO_LooseStonesClean = true,
	-- Launch stations (ECONOMY.md: required at launch), graded A in the lineup beside the Saw
	-- Bench, Recycler, Campfire and Crate by day and night (docs/milestones/m1-launch L01-L03);
	-- one piece each, 0 floater flags.
	EO_Smelter = true,
	EO_Stonecutter = true,
	-- Ammo Press (13.12): cast-iron press, lever and powder can on a plank bench (slice 2B).
	EO_AmmoPress = true,
	-- Fog Run props from the slice 2 family sheets (lineup 2026-11-08: weathered, rusted,
	-- floater gate clean).
	EO_SedanWreck = true,
	EO_PickupWreck = true,
	EO_VanWreck = true,
	EO_TractorWreck = true,
	EO_AppleTree = true,
	EO_HayBales = true,
	EO_Boxcar = true,
	EO_FuelPump = true,
	-- Weapons (realistic per the developer, 2026-11-08): Zona's service pistol (CC0) and
	-- sawn-off (CC-BY), its machete (CC0); our fire axe and shortbow.
	EO_WornPistol = true,
	EO_ScrapShotgun = true,
	EO_Machete = true,
	EO_FireAxe = true,
	EO_Shortbow = true,
} :: { [string]: boolean }

-- Converted family models uploaded from art/higgsfield/m1-slice1 (_roblox_assets.json).
-- A place built by Rojo alone lacks them in ServerStorage.EO_Kit, so the first lookup
-- loads the asset (the creator's own) and conforms it as the Studio pass did: turned by
-- `yaw`, scaled so its world `axis` measures `size` studs, pivot at its base centre.
Art.uploaded = {
	EO_BareBranches = { id = 131242296768407, yaw = 90, axis = "X", size = 5 },
	EO_WallTimber = { id = 124343239589548, yaw = 90, axis = "X", size = 8 },
	EO_PalisadeDoorway = { id = 94082431833572, yaw = 90, axis = "X", size = 8 },
	EO_PalisadeDoor = { id = 87138652228163, yaw = 90, axis = "Y", size = 6.4 },
	EO_PalisadeWindow = { id = 87647223753915, yaw = 90, axis = "X", size = 8 },
	EO_CampfireRing = { id = 81464877202205, yaw = 0, axis = "X", size = 4.6 },
	EO_SpringBasin = { id = 121429807141566, yaw = 0, axis = "X", size = 9 },
	EO_ReedStubbleMesh = { id = 73755966799812, yaw = 0, axis = "Y", size = 1.4 },
	EO_RockCluster = { id = 112631953002450, yaw = 0, axis = "X", size = 7 },
	EO_LanternPost = { id = 115765948750615, yaw = 0, axis = "Y", size = 9 },
	EO_StandingTorch = { id = 76894774227727, yaw = 0, axis = "Y", size = 6 },
	EO_DoorwayTimber = { id = 86510148563388, yaw = 90, axis = "X", size = 8 },
	EO_WindowTimber = { id = 123523155311228, yaw = 90, axis = "X", size = 8 },
	EO_DeadTree = { id = 125675745178137, yaw = 0, axis = "Y", size = 18 },
	EO_StorageCrate = { id = 86480969772739, yaw = 0, axis = "X", size = 5.4 },
	EO_RecyclerStation = { id = 114511988922602, yaw = 0, axis = "Z", size = 6 },
	EO_BarrelCluster = { id = 97808210346830, yaw = 0, axis = "X", size = 4 },
	EO_SupplySacksMesh = { id = 106489665857780, yaw = 0, axis = "X", size = 3.5 },
	EO_RainCollector = { id = 96623096328279, yaw = 0, axis = "Y", size = 5 },
	EO_Signpost = { id = 129379454140930, yaw = 0, axis = "Y", size = 7 },
	EO_WorkbenchP2 = { id = 104388307441616, yaw = 270, axis = "X", size = 5.6 },
	EO_PineConifer = { id = 130639495990824, yaw = 0, axis = "Y", size = 22 },
	EO_LooseStonesClean = { id = 100348018403125, yaw = 0, axis = "X", size = 2.4 },
	EO_ReedsClean = { id = 106633992505764, yaw = 0, axis = "Y", size = 4.2 },
	EO_EmberBushClean = { id = 106896648014033, yaw = 0, axis = "Y", size = 4 },
	EO_ScrapHeapClean = { id = 89747869389109, yaw = 0, axis = "Y", size = 3.8 },
	-- Launch stations (art/higgsfield/m1-launch): turned so the kiln's hatch and the bench's
	-- long side face the front, sized to their 6 x 6 and 6 x 4 footprints.
	EO_Smelter = { id = 134220739947756, yaw = 90, axis = "X", size = 5.8 },
	EO_Stonecutter = { id = 96553555280227, yaw = 90, axis = "X", size = 5.6 },
	EO_AmmoPress = { id = 71241404323624, yaw = 0, axis = "X", size = 5.2 },
	-- Slice 2 props (art/higgsfield/m1-slice2/_roblox_assets.json): long side along X.
	EO_SedanWreck = { id = 121904797870360, yaw = 0, axis = "X", size = 14 },
	EO_PickupWreck = { id = 112415392425301, yaw = 90, axis = "X", size = 16 },
	EO_VanWreck = { id = 75377164376070, yaw = 0, axis = "X", size = 16 },
	EO_TractorWreck = { id = 138754378882219, yaw = 0, axis = "X", size = 11 },
	EO_AppleTree = { id = 119281991299964, yaw = 0, axis = "Y", size = 15 },
	EO_HayBales = { id = 98372468469042, yaw = 90, axis = "X", size = 7 },
	EO_Boxcar = { id = 133928155401070, yaw = 90, axis = "Y", size = 14 },
	EO_FuelPump = { id = 130764128762105, yaw = 0, axis = "Y", size = 6 },
	-- Held weapons (scaled again to Art.held lengths in the hand).
	EO_WornPistol = { id = 137577727330156, yaw = 0, axis = "Y", size = 1 },
	EO_ScrapShotgun = { id = 72894953650046, yaw = 0, axis = "Y", size = 1 },
	EO_Machete = { id = 105390370970083, yaw = 0, axis = "Y", size = 2 },
	EO_FireAxe = { id = 101477205236958, yaw = 0, axis = "Z", size = 3 },
	EO_Shortbow = { id = 104799057457758, yaw = 0, axis = "Z", size = 3 },
} :: { [string]: { id: number, yaw: number, axis: string, size: number } }

local function anyApproved(names: { string }?): boolean
	local list: { string } = names or {}
	for _, name in list do
		if Art.approved[name] then
			return true
		end
	end
	return false
end

-- Whether a build piece can be offered: foundations are material decks; everything
-- else needs an approved kit model.
-- Walls, doorways, windows and doors are exact geometry in their tier's one material
-- (Models.structure), always ready. The Defense fence keeps its kit palisade.
local EXACT_KINDS = { wall = true, doorway = true, window = true, door = true }
local KIT_ONLY = { ["build.fence_wood"] = true }

function Art.exactPiece(pieceId: string, kind: string?): boolean
	return kind ~= nil and EXACT_KINDS[kind] == true and not KIT_ONLY[pieceId]
end

function Art.pieceReady(pieceId: string, kind: string?): boolean
	if kind == "foundation" or Art.exactPiece(pieceId, kind) then
		return true
	end
	return anyApproved(Art.pieces[pieceId])
end

-- Whether a resource node can appear (it needs an approved model).
function Art.nodeReady(nodeId: string): boolean
	local art = Art.nodes[nodeId]
	return art ~= nil and anyApproved(art.names)
end

-- Whether a loot sack can lie on the ground (dropping items needs its model).
function Art.dropReady(): boolean
	return anyApproved(Art.dropModels)
end

-- Items -> kit names for the model held in hand and the rendered 3D icon.
Art.items = {
	["item.stone_hatchet"] = { "EO_StoneHatchet", "Gen_axe" },
	["item.spiked_club"] = { "EO_SpikedClub" },
	["item.scrapblade"] = { "EO_Scrapblade" },
	["item.stone_pick"] = { "EO_StonePick" },
	["item.timber"] = { "Gen_firewood" },
	["item.satchel"] = { "Gen_backpack" },
	["item.pack_frame"] = { "Raw_Backpack", "Gen_backpack" },
	-- Fog Run weapons (slice 2B): realistic guns and the machete from the Zona sources
	-- (CREDITS.md), the fire axe and shortbow from the slice 2 family sheets.
	["item.pipe_pistol"] = { "EO_WornPistol" },
	["item.scrap_shotgun"] = { "EO_ScrapShotgun" },
	["item.machete"] = { "EO_Machete" },
	["item.fire_axe"] = { "EO_FireAxe" },
	["item.shortbow"] = { "EO_Shortbow" },
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
	-- Guns: how far the fist sits off the barrel line toward `edge` (down), as a share of
	-- the gun's size along it (a pistol's grip hangs below the slide).
	drop: number?,
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
	-- Guns: `axis` is the muzzle direction (the fist points it forward) and `edge` the
	-- gun's underside; `length` is the gun's length (realistic, about 1.3x life size
	-- against the 5.6-stud survivor) and `grip` how far from the butt the fist holds.
	["item.pipe_pistol"] = {
		axis = Vector3.new(-1, 0, 0),
		edge = Vector3.new(0, -1, 0),
		grip = 0.22,
		length = 1.1,
		holster = "belt",
		drop = 0.28,
	},
	["item.scrap_shotgun"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(0, -1, 0),
		grip = 0.2,
		length = 2.4,
		holster = "back",
		drop = 0.22,
	},
	["item.machete"] = {
		axis = Vector3.new(0, 1, 0),
		edge = Vector3.new(0, 0, 1),
		grip = 0.12,
		length = 2.3,
		holster = "belt",
	},
	["item.fire_axe"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(0, 1, 0),
		grip = 0.12,
		length = 2.9,
		holster = "back",
	},
	-- The bow faces the way the arrow flies, limbs upright (its depth is `length`).
	["item.shortbow"] = {
		axis = Vector3.new(0, -1, 0),
		edge = Vector3.new(0, 0, 1),
		grip = 0.5,
		length = 0.95,
		holster = "back",
	},
} :: { [string]: HeldArt }

-- Sound IDs. PLACEHOLDER: every "" is still to be chosen in Studio (Phase 2);
-- the client's Sfx skips empty IDs, so nothing plays until one is set.
-- Sounds: every ID is a real asset from the Roblox Creator Store, mostly the licensed
-- Pro Sound Effects and APM Music libraries. Volumes are normalised from measured
-- peaks (AudioAnalyzer) so one-shots land near the same loudness; `region` trims a
-- clip to one event; `variants` are picked at random to avoid repetition.
-- `group` routes to a SoundGroup the settings sliders control.
export type SoundSpec = {
	id: string,
	volume: number,
	speed: number?,
	region: { number }?, -- { start, stop } seconds
	group: ("ui" | "sfx" | "ambience" | "music")?,
	variants: { SoundSpec }?,
}

local function snd(id: number, volume: number, extra: { [string]: any }?): SoundSpec
	local spec: any = { id = `rbxassetid://{id}`, volume = volume }
	if extra then
		for key, value in extra do
			spec[key] = value
		end
	end
	return spec
end

local BAG = 9113667260 -- Pro Sound Effects "Camera Bag 5": flap and rustle
local CLICK = 82714919253928 -- "UI wood_click" (CoreKit)

Art.sounds = {
	-- Interface
	uiOpen = snd(BAG, 3.2, { region = { 0, 0.45 }, group = "ui" }),
	uiClose = snd(BAG, 2.6, { region = { 0, 0.4 }, speed = 1.15, group = "ui" }),
	uiClick = snd(CLICK, 1.5, { group = "ui" }),
	uiHover = snd(CLICK, 0.45, { speed = 1.25, group = "ui" }),
	uiError = snd(117572160588950, 0.6, { group = "ui" }),
	pickup = snd(BAG, 3, { region = { 0, 0.35 }, speed = 1.2, group = "ui" }),
	swap = snd(BAG, 2.6, { region = { 0, 0.22 }, speed = 1.45, group = "ui" }), -- a quick holster rustle (4.9)
	collect = snd(BAG, 3.4, { region = { 0, 0.35 }, speed = 1.05, group = "ui" }),
	reward = snd(131408467630923, 0.5, { group = "ui" }),
	levelUp = snd(9043711287, 0.7, { group = "music" }), -- APM "Triumph of the Underdog - Sting 1"
	questComplete = snd(9038655602, 0.6, { group = "music" }), -- APM "Unfolding Triumph - Sting"
	-- Gathering
	chop = snd(159798370, 0.6, { variants = { snd(9120811299, 4), snd(9120808574, 5) } }),
	mine = snd(9118629291, 0.75, { variants = { snd(9118607563, 0.8, { region = { 0, 0.5 } }) } }),
	pluck = snd(9113581974, 0.6, { variants = { snd(9113581977, 0.6), snd(9113582134, 0.6) } }),
	pluckGrass = snd(102870135066164, 6),
	treeFall = snd(6365855087, 0.8),
	rockBreak = snd(9118689425, 0.9),
	bushBreak = snd(9114518080, 3),
	toolBreak = snd(9113582284, 0.6),
	-- Building and stations
	place = snd(9120950231, 2),
	upgrade = snd(9116652836, 0.7, { region = { 0, 1.2 } }),
	demolish = snd(9120957463, 0.5),
	door = snd(9114135682, 10),
	craftStart = snd(9114769979, 0.6, { region = { 0.2, 1.5 } }),
	workLoop = snd(100885263044327, 1.2),
	fuel = snd(103911273184692, 0.5),
	fireLoop = snd(150367086, 0.7),
	-- Survival
	eat = snd(92009203113499, 0.6),
	drink = snd(9114687054, 1.4),
	lowMeter = snd(6202853067, 0.5, { group = "ui" }),
	-- Footsteps by surface
	stepGrass = snd(116116590426843, 1.2),
	stepDirt = snd(135139856111678, 0.5, { region = { 0, 0.3 } }),
	stepWood = snd(116345792542812, 1.3, { region = { 0.3, 0.55 } }),
	stepStone = snd(87061775498714, 6),
	-- Ambience beds (loops) and music
	dayBed = snd(9112777821, 6, { group = "ambience" }), -- PSE "Farmland Presence 2"
	airBed = snd(9112761455, 4, { group = "ambience" }), -- PSE "Convict Lake 1"
	nightBed = snd(9112764573, 7, { group = "ambience" }), -- PSE "Crickets Night 3"
	eerieBed = snd(9112795463, 0.35, { group = "ambience" }), -- PSE "Hollow Rumble 1"
	musicDay = snd(9040514823, 0.3, { group = "music" }), -- APM "Campfire Embers 60"
	musicNight = snd(1843721367, 0.35, { group = "music" }), -- APM "Low Drone 19"
	-- Fog Runs (S2): Pro Sound Effects and APM library sounds, trimmed to one event.
	pistolShot = snd(
		9117396996,
		1.1,
		{ region = { 0, 0.9 }, variants = { snd(9117398114, 1.1, { region = { 0, 0.9 } }) } }
	), -- PSE "Pistol Single Shots 1/11"
	shotgunShot = snd(9112912106, 1.2, { region = { 0, 1.1 } }), -- PSE "12 Gauge Shotgun 1", the first blast only
	flareLaunch = snd(9118591402, 1, { region = { 0, 1.4 } }), -- PSE "Rocket Flare Out 1"
	reload = snd(9113104516, 1, { region = { 0, 1.4 } }), -- PSE "Ammo Magazine 4"
	dryClick = snd(9117396530, 1, { region = { 0, 0.3 } }), -- PSE "Pistol Handling 1", one click
	meleeSwing = snd(9120972321, 0.9, { variants = { snd(9120728815, 0.8, { region = { 0, 0.6 } }) } }), -- PSE whooshes
	hitThud = snd(
		9117969687,
		0.9,
		{ region = { 0, 0.6 }, variants = { snd(9117969717, 0.9, { region = { 0, 0.6 } }) } }
	), -- PSE "Punch Kit Beefy Hit 2/3"
	hollowAlert = snd(9125467848, 0.8, { variants = { snd(9113973128, 0.8) } }), -- PSE creature growls
	hollowAttack = snd(9125475729, 0.8, { variants = { snd(9113985445, 0.7, { region = { 0, 1.2 } }) } }), -- PSE snarls
	hollowDeath = snd(9113989919, 0.9, { variants = { snd(9113970887, 0.7, { region = { 0, 1.6 } }) } }), -- PSE hiss and dying breath
	bloaterBurst = snd(9120628323, 1, { variants = { snd(9125640290, 0.9) } }), -- PSE wet splat, wheezy burst
	bowDraw = snd(9125407496, 0.9), -- PSE "Bow Stretches Wood Creaking"
	bowRelease = snd(9113166206, 0.9, { region = { 0, 1 } }), -- PSE "Arrow Out Whooshing Pass By 1"
	arrowHit = snd(9113160887, 0.9, { region = { 0, 0.8 } }), -- PSE "Arrow In And Hit 14"
	crateOpen = snd(9120881979, 1), -- PSE "Wood Groan Creak Opening Wood Chest"
	lockerOpen = snd(9116646197, 0.9, { region = { 0, 1.2 } }), -- PSE "Metal Hinge Open Locker"
	searchRummage = snd(9120189795, 0.8), -- PSE "Tool Box Rummage Searching Through 8"
	extractStart = snd(9118027586, 0.8), -- PSE "Radio Static 9"
	fogWarning = snd(9119077419, 0.6, { region = { 0, 3.5 } }), -- PSE "Ship Horn" (the Fog closing)
	combatTension = snd(1835935180, 0.3, { group = "music" }), -- APM "Pulse Of Fear"
} :: { [string]: SoundSpec }

-- Empty equipment slots show a silhouette of what goes there (checklist 4.1): one
-- white-on-transparent atlas (art/higgsfield/m1-slice1/icons/gear/gear_atlas.png),
-- 256 px cells, tinted by the UI.
Art.gearSilhouettes = {
	image = "rbxassetid://92488844905748",
	cell = 256,
	cells = {
		head = Vector2.new(0, 0),
		body = Vector2.new(1, 0),
		legs = Vector2.new(2, 0),
		feet = Vector2.new(0, 1),
		bag = Vector2.new(1, 1),
		weapon = Vector2.new(2, 1),
	} :: { [string]: Vector2 },
}

-- HUD meter glyphs (placeholder until the icon set exists).
-- The UI glyph set (checklist 4.17): 30 matching 256 px icons (art/ui/glyphs), cream
-- on transparent, tinted by ImageColor3. Every icon in the UI comes from here: no
-- emoji, Unicode symbols or default Roblox icons.
Art.glyphs = {
	health = "rbxassetid://115532980247949",
	hunger = "rbxassetid://129214740108707",
	thirst = "rbxassetid://115119460509123",
	energy = "rbxassetid://104189643765839",
	xp = "rbxassetid://104495868342079",
	coin = "rbxassetid://104388916853301",
	attack = "rbxassetid://135915378952394",
	interact = "rbxassetid://84326895236247",
	build = "rbxassetid://76238338427295",
	backpack = "rbxassetid://106229515638743",
	craft = "rbxassetid://125495092640314",
	auto_gather = "rbxassetid://128061896557821",
	swap = "rbxassetid://138508444329514",
	medkit = "rbxassetid://83813460402429",
	sprint = "rbxassetid://80193876808667",
	dodge = "rbxassetid://102265978974188",
	map = "rbxassetid://104238293919401",
	quests = "rbxassetid://113009793632906",
	shop = "rbxassetid://104802217196091",
	inbox = "rbxassetid://97701642293203",
	friends = "rbxassetid://95989041269677",
	settings = "rbxassetid://97520461995565",
	close = "rbxassetid://125780608999128",
	lock = "rbxassetid://72629341295590",
	plus = "rbxassetid://120030852013884",
	minus = "rbxassetid://101783907231713",
	favourite = "rbxassetid://105004904499494",
	trash = "rbxassetid://120304458961712",
	storage = "rbxassetid://104605090820806",
	campfire = "rbxassetid://139250651894110",
	-- Sheet C (S1b, LDOE_PARITY HUD and screens): art/ui/glyphs, uploaded by S1b.
	axe = "rbxassetid://132008963429716", -- context button: chop
	pick = "rbxassetid://116723703965422", -- context button: mine
	talk = "rbxassetid://131895473902591", -- context button: talk
	crew = "rbxassetid://75710612953498", -- menu bar
	pass = "rbxassetid://95275003551384", -- menu bar
	chat = "rbxassetid://80912016428510",
	expand = "rbxassetid://88969264987884",
	sort = "rbxassetid://90551417983901",
	split = "rbxassetid://138832061964321",
	upgrade = "rbxassetid://122680927129738", -- the green upgrade arrow
	brush = "rbxassetid://120848260300004", -- storage label colour
	recipes = "rbxassetid://82674517043372", -- ALL RECIPES
	defense = "rbxassetid://72325909298547", -- armor stat; Defense tray tab
	sun = "rbxassetid://129919915537676",
	moon = "rbxassetid://74460301341960",
	hide_walls = "rbxassetid://140600825829489", -- hide upper walls
	move = "rbxassetid://87099813822929",
	rotate = "rbxassetid://116016044144367",
	chevron = "rbxassetid://98853120119324", -- tracker collapse
	check = "rbxassetid://88186247590426", -- objective done
	timer = "rbxassetid://93404803435369",
	furniture = "rbxassetid://81227467583015", -- tray tab
	station = "rbxassetid://76437812041068", -- tray tab and station headers
	vehicle = "rbxassetid://106222628289474", -- the wrecked hauler
	event = "rbxassetid://128117457014617", -- top-right strip (S3)
	offer = "rbxassetid://71527739225617",
	gift = "rbxassetid://118846511433792",
	fill_up = "rbxassetid://113536503595888", -- FILL UP
} :: { [string]: string }

-- The Fog map (checklist 11.2): its pictures. The map itself is composed from data
-- (Data/FogRegions): a painterly forest floor, meadow, rock and water patches, tree
-- clusters, landmark pictures and fog, cut from the painted map or painted procedurally
-- (art/ui/fogmap), plus each location's panel art.
Art.fogMap = {
	sprites = {
		baseForest = "rbxassetid://97414314023366",
		baseMeadow = "rbxassetid://79751982921449",
		meadow = "rbxassetid://79899317439248",
		rock = "rbxassetid://89764791083228",
		water = "rbxassetid://105894592901020",
		fog = "rbxassetid://73677404641188",
		cliff = "rbxassetid://70405563344897",
		farm = "rbxassetid://133327073008346",
		outpost = "rbxassetid://133217511030439",
		quarry = "rbxassetid://92598748095092",
		railcars = "rbxassetid://77219659895404",
		town = "rbxassetid://114224405252566",
		trees1 = "rbxassetid://123655961716432",
		trees2 = "rbxassetid://132728099422417",
		trees3 = "rbxassetid://123407507301838",
		trees4 = "rbxassetid://93611634724367",
	} :: { [string]: string },
	-- Each picture's height over its width (the files' shapes), so it keeps its aspect.
	aspects = {
		farm = 397 / 512,
		outpost = 289 / 512,
		quarry = 569 / 768,
		railcars = 222 / 512,
		town = 395 / 768,
		cliff = 174 / 256,
		trees1 = 213 / 256,
		trees2 = 204 / 256,
		trees3 = 279 / 256,
		trees4 = 279 / 256,
		fog = 1,
	} :: { [string]: number },
	-- Each location's panel and loading-screen art: its corner of the painted map
	-- (art/higgsfield/m1-slice2/ui/locations, cropped round the pin). The Stranded
	-- Caravan, not on the painting, uses a render of its built map at dusk.
	art = {
		["loc.pine_hollow"] = "rbxassetid://80424846897012",
		["loc.sunken_quarry"] = "rbxassetid://78393149598495",
		["loc.ashfall_depot"] = "rbxassetid://114701602305172",
		["loc.stranded_caravan"] = "rbxassetid://107008535507654",
	} :: { [string]: string },
}

-- The Hollow's animations (checklist 13.1): R15 clips made with Studio's animation
-- generator and published as the creator's own assets, played on each kind's rig
-- (ReplicatedStorage.EO_Hollow.<enemyId>) by Controllers/HollowView.
local SHAMBLE_IDLE = "rbxassetid://134064488942538" -- swaying, head lolling
local SHAMBLE_WALK = "rbxassetid://95035190574951" -- hunched, dragging its feet
local LUNGE = "rbxassetid://128684712386159" -- a two-armed downward claw
local HIT = "rbxassetid://92048533093046" -- staggers back from a blow
local COLLAPSE = "rbxassetid://78846833571776" -- knees buckle, face down
local SPRINT = "rbxassetid://125564840299614" -- low, frantic
local WADDLE = "rbxassetid://116620273303279" -- the bloater's heavy sway

Art.hollowAnimations = {
	["enemy.shambler"] = {
		idle = SHAMBLE_IDLE,
		walk = SHAMBLE_WALK,
		run = SHAMBLE_WALK,
		attack = LUNGE,
		hit = HIT,
		death = COLLAPSE,
	},
	["enemy.runner"] = {
		idle = SHAMBLE_IDLE,
		walk = SHAMBLE_WALK,
		run = SPRINT,
		attack = LUNGE,
		hit = HIT,
		death = COLLAPSE,
	},
	["enemy.bloater"] = {
		idle = SHAMBLE_IDLE,
		walk = WADDLE,
		run = WADDLE,
		attack = LUNGE,
		hit = HIT,
		death = COLLAPSE,
	},
} :: { [string]: { [string]: string } }

-- The HUD meters' glyph names.
Art.meterGlyphs = {
	health = "health",
	hunger = "hunger",
	thirst = "thirst",
	energy = "energy",
	xp = "xp",
} :: { [string]: string }

return Art
