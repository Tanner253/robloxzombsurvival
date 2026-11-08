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
	["build.workbench"] = { "Workbench" },
	["build.campfire"] = { "EO_Campfire", "Campfire" }, -- stone ring and teepee (Studio mesh generator)
	["build.recycler"] = { "EO_RecyclerStation", "Recycler" },
	["build.crate_wood"] = { "EO_StorageCrate", "Crate" },
	["build.crate_banded"] = { "CrateBanded", "Crate" },
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
	EO_RockCluster = Color3.fromRGB(168, 150, 128), -- warm brown-grey, darker (concept palette)
} :: { [string]: Color3 }

-- Resource nodes -> kit names and the height (studs) the model is scaled to.
Art.dropModels = { "EO_SupplySacksMesh", "EO_SupplySacks", "Gen_backpack", "EO_Satchel" }

Art.nodes = {
	["node.pine_tree"] = { names = { "EO_PineTree", "Gen_tree" }, height = 22 },
	["node.boulder"] = { names = { "EO_RockCluster", "EO_Boulder" }, height = 3.1 },
	["node.loose_stones"] = { names = { "EO_LooseStones", "Gen_pebbles" }, height = 1.8 },
	["node.fallen_branches"] = { names = { "EO_BareBranches", "EO_FallenBranches" }, height = 0.94 },
	["node.reed_patch"] = { names = { "EO_Reeds" }, height = 4.2 },
	["node.ember_bush"] = { names = { "EO_EmberBush" }, height = 4 },
	["node.spring_pool"] = { names = { "SpringPool" }, height = 1 },
	["node.fatwood_stump"] = { names = { "EO_FatwoodStump" }, height = 3 },
	["node.scrap_heap"] = { names = { "EO_ScrapHeap" }, height = 3.8 },
	["node.ashroot_mound"] = { names = { "AshrootMound" }, height = 1.6 },
} :: { [string]: { names: { string }, height: number } }

-- What a depleted node leaves behind until it regrows (LDoE leaves stumps and rubble):
-- a kit model scaled to `height`. Small pickups (branches, loose stones) leave nothing.
Art.remnants = {
	["node.pine_tree"] = { names = { "EO_FatwoodStump" }, height = 2.3 },
	["node.fatwood_stump"] = { names = { "EO_FatwoodStump" }, height = 0.55 },
	["node.boulder"] = { names = { "EO_LooseStones" }, height = 1.1 },
	["node.scrap_heap"] = { names = { "EO_ScrapHeap" }, height = 0.9 },
	-- Reeds and bushes leave nothing until their family models pass the lineup gate
	-- (ART_DIRECTION 10a): squashing the standing model made a mud blob.
	["node.reed_patch"] = { names = { "EO_ReedStubble" }, height = 0.9 },
	["node.ember_bush"] = { names = { "EO_BareBranches" }, height = 0.8 },
	["node.ashroot_mound"] = { names = { "EO_LooseStones" }, height = 0.5 },
} :: { [string]: { names: { string }, height: number } }

-- Quality gate (PLAYER_EXPERIENCE_CHECKLIST §0): only kit models graded A may appear.
-- Everything else (fallback builds, look-test and generated stand-ins, models with
-- defects) stays out of the world, and the feature that needs it is hidden until its
-- model is graded A and added here. Grades: docs/briefs/m1-slice1-audit.md.
-- (Loose stones and reeds wait on re-uploads: art/tools/glb_floaters.py found a
-- floating stone and detached blade fragments in their meshes; the fixed GLBs pass.)
Art.approved = {
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
	-- EO_RockCluster: C (orchestrator: light-grey popcorn lumps); gated until a re-conversion.
	-- Batch 2 (captures 105-107):
	EO_StorageCrate = true,
	EO_RecyclerStation = true,
	EO_BarrelCluster = true,
	EO_SupplySacksMesh = true,
	EO_DeadTree = true,
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
} :: { [string]: SoundSpec }

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
Art.meterGlyphs = {
	health = "❤",
	hunger = "🍖",
	thirst = "💧",
	energy = "⚡",
	xp = "★",
} :: { [string]: string }

return Art
