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
	-- Launch content (docs/research/ldoe-mvp-parity-content.md LB-3, LB-5): the camp family's
	-- wrapped torch and lantern post, its rain collector, and the smoke rack (Studio mesh
	-- generator), graded in the lineup beside the Campfire and Crate.
	["build.pitch_torch"] = { "EO_StandingTorch" },
	["build.post_lantern"] = { "EO_LanternPost" },
	["build.rain_barrel"] = { "EO_RainCollector" },
	["build.smoke_rack"] = { "EO_SmokeRack" },
	-- Content 2.0 stations (Studio mesh generator, graded in the lineup beside the Smelter
	-- and Stonecutter, docs/milestones/m1-launch C30): a fieldstone dome furnace banded in
	-- rusted iron, and a honey-wood bench of flasks, a still and a mortar.
	["build.blast_furnace"] = { "EO_BlastFurnace" },
	["build.apothecary"] = { "EO_Apothecary" },
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
	-- Fortified (Content 2.0): riveted steel plates (Studio's material generator, picked from
	-- four takes beside the Reinforced concrete), a shade darker so the tiers read apart and
	-- warmed off its blue toward gunmetal (C24: beside the warm kit it read slate-blue).
	{ base = Enum.Material.DiamondPlate, variant = "EO_Deck_Fortified", tint = Color3.fromRGB(172, 164, 154) },
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
	-- The found mallet's yellow handle, dirtied to the family's weathered palette (lineup L04).
	EO_RailMallet = Color3.fromRGB(176, 156, 118),
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
	-- The Ranger Pack's grey digital camo, toward LDoE's olive Military Backpack (rec9).
	EO_RangerPack = Color3.fromRGB(176, 182, 128),
} :: { [string]: Color3 }

-- Resource nodes -> kit names and the height (studs) the model is scaled to.
Art.dropModels = { "EO_SupplySacksMesh", "EO_SupplySacks", "Gen_backpack", "EO_Satchel" }

-- `sink` (studs) settles a model into the ground; `clump` stems of a thin plant grow as
-- one bush, each turned and offset (CLUMP below), the way LDoE's bushes read round.
export type NodeArt = {
	names: { string },
	height: number,
	sink: number?,
	clump: number?,
	tint: Color3?, -- a retint of the base model (its SurfaceAppearance colour)
}
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
	-- ECONOMY §1 ores: free retints of the A-grade rock cluster, rust-red and copper-green.
	["node.ironstone_rock"] = {
		names = { "EO_RockCluster" },
		height = 3.3,
		sink = 0.3,
		tint = Color3.fromRGB(190, 136, 114), -- QA: 214,138,108 read as terracotta in daylight
	},
	["node.malachite_vein"] = {
		names = { "EO_RockCluster" },
		height = 3.0,
		sink = 0.3,
		tint = Color3.fromRGB(132, 194, 158),
	},
	-- Ironbark (ECONOMY §1.1): the broadleaf hardwood. Interim: the orchard's A-grade
	-- broadleaf, darkened, until the oak-like model is approved.
	["node.ironbark_tree"] = { names = { "EO_AppleTree" }, height = 18, tint = Color3.fromRGB(150, 142, 124) },
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
	-- sawn-off (CC-BY), its machete (CC0); our fire axe, shortbow and photoreal flare pistol.
	EO_WornPistol = true,
	EO_FlarePistol = true,
	EO_ScrapShotgun = true,
	EO_Machete = true,
	EO_FireAxe = true,
	EO_Shortbow = true,
	-- The first five of ARSENAL's roster (§0: uploaded and graded A from side and top renders).
	EO_DutyPistol = true,
	EO_PumpShotgun = true,
	EO_HuntingRifle = true,
	EO_AssaultRifle = true,
	EO_AntiMaterielRifle = true,
	-- Launch content, graded in the lineup beside the Campfire, Crate and Spiked Club
	-- (docs/milestones/m1-launch L04): the camp family's wrapped torch and rain collector,
	-- the generated smoke rack (second take: muted meat, cold ash), Zona's crowbar and
	-- sledgehammer as the found Tire Iron and Rail Mallet (weapons only, per the developer).
	EO_StandingTorch = true,
	EO_RainCollector = true,
	EO_SmokeRack = true,
	EO_TireIron = true,
	EO_RailMallet = true,
	-- The Sharpened Stake: the icon sheet's stake through the family conversion (Tripo,
	-- its base disc dropped by art/tools/glb_drop_base.py).
	EO_SharpenedStake = true,
	-- Content 2.0 (batch 4b), graded A in the lineup beside the survivor and the approved
	-- melee, stations and kit (docs/milestones/m1-launch C29-C31). Zona's licensed gear and
	-- meds (CREDITS.md):
	EO_GasMask = true,
	EO_SteelHelmet = true,
	EO_CombatHelmet = true,
	EO_PlateCarrier = true,
	EO_RangerPack = true,
	EO_TraumaPouch = true,
	EO_FirstAidKit = true,
	EO_EmberStim = true,
	-- and Studio's mesh generator, where Zona has no licensable model (or its file wasn't
	-- grade A: the camping pack didn't read as hide, the pill box was a 12-triangle card,
	-- the four wip-v3 melee files couldn't be uploaded from the approved folder).
	EO_HideboundCap = true,
	EO_HideboundCoat = true,
	EO_HideboundLeggings = true,
	EO_HideboundBoots = true,
	EO_RivetedHelm = true,
	EO_RivetedCuirass = true,
	EO_RivetedLegguards = true,
	EO_RivetedBoots = true,
	EO_HideRucksack = true,
	EO_SteelPlate = true,
	EO_AntisepticBottle = true,
	EO_HandAxe = true,
	EO_HardwoodBat = true,
	EO_FieldKnife = true,
	EO_HayFork = true,
	EO_BlastFurnace = true,
	EO_Apothecary = true,
} :: { [string]: boolean }

