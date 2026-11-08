# Base Building Teardown: Last Day on Earth: Survival (primary) and Zombix Online (secondary)

Research date: 2026-11-07. LDoE is a live game. The current build is **1.53.x "Cult Hunting"**, released 27 Oct 2026 per the [fan wiki](https://lastdayonearthsurvival.fandom.com/wiki/Version/1.53.0); the [App Store listing](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) shows 1.53.2. Several building rules changed this year, in 1.50.0 (July 2026) and 1.53.0 (Oct 2026). Older guides predate those changes, so treat them with caution.

**How this was researched (and its limits).** The main source is the community Fandom wiki, read through its MediaWiki API. I logged each page's last-edit date, and most pages were touched in Oct 2026. An edit date alone does not prove every number on the page is current, so wiki numbers should be checked in-game. A second source is a community base-planner tool ([ovgamesdev/ldoe-base-planner](https://github.com/ovgamesdev/ldoe-base-planner)), whose `catalog.json` encodes the build-menu categories, footprints, floor requirements and placement caps for 236 placeables. That data was made by players, not Kefir. For Zombix I used the Russian and English fan wikis plus store pages.

**What I could not reach.** The shared web-search budget ran out partway through. Reddit blocked automated access. YouTube pages did not render, so I have no list of video guides with view counts. Google Play pages came back truncated. Player sentiment below therefore comes from App Store reviews and wiki commentary only.

---

## 1. LDoE: the Home plot

| Property | Value | Source / note |
|---|---|---|
| Grid | 20 x 18 tiles. 340 are buildable. The Old Pickup Truck blocks a 5x4 area (20 tiles). | [Home](https://lastdayonearthsurvival.fandom.com/wiki/Home). The page also says "396 total tiles", which does not match 20x18 = 360. Likely an editing error. |
| Current width (community model) | 24 x 18. The original width was 20, and columns 20-23 were added by the expansion. | Planner [`constants.ts`](https://github.com/ovgamesdev/ldoe-base-planner) (`MAIN_BASE_WIDTH = 24`, `LEGACY_MAIN_BASE_WIDTH = 20`) |
| Debris | Debris blocks are 2x2 and must be cleared before you can build there. Players who started before 1.50.0 have 9 blocks (36 tiles). New players have 66 blocks (264 tiles). 1.53.0 added 18 more blocks on the NE edge. | [Home](https://lastdayonearthsurvival.fandom.com/wiki/Home), [1.53.0](https://lastdayonearthsurvival.fandom.com/wiki/Version/1.53.0) |
| Expansion currency | Clearing debris consumes a **Site Plan**. Site Plans are bought for 100 Infected Genome in the Genesis Collection, the endgame boss-currency shop (shop limit 212). | [Site Plan](https://lastdayonearthsurvival.fandom.com/wiki/Site_Plan), [Genesis Collection](https://lastdayonearthsurvival.fandom.com/wiki/Genesis_Collection) |
| Multiple storeys | I found no documentation of stairs or a second storey at Home, and the planner models one 2D layer. An undated wiki note (it refers to "beta version"; the 2018 date is unverified) says roofs exist but "can't be upgraded and can't be destroyed". | [Category:Base Builder](https://lastdayonearthsurvival.fandom.com/wiki/Category:Base_Builder) |
| Starting state | Since v1.9.4, new players spawn into a partly built base: some L2 and L3 walls, 9 L2 floors, 6 L3 floors, an unfinished CB Radio and an unfinished Chopper. Starting resource nodes do not respawn. | [Home](https://lastdayonearthsurvival.fandom.com/wiki/Home), [Beginner's Guide](https://lastdayonearthsurvival.fandom.com/wiki/Beginner%27s_Guide) |
| Second base | The **Settlement** unlocks in Act 2 (v1.19.4, Aug 2022). It is a separate 23x18 grid (planner value) with themed rooms (Storehouse, Woodshop, Foundry, Assembly, Workshop), each limited to one, plus power and water networks. The wiki calls it a "safe" storage location. | [Settlement](https://lastdayonearthsurvival.fandom.com/wiki/Settlement), [Home](https://lastdayonearthsurvival.fandom.com/wiki/Home) |

Inference: the playable base is small, and the big vehicle and pet items eat a lot of it: Garage 3x4, ATV Garage 4x4, Dog Crate 3x4, ATV 3x3, Motorboat 2x4. Since July 2026, extra space has been gated behind an endgame currency: Infected Genome, which the wiki lists as coming from bosses, seasons, events and cats, with no direct cash purchase. Whether Site Plans can also be bought for real money (for example in the 1.53 "Landscape Maintenance Pack") is unverified. Space scarcity is a deliberate pressure on the player.

## 2. LDoE: build mode UI and controls (mobile)

- **Entering build mode.** At Home you tap the crossed hammer-and-saw icon on the right of the screen. The camera zooms out a little and the menu shows two tabs. **Build** holds floors, walls, doors and windows, which you build, upgrade or destroy there. **Furniture** holds everything else, which you place from or pick up into your inventory, then move and rotate ([Category:Base Builder](https://lastdayonearthsurvival.fandom.com/wiki/Category:Base_Builder)).
- **Furniture sub-categories.** Wiki placement codes and the planner catalog agree on these:
  - Workbenches: Basic, Advanced, Technologic, Storage, Extractors
  - Furniture: Practical, Comfort, Garden, Protective, Wall-mounted
  - Special: Unique, Transport
  - Decorations: Season rewards, Wall rewards, Plants
- **Snapping.** Everything snaps to a tile grid. Walls, doors and windows sit on the **edges between floor tiles** (thin walls), not inside tiles; the planner's wall layer is keyed by edge. A wall can only be built next to a floor, and **a wall can only be upgraded to a tier its adjacent floor already has** ([Wall](https://lastdayonearthsurvival.fandom.com/wiki/Wall), [General Tips/FAQ](https://lastdayonearthsurvival.fandom.com/wiki/General_Tips/FAQ)).
- **Rotation.** Each item has a fixed number of orientations: 1, 2 or 4. Examples: Spike Trap has 4 positions, Rain Catcher 2 (wiki; the planner allows only 1), Garden Bed 1, Buzzsaw 1.
- **Upgrading.** You upgrade a piece in place and pay only for that step, not again for earlier tiers ([Building (Home)](https://lastdayonearthsurvival.fandom.com/wiki/Building_(Home))).
- **Moving and deleting** went through three stages:
  - **Before v1.11.1:** floors and walls could not be moved. They could only be deleted, with no refund ([FAQ](https://lastdayonearthsurvival.fandom.com/wiki/General_Tips/FAQ); the FAQ line is undated and still says this).
  - **v1.11.1 (18 Dec 2018):** destroying your own walls in build mode returns part of the resources ([Version](https://lastdayonearthsurvival.fandom.com/wiki/Version)).
  - **1.53.0 (Oct 2026):** placed floors, walls, doors and windows can be returned to your inventory, and a workbench **"Fill" button** pulls recipe inputs from base storage ([1.53.0](https://lastdayonearthsurvival.fandom.com/wiki/Version/1.53.0)).
  - Furniture could always be moved and picked up, but a container with items in it cannot be picked up ([Small Box](https://lastdayonearthsurvival.fandom.com/wiki/Small_Box)).
- **Material logistics.** The **Warehouse** (2x1; shop item and season reward; 20 slots x 300) feeds construction automatically, so you no longer carry building materials in your pockets ([Warehouse](https://lastdayonearthsurvival.fandom.com/wiki/Warehouse)).

Inference: it took about nine years (until 1.53) for "pick the wall back up" to ship. Clunky editing is the most obvious historical pain point. One App Store reviewer asks directly for a way to delete things they have built ([App Store](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)).

## 3. LDoE: structural pieces and tiers

Pieces: **Floor, Wall, Door, Window.** Windows cost the same as walls; doors cost a little more. Enemies can damage the player through a window ([Window](https://lastdayonearthsurvival.fandom.com/wiki/Window)). There are no wall frames, gates, ramps or foundations as separate pieces; the floor *is* the foundation.

**Tier names differ by source. Verify them in-game.**

| Lvl | Per-piece wiki pages (Wall/Floor/Door) | "Building (Home)" page (2024) | Signal Scanning table (Oct 2026) |
|---|---|---|---|
| 1 | Wall / Floor | Wooden | Simple |
| 2 | Plank | Boarded | Wood |
| 3 | Stone | Stone | Stone |
| 4 | Metal | Iron | Iron |
| 5 | Brick (added v1.18.4, Aug 2021) | Reinforced | Reinforced |

### Per-step upgrade costs

These come from [Wall](https://lastdayonearthsurvival.fandom.com/wiki/Wall), [Floor](https://lastdayonearthsurvival.fandom.com/wiki/Floor), [Door](https://lastdayonearthsurvival.fandom.com/wiki/Door) and [Window](https://lastdayonearthsurvival.fandom.com/wiki/Window), all edited Oct 2026.

| Lvl | Floor | Wall | Window | Door |
|---|---|---|---|---|
| 1 | 1 Pine Log | 1 Pine Log | 1 Pine Log | 1 Pine Log |
| 2 | 5 Stone Brick + 5 Pine Plank | 5 Stone Brick + 10 Pine Plank | same as wall | 10 Stone Brick + 20 Pine Plank |
| 3 | 15 Stone Brick + 10 Iron Plate | 15 Stone Brick + 10 Oak Plank | same as wall | 20 Stone Brick + 20 Oak Plank |
| 4 | 15 Steel Plate + 20 Iron Plate | 20 Steel Plate + 15 Aluminium Plate | same as wall | 25 Steel Plate + 20 Aluminium Plate |
| 5 | 20 Ash Plank + 10 Titanium Bar | 20 Brick + 10 Steel Plate | 20 Brick + 15 Steel Plate | 15 Brick + 30 Steel Plate |

Caveat: the older [Base building](https://lastdayonearthsurvival.fandom.com/wiki/Base_building) page lists different numbers. For example, an L2 wall there costs 10 Limestone + 20 Common Plank, and an L3 wall costs 20 Stone Brick. Costs have been rebalanced over the years.

### Durability and Base Power (from the 1.53 [Signal Scanning](https://lastdayonearthsurvival.fandom.com/wiki/Signal_Scanning) page)

| Wall type | Health | Base Power |
|---|---|---|
| Simple (L1) | 50 | +5 |
| Wood (L2) | 100 | +10 |
| Stone (L3) | 150 | +15 |
| Iron (L4) | 200 | +20 |
| Reinforced (L5) | 300 | +30 |

The same page lists each enemy's "construction damage": Rotting Spawn 5 or 10, Bloater 20, Behemoth 40, **Exploder 160**. This is the first time the wiki documents numeric HP for structures. Player raids and the daily Horde work differently, as described in section 6.

### Cost scale

A 194-floor / 235-wall / 28-door beginner design needs roughly the following ([Base Design for Beginners](https://lastdayonearthsurvival.fandom.com/wiki/Base_Design_for_Beginners); this page uses older per-piece costs):

| Full house at | Materials |
|---|---|
| L2 | about 6,370 Pine Planks and 3,740 Limestone |
| L3 | about 8,310 Stone Bricks, 3,805 Oak Planks and 1,940 Iron Bars |
| L4 | about 8,310 Steel Plates, 4,085 Aluminium Plates and 3,880 Iron Plates |

The [Honeycomb](https://lastdayonearthsurvival.fandom.com/wiki/Honeycomb_Base_Design) page prices a single 1x1 room as follows:

| 1x1 room at | Materials |
|---|---|
| L1 | 5 logs |
| L3 | 95 Stone Brick, 40 Oak Plank and 10 Iron Bar |
| L5 | 80 Brick, 60 Steel Plate, 20 Ash Plank and 10 Titanium Bar |

The shop has sold a **"Brick Room 3X3"** pack containing every material for a reinforced room, including 235 Bricks and 575 Steel Plates ([Brick Room 3X3](https://lastdayonearthsurvival.fandom.com/wiki/Brick_Room_3X3)).

## 4. LDoE: tier progression (when each tier becomes reachable)

| Tier | Gating materials | What gates them |
|---|---|---|
| L1 | Pine logs | Day 1. Hatchet costs 3 logs + 3 limestone ([Hatchet](https://lastdayonearthsurvival.fandom.com/wiki/Hatchet)). |
| L2 | Pine Plank + Stone Brick | Woodworking Bench (quest "Preparation"; planks unlock at level 2), Stonecutter's Table (level 14) |
| L3 | Oak Plank (walls); Iron Plate (floors) | Oak Plank needs an Iron Hatchet (level 14) and oak from the northern zones. Iron Plate needs the Workbench (level 28). L3 is the **Horde-proof** tier. |
| L4 | Steel Plate + Aluminium Plate | Steel Bar sources are late content: Bunker Bravo, Police Department crates, Genesis Collection ([Steel Plate](https://lastdayonearthsurvival.fandom.com/wiki/Steel_Plate)) |
| L5 | Brick, Ash Plank, Titanium Bar | Brick comes from the Refined Melting Furnace (blueprint from Survivor's Path Act 5 "Northern Region"). Each 90-minute craft makes 2 bricks from cement, sand, peat and limestone ([Brick](https://lastdayonearthsurvival.fandom.com/wiki/Brick)). |
| Raiding | n/a | Unlocks at **player level 150** (since v1.17.2) |

Floor tier also gates which furniture you may place (planner catalog plus wiki infoboxes). This makes upgrading floors a progression lock and not just cosmetic.

| Floor tier | Examples of what it unlocks |
|---|---|
| Ground / any | Spike Trap, Barbed Wire, Garden Bed (2x2), Rain Catcher, Campfire, Extractors |
| L1+ | Small Box, Melting Furnace, Doormat (any surface) |
| L2+ | Chest, Workbench, Woodworking Bench, Stonecutter, Recycler, CB Radio, Gunsmith Bench, Chopper (the planner puts Woodworking Bench and Stonecutter at L2, but their wiki pages say L1 wood floor; check in-game) |
| L3+ | Trunk, Rack, Fridge, Kitchen Stove, Buzzsaw, Repair Workbench, ATV, Motorboat |
| L4+ | Pressing Machine, Chemistry Station, Hydroponic System |
| L3 **walls** | Wall-mounted decor (Trophy Board, boss trophies) |

## 5. LDoE: stations, storage, farming, decor, caps

- **Caps per item type.** Most workbenches are limited to 2. Storage boxes are limited to 40 (Small Box, Chest, Trunk and Rack share one storage group in the planner). Spike Traps are limited to 80, Barbed Wire to 20, Trip Wire to 1, Garden Beds to 2, Doormat to 1, CB Radio to 1 (planner catalog; [Workbench](https://lastdayonearthsurvival.fandom.com/wiki/Workbench), [Spike Trap](https://lastdayonearthsurvival.fandom.com/wiki/Spike_Trap)).
- **Storage ladder.** Each step is an in-place upgrade of the previous box.

  | Container | Slots | Needs floor |
  |---|---|---|
  | Small Box | 15 | L1 |
  | Chest | 25 | L2 |
  | Trunk | 45 (35 before v1.11.6) | L3 |
  | Rack | 75 | L3 |

  Rack slot capacity goes from 20 up to 70 over 11 upgrade levels, for 5,250 items total ([Rack](https://lastdayonearthsurvival.fandom.com/wiki/Rack)). Chests can be repainted with paint items for colour-coding.
- **Specialised storage cannot be raided.** This applies to the Warehouse, Ore Storage, Fridge, Medicine Cabinet, "Another Round" and similar. Several are shop items ([Warehouse](https://lastdayonearthsurvival.fandom.com/wiki/Warehouse), [Ore Storage](https://lastdayonearthsurvival.fandom.com/wiki/Ore_Storage)). There was also a 5-slot **Safe**, sold only in a shop pack and removed in 1.30.1 ([Safe](https://lastdayonearthsurvival.fandom.com/wiki/Safe)).
- **Farming.**
  - Garden Bed: 2x2, ground only, max 2. One seed gives 2 carrots in 1 hour ([Garden Bed](https://lastdayonearthsurvival.fandom.com/wiki/Garden_Bed)).
  - Greenhouse upgrade added in 1.53.
  - Other food buildings: Hydroponic System (L4 floor), Turkey Coop, Caiman Farm, Boar Farm (1.53).
  - Rain Catcher for water.
- **Utility.** The **Doormat** sets your respawn and entry point (max 1). Players wall it in to make a safe spawn room ([Doormat](https://lastdayonearthsurvival.fandom.com/wiki/Doormat)).
- **Decor.** A large share of placeables are cosmetic season, event and boss trophies. The planner lists 56 season-reward items and 15 wall-mounted rewards.

## 6. LDoE: damage, raids, and defence

### What damages structures

- **The Horde.** It arrives about every 24 hours and walks across the plot. Crowd zombies break L1 and L2 walls, doors, windows and traps. They **cannot break L3+** walls and die against them. They never damage floors, stations or crates. Offline damage is reduced ([The Horde](https://lastdayonearthsurvival.fandom.com/wiki/The_Horde), [Crowd Zombie](https://lastdayonearthsurvival.fandom.com/wiki/Crowd_Zombie)). Burning a Witch's Head pauses hordes for 3 days. One App Store reviewer sums it up: "when the zombies attack your base, they only break walls, doors and traps."
- **Signal Scanning (1.53, Halloween event).** You use the CB Radio to call scripted waves of 25-93 enemies from the cardinal directions, lasting 1 to 3 minutes. Recommended Base Power runs from 165 to 750. Free event defences arrive daily:

  | Defence | Base Power | HP | Damage | Limit |
  |---|---|---|---|---|
  | Thorns | 5 | 50 | 15 | 10 |
  | Friend (turret) | 15 | 50 | — | 10 |
  | Slicer | 15 | 75 | — | 10 |

  **Destroyed structures are restored afterwards.** You get 3 attempts per day, with 100 coins to refresh, and mortar air support costs 100 coins ([Signal Scanning](https://lastdayonearthsurvival.fandom.com/wiki/Signal_Scanning)). Damage values for Friend and Slicer differ between their own item pages and the Signal Scanning page.

### Player raids (Raiding System)

Sources: [Raiding System](https://lastdayonearthsurvival.fandom.com/wiki/Raiding_System), [C-4](https://lastdayonearthsurvival.fandom.com/wiki/C-4_Explosive), [Iron Hatchet](https://lastdayonearthsurvival.fandom.com/wiki/Iron_Hatchet), [Metal Cutter](https://lastdayonearthsurvival.fandom.com/wiki/Metal_Cutter).

1. **Getting a target.** At level 150 you call the Raiders on the CB Radio. They give you 5 tasks drawn from a pool (bunker floors, bosses, crafting 5 Iron Hatchets, and so on); each task can be skipped for 45-125 coins. When the tasks are done you get **one target, valid for 8 hours**. Accepting the offer also opens your own base to attack.
2. **Breaching is lock-and-key, not HP.**

   | Wall/door/window level | Breach tool | Tool cost per piece |
   |---|---|---|
   | L1 | Hatchet | 1 Hatchet |
   | L2 | Iron Hatchet | 1 Iron Hatchet (6 hits; it also breaks 2 L1 pieces) |
   | L3 | C-4 | 1 C-4. It unlocks at player level 100 and costs 20 Steel Bar, 15 Spring, 20 Hi-Tech Components, 18 Explosive Material, 10 Plastic, 25 Wiring. Also sold in shop packs. |
   | L4 | Metal Cutter | The wiki says L4 "cannot be damaged until the Metal Cutter is added". The Metal Cutter finally shipped in 1.53, but only as an event tool for **cultist camps**. |
   | L5 | none | "Cannot currently be damaged." |

3. **Noise meter (the raid's soft timer).** Breaking walls, chests and benches, firing unsilenced guns, and leaving and re-entering all add noise:

   | Action | Noise |
   |---|---|
   | L1 wall | +2-3 |
   | L2 wall | +10-11 |
   | C-4 on L3 | +15-16 |
   | Breaking a chest | +8-9 |
   | Leaving and re-entering | +16 |

   Zombie waves spawn at about 24, 46 and 72 noise. At 100 **The Big One** appears: 1,000 HP and 300 armour, with damage that escalates each hit. You can scout a base only once, and you cannot leave and return for a second load.
4. **Raiders' cut.** You must share loot. If you short them, their SWAT trio raids you 2 hours later. They cannot damage L4/L5 walls and can blow up at most 4 stone walls.
5. **Getting raided back.** After you raid, a **Threat of Attack** timer runs, which coins can clear (about 5.75 minutes per coin). One wiki editor reports being raided at most once a day; that page's screenshots date from April 2018, so this may be outdated. Revenge raids follow footprints on the map for up to 8 hours ([Threat Of Attack](https://lastdayonearthsurvival.fandom.com/wiki/Threat_Of_Attack); the 8-hour footprint rule is on [Raiding System](https://lastdayonearthsurvival.fandom.com/wiki/Raiding_System)).
6. **Who is on the other side?** Kefir's patch notes describe attacking "other survivors' bases". The fan wiki states flatly that, outside the Crater, you only raid AI bases and are only raided by AI ([Raiding System](https://lastdayonearthsurvival.fandom.com/wiki/Raiding_System), [NPC Survivor Base](https://lastdayonearthsurvival.fandom.com/wiki/NPC_Survivor_Base)). Either way, **there is never a live defender.**

Inference: L4/L5 walls are unbreachable, raiding unlocks only at level 150, each target needs a 5-task quest chain, and attacks come at most about once a day with no live defender. Together these fully explain the developer's complaint that "nobody comes to raid you". **The endgame base is literally invulnerable.**

### Defences and traps

| Defence | Stats / rules | Verdict in sources |
|---|---|---|
| Spike Trap | 10 dmg per hit. Level 18; 10 Pine Log, 5 Rope, 5 Scrap. Max 80, ground only. | Guards against the Horde. The game itself hints they are weak against raiders. Players use them to suicide-reset hunger and thirst. |
| Barbed Wire | 10 dmg + 10 per second on contact. Level 32. Max 20. | More durable than spikes |
| Bear Trap | Stuns. Unlimited placement. | Minor |
| Trip Wire Trap | Noise only. Max 1. | The wiki calls it useless ([Trip Wire](https://lastdayonearthsurvival.fandom.com/wiki/Trip_Wire_Trap)) |
| Turret (furniture) | 140° arc, runs on gasoline (about 4 hours per can). Max 4. Did not shoot zombies. | **Removed in 1.51.1** and converted into a deployable Portable Turret ([Turret (Furniture)](https://lastdayonearthsurvival.fandom.com/wiki/Turret_(Furniture))) |
| Land Mine | 400 dmg, deployable | Mostly a weapon. Can kill raid TBO since 1.51. |

### Layout meta

Video guides could not be reached, so these come from the wiki.

- **Honeycomb.** Many 1x1 cells, each holding one chest or bench. Each breach reveals very little loot, so raiders burn noise faster ([Honeycomb](https://lastdayonearthsurvival.fandom.com/wiki/Honeycomb_Base_Design)).
- **Layers.** The wiki advises at least 1 layer of L2 plus 2 layers of L3 walls before you start raiding. It also says to skip L1/L2 early and go straight to L3 because of the Horde ([Home](https://lastdayonearthsurvival.fandom.com/wiki/Home)).
- **Spike corridors and spike rings** for the Horde. One beginner layout uses 62 spikes.
- **Walled doormat spawn room.**
- **Bait box** left outside the walls so AI raiders leave footprints you can revenge-raid.
- **Planning tools.** The fan-made [LDOE Base Planner](https://ovgamesdev.github.io/ldoe-base-planner/) (Russian/English) supports line, rectangle and outline wall placement plus shared layouts. Its existence suggests players want to plan off-device.
- **The "wall trick".** Melee enemies stall against a thin wall, letting you strike between their attacks. It is a well-known exploit that Kefir has framed as lore-consistent ([Wall trick](https://lastdayonearthsurvival.fandom.com/wiki/Wall_trick); video "Last Day on Earth: Wall Trick 101" by NOLIMITS STUDIO, view count not retrievable).

## 7. LDoE: what players praise and complain about (limited sample)

- **Praise.** The App Store rating is 4.6 from 104K ratings. Reviewers describe the core loop as engaging; one likes the energy system "although it is a little p2w".
- **Complaints:**
  - Cannot delete or undo built objects (App Store review).
  - Placement and editing was rigid for years (walls could not be moved, then only partly refunded).
  - Defences are weak or useless (Trip Wire, spikes against raiders), and the turret was removed.
  - Raiding is gated, rare and asynchronous.
  - Large footprints crowd a small plot.
  - Protected storage (Warehouse, the old Safe), material packs, raid-timer resets and event refreshes are all tied to money (shop items or coins). Space is gated behind Site Plans, bought with the earned endgame currency Infected Genome; a direct cash route for space is unverified.
- **Wiki tips imply friction.** One tip tells you to build floors only where furniture needs them because floors "cost too much". Another notes windows cost 50% more than walls on the older price list ([Category:Base Builder](https://lastdayonearthsurvival.fandom.com/wiki/Category:Base_Builder)).

---

## 8. Zombix Online: housing, territory, and clan bases

**Context.** Zombix Online is a pixel-art top-down MMO. Its RuStore listing is under Berzerk Games, while the Google Play package ID is `com.ZombixDev.ZombixOnline`. On RuStore it rates 4.0 from 74 ratings (the page's structured data says 3.9), with up to 100k downloads; version 5.01 shipped 28 Oct 2026. The official Discord has 7,458 members ([RuStore](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline), [Discord](https://discord.com/servers/zombix-online-official-720251932710666261)). Fan-wiki pages were last edited between 2021 and 2025, so treat the numbers as possibly outdated.

### Three layers of "base"

1. **Personal Base (Личная База).** A peaceful private instance that only you can enter. You place **storage** (8 slots, expandable; max 10 per base; costs 100 rusty metal + 50 metal + 25 duct tape, or 3 gems), **garden beds** (25 wood; carrot, grape, pepper), statues, and a **workbench** (150 wood, 100 metal, 20 gold; it upgrades gear with spheres). Placement is menu-driven: you use the item from your inventory, choose "apply", pick an empty cell, then "select" ([RU wiki main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики), [Хранилище (Storage)](https://zombix-online.fandom.com/ru/wiki/Хранилище), [Грядка (Garden Bed)](https://zombix-online.fandom.com/ru/wiki/Грядка), [Верстак (Workbench)](https://zombix-online.fandom.com/ru/wiki/Верстак)). It cannot be raided.
2. **Survivors' Bases (Базы выживших).** A PvP map holding pre-built bases guarded by bots. **A clan that captures a base earns clan XP every 30 minutes.** The store pages add that held bases contain resource-producing machines and are "guarded by bots and the strongest clans" ([RU wiki](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики), [Trashbox](https://trashbox.ru/link/zombix-online-android)).
3. **Flag territories (Флажок для базы, "base flag").** You claim a circle of *neutral* ground in the PvP Hot Spot or Survivors' Bases maps; flags cannot go on the pre-built bases. A flag costs 50 leather + 100 glue + 100 wood, and trades for about 4-5 gold. It is **invulnerable for 1 hour**, after which anyone can break it. **If the flag dies, everything on it is destroyed and 50% of its crafting resources scatter on the ground** as loot. Each flag holds up to **4 turrets** and **2 generators** ([Флажок для базы (Base Flag)](https://zombix-online.fandom.com/ru/wiki/Флажок_для_базы)).

### Placeable defensive structures

| Piece | HP | Recipe | Notes |
|---|---|---|---|
| Wooden wall | 500 | 25 wood | Trades at 2 per gold |
| Metal wall | 2,500 | 25 metal | Trades at 2 per gold |
| Gold wall | 5,000 | 15 gold | Trades at 1 per 15 gold |
| Small turret | 750 | 50 rusty metal, 50 duct tape, 15 copper wire | NPC General has sold it for 350 currency since Apr 2023 |
| Turret | 3,000 | 50 metal, 10 gold, 25 copper wire | Ignores clanmates and party members |
| Motorcycle generator | n/a | 25 sensors, 25 gears, 25 copper wire | After 25 minutes it mails you a motorcycle, then self-destructs |

Sources: [Деревянная стенка (Wooden Wall)](https://zombix-online.fandom.com/ru/wiki/Деревянная_стенка), [Металлическая стенка (Metal Wall)](https://zombix-online.fandom.com/ru/wiki/Металлическая_стенка), [Gold Wall](https://zombix.fandom.com/wiki/Gold_Wall), [Турель (Turret)](https://zombix-online.fandom.com/ru/wiki/Турель), [Малая Турель (Small Turret)](https://zombix-online.fandom.com/ru/wiki/Малая_Турель), [Генератор (Generator)](https://zombix-online.fandom.com/ru/wiki/Генератор).

**Wall placement** is free-form, not grid-based:
- Using a wall from your inventory shows a translucent ghost. You position it, can change its shape (straight wall, **arch, or slope**) so walls can be assembled into buildings, then confirm with a button.
- Once placed, a wall **cannot be moved**.
- Any weapon damages it. Monsters and bots path around walls, and broken walls drop some of their material.
- Known exploit: walls placed against a spawn point trap players until manual-fire mode is enabled.

**Clans** cost 1,000 zombucks to create, and member capacity scales with clan level.

Inference: Zombix's territory loop is crude but has the right bones. Claims are contestable and short-lived, a grace timer protects the builder, destruction pays the attacker in dropped materials, and turret and generator counts are capped per claim. It is missing a raidable home base, loot vaults to fight over, and editing or upgrading of placed pieces. Its wall shapes are its one notable "real building" feature.

---

## Design implications for our game

1. **Never ship an unraidable tier.** In LDoE, top-tier walls and storage are immune: L4/L5 walls cannot be breached, and specialised storage cannot be looted. That is the root of "nobody raids you". Every piece should have HP and a known, escalating breach cost, Rust-style. Make the top tier *expensive* to raid, never *impossible*. If we offer a protected stash, keep it small, earnable, and never sold.
2. **Use HP plus damage types, not one-key-per-tier.** LDoE's hatchet/iron hatchet/C-4/cutter mapping is easy to read but kills strategy. Keep the clarity (show the "cost to breach" on inspect) and drive it with HP and damage multipliers, so mixed tiers, soft sides and honeycombing become real choices.
3. **Steal the noise meter.** It is LDoE's best raid idea: breaching and gunfire draw escalating zombie waves and finally a boss. Use it in real-time PvP raids as a PvPvE timer that punishes long sieges and gives defenders and third parties time to respond.
4. **Raids must have a live defender path.** That means push alerts, online raid windows or offline-protection rules, and footprints and revenge as a *bonus*, not the core. Gate raiding by safe-zone rules or regions, not by level 150 plus a quest chain.
5. **Fix the build UX on day one.** We need:
   - Thin edge-walls snapped to floor tiles, with "wall tier ≤ floor tier" kept because it is a readable progression lock.
   - Drag to place lines and rectangles of walls.
   - Free move and rotate.
   - A full refund within a short grace window and a partial refund after.
   - Undo, saved blueprints and layouts.
   - A Warehouse-style auto-pull of materials from base storage, free and not a shop item.
6. **Floor-gated stations are good glue; runaway costs are not.** Gating chests, benches and tech behind floor tier creates natural upgrade goals. LDoE's full-base costs (thousands of plates per tier) push players toward shop packs. Budget a full mid-tier base at hours, not weeks, of play.
7. **Defences need agency and upkeep.** LDoE's spikes and trip wire are filler, and its turret was removed. Ship a few meaningful defences: powered or ammo-fed turrets, door locks and codes, traps with counterplay. Cap them per claim, as Zombix does (4 turrets per flag).
8. **Use PvE base pressure to *test* layouts, not to tax them.** The Horde becomes trivial once you reach L3. The 1.53 wave mode with Base Power and post-event repair shows players want active defence. Run periodic horde sieges that damage what is poorly built and reward good layouts, and do not grind down offline players.
9. **Space is a design lever, not a paid unlock.** We should not sell expansion, or lock it behind an endgame-only currency as LDoE now does with Site Plans (bought with Infected Genome; whether they are also sold for cash is unverified). Use claim radius, upkeep and decay so space is earned and abandoned bases free up land.
10. **Adopt Zombix's contestable outposts.** A **flag claim** with a short grace period, a cap on what it holds, and 50% of its materials dropped when destroyed. Add clan control points that pay out on a timer (Zombix gives clan XP every 30 minutes). These create reasons to fight between raids.
11. **Free-form shape variants (arch, slope) add expression.** Pair them with grid snapping for mobile precision.

## Fact-check notes

Fact-checked 2026-11-07. About 54 claims were re-checked against primary sources: raw wikitext pulled from the LDoE and Zombix Fandom wikis through the MediaWiki API, the iTunes lookup API and App Store review text, the live RuStore listing, the public Discord server page, and the planner's `constants.ts` and `catalog.json` on GitHub. The web-search budget ran out early in the check, so independent outside corroboration (press, Kefir dev blog text, Reddit) was not possible. Most claims therefore rest on fan-maintained sources, which the document already warns about.

**Corrections made**
- **Wall refund version.** The partial refund for destroying your own walls shipped in **v1.11.1 (18 Dec 2018)**, not "v1.17.8 (Dec 2018)". v1.17.8 is a Feb 2021 Chinese New Year update. I fixed both the "Before" and "v1.11.1" bullets in section 2.
- **Trunk capacity.** The current wiki page and blueprint text say **45** slots. 35 was the pre-v1.11.6 value. The table had these the wrong way round.
- **Site Plans framed as "sold".** Site Plans cost 100 Infected Genome. The wiki lists Infected Genome as earned from bosses (Borealis, Consilium, Leviathan), seasons, events and cats, with no direct cash purchase. I reworded the section 1 inference, the section 7 complaint and design implication 9 so they no longer say space is sold for money, and marked any cash route as unverified.
- **Floor gating conflict.** The planner says Woodworking Bench and Stonecutter's Table need an L2 floor. Their wiki infoboxes say L1 (wood floor). I added a note to the floor-tier table.
- **Rain Catcher orientations.** The wiki says 2. The planner catalog says 1 (not rotatable). I added a note.
- **Roof note date.** The Category:Base Builder page gives no date. It only says "beta version". I marked the "2018" date unverified.
- **Raid-frequency observation.** The "raided at most once a day" claim comes from a Threat of Attack page with April 2018 screenshots, so it may be outdated. I added that, and pointed the 8-hour footprint rule at the Raiding System page, where it actually appears.
- **Zombix rating.** The RuStore page shows 4.0 from 74 ratings, but its schema.org data says 3.9. Both are now noted.

**Confirmed as written (selection)**
- **Version dates:** 1.53.0 "Cult Hunting" (27 Oct 2026), 1.53.2 on the App Store (6 Nov 2026), 1.50.0 (18-19 Jul 2026), 1.51.1 (13 Aug 2026), 1.19.4 (10-11 Aug 2022), 1.18.4 (10-11 Aug 2021), 1.30.1 (2-3 Dec 2024), raiding gated at level 150 since v1.17.2, partial-base start since v1.9.4.
- **Home plot and debris:** 20x18 grid, 340 buildable tiles, a 5x4 truck, and the "396 total tiles" mismatch. Debris is 9 blocks / 36 tiles for older players, 66 / 264 for new ones, plus 18 more on the NE edge in 1.53. Site Plan costs 100 Infected Genome with a shop limit of 212. Planner values: 24x18 Home (legacy width 20) and 23x18 Settlement.
- **1.53 build changes:** returning floors, walls, doors and windows to inventory, and the workbench "Fill" button.
- **Costs and durability:** every per-step cost in the Floor/Wall/Window/Door table, the older Base building numbers, the Signal Scanning HP, Base Power and construction-damage tables, the Beginner design totals, the Honeycomb room costs and the Brick Room 3X3 contents.
- **Raid rules:** the breach table, C-4 at level 100 and its recipe, the Metal Cutter as a cult-camp event tool, noise values and thresholds (24/46/72/100), The Big One (1,000 HP, 300 armour), SWAT retaliation after 2 hours and its 4-stone-wall limit, 5 tasks with 45-125 coin skips, the 8-hour target window, and the wiki's "only AI raids" statement. The 1.7 patch notes do say "Attack other survivors' bases".
- **Storage and items:** storage caps and the shared group of 40, Rack 75 slots (20 to 70 per slot, 5,250 total), the Warehouse (2x1, 20x300, unraidable), the Safe (5 slots, removed in 1.30.1), and the furniture Turret (140°, about 4 hours per gasoline, max 4, did not target zombies, removed in 1.51.1).
- **Store data:** App Store rating 4.56 from 103,599 ratings, and the quoted App Store reviews.
- **Zombix:** RuStore lists the game under Berzerk Games, version 5.01 dated 28 Oct 2026, up to 100k downloads. The Discord shows 7,458 members. The flag, wall, turret, small turret, generator, storage, garden bed, workbench and clan figures all match the RU and EN wiki pages, including max 4 turrets and 2 generators per flag and neutral ground only.

**Still unverified:** whether Site Plans or Infected Genome can be bought for cash, the Google Play package ID (checked only through RuStore and BlueStacks), "planks unlock at level 2", the Kefir promo video framing of the wall trick, and the claim that most wiki pages were edited in Oct 2026.

**Overall reliability: high.** The numbers and mechanics match their cited sources closely. The errors were one wrong version number, one inverted capacity value, one monetization framing that overstated what the sources support, and two source conflicts the document had not flagged. The underlying data is still fan-maintained, so check it in-game before locking any numbers.

## Sources

- LDoE fan wiki (Fandom; read through the MediaWiki API, Nov 2026): [Home](https://lastdayonearthsurvival.fandom.com/wiki/Home), [Wall](https://lastdayonearthsurvival.fandom.com/wiki/Wall), [Floor](https://lastdayonearthsurvival.fandom.com/wiki/Floor), [Door](https://lastdayonearthsurvival.fandom.com/wiki/Door), [Window](https://lastdayonearthsurvival.fandom.com/wiki/Window), [Base building](https://lastdayonearthsurvival.fandom.com/wiki/Base_building), [Building (Home)](https://lastdayonearthsurvival.fandom.com/wiki/Building_(Home)), [Category:Base Builder](https://lastdayonearthsurvival.fandom.com/wiki/Category:Base_Builder), [Base Design for Beginners](https://lastdayonearthsurvival.fandom.com/wiki/Base_Design_for_Beginners), [Honeycomb Base Design](https://lastdayonearthsurvival.fandom.com/wiki/Honeycomb_Base_Design), [Raiding System](https://lastdayonearthsurvival.fandom.com/wiki/Raiding_System), [Threat Of Attack](https://lastdayonearthsurvival.fandom.com/wiki/Threat_Of_Attack), [Raiders](https://lastdayonearthsurvival.fandom.com/wiki/Raiders), [NPC Survivor Base](https://lastdayonearthsurvival.fandom.com/wiki/NPC_Survivor_Base), [The Horde](https://lastdayonearthsurvival.fandom.com/wiki/The_Horde), [Crowd Zombie](https://lastdayonearthsurvival.fandom.com/wiki/Crowd_Zombie), [The Big One](https://lastdayonearthsurvival.fandom.com/wiki/The_Big_One), [Signal Scanning](https://lastdayonearthsurvival.fandom.com/wiki/Signal_Scanning), [Cult Hunting](https://lastdayonearthsurvival.fandom.com/wiki/Cult_Hunting), [Version history](https://lastdayonearthsurvival.fandom.com/wiki/Version), [Version 1.53.0](https://lastdayonearthsurvival.fandom.com/wiki/Version/1.53.0), [C-4 Explosive](https://lastdayonearthsurvival.fandom.com/wiki/C-4_Explosive), [Metal Cutter](https://lastdayonearthsurvival.fandom.com/wiki/Metal_Cutter), [Hatchet](https://lastdayonearthsurvival.fandom.com/wiki/Hatchet), [Iron Hatchet](https://lastdayonearthsurvival.fandom.com/wiki/Iron_Hatchet), [Spike Trap](https://lastdayonearthsurvival.fandom.com/wiki/Spike_Trap), [Barbed Wire](https://lastdayonearthsurvival.fandom.com/wiki/Barbed_Wire), [Trip Wire Trap](https://lastdayonearthsurvival.fandom.com/wiki/Trip_Wire_Trap), [Bear Trap](https://lastdayonearthsurvival.fandom.com/wiki/Bear_Trap), [Turret (Furniture)](https://lastdayonearthsurvival.fandom.com/wiki/Turret_(Furniture)), [Portable Turret T-I](https://lastdayonearthsurvival.fandom.com/wiki/Portable_Turret_T-I), [Land Mine](https://lastdayonearthsurvival.fandom.com/wiki/Land_Mine), [Thorns](https://lastdayonearthsurvival.fandom.com/wiki/Thorns), [Friend](https://lastdayonearthsurvival.fandom.com/wiki/Friend), [Slicer](https://lastdayonearthsurvival.fandom.com/wiki/Slicer), [Warehouse](https://lastdayonearthsurvival.fandom.com/wiki/Warehouse), [Ore Storage](https://lastdayonearthsurvival.fandom.com/wiki/Ore_Storage), [Safe](https://lastdayonearthsurvival.fandom.com/wiki/Safe), [Small Box](https://lastdayonearthsurvival.fandom.com/wiki/Small_Box), [Chest](https://lastdayonearthsurvival.fandom.com/wiki/Chest), [Trunk](https://lastdayonearthsurvival.fandom.com/wiki/Trunk), [Rack](https://lastdayonearthsurvival.fandom.com/wiki/Rack), [Garden Bed](https://lastdayonearthsurvival.fandom.com/wiki/Garden_Bed), [Doormat](https://lastdayonearthsurvival.fandom.com/wiki/Doormat), [Workbench](https://lastdayonearthsurvival.fandom.com/wiki/Workbench), [Steel Plate](https://lastdayonearthsurvival.fandom.com/wiki/Steel_Plate), [Brick](https://lastdayonearthsurvival.fandom.com/wiki/Brick), [Brick Room 3X3](https://lastdayonearthsurvival.fandom.com/wiki/Brick_Room_3X3), [Site Plan](https://lastdayonearthsurvival.fandom.com/wiki/Site_Plan), [Genesis Collection](https://lastdayonearthsurvival.fandom.com/wiki/Genesis_Collection), [Settlement](https://lastdayonearthsurvival.fandom.com/wiki/Settlement), [Wall trick](https://lastdayonearthsurvival.fandom.com/wiki/Wall_trick), [General Tips/FAQ](https://lastdayonearthsurvival.fandom.com/wiki/General_Tips/FAQ), [Beginner's Guide](https://lastdayonearthsurvival.fandom.com/wiki/Beginner%27s_Guide)
- Community planner: [LDOE Base Planner](https://ovgamesdev.github.io/ldoe-base-planner/), [GitHub repo (catalog.json, constants.ts)](https://github.com/ovgamesdev/ldoe-base-planner)
- [LDoE on the App Store](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)
- [YouTube: "Last Day on Earth: Wall Trick 101", NOLIMITS STUDIO](https://www.youtube.com/watch?v=gdPpCVwD8hQ) (metadata via oEmbed only)
- Zombix Online: [RU fan wiki main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики), [Флажок для базы (Base Flag)](https://zombix-online.fandom.com/ru/wiki/Флажок_для_базы), [Деревянная стенка (Wooden Wall)](https://zombix-online.fandom.com/ru/wiki/Деревянная_стенка), [Металлическая стенка (Metal Wall)](https://zombix-online.fandom.com/ru/wiki/Металлическая_стенка), [Турель (Turret)](https://zombix-online.fandom.com/ru/wiki/Турель), [Малая Турель (Small Turret)](https://zombix-online.fandom.com/ru/wiki/Малая_Турель), [Генератор (Generator)](https://zombix-online.fandom.com/ru/wiki/Генератор), [Хранилище (Storage)](https://zombix-online.fandom.com/ru/wiki/Хранилище), [Грядка (Garden Bed)](https://zombix-online.fandom.com/ru/wiki/Грядка), [Верстак (Workbench)](https://zombix-online.fandom.com/ru/wiki/Верстак), [Кланы (Clans)](https://zombix-online.fandom.com/ru/wiki/Кланы), [EN wiki: Gold Wall](https://zombix.fandom.com/wiki/Gold_Wall), [EN wiki: Zombix Wiki](https://zombix.fandom.com/wiki/Zombix_Wiki), [RuStore listing](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline), [Trashbox listing](https://trashbox.ru/link/zombix-online-android), [BlueStacks page](https://www.bluestacks.com/campaign/com.ZombixDev.ZombixOnline/ru), [Official Discord](https://discord.com/servers/zombix-online-official-720251932710666261)