-- Converted family models uploaded from art/higgsfield/m1-slice1 (_roblox_assets.json).
-- A place built by Rojo alone lacks them in ServerStorage.EO_Kit, so the first lookup
-- loads the asset (the creator's own) and conforms it as the Studio pass did: turned by
-- `yaw`, scaled so its world `axis` measures `size` studs, pivot at its base centre.
Art.uploaded =
	{
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
		EO_FlarePistol = { id = 130325429565330, yaw = 0, axis = "Z", size = 1.25 },
		EO_ScrapShotgun = { id = 72894953650046, yaw = 0, axis = "Y", size = 1 },
		EO_Machete = { id = 105390370970083, yaw = 0, axis = "Y", size = 2 },
		EO_FireAxe = { id = 101477205236958, yaw = 0, axis = "Z", size = 3 },
		EO_Shortbow = { id = 104799057457758, yaw = 0, axis = "Z", size = 3 },
		-- ARSENAL §0's graded uploads (art/zona/guns). As imported the muzzle points along -X
		-- (the Duty Pistol's along -Z) with the top up, measured in Studio 2026-11-11.
		EO_DutyPistol = { id = 72665632302595, yaw = 0, axis = "Z", size = 1.2 },
		EO_PumpShotgun = { id = 102438923048838, yaw = 0, axis = "X", size = 4 },
		-- The source model carries a loose cartridge under its magazine: a floater, left out.
		EO_HuntingRifle = { id = 99562708864658, yaw = 0, axis = "X", size = 4.3, omit = { "Vert.023" } },
		EO_AssaultRifle = { id = 129256241328198, yaw = 0, axis = "X", size = 3.5 },
		EO_AntiMaterielRifle = { id = 93078334956668, yaw = 0, axis = "X", size = 4.7 },
		-- Launch content: found melee from Zona (art/zona/melee), the generated smoke rack.
		EO_TireIron = { id = 74586365090292, yaw = 0, axis = "Y", size = 2 },
		EO_SharpenedStake = { id = 88147290024814, yaw = 0, axis = "Y", size = 2 },
		EO_RailMallet = { id = 84097844053183, yaw = 0, axis = "Y", size = 3.4 },
		EO_SmokeRack = { id = 132431669150006, yaw = 0, axis = "X", size = 5.6 },
		-- Content 2.0 (batch 4b). Worn and carried items face +Z (the icon camera's side), so
		-- an icon shows the front; Art.wornModels turns them to face ahead on the body. The gas
		-- mask was imported face up (`pitch` stands it up first). Bags show their outer face.
		EO_GasMask = { id = 135203303519979, yaw = 180, pitch = -90, axis = "Y", size = 1 },
		EO_SteelHelmet = { id = 117347120589715, yaw = 0, axis = "Z", size = 0.95 },
		EO_CombatHelmet = { id = 82934175970933, yaw = 0, axis = "Z", size = 1.05 },
		EO_PlateCarrier = { id = 71564496579353, yaw = 0, axis = "Y", size = 1.8 },
		EO_RangerPack = { id = 129119268659888, yaw = 180, axis = "Y", size = 1.85 },
		EO_TraumaPouch = { id = 106960913686733, yaw = 0, axis = "Y", size = 0.65 },
		EO_FirstAidKit = { id = 89281981728389, yaw = 0, axis = "X", size = 1.4 },
		EO_EmberStim = { id = 135609039504160, yaw = 0, axis = "Z", size = 0.5 },
		EO_HideboundCap = { id = 77172601565001, yaw = 180, axis = "X", size = 1 },
		EO_HideboundCoat = { id = 71576554068381, yaw = 180, axis = "Y", size = 2.4 },
		EO_HideboundLeggings = { id = 84832116640218, yaw = 180, axis = "Y", size = 2.6 },
		EO_HideboundBoots = { id = 112414225746582, yaw = 180, axis = "Y", size = 1.3 },
		EO_RivetedHelm = { id = 70666819282091, yaw = 180, axis = "X", size = 1 },
		EO_RivetedCuirass = { id = 136751421981432, yaw = 180, axis = "Y", size = 2.3 },
		EO_RivetedLegguards = { id = 98389006096672, yaw = 180, axis = "Y", size = 2.6 },
		EO_RivetedBoots = { id = 101760723597225, yaw = 180, axis = "Y", size = 1.3 },
		EO_HideRucksack = { id = 132651051145310, yaw = 180, axis = "Y", size = 2 },
		EO_SteelPlate = { id = 82910989221839, yaw = 0, axis = "X", size = 1.6 },
		EO_AntisepticBottle = { id = 97827015398174, yaw = 180, axis = "Y", size = 0.6 },
		-- Melee as generated: handle down (+Y head) except the bat, which lies along Z, knob at +Z.
		EO_HandAxe = { id = 133113732197143, yaw = 0, axis = "Y", size = 2 },
		EO_HardwoodBat = { id = 117761103396118, yaw = 0, axis = "Z", size = 3 },
		EO_FieldKnife = { id = 104034707094359, yaw = 0, axis = "Y", size = 1.3 },
		EO_HayFork = { id = 113254000755998, yaw = 0, axis = "Y", size = 4.6 },
		-- Stations: front to +Z (the gameplay camera's side), sized to 6 x 6 and 6 x 4 footprints.
		EO_BlastFurnace = { id = 134195576178730, yaw = 180, axis = "X", size = 5.8 },
		EO_Apothecary = { id = 99418897818426, yaw = 180, axis = "X", size = 5.6 },
	} :: { [string]: { id: number, yaw: number, pitch: number?, axis: string, size: number, omit: { string }? } }

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
-- The Reed Doormat is a flat woven mat in exact geometry (Models.piece).
local EXACT_PIECES = { ["build.doormat"] = true }

function Art.exactPiece(pieceId: string, kind: string?): boolean
	if EXACT_PIECES[pieceId] then
		return true
	end
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
-- Worn armor: the tint each piece lays over the survivor's clothes (Services/Inventory
-- applyWorn), multiplied into the rig's one atlas texture: a multiply can only shift and
-- darken the dark field clothes, so each set takes a clear hue. Reedweave warms them to
-- straw-tan, Padded cools them to slate with dark leather boots (lineup L04). Head pieces
-- show on the paperdoll only.
Art.worn = {
	["item.reedweave_shirt"] = Color3.fromRGB(255, 226, 140),
	["item.reedweave_trousers"] = Color3.fromRGB(246, 214, 132),
	["item.reedweave_wraps"] = Color3.fromRGB(236, 204, 128),
	["item.padded_vest"] = Color3.fromRGB(156, 172, 186),
	["item.padded_leggings"] = Color3.fromRGB(146, 158, 172),
	["item.padded_boots"] = Color3.fromRGB(128, 98, 74),
	-- Content 2.0 (batch 4b): Hidebound warms them to tanned hide, Riveted greys them to
	-- iron over dark leather, the Plate Carrier darkens the chest to its black webbing.
	["item.hidebound_coat"] = Color3.fromRGB(204, 150, 104),
	["item.hidebound_leggings"] = Color3.fromRGB(190, 140, 100),
	["item.hidebound_boots"] = Color3.fromRGB(150, 104, 72),
	["item.riveted_cuirass"] = Color3.fromRGB(140, 142, 146),
	["item.riveted_legguards"] = Color3.fromRGB(126, 128, 132),
	["item.riveted_boots"] = Color3.fromRGB(108, 98, 90),
	["item.plate_carrier"] = Color3.fromRGB(100, 104, 98),
} :: { [string]: Color3 }

--[[
	Worn gear with a model on the body (2.0 batch 4b; World/Models.worn): headwear on the
	head, bags on the back. The kit model (Art.items) is turned by `turn` (degrees), scaled so
	its longest side is `size` studs and centred at `at` in the part's frame (x right, y up,
	z back), measured on the StarterCharacter in Studio (captures C31). A worn bag hides the
	survivor's own small pack and pushes a back-slung weapon `depth` studs out.
]]
export type WornArt = {
	mount: "head" | "pack",
	size: number,
	at: Vector3,
	turn: Vector3?,
	depth: number?,
}

local FACE_AHEAD = Vector3.new(0, 180, 0)

Art.wornModels = {
	["item.steel_helmet"] = { mount = "head", size = 0.98, at = Vector3.new(0, 0.24, 0.03), turn = FACE_AHEAD },
	["item.combat_helmet"] = { mount = "head", size = 1.05, at = Vector3.new(0, 0.16, 0.04), turn = FACE_AHEAD },
	["item.gas_mask"] = { mount = "head", size = 1.08, at = Vector3.new(0, 0.02, -0.06), turn = FACE_AHEAD },
	["item.hidebound_cap"] = { mount = "head", size = 1, at = Vector3.new(0, 0.22, 0.02), turn = FACE_AHEAD },
	["item.riveted_helm"] = { mount = "head", size = 1.02, at = Vector3.new(0, 0.2, 0.03), turn = FACE_AHEAD },
	["item.hide_rucksack"] = { mount = "pack", size = 1.9, at = Vector3.new(0, 0.15, 1.25), depth = 0.9 },
	["item.ranger_pack"] = { mount = "pack", size = 1.85, at = Vector3.new(0, 0.1, 1.2), depth = 0.85 },
} :: { [string]: WornArt }

Art.items = {
	["item.stone_hatchet"] = { "EO_StoneHatchet", "Gen_axe" },
	["item.spiked_club"] = { "EO_SpikedClub" },
	["item.scrapblade"] = { "EO_Scrapblade" },
	["item.stone_pick"] = { "EO_StonePick" },
	-- The forged tools have no model of their own yet (art spend): they show their stone
	-- forms, the same silhouette as their icons, rather than a built stand-in.
	["item.forged_hatchet"] = { "EO_StoneHatchet" },
	["item.forged_pick"] = { "EO_StonePick" },
	["item.timber"] = { "Gen_firewood" },
	["item.satchel"] = { "Gen_backpack" },
	["item.pack_frame"] = { "Raw_Backpack", "Gen_backpack" },
	-- Fog Run weapons (slice 2B): realistic guns and the machete from the Zona sources
	-- (CREDITS.md), the fire axe and shortbow from the slice 2 family sheets.
	["item.pipe_pistol"] = { "EO_WornPistol" },
	["item.flare_pistol"] = { "EO_FlarePistol" },
	["item.scrap_shotgun"] = { "EO_ScrapShotgun" },
	["item.machete"] = { "EO_Machete" },
	["item.fire_axe"] = { "EO_FireAxe" },
	["item.shortbow"] = { "EO_Shortbow" },
	["item.duty_pistol"] = { "EO_DutyPistol" },
	["item.pump_shotgun"] = { "EO_PumpShotgun" },
	["item.hunting_rifle"] = { "EO_HuntingRifle" },
	["item.assault_rifle"] = { "EO_AssaultRifle" },
	["item.anti_materiel_rifle"] = { "EO_AntiMaterielRifle" },
	-- Launch content: the starter stake, the found Tire Iron and Rail Mallet (Zona meshes).
	["item.sharpened_stake"] = { "EO_SharpenedStake" },
	["item.tire_iron"] = { "EO_TireIron" },
	["item.rail_mallet"] = { "EO_RailMallet" },
	-- Content 2.0 (batch 4b): the icon is the model itself (ItemIcon renders it).
	["item.hand_axe"] = { "EO_HandAxe" },
	["item.hardwood_bat"] = { "EO_HardwoodBat" },
	["item.field_knife"] = { "EO_FieldKnife" },
	["item.hay_fork"] = { "EO_HayFork" },
	["item.hidebound_cap"] = { "EO_HideboundCap" },
	["item.hidebound_coat"] = { "EO_HideboundCoat" },
	["item.hidebound_leggings"] = { "EO_HideboundLeggings" },
	["item.hidebound_boots"] = { "EO_HideboundBoots" },
	["item.riveted_helm"] = { "EO_RivetedHelm" },
	["item.riveted_cuirass"] = { "EO_RivetedCuirass" },
	["item.riveted_legguards"] = { "EO_RivetedLegguards" },
	["item.riveted_boots"] = { "EO_RivetedBoots" },
	["item.steel_helmet"] = { "EO_SteelHelmet" },
	["item.combat_helmet"] = { "EO_CombatHelmet" },
	["item.plate_carrier"] = { "EO_PlateCarrier" },
	["item.gas_mask"] = { "EO_GasMask" },
	["item.hide_rucksack"] = { "EO_HideRucksack" },
	["item.ranger_pack"] = { "EO_RangerPack" },
	["item.trauma_pouch"] = { "EO_TraumaPouch" },
	["item.first_aid_kit"] = { "EO_FirstAidKit" },
	["item.ember_stim"] = { "EO_EmberStim" },
	["item.steel_plate"] = { "EO_SteelPlate" },
	["item.antiseptic"] = { "EO_AntisepticBottle" },
} :: { [string]: { string } }

-- Items whose model above is a stand-in for the hand: the inventory shows their painted
-- icon (ItemDef.icon), not a render of the stand-in.
Art.paintedIcon = {
	["item.forged_hatchet"] = true,
	["item.forged_pick"] = true,
} :: { [string]: boolean }

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
	-- Where the handle's centre line runs, off the bounding box's centre line, in studs in
	-- the model's own space at `length`: a head that juts to one side (an axe's blade, a
	-- pick's point) pulls the box off the handle. Measured in Studio by casting rays across
	-- the handle (2026-11-12, batch 1); with it the fist closes on the handle, not beside it.
	offset: Vector3?,
}

Art.held = {
	["item.stone_hatchet"] = {
		axis = Vector3.new(0.579, 0.715, -0.393),
		edge = Vector3.new(0, 0, -1),
		grip = 0.18,
		length = 1.7,
		holster = "belt",
		offset = Vector3.new(0.02, 0.024, 0.074),
	},
	["item.stone_pick"] = {
		axis = Vector3.new(0.336, 0.875, -0.347),
		edge = Vector3.new(0, 0, -1),
		grip = 0.16,
		length = 2.2,
		holster = "belt",
		offset = Vector3.new(-0.024, 0.1, 0.229),
	},
	["item.forged_hatchet"] = {
		axis = Vector3.new(0.579, 0.715, -0.393),
		edge = Vector3.new(0, 0, -1),
		grip = 0.18,
		length = 1.7,
		holster = "belt",
		offset = Vector3.new(0.02, 0.024, 0.074),
	},
	["item.forged_pick"] = {
		axis = Vector3.new(0.336, 0.875, -0.347),
		edge = Vector3.new(0, 0, -1),
		grip = 0.16,
		length = 2.2,
		holster = "belt",
		offset = Vector3.new(-0.024, 0.1, 0.229),
	},
	["item.spiked_club"] = {
		axis = Vector3.new(0.289, 0.696, 0.657),
		edge = Vector3.new(1, 0, 0),
		grip = 0.14,
		length = 2.3,
		holster = "back",
		offset = Vector3.new(-0.041, 0.029, -0.013),
	},
	["item.scrapblade"] = {
		axis = Vector3.new(0.087, 0.712, 0.697),
		edge = Vector3.new(0, -1, 1),
		grip = 0.12,
		length = 2,
		holster = "back",
		offset = Vector3.new(0.046, 0, -0.006),
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
	-- An orange signal pistol, a little longer than the service pistol (about 24 cm).
	["item.flare_pistol"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(0, -1, 0),
		grip = 0.2,
		length = 1.25,
		holster = "belt",
		drop = 0.3,
	},
	["item.scrap_shotgun"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(0, -1, 0),
		grip = 0.2,
		length = 2.4,
		holster = "back",
		drop = 0.22,
	},
	-- ARSENAL's first five. `grip` is the pistol grip (the stock's wrist on the Hunting
	-- Rifle), read from a side capture of each model; long guns ride on the back.
	["item.duty_pistol"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(0, -1, 0),
		grip = 0.23,
		length = 1.2,
		holster = "belt",
		drop = 0.2,
	},
	["item.pump_shotgun"] = {
		axis = Vector3.new(-1, 0, 0),
		edge = Vector3.new(0, -1, 0),
		grip = 0.3,
		length = 4,
		holster = "back",
		drop = 0.19,
	},
	["item.hunting_rifle"] = {
		axis = Vector3.new(-1, 0, 0),
		edge = Vector3.new(0, -1, 0),
		grip = 0.25,
		length = 4.3,
		holster = "back",
		drop = 0.05,
	},
	["item.assault_rifle"] = {
		axis = Vector3.new(-1, 0, 0),
		edge = Vector3.new(0, -1, 0),
		grip = 0.31,
		length = 3.5,
		holster = "back",
		drop = 0.08,
	},
	["item.anti_materiel_rifle"] = {
		axis = Vector3.new(-1, 0, 0),
		edge = Vector3.new(0, -1, 0),
		grip = 0.22,
		length = 4.7,
		holster = "back",
		drop = 0.27,
	},
	["item.machete"] = {
		axis = Vector3.new(0, 1, 0),
		edge = Vector3.new(0, 0, 1),
		grip = 0.12,
		length = 2.3,
		holster = "belt",
		offset = Vector3.new(0, 0, 0.026),
	},
	["item.fire_axe"] = {
		axis = Vector3.new(0.056, 0.276, -0.959),
		edge = Vector3.new(0, 1, 0),
		grip = 0.12,
		length = 2.9,
		holster = "back",
		offset = Vector3.new(-0.016, -0.156, -0.046),
	},
	-- The stake lies on a diagonal in its model (converted as drawn); the point is its thin
	-- end, toward -X -Y -Z, and the fist closes on the cord wrap (measured 2026-11-12: the old
	-- axis crossed the stick at about 80 degrees, so it sat across the fist).
	["item.sharpened_stake"] = {
		axis = Vector3.new(-0.658, -0.622, -0.425), -- butt (cord) to the charred point
		edge = Vector3.new(0.728, -0.686, 0),
		grip = 0.3,
		length = 3.4,
		holster = "back",
	},
	-- Found melee (Zona meshes, length along +Y, head at the top): the crowbar's hook bends
	-- toward +Z, the mallet's faces point along X.
	["item.tire_iron"] = {
		axis = Vector3.new(0, 1, 0),
		edge = Vector3.new(0, 0, 1),
		grip = 0.14,
		length = 2,
		holster = "belt",
		offset = Vector3.new(0, 0, 0.113),
	},
	["item.rail_mallet"] = {
		axis = Vector3.new(0, 1, 0),
		edge = Vector3.new(1, 0, 0),
		grip = 0.1,
		length = 3.4,
		holster = "back",
	},
	-- Content 2.0 melee (Studio mesh generator), measured 2026-11-12 (batch 4b) by casting
	-- rays across 12 slices of each conformed model: the hand axe's handle curves toward +Z
	-- at the butt, the knife lies on a diagonal in its model (point toward +Y +Z), the bat's
	-- knob is at +Z and the fork's tines spread along X (they lie flat in the fist).
	["item.hand_axe"] = {
		axis = Vector3.new(-0.025, 0.965, -0.26),
		edge = Vector3.new(1, 0, 0),
		grip = 0.18,
		length = 1.9,
		holster = "belt",
		offset = Vector3.new(0.039, 0, 0.069),
	},
	["item.hardwood_bat"] = {
		axis = Vector3.new(0, 0, -1),
		edge = Vector3.new(1, 0, 0),
		grip = 0.1,
		length = 2.8,
		holster = "back",
	},
	["item.field_knife"] = {
		axis = Vector3.new(0, 0.897, 0.442),
		edge = Vector3.new(0, 0.442, -0.897),
		grip = 0.2,
		length = 1.2,
		holster = "belt",
		offset = Vector3.new(0, 0, -0.095),
	},
	["item.hay_fork"] = {
		axis = Vector3.new(0, 1, 0),
		edge = Vector3.new(0, 0, 1),
		grip = 0.3,
		length = 4.2,
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
	-- Rifles and the .50 reuse the two licensed shots, pitched down (no new sound was added):
	-- a rifle is the pistol crack a fifth lower, the Anti-Materiel Rifle the 12 gauge slowed.
	rifleShot = snd(9117396996, 1.2, { region = { 0, 0.9 }, speed = 0.78 }),
	heavyShot = snd(9112912106, 1.35, { region = { 0, 1.1 }, speed = 0.7 }),
	flareLaunch = snd(9118591402, 1, { region = { 0, 1.4 } }), -- PSE "Rocket Flare Out 1"
	reload = snd(9113104516, 1, { region = { 0, 1.4 } }), -- PSE magazine clip, "Magazine 4" (the reload beat)
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
		caravan = "rbxassetid://107928089189056",
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
		caravan = 362 / 512,
		cliff = 174 / 256,
		trees1 = 213 / 256,
		trees2 = 204 / 256,
		trees3 = 279 / 256,
		trees4 = 279 / 256,
		fog = 1,
	} :: { [string]: number },
	-- Each location's panel and loading-screen art: its corner of the painted map
	-- (art/higgsfield/m1-slice2/ui/locations, cropped round the pin). The Stranded
	-- Caravan, not on the painting, has its own painted piece in the same style.
	art = {
		["loc.pine_hollow"] = "rbxassetid://80424846897012",
		["loc.sunken_quarry"] = "rbxassetid://78393149598495",
		["loc.ashfall_depot"] = "rbxassetid://114701602305172",
		["loc.stranded_caravan"] = "rbxassetid://137407895553916",
		-- The resource zones: corners of the same painting until their maps are rendered.
		["loc.bracken_edge"] = "rbxassetid://96114023676635",
		["loc.ironbark_stand"] = "rbxassetid://89748983476178",
		["loc.gloaming_deep"] = "rbxassetid://96078812443149",
		["loc.rockfall_slope"] = "rbxassetid://103015990609868",
		["loc.greenvein_bluffs"] = "rbxassetid://140391888762231",
		["loc.deepcut_pit"] = "rbxassetid://120630890068398",
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

-- Wildlife rigs (LDOE_PARITY #35): the deer and the wolf carry no clips. Controllers/Gait
-- drives their joints from how fast they move. Each leg lists its joints from the body
-- down, how far each one swings with the stride (`swing`) and folds while the foot is in
-- the air (`fold`), in radians per unit of stride, and where the leg sits in the walk and
-- the run (a share of the cycle). Rest axes: X across the body, Y up, -Z forward.
-- Rigs: our own (post-launch: a family sheet, a generated mesh, segmented and jointed with
-- these joint names). No free models; until then the deer and wolf don't spawn.
export type WildlifeLeg = {
	joints: { string },
	swing: { number },
	fold: { number },
	walk: number,
	run: number,
}
export type WildlifeRig = {
	root: string, -- the body's joint to the root: bob, lunge, flinch, fall
	spine: string?, -- flexes on the run
	legs: { WildlifeLeg },
	neck: { string },
	jaw: string?,
	ears: { string }?,
	tail: { string }?,
	stride: number, -- studs per cycle at a walk
	grazes: boolean, -- drops its head to feed when idle
}

local ELK_FRONT_SWING = { 1, 0.2, 0, 0 }
local ELK_FRONT_FOLD = { 0, 0.35, -1.2, -0.6 }
local ELK_HIND_SWING = { 1, 0, 0, 0 }
local ELK_HIND_FOLD = { 0.2, 0.7, -1.1, 0.5 }
local WOLF_FRONT_SWING = { 0.45, 0.6, 0, 0, 0 }
local WOLF_FRONT_FOLD = { 0, 0.25, 0.2, -1.1, -0.6 }
local WOLF_HIND_SWING = { 1, 0, 0, 0 }
local WOLF_HIND_FOLD = { 0.2, 0.8, -1.1, 0.5 }

Art.wildlifeRigs = {
	["enemy.deer"] = {
		root = "Shoulders",
		spine = "Hips",
		legs = {
			{
				joints = { "LThigh", "LCalf", "LAnkle", "LFoot" },
				swing = ELK_HIND_SWING,
				fold = ELK_HIND_FOLD,
				walk = 0,
				run = 0,
			},
			{
				joints = { "LArm1", "LArm2", "LArm3", "LWrist" },
				swing = ELK_FRONT_SWING,
				fold = ELK_FRONT_FOLD,
				walk = 0.25,
				run = 0.55,
			},
			{
				joints = { "RThigh", "RCalf", "RAnkle", "RFoot" },
				swing = ELK_HIND_SWING,
				fold = ELK_HIND_FOLD,
				walk = 0.5,
				run = 0.1,
			},
			{
				joints = { "RArm1", "RArm2", "RArm3", "RWrist" },
				swing = ELK_FRONT_SWING,
				fold = ELK_FRONT_FOLD,
				walk = 0.75,
				run = 0.65,
			},
		},
		neck = { "Neck1", "Neck2", "Neck3", "FakeHead" },
		jaw = "Jaw",
		ears = { "LEar", "REar" },
		stride = 3.6,
		grazes = true,
	},
	["enemy.wolf"] = {
		root = "Chest",
		spine = "Waist",
		legs = {
			{
				joints = { "ThighL", "CalfL", "FootL", "PawHL" },
				swing = WOLF_HIND_SWING,
				fold = WOLF_HIND_FOLD,
				walk = 0,
				run = 0,
			},
			{
				joints = { "ShoulderL", "UpperarmL", "ForearmL", "WristL", "PawFL" },
				swing = WOLF_FRONT_SWING,
				fold = WOLF_FRONT_FOLD,
				walk = 0.25,
				run = 0.55,
			},
			{
				joints = { "ThighR", "CalfR", "FootR", "PawHR" },
				swing = WOLF_HIND_SWING,
				fold = WOLF_HIND_FOLD,
				walk = 0.5,
				run = 0.1,
			},
			{
				joints = { "ShoulderR", "UpperarmR", "ForearmR", "WristR", "PawFR" },
				swing = WOLF_FRONT_SWING,
				fold = WOLF_FRONT_FOLD,
				walk = 0.75,
				run = 0.65,
			},
		},
		neck = { "Neck1", "Neck2", "Neck3", "RealHead" },
		jaw = "Jaw",
		tail = { "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6" },
		stride = 2.8,
		grazes = false,
	},
} :: { [string]: WildlifeRig }

-- The soft amber mark on the ground at an exit a survivor stands near (checklist 12.10:
-- no bright circles; art/ui/fogmap/exit_ground_glow.png, made by a script, not generated).
Art.exitGroundGlow = "rbxassetid://132317298258032"

-- The HUD meters' glyph names.
Art.meterGlyphs = {
	health = "health",
	hunger = "hunger",
	thirst = "thirst",
	energy = "energy",
	xp = "xp",
} :: { [string]: string }

return Art
