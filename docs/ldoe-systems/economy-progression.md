# LDoE systems catalog, part 2: economy and progression

**Scope:** the resource tree, gathering systems, stations, the crafting ladder, the survival economy, player level, the incremental grind and storage in *Last Day on Earth: Survival* (Kefir!), as of version **1.53.x (Nov 2026)**. This document is a data reference for building our own incremental survival-crafting game on Roblox, with our own names and art.

**Not covered here:**
- Locations, bunkers, keycards and loot boxes (another document covers these).
- The shallower overview in [`docs/research/ldoe-core-systems.md`](../research/ldoe-core-systems.md), which this document only adds depth to. Facts already established there are referenced as "core doc §n" rather than repeated.
- Monetization, which is cross-checked against [`docs/research/ldoe-monetization.md`](../research/ldoe-monetization.md) ("monetization doc").

**Method and caveats**
- **Primary source:** the LDoE Fandom wiki, read as raw wikitext through its MediaWiki API on 2026-11-07, about 400 pages in category batches. The most authoritative current page is **[Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints)**, which was edited for 1.53. It lists every craftable recipe with its quest unlock. Many individual item pages still carry pre-2022 text, such as "Level: 28, Craft Points: 2" (the [Craft Points](https://last-day-on-earth-survival.fandom.com/wiki/Craft_Points) system was removed in 1.18.14).
- **When sources disagree:** this document uses the Blueprints table for recipes and quest unlocks, and flags conflicts in the table they belong to and in [§9](#9-conflicts-and-stale-data).
- **Labels:**
  - **Inference:** marks my own reasoning or arithmetic.
  - **(stale)** marks numbers from item pages whose last substantive edit predates current systems.
  - **(conflict)** marks two wiki pages that disagree.
- **No invented numbers:** where no source gives a value, the cell says "?" or "not found".

---

## Contents
1. [Resource tree](#1-resource-tree)
2. [Gathering systems](#2-gathering-systems)
3. [Stations](#3-stations)
4. [Crafting progression ladder](#4-crafting-progression-ladder)
5. [Survival economy](#5-survival-economy)
6. [Player level and XP](#6-player-level-and-xp)
7. [The incremental grind](#7-the-incremental-grind)
8. [Storage and inventory](#8-storage-and-inventory)
9. [Conflicts and stale data](#9-conflicts-and-stale-data)
10. [Data model implications](#data-model-implications)
11. [Sources](#sources)

---

## 1. Resource tree

### 1.1 Raw resources: nodes and pickups

Each harvested item gives **10 XP** on pickup, per the [Pine Log](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Log), [Limestone](https://last-day-on-earth-survival.fandom.com/wiki/Limestone) and [Edible Mushroom](https://last-day-on-earth-survival.fandom.com/wiki/Edible_Mushroom) pages.

**Node respawn** (core doc §4):
- Home-plot nodes never respawn.
- Zone nodes fully regenerate when you leave or die.

**Auto Mode** (default skill) harvests automatically. Players split stacks to fill their backpack, so it only picks up what they want ([General Tips/FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ)).

| Resource | Node / source | Tool required | Hits | Yield per node | Where | Skill / buff bonus | Notes |
|---|---|---|---|---|---|---|---|
| Pine (Common) Log | Pine Tree | Hatchet (any) | 4 | 3 logs | Every outdoor zone, home plot | Lumberjack +2%/lvl extra log (max 20%) | Loose logs on ground too. Also fuel. Seedlings regrow at home (§2.2) |
| Pine Log | Dead Tree | Hatchet | 4 | 3 logs | Yellow/red zones, Infected Forest | — | — |
| Oak Log | Oak Tree | **Iron Hatchet** | 4 | 2 (+1 chance) | Oak Bushes / Grove (since 1.30.1), Factory, Farm | Logger +2%/lvl (max 20%); "Salmon soup" stove buff +10/15/20% extra log | Crate with Oak Logs (Buzzsaw) gives about 106–142 logs |
| Ash Log / Ash Billet | Ash Tree | **Chainsaw only** | ? | 2 Ash Billet | Swamp Forest, Wild Bogs (ATV-only) | — | Naming is muddled on the wiki: "Ash Billet" was formerly called "Ash Log", and a separate current "Ash Log" page exists. Recipes say "Ash Log". Chainsaw blueprint is Genesis-only (2,000 genome) |
| Limestone | Limestone Rock | Pickaxe (any) | 5 | 3 | Limestone zones, Pine and Oak zones, North | — | Loose pieces everywhere except bunkers and NPC bases |
| Iron Ore | Iron Rock | Pickaxe | 5 | 3 (+1 Bauxite rarely; Spires bauxite removed 1.30.1) | Limestone Ridge/Cliffs/Spires, NPC bases | Iron Miner +2%/lvl (max 20%); "Fish sticks" buff 10/15/20% extra ore | Cliffs has about 30 rocks, roughly 90 ore (core doc §4) |
| Copper Ore | Copper Rock | **Iron Pickaxe** | 5 (infobox says 10, conflict) | 1–3 | Frosty Backwoods (North), Basements | Copper Miner +2%/lvl (max 20%) | Crate with Copper at Frozen Training Ground: up to 100 ore |
| Aluminum Ore / Bauxite | Loot; rare Iron Rock drop | — | — | — | Wooded Foothills, Rest Stop, NPC bases | — | Renamed "Bauxite" on newer pages. Extractor (§2.1) |
| Quartz | Quartz Rock / cave walls | Pickaxe / **Manual earth drill** | 4 | 3 Limestone + 1 Quartz | Sand Quarry, Old Mine (Islands) | — | Drill also mines Halite and Titanium |
| Titanium Ore | Cave deposits | Manual earth drill | ? | 5–8 per deposit | Dead Island, Old Mine | — | Also Rations auto-clear of Dead Island |
| Sulfur | Sulfur Rock | Pickaxe | 6 | 2 (+ some limestone) | Swamp Forest, Wild Bogs | — | Sulfur Extractor (event) |
| Sand | Ground deposit | **Shovel** | — | 2 per deposit | Sand Quarry | — | — |
| Peat | Ground deposit | Shovel | — | ? | Wild Bogs, Swamp Forest | — | — |
| Thermite | Buried chest under snow | Shovel | — | 2–3 per chest | Wooded Foothills, Frosty Backwoods, Icy Outskirts | — | Genesis sells 20 for 45 genome |
| Lead | Crate of Lead (formerly Ore Crate), opened at Buzzsaw | — | — | 20 Lead per crate | Bogs (needs ATV + Car Battery) | — | Lead Extractor (event, 1.49) |
| Antimony | Loot / Crate of Antimony | — | — | ? | Swamp Forest, Wild Bogs | — | — |
| Halite | Cave walls | Manual earth drill | — | ? | Old Mine, Dead Island | — | Genesis sells 20 for 70 genome |
| Block of Marble | Marble Rock | Pickaxe | 5 | 3 | Limestone zones (event content, 1.10.1) | — | — |
| Plant Fiber | Ground pickup | none | — | 1 | All farming zones | — | Picking fiber sometimes yields **Seeds** |
| Berry | Berry Bush | none | — | 3 | All resource zones, home (7 bushes) | — | Northern Berry Bush also gives 3 |
| Edible Mushroom | Ground pickup | none | — | 1 | Yellow/red Oak zones | — | — |
| Corn Seeds, Sprout | Light-green bushes | none | — | chance | Swamp Forest, Wild Bogs | — | Farming inputs (§2.2) |
| Raw Meat, Animal Rawhide, Fur, Wolf Hair, Thick Hide | Animals | any weapon | — | see §2.4 | Zones | Skinner +2%/lvl extra rawhide (max 20%) | — |
| Piece of Cloth, Rope | Zombie drops, containers | — | — | Roaming Zombie: Rope 0–2 (50%), Cloth 0–2 (25%) | Everywhere | — | Per the [drop chart](https://last-day-on-earth-survival.fandom.com/wiki/Creatures_Items_Drop_Chance_chart) |
| Scrap Metal | Containers, AI survivors | — | — | — | Everywhere | — | **Stack 50** (not 20) |

**Tool durability economics** (from the tool pages):

| Tool | Durability | What one tool harvests | Recipe | ROI |
|---|---|---|---|---|
| Hatchet | 50 hits | about 12.5 pine trees (wiki: 2 hatchets ≈ 25 trees), so ≈ 37 logs | 3 Pine Log + 3 Limestone | **Inference:** about 12× return on logs |
| Pickaxe | 50 hits | 10 nodes, so 30 limestone or 30 iron ore | 3 Pine Log + 3 Limestone | **Inference:** about 10× return |
| Iron Hatchet | 75 hits | 18.75 pine trees, or about 9 oak trees | 5 Iron Bar + 3 Pine Plank + 2 Nails + 5 Duct Tape | Required for oak |
| Iron Pickaxe | 75 hits | 15 nodes | same as Iron Hatchet | Required for copper |
| Shovel | 70 as weapon / **35 as tool** | Sapling dig costs 6 durability (3 animations × 2) | 8 Pine Plank + 7 Iron Bar + 3 Nails | Required for sand, peat, thermite, stashes, saplings |
| Manual earth drill | 40 | ? | 1 Steel Bar + 3 Engine Part + 2 Thermite + 15 Wiring + 2 Gasoline | Cannot be wielded as a weapon. Genesis sells it for 120 genome |
| Chainsaw | ? | Ash trees | Genesis blueprint. Recipe is a (conflict): see §4.2 | AoE melee hybrid (1.51) |

Tools don't need to be equipped. They are consumed in inventory order, top-left first ([General Tips/FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ)).

### 1.2 Processed tiers and conversions

| Output | Inputs | Station | Time | Notes |
|---|---|---|---|---|
| Pine Plank | 1 Pine Log | Woodworking Bench | 4 m | 1:1 |
| Oak Plank | 3 Oak Log | Woodworking Bench | 20 m | — |
| Ash Plank | 8 Ash Log | Woodworking Bench | 1 h | (conflict) The [Ash Plank](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Plank) page says 5 logs / 30 min |
| Charcoal | 1 Pine Log → 1 · 1 Oak Log → 1 · 1 Ash Log → 2 · 1 Pine Plank → 2 · 1 Oak Plank → 4 · 1 Ash Plank → 4 | Campfire | 2–10 m | Oak Log takes 2 m, Ash Plank 10 m, the rest 4 m. Needs separate fuel |
| Stone Brick | 2 Limestone | Stonecutter's Table | 4 m | Main building material for wall and floor tiers 2–3 |
| Brick | 2 Cement + 5 Sand + 5 Peat + 10 Limestone → **2 Brick** | Refined Melting Furnace | 1 h 30 m | L5 walls (core doc §7) |
| Cement | 15 Sand + 20 Limestone + 5 Bauxite + 10 Bottle of Water → 3 | Concrete mixer (Port) | 60 m | Also CYF crate loot |
| Glass | 5 Sand | Melting Furnace | 26 m 40 s | (conflict) The [Quartz](https://last-day-on-earth-survival.fandom.com/wiki/Quartz) page says 4 Quartz → 1 Glass |
| Processed Quartz | 4 Quartz | Stonecutter's Table | ? | — |
| Refined Antimony | 8 Antimony | Stonecutter's Table | 10 m | — |
| Iron Bar | 2 Iron Ore **or** 4 Scrap Metal | Melting Furnace | 4 m | — |
| Iron Plate | 1 Iron Bar | Workbench | 20 m | Alt: 15 Scrap Metal + 1 Adhesive at Pressing Machine, 20 m |
| Nails | 1 Iron Plate → **2 Nails** | Workbench | 4 m | — |
| Aluminium Bar | 4 Bauxite (1 h) **or** 2 Aluminium Wire (26 m 40 s) | Melting Furnace | see inputs | — |
| Aluminium Plate | 2 Aluminium Bar | Workbench | 1 h | — |
| Bolts | 1 Aluminium Plate → **2 Bolts** | Workbench | 10 m | — |
| Copper Bar | 5 Copper Ore | Melting Furnace | 1 h | — |
| Titanium Bar | 5 Titanium Ore | Melting Furnace | 1 h 30 m | — |
| Lead Bar | 16 Lead | Melting Furnace | 30 m | — |
| **Steel Bar** | 1 Iron Bar + 1 Aluminium Bar + 1 Copper Bar + 2 Charcoal | Refined Melting Furnace | 1 h 30 m | The tier gate: three separate metal chains converge here |
| Steel Plate | 1 Steel Bar | Workbench | 1 h 30 m | — |
| Titanium Alloy | 2 Titanium Bar + 1 Processed Quartz + 3 Iron Bar + 1 Aluminium Bar | Refined Melting Furnace | 2 h | Genesis sells 1 for 120 genome |
| Tungsten Bar | 1 Tungsten Ore + 2 Alu Bar + 1 Copper Bar + 4 Charcoal | Refined Melting Furnace | **Not available** | Still unobtainable. Gates 5 weapons, the Assault set, the Tactical Backpack, the Mortar and the Mi-24 (core doc §4) |
| Lead Plate | 2 Lead Bar + 1 Refined Antimony | Pressing Machine | 1 h | — |
| Rubber | 20 Rubber Parts + 1 Adhesive | Pressing Machine | 1 h | Genesis sells 10 for 80 genome |
| Reinforced Fabric | 1 Protective Fabric + 1 Refined Antimony | Pressing Machine | ? | CBRN set input |
| Fuel Briquette | 2 Peat + 4 Ash Log | Pressing Machine | 20 m | 12-min burn, equal to 9 log-equivalents |
| Leather | 1 Animal Rawhide | Tanning Rack | 4 m | — |
| Rope | 2 Plant Fiber | Tanning Rack | 4 m | — |
| Tanned Fur | 2 Fur | Tanning Rack | ? | Fur and Reinforced Fur sets |
| Piece of Cloth | 2 Plant Fiber | Sewing Table | 2 m | — |
| Thick Fabric | 2 Piece of Cloth | Sewing Table | 2 m | (conflict) The [Thick Fabric](https://last-day-on-earth-survival.fandom.com/wiki/Thick_Fabric) page says 1 m |
| Woolen Fabric | 2 Piece of Wool | Sewing Table | 2 m | (conflict) The [Woolen Fabric](https://last-day-on-earth-survival.fandom.com/wiki/Woolen_Fabric) page says 12 m |
| Protective Fabric | 2 Piece of Protective Fabric | Sewing Table | 12 m | Hazmat set |
| Sturdy Belts | 2 Tough Leather | Sewing Table | ? | — |
| Alcohol | 5 Berry | Medical Table | 10 m | A full stack of 20 berries gives 4 Alcohol in 40 m |
| Iodine | 2 Seaweed | Medical Table | 10 m | — |
| Acid | 10 Sulfur + 20 Bottle of Water | Chemistry Station | 1 h | — |
| Gunpowder | 20 Sulfur + 20 Charcoal | Chemistry Station | 1 h | (conflict) The [Gunpowder](https://last-day-on-earth-survival.fandom.com/wiki/Gunpowder) page says 1 h 30 m |
| Spore Blocker | 4 Spore Sample + 1 Iodine | Chemistry Station | 4 m | — |
| Sporicide | 3 Halite + 1 Iodine | Chemistry Station | 4 m | — |
| Spices | 3 Sprout | Hydroponic System | 1 h 30 m | Skip: 22 coins |
| Seaweed | 1 Sporicide → 4 Seaweed | Seaweed Farm (Port Lab) | 52 m 30 s | Burns Charcoal (1.51) |

**Inference:** the metal ladder is the spine of the game.
- iron (home + Limestone zones) → aluminium (bauxite loot, wire) → copper (North) → steel (needs all three plus charcoal) → titanium (Islands, drill) → titanium alloy → lead / antimony (Bogs, ATV) → tungsten (still withheld).
- Each step needs a new region, and each region needs a new vehicle or gear set.

### 1.3 Parts (components) and their sources

"Craftable" means a current recipe exists (via the Blueprints table or a station page). Otherwise the part is loot-only.

| Part | Craftable? | Main sources (wiki "Obtaining") | Key uses | Notes |
|---|---|---|---|---|
| Bolts | Workbench: 1 Alu Plate → 2 (10 m) | Containers in all areas, Junkyard, convoys, Airdrops, Limestone crates; shop "Pack of weapon parts" | Chopper (5 + 30), Chest, Garage, Gunsmith, Recycler (20), Glock (15) | Path rewards hand out 10–20 at a time |
| Nails | Workbench: 1 Iron Plate → 2 (4 m) | Bunker Alfa lockers | Iron tools, reinforced clothes, Chemistry Station (20), C-4 path | — |
| Wiring | Laboratory: output 5 Wiring from 1 Copper Bar + 3 Plastic + 5 Cloth + 5 Duct Tape (as tabulated); older page: 1 Copper Bar + 1 Cloth + 1 Duct Tape (L64, stale) | "One of the more common items", found in any resource location, Junkyard, convoys | Chopper (10), ATV frame (15), Laboratory (20), C-4 (25) | — |
| Rubber Parts | No | Containers in all areas: Motel, Junkyard, Airdrops, crashed planes | Chopper (20), Recycler (10), Sewing Table, Rubber (×20) | — |
| Rubber | Pressing Machine | Junkyard, Port Sewer, Genesis Lab crates, Bunker Bravo, Genesis (10 for 80) | ATV (250), Motorboat (30), Chemistry Station (10) | — |
| Duct Tape | No | NPC bases, bunkers, crates in all zone tiers; shop weapon-parts pack | Iron tools (5 each), Bow, Recycler (10), Generator (40) | — |
| Adhesive | No | Farm, Bunker Alfa, Airdrops, zone chests, AI survivors; shop | Workbench (5), Sewing Table (5), Mirror (15), Zip Gun (8), reinforced clothes | — |
| Ball Bearing | No | Bunker Alfa, resource zones, NPC bases, Junkyard, Airdrops | Chopper (10), Pressing Machine (20), Generator (20) | — |
| Engine Part | No | Bunker Alfa coupon boxes, Farm, NPC bases, Airdrops, **recycling Rusty/Intact Engines** from rusty vehicles, Abandoned Factory, hourly Unknown Box (rare); shop "Mechanic's pack" | **Chopper (20)**, **ATV (200)**, Boat engine (10 each × 2), Trolley (80), Chopper upgrades | The canonical "one more run" part. 1.10.2 notes raised its drop rates |
| Spring | No | Bunker Alfa terminals, Bunker Bravo, Port Lab, Farm, Blackport PD, Motel, Airdrops; recycling firearms (Output 1) | Glock (8), Crossbow, Motorboat (30), C-4 (15); Genesis 5 for 20 genome | — |
| Factory Parts | No | Season passes, **recycling firearms**, Bunker Bravo, Port sunken box, Gas Station (Caps), Genesis (1 for 70) | Scorcher, Crossbow, Glock, M16, The Equalizer | — |
| Carbon Composite | No | Season (infinite tier), recycling firearms, Bunker Bravo 2F (4–7), Genesis Lab crates (10 for 450 samples per 3 days), Fisherman trade (75 coins) | **ATV (200)**, Kevlar set, Motorboat (20), Glock, M16 | — |
| Gun Oil | No | Bunker Alfa (doggy doors, Hard Mode), Bunker Bravo, NPC raids, shop, Expeditions, "extremely rare in red zones" | Pressing Machine (15 on the old page, 5 in the current table), Neutralizer, turrets | — |
| Cog | No | Bunker Alfa kit crates (1 per kit), Junkyard, Bunker Bravo, recycling ATV Transmission; Genesis 1 for 35 genome; Genesis Storage 100 samples (1 per 3 days) | **ATV (200)** | — |
| Plastic | No | Recycling bottles, CAC cards, car batteries, phones, gas masks | Many | Empty Bottle → Plastic is only a 5% base chance |
| Electronic Circuit | Laboratory: 3 Plastic + 4 Processed Quartz + 5 Iron Bar + 2 Alu Bar | Recycling phones, USB drives, signal amplifiers; Blackport PD; Port Sewer | Chainsaw, The Equalizer, Turret T-I, Flight Controller | — |
| Hi-Tech Components | Laboratory: 1 Lead Plate + 12 Plastic + 4 Glass + 4 Light Bulb | Recycling Mobile Phone / Heat sensor | C-4 (20), Heat sensor, Mi-24 | — |
| Explosive Material | Laboratory: 20 Alu Bar + 20 Plastic + 10 Gunpowder + 5 Gasoline | — | **C-4 (18)**, Land Mine (1) | See §7.1 for the C-4 cost explosion |
| Car Battery | Laboratory: 2 Titanium Alloy + 10 Plastic + 15 Wiring + 5 Sporicide (conflict: the [Car Battery](https://last-day-on-earth-survival.fandom.com/wiki/Car_Battery) page says 4 Titanium **Bar**) | Junkyard, Bunker Bravo 3F, Gas Station slot jackpot, Fisherman (75 coins), shop | **ATV (60)**, Pressing Machine (1) | — |
| Gasoline | No (Empty Canister refills) | Farm barn, Airdrops, Bunker Alfa crates, Bunker Bravo, Junkyard, Rest Stop choppers | Chopper fuel (1 = 25 fuel), extractors, Motorboat (20), Generator (10) | — |
| Gas Cylinder | No (recycler recipe added 1.26) | Combat Gear Coupon chest (always 1), Landfill, Transport Hub crates, Bunker Bravo 4F | **ATV (30)** | — |
| Air Filter | No | Loot | ATV (150), Boat engine (10), Acid Bath, Enhanced anti-spore set | — |
| Wrench / Hammer | No | Loot; Path premium; Genesis (3 Wrench for 50 genome) | Pressing Machine (10 Wrench, 5 Hammer), Generator (5 Wrench), Motorboat (3 + 3) | — |
| Pipes | No | Genesis Laboratory boxes; Abandoned Factory (1.51.1+) | Hand Pump (10) | — |
| Chopper Wheel / Fork / Gas Tank | No | Bunker Alfa yellow/red coupon crates (rare); Farm barn; first wheel from the first AI survivor kill; shop "Specialist's pack" (wheel, fork) and "Mechanic's pack" (gas tank) | Chopper finalization (2 wheels, 1 fork, 1 tank) | **Non-stackable.** Also given as Survivor's Path premium rewards (§4.7) |
| ATV Wheel | No | Genesis Storage 400 samples (**1 per 3 days**), Bunker Bravo 4F (rare), raids, Leviathan's Lair | ATV (16); ATV upgrade 3,000 points each, 1 per day | — |
| ATV Transmission | No | Genesis Storage 1,100 samples (**1 per 3 days**), Gas Station slot (extremely rare), Transport Hub GM crate, Path premium ("Laboratory" quest) | ATV (10); upgrade 6,000 points each, 1 per day | — |

---

## 2. Gathering systems

### 2.1 Mining, quarrying and extractors
- **Nodes:** see §1.1. Every rock is 4–6 hits. Ore tier is gated by tool tier: copper and oak need iron tools, titanium and quartz need the drill, ash needs the chainsaw.
- **Bulk crates (Buzzsaw):** heavy crates are carried home and sawn open for a resource fee. Opening one is a timer with a coin skip (see the table below). Examples:
  - Crate with Oak Logs costs 7 Nails, 7 Iron Bar, 5 Wrench and 3 Iron Plate. It takes 60 m (skip 20 coins) and yields about 106–142 Oak Logs, 7–12 Charcoal and 0–6 Oak Plank.
  - Crates with Hides, Stone, Iron, Pine Logs or Provision take 32 m 30 s (skip 18 coins) and cost small part bundles, e.g. Iron: 4 Plank + 4 Ball Bearing + 2 Spring.
  - [Buzzsaw](https://last-day-on-earth-survival.fandom.com/wiki/Buzzsaw), [Crate with Oak Logs](https://last-day-on-earth-survival.fandom.com/wiki/Crate_with_Oak_Logs).
- **Ore extractors** (1.36+; sulfur and lead added 1.49). They are **event or shop rewards only** and cannot be crafted. Max 2 per type, ground only. Each burns Gasoline and produces **1 ore per 1 h cycle** into a 20-slot output ([Extractors](https://last-day-on-earth-survival.fandom.com/wiki/Extractors)).

| Extractor | Burn time per Gasoline | Efficient load (wiki tip) | Output |
|---|---|---|---|
| Aluminum | 4 h 48 m | 4 Gasoline = 19 h 12 m | Aluminum Ore |
| Copper | 2 h 24 m | 8 Gasoline = 19 h 12 m | Copper Ore |
| Titanium | 36 m | 21 Gasoline = 12 h 36 m, about 12.6 ore | Titanium Ore |
| Sulfur, Lead | ? | ? | Sulfur / Lead (from the "Metal & Mud" event, May 2026) |
| Echo | no fuel | — | 1 random ore per interaction, 1 h cooldown (Season 17 / shop) |

**Inference:** the wiki's "efficient load" tips show extractors are tuned so that **a fuel load lasts about one day** (the wiki tips give 19 h 12 m for Aluminum and Copper, 12 h 36 m for Titanium). That makes them a once-a-day check-in, the same cadence as the Energy refill.

### 2.2 Farming

LDoE farming is **thin by design**. The Wasteland has no watering or fertiliser mechanic:
- **Fertilizer** is only a Crater (multiplayer) Chemistry input: 1 Fertilizer + 4 Cloth → Saltpeter.
- **Watering can** is a Season 16 delivery and quest item.
- Sources: [Fertilizer](https://last-day-on-earth-survival.fandom.com/wiki/Fertilizer), [Watering can](https://last-day-on-earth-survival.fandom.com/wiki/Watering_can).

| Plot / crop | Station | Input | Output | Grow time | Skip | Station cost and limits | Unlock |
|---|---|---|---|---|---|---|---|
| Carrot | Garden Bed | 1 Seeds | **2 Carrot** | 1 h | ? | 5 Limestone + 1 Plant Fiber; ground only; 2×2; max 2 | "Resource collecting" quest |
| Corn | Garden Bed | 1 Corn Seeds | 1 Corn | 1 h 30 m | ? | same | Seeds from Bogs bushes |
| Spices | Hydroponic System | 3 Sprout | 1 Spices | 1 h 30 m | **22 coins** | 5 Halite + 10 Oak Plank + 20 Iodine + 2 Ti Alloy + 4 Air Filter + 10 Nails (current table); max 1; Iron/Brick floor | "Expedition Begins" quest (the page says "Woodshop" quest, conflict) |
| Seaweed | Seaweed Farm (Port Lab, fixed) | 1 Sporicide | 4 Seaweed | 52 m 30 s | ? | Assembly: 2 Air Filter, 5 Sporicide, 4 Light Bulb, 16 Rope, 1 Pump, 20 Water, 8 Copper Bar, 20 Wiring, 10 Glass, 2 Nails | Port Laboratory |
| Pine / Oak trees | Saplings planted at home | Seedling dug with Shovel (30 XP, 6 durability) | Harvestable tree | Pine: 1 growth stage per 12 h; Oak: 1 stage per 24 h (stage count not found) | — | Max 20 each, ground only | Seedlings from Pine Grove / Oak zones; shop "Blossom Pack" (S16) |
| Turkey (ranch) | Turkey Coop | 20 Seeds | 1 Turkey **or** Wild Turkey (hostile, no loot) | 6 h | **39 coins** | Seed capacity 100; no new cycle while 5 birds are on base; season reward | Season reward (1.48 era) |
| Caiman (ranch) | Caiman Farm | 5 Raw Turkey | 1 Caiman (friendly until provoked) → drops **Leather** | 8 h | **49 coins** | Slot capacity 20 | "Metal & Mud" event (1.49) |
| Boar (ranch) | Boar Farm | ? | Boar (skins) | ? | ? | ? | Added 1.53; data not found |

- **Seeds** come mostly from harvesting Plant Fiber, plus Farm storages, raider NPC bases, the Rest Stop truck and Rations.
- **Yield math (Inference):**
  - Two Garden Beds give at most 4 Carrots per hour. A Carrot restores 5 Hunger, or 25 Hunger as Carrot Stew (2 m at the Campfire).
  - So two beds supply roughly 100 Hunger per hour of real time. At a drain of about 1 point per 10 s (360 per hour), that is far below active-play needs.
  - Farming is a **passive top-up**. The real food engine is hunting plus the free daily inbox (3 water and 3 canned food until level 100).
- **Ranch chain (Inference):** Seeds → Turkey (6 h) → 5 Raw Turkey → Caiman (8 h) → Leather. This is the only renewable home source of leather besides hunting, and every link has a coin skip.

### 2.3 Fishing
- **Gate:**
  - The **Fisherman** passive skill (1 level) unlocks crafting the rod and spawns fishing events.
  - The Fishing Rod blueprint comes from the "Search for Survivors" quest.
  - Rod recipe: 3 Pine Plank + 5 Duct Tape + 5 Rope + 3 Adhesive. **Durability 10.**
  - The Professional rod has durability 20. It is uncraftable: get it from the shop "Fisherman's Pack", from season tasks, or from the Fisherman NPC for fish or **75 coins**.
  - Sources: [Fishing Rod](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Rod), [Professional fishing rod](https://last-day-on-earth-survival.fandom.com/wiki/Professional_fishing_rod).
- **Where:** a **Fishing Spot is a 12-hour event location** on the global map. There are three ponds, plus the Pier ([Fishing Spot](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Spot)).
  - Grasslands: Perch, Pike (rare), Catfish (rare), Sturgeon (very rare).
  - Oak Pond: Perch, Trout, Salmon, Pike (rare), Catfish (rare).
  - Snowbound: Salmon, Pike, Catfish (rare), Sturgeon (very rare). Needs 10 cold protection.
- **Mechanics:**
  - Fish come in **Bronze, Silver or Gold quality**, which scales the duration of kitchen-stove buffs.
  - **Burley** re-stocks an emptied pond.
  - Explosives (Grenade, Milkor, AK grenade-launcher mod) also harvest fish, but never Gold quality.
  - Exploit: swapping the rod out of the main slot after each catch avoids durability loss.
- **Modifiers:**
  - Fishing Skill: +2% per level (5 levels).
  - Fisherman's Luck: 3 levels unlock rarer fish.
  - "Catfish and a side of vegetables" stove buff: higher rare-fish chance.
  - "Carp stuffed with mushrooms" buff: higher chance to fish up a chest.
- **Fisherman NPC trades:**
  - Fish or coins for Carbon Composite, Car Battery or a Professional rod (75 coins each).
  - Spices (25 coins each).
- **Uses:**
  - Raw fish restores only 7 HP / 5 Hunger / 5 Thirst. Fish are mainly **buff ingredients** for the Kitchen stove (§5.4).
  - Storage: Fish Fridge, 15 slots × 60.

### 2.4 Hunting and "trapping"

| Animal | HP | Behaviour | Drops | XP |
|---|---|---|---|---|
| Deer | 25 | Flees; never attacks; only killable by undetected sneak attack or ranged weapon | 3 Raw Meat + usually 1 Animal Rawhide | 10 |
| Grey Wolf | ? | Aggressive | Raw Meat 0–1 (50%), Rawhide 0–1 (25%), Wolf Hair (with hunting weapons) | ? |
| Rabid Wolf | ? | Aggressive | Raw Meat 0–1 (25%), Rawhide 0–1 (25%); Fur | ? |
| Diseased Wolf | ? | Aggressive | Nothing (100%) | ? |
| Boar | 150 | Telegraphed charge (red arrow, 24 dmg); stunned on hitting obstacles | Raw Meat, Fur | ? |
| Bear | 150 | Knockback; event locations only | ? | ? |
| Fox, Northern Deer | ? | — | Fur | ? |
| Spore Deer / Wolf / Bear | ? | Islands | Thick Hide | ? |
| Caiman (Bogs, ranch) | ? | — | Leather | ? |

Sources: [Deer](https://last-day-on-earth-survival.fandom.com/wiki/Deer), [Boar](https://last-day-on-earth-survival.fandom.com/wiki/Boar), [Bear](https://last-day-on-earth-survival.fandom.com/wiki/Bear), [drop chart](https://last-day-on-earth-survival.fandom.com/wiki/Creatures_Items_Drop_Chance_chart), [Fur](https://last-day-on-earth-survival.fandom.com/wiki/Fur), [Thick Hide](https://last-day-on-earth-survival.fandom.com/wiki/Thick_Hide).

- **Modifiers:**
  - Skinner: +2% extra rawhide per level (max 20%).
  - The Animal Friend active skill makes animals unafraid for a while.
- **Traps:** Spike Trap, Bear Trap and Trip Wire Trap exist, but they are **base-defense and PvE furniture, not food traps**.
  - **Inference:** LDoE has no snare-for-food loop. The "trapping" role is filled by the ranch furniture in §2.2 (Turkey Coop → Caiman Farm, 1.48–1.53).

### 2.5 Water collection

| Source | Output | Rate / cost | Notes |
|---|---|---|---|
| Rain Catcher | 1 Empty Bottle → 1 Bottle of Water | **10 m per bottle**; slots cap 20 | Cost 5 Pine Log + 3 Cloth + 2 Scrap (current table; old page 10 logs); max 2; "Neighborhood" quest |
| Hand Pump | Instantly fills Empty Bottles | — | 15 Iron Plate + 10 **Pipes** + 12 Nails + 10 Rubber Parts; max 2; "First Field Trip" quest (Settlement track; formerly L52) |
| Bottle with dirty water | 23 Thirst | loot | — |
| Daily inbox | 3 Bottle of Water + 3 Canned Food per day | until about level 100 | Expires if unclaimed (core doc §2) |
| Drinks | see §5.2 | — | — |

- **Empty Bottles are reusable forever.** They are also used to pour Gasoline in and out of the Chopper.
- Drinking 13 full bottles triggers the need to pee ([Bottle of Water](https://last-day-on-earth-survival.fandom.com/wiki/Bottle_of_Water)).
- **Inference:** 2 Rain Catchers give 12 bottles per hour, which is 600 Thirst per hour against a drain of about 360 per hour. **Water is solved permanently by about 2 hours of early-game effort**, which matches the core doc's "meters are pacing taxes, not drama".

### 2.6 Recycling and disassembly

**[Recycler](https://last-day-on-earth-survival.fandom.com/wiki/Recycler) basics**
- **Unlock:** "Crooked Creek Farm" quest.
- **Cost:** 20 Pine Plank + 5 Iron Plate + 20 Bolts + 10 Duct Tape + 10 Rubber Parts.
- **Placement:** Plank floor (L2). **Max 1, excluding a second one bought in the shop.**
- **Upgrade:** the Recycler upgrade blueprint is the most expensive bench blueprint in the Genesis Collection, at **5,000 genome** (the account cap).

**Six recycling skills**, each up to **level 50**: Clothes, Melee Weapons (tools count as melee), Other, Mechanics, Electronics, Firearms. Disassembling an item raises the matching skill.

**Output odds**
- Each item has 1–4 outputs. Their chances rise with skill level:
  - Output 1: +1% every 3 levels.
  - Output 2: +1% every 5 levels.
  - Output 3: +1% every 10 levels.
- The wiki's summary gives 89% / 15% / 5% at level 50.
- The firearm table instead runs from Spring 80 / Factory Parts 50 / Carbon Composite 10 / Blueprint 10 at L1 to **100 / 75 / 20 / 20 at L50** (conflict between the two summaries).
- **Durability multiplies the chance.** For example, an AK at 50% durability has 5% instead of 10% for its blueprint.

**Times by category**

| Category | Time | Examples (input → possible outputs) |
|---|---|---|
| Clothes | 10 m | Reinforced Jacket → Scrap/Thick Fabric/Leather; SWAT pieces → Cloth/Steel Bar/Leather; Hazmat → Plastic/Rubber/**Lead Plate**; Military Backpack → Rope/Thick Fabric/Steel Bar |
| Melee | 10 m | Katana → Scrap/Aluminium Bar/Steel Bar; Slasher → Copper Bar/Thermite/Oak Plank; Fishing Rod → Plastic/Rope/Steel Bar |
| Other | 10 m (some 10 m 1 s) | Workbenches return part of their build cost; Car-part furniture; Empty Can → Scrap/Alu Bar; First Aid Kit → Cloth/Alcohol |
| Electronics | 30 m (Car Battery 10 m) | Batteries → Scrap/Copper Bar; Car Battery → Plastic/**Acid**/**Lead Plate**; Mobile Phone → Plastic/Hi-Tech/Electronic Circuit; USB Drive → Plastic/Transistor/Electronic Circuit; Heat sensor → Alu/Steel/Hi-Tech |
| Mechanics | 1 h (engines/generator 1 h 30 m; turret parts 30 m) | **Rusty Engine → Alu Wire/Alu Bar/Engine Part**; Intact Engine → Alu Bar/Engine Part/Steel Plate; ATV Transmission → Steel Bar/Titanium Bar/**Cog**; ATV Wheel → Scrap/Steel Bar |
| Firearms | 1 h (pistol and special guns 10–30 m) | Glock, M16, AK-47, FN SCAR, Mini Uzi, Shotgun, VSS → **Spring / Factory Parts / Carbon Composite / that gun's Blueprint**; Zip Gun → Iron Plate/Spring/Duct Tape/Zip Gun BP |

**Not recyclable:** raw and processed basics (ores, bars, plates, logs, planks, leather, cloth, rope, fiber), most food, Kevlar and Raider sets, C-4, mines, Protector, Ultimatum, coupons.

**Inference: the recycler is the main sink for loot clutter and the main faucet for mid-tier parts.**
- Factory Parts, Carbon Composite and Springs mostly come from shredding found guns.
- Engine Parts come from shredding rusty engines hauled home on the Chopper.
- Recycling a gun is also a **second-chance blueprint lottery** for that gun.

---

## 3. Stations

### 3.1 Master station table

Notes on the columns:
- **Unlock** is the current Survivor's Path quest. Legacy level and craft-point values are shown where the item page still lists them.
- **Cost** is from the current Blueprints table unless marked otherwise.
- **All stations run in real time while offline** and fire a notification when done (core doc §6).
- **Slot caps:** furnace and campfire input, output and fuel slots each cap at **20**. Upgrades add **+20 per level**.

| Station | Unlock (current / legacy) | Build cost | Floor req. | Max | Fuel? | Recipes (in → out @ time) |
|---|---|---|---|---|---|---|
| Campfire | "First Companion" | 5 Pine Log + 5 Limestone + 1 Plant Fiber | Ground | 2 | Yes | Raw Meat → Juicy Steak 2 m · 3 Berry → Berry Tea 2 m · 3 Northern Berry → Berry Tincture 2 m · Carrot → Carrot Stew 2 m (the [Carrot Stew](https://last-day-on-earth-survival.fandom.com/wiki/Carrot_Stew) page says 4 m) · Raw Turkey → Roasted Turkey 40 m · logs/planks → Charcoal (§1.2) |
| Meat Dryer | "First Companion" | 5 Pine Plank + 10 Rope + 10 Limestone | Ground | 2 | **No** | Raw Meat → Jerky 10 m |
| Garden Bed | "Resource collecting" | 5 Limestone + 1 Plant Fiber | Ground only, 2×2 | 2 | No | Seeds → 2 Carrot 1 h · Corn Seeds → Corn 1 h 30 m |
| Rain Catcher | "Neighborhood" | 5 Pine Log + 3 Cloth + 2 Scrap | Ground only | 2 | No | Empty Bottle → Water 10 m |
| Woodworking Bench | "Preparation" | 5 Pine Log + 5 Iron Ore | Wood floor L1 | 2 | No | Pine Log → Plank 4 m · 3 Oak Log → Oak Plank 20 m · 8 Ash Log → Ash Plank 1 h |
| Melting Furnace | "Exploring the Grounds" | 10 Limestone + 5 Iron Ore | Ground | 2 | Yes | 2 Iron Ore or 4 Scrap → Iron Bar 4 m · 2 Alu Wire → Alu Bar 26 m 40 s · 4 Bauxite → Alu Bar 1 h · 5 Copper Ore → Copper Bar 1 h · 5 Sand → Glass 26 m 40 s · 5 Ti Ore → Ti Bar 1 h 30 m · 16 Lead → Lead Bar 30 m |
| Stonecutter's Table | "Saving the Survivors!" / L14 | 10 Pine Plank + 5 Iron Bar + 5 Scrap | Floor L1 | 2 | No | 2 Limestone → Stone Brick 4 m · 4 Quartz → Processed Quartz ? · 8 Antimony → Refined Antimony 10 m |
| Kitchen stove | "My home is my fortress" | 10 Iron Bar + 15 Pine Plank + 15 Stone Brick + 10 Scrap + 5 Adhesive | Stone floor L3 | **1** | ? | Discovery-based fish recipes with timed buffs, 25 m – 2 h 38 m (§5.4) |
| Gunsmith Bench (2-phase) | "Gunsmith's House" | 20 Pine Plank + 10 Iron Bar + 10 Rubber Parts + 5 Adhesive + 10 Bolts + 2 Small Box (the page says its old phase-2 list "is removed as of 1.42.1"; whether finalization still exists is unclear) | Plank floor L2, 2×2 | 1 | No | Weapon mod crafting/attachment: 23 moddable weapons, 236 mods (145 common, 41 rare, 25 extremely rare, 23 with active skills) |
| Tanning Rack | "Gunsmithing" / L14 | 10 Pine Plank + 5 Iron Bar + 10 Rope + 5 Scrap | Ground only | 2 | No | Rawhide → Leather 4 m · 2 Fiber → Rope 4 m · 2 Fur → Tanned Fur ? |
| Workbench | "Home Comfort" / L28 | 15 Pine Plank + 10 Iron Bar + 10 Stone Brick + 5 Adhesive | Plank floor L2 | 2 | No | Iron Bar → Iron Plate 20 m · 2 Alu Bar → Alu Plate 1 h · Iron Plate → 2 Nails 4 m · Alu Plate → 2 Bolts 10 m · Steel Bar → Steel Plate 1 h 30 m |
| Sewing Table | "Self Defense" | 15 Pine Plank + 10 Iron Bar + 5 Rubber Parts + 5 Adhesive | Plank floor L2 | 2 | No | 2 Fiber → Cloth 2 m · 2 Cloth → Thick Fabric 2 m · 2 Wool → Woolen Fabric 2 m · 2 Prot. Fabric piece → Protective Fabric 12 m · 2 Tough Leather → Sturdy Belts ? |
| Recycler | "Crooked Creek Farm" / L32 | 20 Pine Plank + 5 Iron Plate + 20 Bolts + 10 Duct Tape + 10 Rubber Parts | Plank floor L2 | 1 (+1 shop) | No | §2.6 |
| Medical Table | "Police Search" / L34 | 20 Pine Plank + 15 Iron Bar + 7 Nails + 3 Duct Tape + 5 Iron Plate + 2 Plastic | Plank floor L2 | 2 | No | 5 Berry → Alcohol 10 m · 2 Seaweed → Iodine 10 m |
| Electric Generator (2-phase) | "Bunker Alfa" / L34 | 10 Iron Plate + 15 Bolts + 5 Wrench; finalize: 10 Iron Plate + 40 Duct Tape + 10 Gasoline + 40 Bolts + 15 Rubber Parts + 20 Ball Bearing | Ground | 1 | — | Quest object: powers the Northern Watchtower, Bunker Bravo, Port Sewer (Chopper/ATV hauls it) |
| Garage | "Chopper" | 15 Scrap + 10 Bolts + 20 Stone Brick + 12 Pine Plank + 8 Rubber Parts + 10 Iron Bar | Ground, 4×3 | 1 | — | Chopper repair, wash (5 water), patterns; garage workbench (Scouting, 1.40+) |
| Buzzsaw | "Chopper" | 15 Pine Plank + 10 Iron Bar | Stone floor L3 | 1 | No | Opens heavy crates for a resource fee: 32 m 30 s – 60 m, skip 18–20 coins (§2.1). Replaced the Acid Bath in 1.47 |
| Refined Melting Furnace | "Protection From Frost" | 20 Oak Plank + 20 Stone Brick + 20 Iron Bar + 10 Iron Plate | Any floor | **1 (2 if a second is bought in the shop)** | Yes | Steel Bar 1 h 30 m · 2 Brick 1 h 30 m · Titanium Alloy 2 h · Tungsten Bar (not available) |
| Chemistry Station | "Protection from Spores" / L94 | 10 Steel Plate + 20 Oak Plank + 10 Rubber + 20 Nails + 25 Alcohol + 10 Iodine (the page says 3 Acid instead of Iodine, conflict) | Iron floor L4 | 1 | Yes (on the fuel table) | Acid 1 h · Gunpowder 1 h · Spore Blocker 4 m · Sporicide 4 m |
| Laboratory | "Laboratory" quest (the page says "The finish line", conflict) | 16 Oak Plank + 3 Ti Alloy + 20 Wiring + 15 Protective Fabric + 16 Rubber + 5 Carbon Composite | Stone floor+ | 1 | ? | Wiring, Electronic Circuit, Explosive Material, Car Battery, Flight Controller, Hi-Tech Components, Heat sensor (timers not found). Renamed from Electronics Lab and given upgrade levels in 1.51.1 |
| Pressing Machine | "Into the Unknown" / L70 | 20 Ball Bearing + 5 Steel Plate + 5 Gun Oil + 1 Car Battery + 4 Ash Log (old page: 15 Steel Plate, 15 Gun Oil, 20 Spring, 10 Wrench, 5 Hammer) | Iron floor L4 | 1 | No | Iron Plate (from scrap) 20 m · Rubber 1 h · Reinforced Fabric ? · Fuel Briquette 20 m · Lead Plate 1 h · Corn Starch (corn + acid) ? |
| Hydroponic System | "Expedition Begins" | §2.2 | Iron/Brick floor | 1 | No | 3 Sprout → Spices 1 h 30 m |
| Hand Pump | "First Field Trip" | §2.5 | Ground only | 2 | No | Instant water |
| Repair Workbench | Genesis Collection: 3,600 genome **and** 10 Borealis kills | 10 Oak Plank + 10 Rubber + 6 Steel Plate + 20 Wiring + 10 Bolts + 10 Scrap | ? | 1 | ? | Restores durability; consumes materials such as Thermite (e.g. Flare Gun 9% per Thermite). The VIP-zone repair bench takes 12–24 h, sometimes 2 days |
| Ore Extractors | Events / shop only | — | Ground only | 2 per type | Gasoline | §2.1 |
| Turkey Coop / Caiman Farm / Boar Farm | Season or event rewards | — | Ground / any | 1 | No | §2.2 |
| Dog Crate, Cat Tree / Playpen, Robodog dock | Path quests / Genesis | — | — | — | — | Companion timers (core doc §13) |

Sources: the station pages linked in [Sources](#sources), plus [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints).

### 3.2 Fuel

| Fuel | Burn time (Furnace / Campfire / Refined) | "Log equivalence" (wiki) |
|---|---|---|
| Pine, Oak, Ash Log | **2 m** on the station pages; the [Fuel](https://last-day-on-earth-survival.fandom.com/wiki/Fuel) page says 1 m 20 s (conflict) | 1 |
| Pine, Oak, Ash Plank | 3 m | 2.25 |
| Charcoal | 5 m 20 s | 4 |
| Fuel Briquette | 12 m | 9 |
| Gas Cylinder | 9 h 59 m in an advanced station (column ambiguous on the wiki) | — |
| Energy cell | listed, value blank | — |

**Inference: fuel and stack caps set the check-in cadence.**
- A full 20-stack of Charcoal burns for about 1 h 47 m. A 20-stack of Briquettes burns for 4 h.
- **Input stack × recipe time** sets how long a station can run unattended:
  - Iron bars: 20 × 4 m = 80 m.
  - Steel: 20 × 1 h 30 m = 30 h.
- **Fast recipes force frequent visits, slow recipes allow overnight queues.** Bench upgrades (+20 slot cap per level) are effectively *longer offline queues*.
- The wiki documents a trick: put a single fuel item in, let it ignite, then add a full stack. This bypasses the fuel cap.

### 3.3 Station upgrades (bench levels)

Since 1.30.1 (more in 1.35 and 1.51.1), benches level up "like chests". The upgrade button sits in the bench window and is blocked while the bench is busy or on an unsuitable floor ([Kefir FAQ 958](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/958-how-do-i-upgrade-workbenches/)).

Each level needs a **unique upgrade blueprint bought with Infected Genome in the Genesis Collection**, plus materials. What a level grants is documented only for a few benches:

| Station | Level 2 cost (besides blueprint) | Effect per level | Genesis blueprint price (purchase limit) |
|---|---|---|---|
| Melting Furnace | 15 Thermite + 15 Steel Bar (L3: blueprint + ?) | +20 slot stack | 1,350 (2) |
| Woodworking Bench | 15 Steel Plate + 20 Oak Plank | +20 slot capacity | 1,350 (2) |
| Campfire | 10 Woolen Fabric + 15 Oak Plank | +20 slot stack | 1,350 (2) |
| Meat Dryer | ? | ? | 900 (2) |
| Tanning Rack | ? | ? | 900 (2) |
| Workbench | ? | ? | 2,000 (2) |
| Sewing / Stonecutter / Medical Table | ? | ? | 2,000 each (2) |
| Refined Melting Furnace | ? | ? | 2,000 (2) |
| Recycler | ? | ? | **5,000 (2)** |
| Chemistry Station / Pressing Machine / Buzzsaw | ? | ? | 2,700 each (1) |
| Laboratory / Hydroponic | ? | ? | 1,600 each (1) |
| Garage | ? | ? | 500 (4, North tab) and 1,200 (4, Bogs tab) |
| Dog Crate | ? | ? | 1,250 (1) |
| Robodog Docking Station | ? | ? | 1,500 (1) |

**Inference:**
- The "limit" column is the number of purchasable levels, so most benches go to L3.
- 1.51.1 "new workbench levels" and a "Storage for Alloys" exist in the patch notes, but no wiki page documents them yet.
- **Genome cost to fully upgrade every production bench above (excluding Garage, Dog Crate and Robodog dock): about 53,000.** See §7.2 for what that means in days.

### 3.4 Which station unlocks which recipes (dependency view)

```
Hand ─► Hatchet/Pickaxe/Basic Backpack/Small Box (starter)
Campfire ─► food, Charcoal ───────────────┐
Woodworking ─► Pine/Oak/Ash Planks ───────┤
Stonecutter ─► Stone Brick ───────────────┼─► walls/floors L2–L3 (core doc §7)
Melting Furnace ─► Iron/Alu/Cu/Ti/Lead bars, Glass
   └─► Workbench ─► Iron/Alu/Steel Plates, Nails, Bolts ─► iron tools, reinforced clothes, Recycler, Medical Table
Tanning Rack ─► Leather, Rope, Tanned Fur ─► leather/fur armor
Sewing Table ─► Cloth, Thick/Woolen/Protective Fabric ─► Tactical/SWAT/Hazmat armor
Refined Furnace (needs Fe+Al+Cu) ─► Steel Bar, Brick, Titanium Alloy ─► Steel Plate (Workbench), Military Backpack, Scorcher, C-4
Medical Table ─► Alcohol, Iodine ─► First Aid Kit, Chemistry Station, Iodine chain
Chemistry Station ─► Acid, Gunpowder, Spore Blocker, Sporicide ─► guns, Inhaler, anti-spore gear, Car Battery
Laboratory ─► Wiring, Electronic Circuit, Hi-Tech, Explosive Material, Car Battery ─► C-4, Land Mine, ATV parts, drone
Pressing Machine ─► Rubber, Lead Plate, Reinforced Fabric, Fuel Briquette ─► CBRN set, Ultimatum, turrets
Recycler ─► Springs, Factory Parts, Carbon Composite, Engine Parts, weapon blueprints ─► guns, vehicles
Gunsmith Bench ─► weapon mods
```

---

## 4. Crafting progression ladder

**How crafting works now** ([Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints)):
- **Unlocks:** every recipe except the four starters is unlocked by a **Survivor's Path quest** or bought in the **Genesis Collection**. Weapon blueprints can also drop from recycling that weapon.
- **Inputs:** they come from inventory first, then from nearby storages.
- **Quality of life:**
  - A quantity slider (1.41).
  - "Auto filling of blueprints" (1.18.2).
  - A **"Fill" button** that pulls inputs from base storage (1.53).
- **Big builds are two-phase:** craft the frame, place it, then **finalize** it with a long parts list.

### 4.1 Tools

| Item | Tier | Recipe | Station | Unlock | Durability | Notes |
|---|---|---|---|---|---|---|
| Hatchet | T1 | 3 Pine Log + 3 Limestone | Hand | Starter | 50 | Pine only; breaks one L1 wall per hatchet |
| Pickaxe | T1 | 3 Pine Log + 3 Limestone | Hand | Starter | 50 | Limestone, iron |
| Iron Hatchet | T2 | 5 Iron Bar + 3 Pine Plank + 2 Nails + 5 Duct Tape | Hand | "Limestone Cliffs" | 75 | Oak; breaks one L2 wall. Genesis: 20 genome |
| Iron Pickaxe | T2 | same | Hand | "Limestone Cliffs" | 75 | Copper. Genesis: 20 genome |
| Shovel | T2 | 8 Pine Plank + 7 Iron Bar + 3 Nails | Hand | "Crooked Creek Farm" | 70 / 35 as tool | Sand, peat, stashes, saplings, thermite |
| Torch | T2 | 4 Oak Plank + 5 Thick Fabric | Hand | "SOS Signal" | 100 | Light, scares animals, fire DoT |
| Fishing Rod | T2 | 3 Pine Plank + 5 Duct Tape + 5 Rope + 3 Adhesive | Hand | "Search for Survivors" + Fisherman skill | 10 | Pro rod: 20, not craftable |
| Crowbar | T2 | 7 Iron Bar + 3 Leather | Hand | "Bunker Alfa" | 100 | Opens locked doors (Bunker Alfa L3, PD, camps) |
| Manual earth drill | T3 | 1 Steel Bar + 3 Engine Part + 2 Thermite + 15 Wiring + 2 Gasoline | Hand | "Protection from Spores" | 40 | Titanium, quartz, halite. Genesis: 120 genome |
| Chainsaw | T4 | Table: 1 Lead Bar + 1 Electronic Circuit + 2 Gun Oil + 3 Engine Part; page: 5 / 5 / 10 / 15 (conflict) | Hand | Genesis 2,000 genome | ? | Ash trees; AoE armor-piercing melee |
| Starter Unit | consumable | 1 Ti Bar + 1 Gun Oil + 1 Thermite | Hand | "Laboratory" quest | — | Genesis: 70 genome |

### 4.2 Melee weapons

Damage and speed figures are Wasteland values from the weapon infoboxes.

| Item | Tier | Recipe | Unlock | Durability | Dmg / speed | Notes |
|---|---|---|---|---|---|---|
| Fists | — | — | — | — | 6 / 1.8 | — |
| Spear | T1 | 3 Pine Log | "Resource collecting" | 100 | 10.2 / 1.1 | Cheap "wall trick" ammo |
| Makeshift Bat | T1 | 5 Pine Plank + 3 Duct Tape | "Home Improvement" | 100 | 14 / 1.0 | — |
| Cleaver | T2 | 5 Iron Bar + 5 Plank + 4 Bolts | "Gunsmith's House" | 100 | 17 / 1.4 | Starter loot in the pickup |
| Crowbar | T2 | 7 Iron Bar + 3 Leather | "Bunker Alfa" | 100 | 17 / 1.6 | — |
| Metal Pipe | T2 | 10 Iron Bar + 5 Bolts + 5 Leather + 1 Iron Plate | "New Territories" | 90 | 26 / 1.3 | — |
| Machete | T3 | 15 Iron Bar + 3 Plank + 12 Leather | "First Aid" | 80 | 30 / 1.3 | Free on 5th death (core doc) |
| Skull Crusher | T3 | 12 Iron Bar + 12 Nails + 2 Stone Brick + 5 Leather + 4 Duct Tape | "Chopper" | 45 | 45 / 0.7 | Pre-placed in the Weapon Rack |
| Saw Blade Mace | T3 | 15 Iron Bar + 10 Plank + 5 Duct Tape + 5 Scrap + 12 Leather | "Northern Watchtower" | 30 | 55 / 0.7 | High damage, very low durability |
| Slasher | T4 (North) | 10 Copper Bar + 8 Oak Plank + 4 Thermite + 4 Alu Plate + 6 Bolts | "Maximum Warming" | 90 | 13 (46 with effect) / 0.8 | Cold weapon; repaired with Thermite |
| Katana | premium | not craftable | Path premium ("Resource collecting") | 70 | 35 / 1.3 | Premium reward in chapter 2 |
| Chainsaw | T5 | §4.1 | Genesis | ? | 40 / 0.9 | — |

### 4.3 Ranged, thrown and deployables

| Item | Tier | Recipe | Unlock | Durability | Dmg / speed | Notes |
|---|---|---|---|---|---|---|
| Bow | T1 | 5 Plank + 1 Iron Bar + 5 Rope + 3 Duct Tape + 3 Adhesive | "Exploring the Grounds" | 50 | 8–20 / 0.6–1.0 | — |
| Makeshift crossbow | T2 | 10 Iron Bar + 5 Plank + 5 Duct Tape + 5 Alu Wire + 10 Nails | "Self Defense" | 35 | 50 single / 27 multi | — |
| Zip Gun | T2 | 16 Iron Plate + 4 Spring + 5 Duct Tape + 3 Bolts + 1 Oak Plank + 8 Adhesive | "Safe and Warm" | 100 | 18 / 0.8 | — |
| Molotov Cocktail | T2 | 1 Strong alcohol + 2 Thermite + 4 Piece of Wool | "Safe and Warm" | consumable | 5 (18 with effect) | — |
| Flare Gun | T3 | 5 Alu Plate + 5 Plastic + 4 Thermite + 10 Iron Plate | "Northern People" | 32 | 10 (35 with effect) | — |
| Scorcher | T3 | 8 Steel Bar + 8 Oak Plank + 4 Thermite + 4 Factory Parts + 3 Spring | "Path to the Ship" | 70 | 11 / 2.0 | — |
| Crossbow | T3 | 5 Alu Wire + 4 Factory Parts + 3 Steel Plate + 3 Oak Plank + 5 Spring + 10 Duct Tape | "Scientists' Base" | 35 | 70 / 0.6 | — |
| Glock 17 | T3 | 15 Titanium Bar + 15 Bolts + 8 Spring + 5 Gunpowder + 3 Carbon + 2 Factory Parts | "Lost assistant" (Settlement) | 100 | 20 / 3.3 | Path premium reward in chapter 1; free on 100th death |
| M16 | T4 | 17 Titanium Bar + 4 Spring + 5 Ash Plank + 5 Gunpowder + 5 Carbon + 3 Factory Parts | "Got Connection" | 170 | 12 / 8.3 | — |
| Anti-Spore Pistol / Rifle / Sniper | T4 (Islands) | 2 Glass + 3 Thick Leather + 5 Spring + 5 Plank + 4 Iron Bar + 2 Alcohol / 4 Lens + 4 Rubber + 4 Sporicide + 4 Copper Bar + 4 Glass / 2 Ti Alloy + 4 Glass + 6 Sporicide + 4 Lens + 3 Engine Part + 10 Spring | "Sprouts of Evil" / "Mineral Resources" / "Extent of the Threat" | 60 / 88 / 79 | 8 / 10 / 16 (×5 vs spore enemies) | — |
| Neutralizer | T4 (Bogs) | 2 Protective Fabric + 1 Gun Oil + 1 Ti Bar + 3 Spring | "Laboratory" | 100 | 30 / 2 | — |
| The Equalizer | T5 | 1 Refined Antimony + 1 Factory Parts + 1 Electronic Circuit + 3 Ash Plank | "Settle in the bogs" | 170 | 15 / 8.3 | — |
| Ultimatum | T5 | 1 Lens + 2 Factory Parts + 1 Lead Plate + 2 Gunpowder | "Into the Unknown" | 28 | 110 / 0.7 | — |
| Flamethrower | Genesis (550) | 4 Steel Plate + 4 Rubber + 3 Thermite + 3 Factory Parts + 4 Gasoline | Genesis | ~160 | 2 / 8.3 (fire) | — |
| Apocalypse Breath | Genesis (550) | 5 Ti Bar + 4 Copper Bar + 6 Oak Plank + 4 Thermite + 3 Factory Parts | Genesis | ~150 | 10 + fire DoT | — |
| Spore Destroyer / Dissolver | Genesis (1,000 each) | Ti Alloy + Sporicide-based | Genesis | 20 / ? | 50 / 3 | — |
| Protector / Resonator | Genesis (2,000 each) | 1 Heat sensor + 1 Factory Parts + 1 Gunpowder + 2 Ash Plank / 1 Lead Plate + 1 Gunpowder + 2 Ash Plank + 10 Wiring | Genesis | 40 / 200 | 65 / 14 | — |
| Portable Turret T-I / II / III | Genesis (2,000 / 3,500 / 5,000, sequential) | 1 Refined Antimony + 1 Electronic Circuit + 1 Gun Oil / 1 Lead Plate + 2 Ash Plank + 1 Gun Oil + 1 Carbon / 1 Hi-Tech + 1 Gunpowder + 1 Ti Bar | Genesis | ? | ? | Max 3 per location |
| Land Mine | T4 | 1 Lead Bar + 1 Explosive Material + 2 Carbon + 5 Spring | "Storehouse" | consumable | 400 | — |
| C-4 Explosive | T5 | 20 Steel Bar + 15 Spring + 20 Hi-Tech + **18 Explosive Material** + 10 Plastic + 25 Wiring | "Intruders" | consumable | — | Raid breach for L3 walls (core doc §7) |
| **Not craftable (Tungsten):** Shotgun, AK-47, VSS Vintorez, The Dragunov | — | Tungsten Bar recipes | "First Field Trip", "New Responsibility", "Toxic water", "Alternating Current" | 40 / 170 / 60 / 36 | 70 / 15 / 50 / 130 | Obtainable only as loot, Path/season **premium**, events or recycler drops |

### 4.4 Armor sets

Defence values below are helmet / torso / legs / feet. Damage reduction is A / (A + 50/3) (core doc §11).

| Set | Tier | Torso recipe (example) | Unlock | Defence H/T/L/F | Durability | Special |
|---|---|---|---|---|---|---|
| Basic (Dad Hat, Shirt, Cargo Pants, Sneakers) | T1 | Shirt: 4 Fiber + 4 Cloth | "Neighborhood" | 2 / 3 / 3 / – | ? | Cold 1–2, spore 1–2 |
| Reinforced basic (Shirt, Trousers, Sneakers) | T1+ | Shirt + 5 Rope + 2 Leather + 2 Adhesive | "Home Comfort" | – / 5 / 4 / 1 | ? | Upgrade-by-consuming-base-item pattern |
| Leather (Beanie, Thick Jacket, Denim Jeans, Work Boots) | T2 | 5 Leather + 7 Rope + 7 Thick Fabric + 3 Adhesive | "Recycling" | 3 / 6 / 5 / 2 | 150 | — |
| Reinforced (Beanie, Jacket, Jeans, Boots) | T2+ | Thick Jacket + 2 Iron Plate + 2 Nails + 3 Leather + 5 Adhesive | "First Aid" | 4 / 7 / 6 / 3 | 180 | Unknown Box reward pool |
| Tactical | T3 | 10 Thick Fabric + 8 Leather + 4 Iron Plate | "Northern Watchtower" | 5 / 8 / 7 / 4 | 150 | Path premium in "Recycling"/"New Territories" |
| Fur | T3 (cold) | 6 Tanned Fur + 3 Leather + 6 Thick Fabric + 2 Iron Plate + 2 Adhesive | "SOS Signal" | 4 / 5 / 5 / 2 | 150 | Cold 3 / 5 / 4 / 3 |
| Reinforced Fur | T3+ | Fur Jacket + 12 Tanned Fur + 9 Woolen + 2 Leather + 2 Copper Bar + 5 Iron Plate | "Protection From Frost" | 6 / 8 / 8 / 4 | 180 | Cold 4 / 8 / 7 / 4 |
| SWAT | T4 | 12 Thick Fabric + 10 Woolen + 3 Steel Plate | "New Home" (Settlement) | 7 / 10 / 10 / 5 | 150 | — |
| Kevlar | T4 | 8 Ti Bar + 8 Leather + 7 Thick Fabric + 5 Carbon + 4 Plastic + 3 Steel Plate | "Storehouse" | 8 / 12 / 12 / 6 | 150 | Not recyclable |
| Anti-Spore | T4 (Islands) | 5 Tanned Fur + 5 Thick Leather + 4 Woolen + 2 Copper Bar + 4 Plastic + 5 Glass | "Sprouts of Evil" | 4 / 6 / 6 / 2 | 150 | Spore 3 / 5 / 4 / 2 |
| Enhanced Anti-Spore | T4+ | 5 Thick Leather + 9 Spore Blocker + 5 Rubber + 4 Lens + 2 Copper Bar + 2 Air Filter | "Extent of the Threat" | 6 / 8 / 8 / 4 | 180 | Spore 4 / 8 / 7 / 4 |
| Hazmat | T5 (Bogs) | 4 Protective Fabric + 3 Thick Hide + 4 Woolen + 1 Ti Bar | "Laboratory" | 2 / 4 / 3 / 1 | 150 | Radiation 5 / 8 / 7 / 5 |
| CBRN Combat | T5+ | 3 Lead Bar + 5 Reinforced Fabric + 1 Carbon + 2 Acid + 8 Tough Leather + 1 Ti Bar | "Into the Unknown" | 7 / 10 / 10 / 5 | ? | Radiation 4 each |
| Assault | T6 (not craftable) | 20 Thick Fabric + 7 Leather + **5 Tungsten** + 18 Carbon + 10 Plastic + 8 Steel Plate | "New Heights" | 14 / 20 / 20 / ? | **400** | Premium/season only |

**Inference: the armor ladder alternates two kinds of rung.**
- **General defence rungs:** Leather → Reinforced → Tactical → SWAT → Kevlar → Assault.
- **Regional-hazard rungs:** Fur for cold, Anti-Spore for spores, Hazmat/CBRN for radiation. These trade defence for a hazard stat.
- "Reinforced X" recipes **consume the lower item** as an ingredient, so upgrades are a material sink.

### 4.5 Backpacks

| Backpack | Slots added | Recipe | Unlock | Notes |
|---|---|---|---|---|
| Basic Backpack | +5 | 2 Rope + 3 Plant Fiber | Starter | The Chopper eats 4 of them (finalization) |
| Military Backpack | +10 | 10 Thick Fabric + 2 Steel Plate + 15 Rope | "Path to the Ship" (North ch. 6) | Also a premium reward in "Self defense" and "Northern Watchtower"; in the Unknown Box pool |
| Tactical Backpack | +15 | 20 Leather + **5 Tungsten** + 10 Thick Fabric + 15 Plastic + 3 Adhesive | "Secret Research" (not craftable) | **Premium reward** of "Alternating Current" |
| Dog Saddle Bag | dog storage | 18 Tanned Fur + 16 Woolen + 8 Ti Bar + 8 Steel Plate + 18 Rope | Genesis 2,070 | — |
| Robodog Storage Compartment | +2 Robodog slots | 1 Refined Antimony + 2 Ash Plank, 5 m | Robodog dock | Expanded version exists (data not found) |

### 4.6 Blueprint and part gating: two-phase builds

| Build | Phase 1 (frame) | Phase 2 (finalize) | Gate | Scarce inputs |
|---|---|---|---|---|
| **Chopper** (bike) | 10 Pine Plank + 5 Iron Bar + 5 Bolts; Plank floor L2, 2×2 (legacy unlock L6) | 30 Bolts, 10 Ball Bearing, 1 Chopper Fork, 1 Chopper Gas Tank, **4 Basic Backpack**, 30 Scrap, 20 Rubber Parts, **2 Chopper Wheel**, 10 Wiring, **20 Engine Part** | The frame sits pre-placed at home from minute one; the "Chopper" quest | Fork, tank and wheels: rare Bunker Alfa yellow/red coupon crates or the Farm barn. Engine Parts |
| Chopper upgrades | — | Give parts to the Gas Station Mechanic (Jane): each Chopper Wheel = **500 chopper EXP**; Engine Parts accepted | 1.47 bike upgrades | — |
| **Motorboat** | 10 Copper Bar + 15 Oak Plank + 3 Hammer + 10 Bolts + 10 Nails + 3 Wrench; Stone floor, 4×2 | 30 Alu Plate, 30 Rubber, **2 Boat engine**, 20 Oak Plank, 20 Gasoline, 16 Steel Plate, 10 Pump, 30 Plastic, 20 Carbon, 30 Spring | "Northern Horror" | Boat engine ×2, each = 10 Engine Part + 3 Propeller + 20 Plastic + 10 Wrench + 10 Air Filter + 20 Rubber Parts |
| **ATV** | 25 Iron Bar + 20 Plank + 15 Wiring + 15 Bolts + 10 Duct Tape; Stone floor, 3×3 | 250 Rubber, 150 Air Filter, 16 ATV Wheel, 200 Steel Plate, 30 Gas Cylinder, 10 ATV Transmission, 200 Carbon Composite, 60 Car Battery, **200 Engine Part**, 200 Cog | "Spore Source" (end of the Islands chapter) | Wheels and transmissions on **3-day Genesis Storage cooldowns** |
| ATV levels | — | Feed parts for points: Transmission 6,000 (1/day), Wheel 3,000 (1/day). Level 2 = 1,000 pts, L40 = 18,500, L56 = 35,000 | ATV Garage | Each level: pick 1 of 3 specs |
| ATV Garage | 4 Ti Alloy + 12 Oak Plank + 10 Nails + 8 Glass + 5 Gun Oil | — | "Spore Source" | — |
| Gunsmith Bench | §3.1 | phase 2 removed 1.42.1 | "Gunsmith's House" | 2 Small Box |
| Electric Generator | §3.1 | 10 Iron Plate + 40 Duct Tape + 10 Gasoline + 40 Bolts + 15 Rubber Parts + 20 Ball Bearing | "Bunker Alfa" | Needs a vehicle to haul it |
| Acid Bath (removed 1.47) | 25 Plank + 40 Iron Bar + 10 Alu Bar + 20 Stone Brick | 20 Alu Plate, 50 Wiring, 10 Cog, 5 Circuit, 30 Rubber Parts, 15 Engine Part, 25 Steel Plate, 15 Alu Bar, 25 Air Filter, 100 Bolts | Bunker Alfa F3 blueprint | Historical example of a "deposit wall" |
| Mi-24 Helicopter | 20 **Tungsten** + 20 Hi-Tech + 18 Wiring + 20 Ball Bearing + 25 Bolts + 25 Ash Plank | ? | "Flying Assistant" | Not craftable |

### 4.7 Survivor's Path quest chain and rewards

**Structure**
- Two independent tracks with **free and premium rewards** on every quest.
- Premium and Premium+ are time-limited purchases, separate from the season pass. Ultra / Ultra Plus are 30-day subscriptions: +10% XP, or +20% XP plus +10% season XP and no ads.
- Source: [Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path) and the chapter templates.

In the tables below, **BP** means the quest unlocks that recipe.

**Survival track**

| Ch. | Quest | Free: blueprint unlocks | Free: items | Premium rewards |
|---|---|---|---|---|
| 1 New beginning | Settling In | — | 10 Canned Food, 10 Water | Glock 17, 10 First Aid Kit |
| | Clean Home | — | 20 Pine Log, 10 Limestone | 2 Iron Hatchet, 2 Iron Pickaxe |
| | Restoration | — | Cleaver, 10 Bandages | 20 Pine Plank, 20 Stone Brick |
| 2 True friend | Resource collecting | Spear, Garden Bed | 10 Cloth, 5 Empty Can | **Katana, Reanimator** |
| | Preparation | Woodworking Bench, Dog Crate | 10 Bolts, 20 Scrap | 10 Duct Tape, 10 Rubber Parts |
| | Home Improvement | Makeshift Bat, Bandages | Road Sign, 10 Rope | Reinforced Beanie + Jacket |
| | Neighborhood | Rain Catcher, Shirt, Dad Hat, Cargo Pants, Sneakers | 10 Plank, 10 Duct Tape | Reinforced Jeans + Boots |
| | First Companion | Campfire, Meat Dryer | 2 Shepherd Puppy, 10 Raw Meat | 2 Shepherd Puppy, 3 Dry Food |
| 3 Powershot | Exploring the Grounds | Melting Furnace, Bow | Dad Hat, Shirt | Saw Blade Mace, 5 Grenade |
| | Search for Survivors | Shower, Fishing Rod | Cargo Pants, Sneakers | 20 Bolts, 20 Rubber Parts |
| | Saving the Survivors! | Spike Trap, Stonecutter's Table | Zip Gun, 10 Rubber Parts | 40 Plank, 20 Iron Bar |
| | My home is my fortress | Trip Wire Trap, Kitchen stove | 10 Duct Tape, 10 Adhesive | Colt Python, 10 First Aid Kit |
| | The Marine Calls | Houseplant, Bear Trap | 20 Plank, 10 Iron Bar | 200 Caps, 2 B-Complex |
| | Gunsmith's House | Gunsmith Bench, Cleaver | 10 Leather, 10 Juicy Steak | "Pathfinder" outfit + backpack style |
| | Gunsmithing | Tanning Rack, Doormat | Machete, common mod BP | **AK-47**, extremely rare mod BP |
| 4 Iron Warrior | Home Comfort | Reinforced Shirt/Trousers/Sneakers, **Workbench**, Cat Playpen, Cat Tree | — | 20 Bolts, 10 Plastic |
| | Limestone Cliffs | Iron Hatchet, Iron Pickaxe | 20 Plank, 20 Stone Brick | 10 Alu Bar, 10 Iron Plate |
| | Self defense | Sewing Table, Makeshift crossbow | Weapon Crate, 10 First Aid Kit | **Military Backpack**, 5 Land Mine |
| | Crooked Creek Farm | **Recycler**, Shovel | 20 Bolts, 20 Rubber Parts | **Chopper Wheel**, 5 Wrench |
| | Recycling | Thick Jacket, Beanie, Denim Jeans, Work Boots, Mirror | 10 Mobile Phone, 20 Wiring | Tactical Cap + Body Armor |
| | New Territories | Dining Table, Metal Pipe | 10 Ball Bearing, **10 Engine Part** | Tactical Trousers + Boots |
| | Police Search | Medical Table, First Aid Kit | Mini Uzi, 5 Sergeant Card | M16, 2 Captain Card |
| | First Aid | Machete, Reinforced Jacket/Beanie/Jeans/Boots | Crowbar, 10 Ration Coupon | **Chopper Fork**, 10 Gun Oil |
| | Bunker Alfa | Electric Generator, Crowbar | **Chopper Wheel**, 10 Gasoline | **Chopper Gas Tank, 10 Engine Part** |
| | Chopper | Garage, Skull Crusher, Buzzsaw | 3 Repair Kit | Shotgun, 2 Biker Magazine |
| | Northern Watchtower | Saw Blade Mace, Tactical set | 10 Thick Fabric, 10 Leather | 10 First Aid Kit, Military Backpack |
| 5 North | SOS Signal | Torch, Fur set | 10 Fur, 10 Iron Plate | 20 Thick Fabric, 20 Tanned Fur |
| | Safe and Warm | Molotov, Zip Gun | 15 Bolts, 5 Strong alcohol | 20 Wool, 5 Thermite |
| | Lost Expedition | Cozy Couch, Barbed Wire | 10 Thick Fabric, 10 Plastic | 10 First Aid Kit, 20 Oak Plank |
| | Northern People | Warming First Aid Kit, Flare Gun | 20 Aluminum Ore, 10 Wool | 5 Berry Tincture, 20 Woolen Fabric |
| | Protection From Frost | Reinforced Fur set, **Refined Melting Furnace** | 10 Alu Plate, 5 Thermite | Slasher, 5 Molotov |
| | Path to the Ship | Scorcher, **Military Backpack** | 10 Leather, 10 Oak Plank | 10 Spring, 10 Steel Bar |
| | Maximum Warming | Slasher, Floor Lamp | Flare Gun, 10 Copper Ore | 10 Warming FAK, 10 Copper Bar |
| | Northern Horror | **Motorboat, Boat engine** | Flamethrower, 10 Steel Plate | Apocalypse Breath, Factory Parts. **Unlocks the Genesis Collection** |
| 6 Off To New Shores | Scientists' Base | Crossbow | 20 Transistor, 5 Alu Bar, 5 Carbon | 10 Alu Plate, Electronic Circuit |
| | Helping Chris | Weapon Stand | 10 Iron Plate, 5 Rubber, 10 Plastic | 10 Rubber, 20 Plastic |
| | Let There Be Light | — | Pump, Mini Uzi, 5 Spring, 10 Oak Plank | 4 Air Filter, 2 Propeller |
| | Iron Sail | — | 5 Engine Part, 2 B-Complex, 10 Bolts, 5 FAK | 10 Gasoline, AK-47 |
| | Conquering Heights | — | Shotgun, 100 Caps, 2 Shovel, 5 Copper Bar | 5 Combat Gear Coupon, 5 Steel Plate |
| 7 Islands | Sprouts of Evil | Anti-Spore set + Pistol | 10 Plastic, 10 Sand | 10 Glass, 15 Thick Leather |
| | Protection from Spores | **Chemistry Station**, Manual earth drill | Gas Cylinder, 5 Thermite | 10 Spring, 15 Gasoline |
| | Mineral Resources | Inhaler, Anti-Spore Rifle | 10 Spore Blocker, 10 Iodine | 5 Sporicide, 5 Halite |
| | Spore Resistance | — | 5 Steel Bar, 20 Seaweed, 10 Engine Part, 10 Rubber | 10 Processed Quartz, 5 Lens |
| | Extent of the Threat | Enhanced Anti-Spore set + Sniper | 10 Thick Leather, 10 Spore Blocker | 5 Air Filter, 20 Ti Ore |
| | Sealed | — | 2 Shovel, 10 FAK, 5 Spring, 10 Glass | 5 Ti Bar, Anti-Spore Rifle |
| | Clearing the Path | — | Anti-Spore Pistol, 10 Spore Sample, 20 Quartz, 10 Copper Bar | 5 Inhaler, 5 Sporicide |
| | Spore Source | **ATV, ATV Garage** | 10 Rubber, 10 Wiring | Anti-Spore Sniper, 5 Ti Alloy |
| 8 Heavy Machinery | Laboratory | Hazmat set, Neutralizer, **Laboratory**, Starter Unit | — | **ATV Transmission**, 5 Ti Bar |
| | Heavy Machinery | — | 20 Prot. Fabric pieces, 15 Thick Hide, 15 Wool, 10 Spring | 2 Starter Unit, Neutralizer |
| | Radiation Protection | — | 2 Ti Bar, ATV Repair Kit, 20 FAK, 100 Pine Log | 20 Gasoline, The Equalizer |
| 9 Operation "Dead Water" (1.51.1) | Expedition Begins | Hydroponic System, Anti-radiation Pills | 5 Thermite, 20 Sulfur | 2 Ti Alloy, 4 Air Filter |
| | Settle in the bogs | The Equalizer | 5 Proc. Quartz, 5 Halite, 20 Ash Log | 20 Antimony, 10 Prot. Fabric |
| | Mass Production | — | 30 Antimony, 30 Lead, 30 Alligator Skin, Gunpowder | 10 Anti-rad Pills, 3 Land Mine |
| | Into the Unknown | CBRN set, Ultimatum, **Pressing Machine**, AntiRad | — | 5 Carbon, 5 Lead Bar |
| | Thorough Preparation | — | 2 Ti Alloy, Hi-Tech, 3 Factory Parts, 10 Fuel Briquette | 5 Radiation Blocker, 3 Lead Plate |
| | On the Beast's Trail | — | The Equalizer, 2 Gunpowder, 3 Rare Weapon Module BP, 10 AntiRad | **Portable Turret T-II, Ultimatum** |
| | Bane of the Bogs | — | Heat sensor, 5 Drone Battery, extremely rare mod BP, Turret T-I | **Turret T-III**, Launchable Winch |

**Settlement track** (separate tab since 1.50)

| Ch. | Quest | Free: blueprint unlocks | Free: items | Premium |
|---|---|---|---|---|
| Expeditions | New Home | Comfortable Bed, **SWAT set** | 10 Thick Fabric, 20 Leather | 5 Screws, 20 Spring |
| | Lost assistant | **Glock 17** | 10 Alu Bar, 20 Nails | Antenna, 10 Glass |
| | Got Connection | **M16** | 20 Bolts, 10 Alu Plate, 10 Plastic | 2 Spark Plug, 10 Rubber |
| | The Finish Line | — | Slasher, 10 Mercenary's Tag | Raider's Battle Helmet + Armor |
| | First Field Trip | Shotgun (uncraftable), **Hand Pump** | weapon mod BP, 3 Land Mine | Raider's Battle Pants + Boots |
| | New Responsibility | AK-47 (uncraftable) | **FN SCAR**, 25 Universal Stripe | FN SCAR, 50 Mercenary's Tag |
| New Home | Storehouse | **Land Mine, Kevlar set** | 10 Alu Wire, 20 Iron Plate | 5 Iron wire, 10 Pine Beam |
| | Intruders | **C-4**, Spruce | Tactical Cap + Body Armor | Gas Mask, 5 Air Filter |
| | Woodshop | — | Glock 17, Tactical Trousers + Boots | 5 Asbestos, 10 Copper Bar |
| | Bunker Alfa Supplies | VSS (uncraftable) | 5 Spark Plug, 20 Spring | AK-47, **20 Engine Part** |
| | Foundry | — | 10 Iron Billet, 10 Pine Beam | outfit style, 20 Light Frame |
| Engineering Networks | Assembly | — | 20 Rubber, 20 Alu Wire, 10 Steel Plate, 20 Alu Plate | SWAT Helmet + Armor |
| | Room in the Settlement: Workshop | Tire Flowerbed, Bath with flowers | 10 Factory Parts, 10 Carbon | SWAT Trousers + Boots |
| | Alternating Current | Outdoor toilet, Dragunov (uncraftable) | VSS Vintorez, 20 FAK | VSS Vintorez, **Tactical Backpack** |
| Air support | New Heights | Assault set + Mortar (uncraftable) | 10 Seaweed, 20 Inhaler | 5 Car Battery, 20 Iodine |
| | Secret Research | Decorative Pond, Tactical Backpack (uncraftable) | 5 Circuit, 20 Plastic | 5 Flight Controller, 20 Hi-Tech |
| | Conquering Heights | Sculpture | The Equalizer, 20 Fiberglass | Ultimatum, 20 Ti Bar |
| | Flying Assistant | Mi-24 (uncraftable) | 10 Drone Parts, common mod BP | 10 Drone Battery, rare mod BP |

**Inference: the Path is the real progression gate.**
- Blueprint unlocks always sit on the **free** side. The premium side hands out exactly the **bottleneck parts and uncraftable endgame items**: Chopper Wheel, Fork and Gas Tank, 30 Engine Parts, ATV Transmission, Military and Tactical Backpacks, AK-47, VSS, Turret T-III.
- The quest's *task list* forces the player to craft or visit the previous step. For example, "Self defense" requires building a Workbench and crafting Nails, an Iron Hatchet and the reinforced set. Each quest therefore doubles as a guided sink for the materials it just unlocked.

---

## 5. Survival economy

**Meters:** Hunger and Thirst run 0–100 and drain about 1 point per 10 s, so a full meter lasts about 16–17 min of active play. At 0 you take 2 HP/s, or 5 HP/s per another wiki page (conflict; core doc §3).
- They **do not drain on the global map** per [Hunger](https://last-day-on-earth-survival.fandom.com/wiki/Hunger) and [Thirst](https://last-day-on-earth-survival.fandom.com/wiki/Thirst). The FAQ says they do (conflict).
- Health is 100 base, +2 per Bruiser level (max 120).

### 5.1 Food

Values are as listed in the food infoboxes.

| Item | Source / recipe | Station, time | HP | Hunger | Thirst | Notes |
|---|---|---|---|---|---|---|
| Berry / Blackberry / Northern Berry | Bush (3 each) | — | 5 (6 for Northern) | 2 | 1 | — |
| Edible Mushroom | Oak zones | — | 5 | 2 | 1 | — |
| Carrot | Garden Bed | 1 h, 1 seed → 2 | 5 | 5 | 5 | — |
| Raw Meat / Raw Turkey / raw fish | Animals, fishing | — | 7 | 5 | 5 | — |
| Baked Beans, Canned Food | Loot, daily inbox | — | 15 | 25 | 5 | — |
| Corn, Pumpkin | Garden Bed / event | 1 h 30 m (corn) | 15 | 25 | 5 | — |
| Carrot Stew | 1 Carrot | Campfire 2 m (or 4 m) | 20 | 25 | 5 | — |
| Juicy Steak | 1 Raw Meat | Campfire 2 m (fuel) | 20 | 30 | 5 | — |
| Jerky | 1 Raw Meat | Meat Dryer 10 m (**no fuel**) | 20 | **40** | 5 | Wiki recommends it over the steak |
| Steamed Fish | ? | ? | 20 | 30 | 5 | — |
| Carrot Sticks | ? | ? | 20 | 35 | 5 | — |
| Canned Tuna | loot | — | 35 | 25 | 10 | — |
| Meat soup (Crater) | — | — | 42 | 35 | 10 | — |
| Yakitori | event | — | 40 | 45 | 10 | — |
| Army Field Ration | loot | — | 70 | 60 | 15 | — |
| Roasted Turkey | 1 Raw Turkey | Campfire **40 m** | **100** | **80** | 5 | Ranch output (§2.2) |
| Cake with Candles / Ripe Pumpkin | events | — | 100 / 100 | 80 / 100 | 5 / 15 | — |
| Fish stew (Kitchen stove fallback) | unrecognised fish combo | Stove 33 m 20 s | full | full | full | — |

**Food multipliers:**
- Glutton: food restores +2% HP per level (max 10%).
- Strict Diet: hunger drains 2% slower per level (max 20%).
- Camel: thirst drains 2% slower per level (max 20%).

### 5.2 Drinks

| Item | Source | Thirst | Other |
|---|---|---|---|
| Bottle of Water | Rain Catcher 10 m; Hand Pump | 50 | Leaves an Empty Bottle |
| Bottle with dirty water | loot | 23 | — |
| Berry Tea | 3 Berry, Campfire 2 m | 30 | +5 Hunger |
| Berry Tincture | 3 Northern Berry, Campfire 2 m | 30 | **+5 cold resistance for 60 s** |
| Green Tea | event | 30 (2018) / 50 (2021) | — |
| Beer | loot | 20 | Forces pee |
| Strong alcohol, Champagne, Egg-nog | loot / event | 30 | — |

### 5.3 Healing ladder

| Item | Recipe | Station | Unlock | Heals | Extra |
|---|---|---|---|---|---|
| Food | §5.1 | — | — | 5–100 | — |
| Self-Healing (active skill) | — | — | Skill pick | 10 HP/s for 11 s (110) | Cooldown |
| Homebody (passive) | — | — | Skill pick | Heals over 10 min at base, −2 min per level (min 2 min) | — |
| Level-up | — | — | — | Full heal | — |
| **Bandages** | 5 Piece of Cloth | Hand | "Home Improvement" | **40** (Medic +2%/lvl, max 44) | — |
| **First Aid Kit** | 2 Alcohol + 3 Bandages | Hand | "Police Search" | **100** | Genesis: 5 for 40 genome |
| Inhaler | 4 Spore Blocker + 2 Plastic + 2 Bandages | Hand | "Mineral Resources" | 100 | Cures spores |
| Warming First Aid Kit | 1 FAK + 3 Berry Tincture + 4 Wool + 4 Fur | Hand | "Northern People" | ? | Prevents freezing |
| Anti-radiation Pills | 3 Iodine + 2 Spices + 1 Corn (table; old page 5 Iodine + 10 Spices) | Hand | "Expedition Begins" | 50 | Restores radiation-capped max HP |
| AntiRad | 2 Spices + 2 Corn Starch + 3 Water + 1 Fuel Briquette | Hand | "Into the Unknown" | — | +12 radiation armor for 5 min |
| Fish stew | stove fallback | Kitchen stove | — | Full HP, hunger, thirst | — |
| Sterile bandage / Antibiotic | Crater-only | — | — | 70 | — |
| Reanimator | shop / Genesis 55 genome / Path premium | — | — | Auto-revive within a 4 h window | Core doc §12 |

### 5.4 Buff food (Kitchen stove)

- Recipes are **discovered by experimenting** with fish combos, so they are not looted.
- Only one dish cooks at a time. Running several at once needs ads or coins to skip.
- Buffs don't stack. Duration scales with fish quality.
- Each dish row has an unlabeled number column (18, 17, 19 …). **Inference:** it is probably the coin skip cost; see §7.3.

| Dish | Ingredients | Buff | Duration B/S/G (min) | Cook time |
|---|---|---|---|---|
| Sweet and sour perch | Perch + Berry | No thirst | 20 / 25 / 30 | 30 m |
| Perch stuffed with vegetables | Perch + Carrot + Mushroom | No hunger | 20 / 25 / 30 | 30 m |
| Salmon baked with vegetables | Salmon + Carrot + Mushroom | +30% XP from zombie kills | 8 / 13 / 20 | 26 m 40 s |
| Salmon soup | Salmon + Carrot + Mushroom + Canned Food | +10/15/20% chance of an extra log | 10 / 15 / 20 | 31 m 40 s |
| Fish sticks | Salmon + Carp | +10/15/20% chance of extra ore | 10 / 15 / 20 | ? |
| Stuffed pike | Pike + Corn + Carrot + Mushroom | Map travel costs less energy | 20 / ? / ? | ? |
| Pike with mushroom sauce | Pike + Strong alcohol + Mushroom | Run faster | 6 / 12 / 18 | 45 m |
| Fish Mix | Perch + Carp + Salmon | +10 armor | 8 / 13 / 20 | 1 h 1 m |
| Thick soup with trout | Trout + Water + Mushroom + Corn | −15% active-skill cooldown | 8 / 15 / ? | ? |
| Carp stuffed with mushrooms | Carp + Carrot + Mushroom | Fish up chests more often | 10 / 15 / 18 | 25 m |
| Kitten foods (3) | 3 fish + extras | Faster kitten growth | — | 1 h 38 m – 2 h 38 m |

### 5.5 Energy restoration

| Source | Amount | Limits | Monetized? |
|---|---|---|---|
| Natural regen | 1 per 5 min, max **200** (full refill 16 h 40 m) | — | — |
| Rewarded ads | +15 each | 5 per day | Ads |
| Energy Drink | **+50** | Can't drink at full. **No longer lootable since 1.14.3** (events only) | Event reward |
| Rations | Refill (amount not found) | — | Shop, season pass, Expeditions |
| Healer | +140 via ad (core doc §8) | — | Ads |
| VIP | −10% travel cost per tier, up to **−50%** at Prestige | — | Spend tiers |
| Walker skill | Walk time −3% per level (max 15%). Energy cost bands depend on walk time | — | — |
| "Stuffed pike" buff | Cheaper map travel | 20+ min | — |
| Chopper / ATV | Travel on Gasoline instead (1 Gasoline = 25 fuel; Chopper tank 200) | — | Gasoline in packs |

---

## 6. Player level and XP

**XP sources.** XP comes from harvesting and combat, **not crafting** ([General Tips/FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ)). Sourced values:

| Action | XP |
|---|---|
| Collect any resource unit (log, limestone, mushroom, fiber…) | 10 each |
| Kill a Deer | 10 |
| Kill a Crowd Zombie | 10 |
| Kill a Raider | 30 |
| Dig a sapling | 30 (10 per dig animation) |
| Kill a Frenzied Giant | 400 |
| Read an XP magazine | 300 |
| Full clear of Pine Bushes (green zone) | about 2,050 (core doc §4) |

**XP multipliers:**
- VIP: +10% per relevant tier, **+50% at Prestige**.
- Survivor's Path Ultra +10% or Ultra Plus +20% (30-day subscriptions).
- Quick Learner skill: +5% per level (max 15%).
- "Salmon baked with vegetables": +30% on zombie kills.

**What a level gives:**
- One skill point: pick 1 of 3 random skills. A reroll costs **10 coins**, with no limit.
- A full heal.
- Cap: 200 since 1.11.5; the core doc cites 209 (unverified).
- 44 skills as of 1.15: 7 actives, 37 passives. The economy-relevant passives are listed below.

**Economy-relevant passive skills** ([New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills))

| Skill | Effect per level | Max levels | Max effect |
|---|---|---|---|
| Lumberjack / Logger | +2% extra pine / oak log | 10 | 20% |
| Iron Miner / Copper Miner | +2% extra ore | 10 | 20% |
| Skinner | +2% extra rawhide | 10 | 20% |
| Camel / Strict Diet | thirst / hunger 2% slower | 10 | 20% |
| Glutton | food heals +2% | 5 | 10% |
| Medic | bandages +2% | 5 | 10% |
| Quick Learner | +5% XP | 3 | 15% |
| Lucky | +2% rare loot from chests | 5 | 10% |
| Walker | −3% map walk time | 5 | 15% |
| Biker | −4% motorcycle fuel | 5 | 20% |
| Fishing Skill / Fisherman's Luck | +2% rod handling / rarer fish | 5 / 3 | 10% / tiered |
| Bruiser | +2 max HP | 10 | +20 |
| Homebody | base regen faster | 5 | 2 min |
| Good Memory | buffs last +6% | 5 | 30% |
| Extra Pocket, Burglar (3), Hacker, Fisherman, Trader, Builder | unlock flags | 1–3 | — |

**What each level range unlocks**
- **Now:** recipes are quest-gated, so level mainly gates *places and modes*, plus the skill pool:
  - Pine Grove and Limestone Cliffs: L10.
  - Farm and North: L15.
  - Bunker Alfa: L40.
  - Daily inbox gifts: until about L100.
  - The Crater: L100 + a quest.
  - Raiding: L150.
  - (core doc §§2, 9, 14.)
- **Legacy (pre-1.18.14, stale but still printed on item pages):** this was LDoE's original level → recipe pacing curve. It remains a useful reference for **how far apart tiers were spaced**.

| Level band (legacy) | Example unlocks |
|---|---|
| 1–10 | Starter tools; Iron Bar recipe (L6); Chopper frame (L6); Bow (L10) |
| 11–20 | Iron Hatchet/Pickaxe, Stonecutter, Tanning Rack (L14); Reinforced Shirt set (L16); Cleaver (L18) |
| 21–30 | Crowbar, Fishing Rod, Beanie/Thick Jacket set (L22); Workbench, Nail Board (L28) |
| 31–40 | Recycler, Reinforced set (L32); Medical Table, First Aid Kit, Shovel, Metal Pipe, Zip Gun, Generator (L34); Tactical set, Glock (L40) |
| 41–60 | Skull Crusher, Fur set, Trunk (L46); Machete, Hand Pump, Motorboat (L52); SWAT (L58) |
| 61–100 | Military Backpack, Wiring, Saw Blade Mace (L64); Pressing Machine (L70); Kevlar (L76); Electronic Circuit (L88); Chemistry Station, M16, Hydroponic (L94) |
| 100–140 | Hazmat, Safe (L120); Anti-radiation Pills (L135); Tactical Backpack (L140) |

**How long levels take: not found.**
- No XP-per-level table exists on the wiki, and web searches turned up nothing citable.
- The old Exploration-Experience system (removed 1.11.5) is documented as needing escalating actions per %. One player claim says 30+ actions per 1%. That system is dead.
- **Inference:** treat leveling speed as unknown. If we want a target, the legacy unlock spacing above implies the designers expected roughly 30–40 levels to reach "mid-game" (Workbench, Recycler, First Aid Kit), about 90 levels for chemistry and rifles, and 140 for the top backpack.

---

## 7. The incremental grind

### 7.1 Concrete "one more run" chains

| Goal | Bottleneck inputs | Where they come from | Timers and gates | Shop / premium shortcut |
|---|---|---|---|---|
| **Chopper** | 20 Engine Part, 2 Chopper Wheel, 1 Fork, 1 Gas Tank, 4 Basic Backpacks | Engine parts: Bunker Alfa coupon boxes, Farm, NPC bases, Airdrops, rusty-engine recycling. Fork and tank: **rare** in yellow/red coupon crates or the Farm barn | Bunker Alfa and Farm reset 48 h (core doc §9); coupon crates need coupons from mob drops (Survival Kit coupon 5–25%) | Path premium gives wheel + fork + tank + 30 Engine Parts. Shop "Mechanic's pack" and "Specialist's pack" |
| **Motorboat** | 2 Boat engines (20 Engine Part, 6 Propeller), 30 Spring, 20 Carbon, 10 Pump | Loot; recycling | "Northern Horror" quest | Path premium "Let There Be Light": 2 Propellers |
| **ATV** | 200 Engine Part, 200 Cog, 200 Steel Plate, 200 Carbon Composite, 60 Car Battery, 16 ATV Wheel, 10 Transmission, 30 Gas Cylinder, 150 Air Filter, 250 Rubber | Cog: Genesis 35 genome each (7,000 genome total). Wheel and transmission: **Genesis Storage, 1 per 3 days each** | Wheel: 16 × 3 days = **48 days** if bought; transmission: 10 × 3 = **30 days** (Inference) | Path premium (Transmission); shop packs; season premium |
| **Steel economy** (for ATV, SWAT, C-4) | Steel Bar = Fe + Al + Cu + 2 Charcoal, 1 h 30 m | Refined Furnace (max 1) → Workbench 1 h 30 m | 200 Steel Plates = **300 furnace-hours** with one furnace (Inference) | **Second Refined Furnace sold in the shop**; VIP +10–30% bench speed |
| **C-4** | 18 Explosive Material, 20 Hi-Tech, 20 Steel Bar | Each Explosive Material = 20 Alu Bar + 20 Plastic + 10 Gunpowder + 5 Gasoline; each Gunpowder = 20 Sulfur + 20 Charcoal | **Inference:** fully crafted, one C-4 = 360 Alu Bar, 360 Plastic, 180 Gunpowder (3,600 Sulfur + 3,600 Charcoal), 90 Gasoline. This looks implausibly large; verify before reuse (possible table error, or Explosive Material is mostly looted) | Season and event rewards |
| **Kevlar set** | about 30 Titanium Bar, 18 Carbon | Ti ore only from Dead Island deposits (5–8 each) or the Titanium Extractor | **Inference:** 30 bars = 150 ore = 45 furnace-hours | Brick Room 3×3 shop pack includes **90 Ti bars** |
| **Bench upgrades** | Genesis upgrade blueprints (900–5,000 genome) + materials | Genesis currency from daily regional boss kills (Borealis 300, Consilium 450, Leviathan 600; cap 5,000) | §7.2 | Rations auto-complete the dailies (core doc §15) |
| **Recycler blueprint chance** | Same gun recycled repeatedly | Bunker and PD loot | 1 h per gun; chance × durability | — |
| **Ranching** | Seeds → Turkey → Caiman → Leather | Plant fiber | 6 h + 8 h | 39 + 49 coin skips |

### 7.2 How long milestones take

**Inference** throughout, except where a source is named. Sourced inputs are in the Evidence column.

| Milestone | Evidence | Estimate |
|---|---|---|
| Water and food "solved" | 2 Rain Catchers = 12 bottles/h; Jerky with no fuel; daily inbox | First session (≤ 2 h) |
| Full Energy bar | 200 at 1 per 5 min | 16 h 40 m, so **2 real play windows per day** |
| Chopper | 20 Engine Parts from 48-h-reset bunkers and farm plus rare unique parts | Not sourced. Likely **weeks** for F2P; immediate with premium Path |
| ATV via Genesis Storage alone | 16 wheels and 10 transmissions on 3-day cooldowns | **≥ 48 days** for wheels (if they are the only source), running in parallel with ~7,000 genome for cogs |
| Every bench to max via Genesis | 41,700 for the 11 two-level benches + 11,300 for the five one-level benches = **≈ 53,000 genome** | At one Leviathan kill a day (600): ~88 days. At all three bosses a day (1,350, if possible): ~39 days |
| Every storage-upgrade blueprint | Sum of Genesis storage blueprint prices × limits ≈ **26,000 genome** | ~19–43 days on the same assumptions |
| Repair Workbench | 3,600 genome + **10 Borealis kills** | ≥ 10 boss kills, so ≥ 10 days if bosses are once a day |
| Fridge L1 (Genesis) | 800 genome | ~1–3 days |
| Recycling skill 50 in one category | Not found | Unknown |
| Player level milestones | XP curve not found | Unknown (§6) |

### 7.3 Every timer that brings players back

| Timer | Duration | Scope | Runs offline? | Skippable? | Source |
|---|---|---|---|---|---|
| Energy regen | 1 per 5 min, full in 16 h 40 m | Player | Yes | Rations, ads, drinks | [Energy](https://last-day-on-earth-survival.fandom.com/wiki/Energy) |
| Ad energy | 5 per day | Player, daily | — | — | Energy |
| Daily reset (tasks, inbox, events, Wheel of Fortune, Street food) | 24 h at **00:00 UTC** | Global | — | — | Core doc §15, VIP zone |
| Daily inbox gift | 3 water + 3 canned food per day until L100 | Player | Expires | — | FAQ |
| Station crafts | 2 m – 2 h (most 4 m – 1 h 30 m) | Station | Yes | Coins | §3.1 |
| Recycler | 10 m – 1 h 30 m | Station | Yes | Coins (assumed) | §2.6 |
| Buzzsaw crates | 32 m 30 s – 60 m | Station | Yes | **18–20 coins** | Buzzsaw |
| Rain Catcher | 10 m per bottle | Station | Yes | — | Rain Catcher |
| Garden Bed | 1 h (carrot), 1 h 30 m (corn) | Station | Yes | ? | Garden Bed |
| Hydroponic | 1 h 30 m | Station | Yes | **22 coins** | Hydroponic System |
| Seaweed Farm | 52 m 30 s | Station | Yes | ? | Seaweed Farm |
| Turkey Coop | 6 h | Station | Yes | **39 coins** | Turkey Coop |
| Caiman Farm | 8 h | Station | Yes | **49 coins** | Caiman Farm |
| Kitchen-stove buffs | 6–30 min buff; 25 m – 2 h 38 m cook | Player / station | Cook: yes | Ads or coins | Kitchen stove |
| Extractors | 1 h per ore; fuel lasts 36 m – 4 h 48 m per Gasoline | Station | Yes | — | Extractors |
| Saplings | Pine: 1 stage per 12 h; Oak: 1 stage per 24 h | Base | Yes | — | Saplings |
| Cat growth | 4 d 3 h | Pet | Yes | **299 coins** | Core doc §13 |
| Dog breeding / food timers | multi-day | Pet | Yes | Coins | Dog Crate |
| Unknown Box | **1 per hour** (ad) | Player | — | — | Unknown Box |
| Healer buffs | 1 h | Player | — | Ad | Healer |
| Genesis Storage purchases | **1 per 3 days** per item | Player | Yes | — | ATV Wheel, Cog, Carbon Composite pages |
| ATV upgrade feeding | 1 Transmission + 1 Wheel per day | Player | — | — | ATV Transmission / Wheel |
| Location resets | Resource zones on exit; Bunker Alfa and Farm 48 h; Blackport PD 3 days | Zone | Yes | — | Core doc §9 (owned by the locations doc) |
| Fishing Spot event | Lasts 12 h | Global map | — | — | Fishing Spot |
| Airdrops | Up to 3 per day at energy thresholds | Player | — | — | Core doc §8 |
| Horde | Every 24 h | Base | Yes | — | Core doc §7 |
| VIP repair bench | 12–24 h (sometimes 2 days) | Station | Yes | — | VIP zone |
| Season / events | 21 days / about 11 days | Global | — | Level skips sold | Core doc §15 |
| Path Premium, Ultra | Time-limited; Ultra 30 days | Player | — | Bought | Survivor's Path |

**Inference: coin skip prices follow a near-linear curve.**
- Sourced points:

| Timer | Skip cost (coins) | Source |
|---|---|---|
| 32 m 30 s | 18 | Buzzsaw |
| 60 m | 20 | Buzzsaw |
| 1 h 30 m | 22 | Hydroponic |
| 6 h | 39 | Turkey Coop |
| 8 h | 49 | Caiman Farm |
| 4 d 3 h | 299 | Cat |

- These fit **cost ≈ 15 + 4.25 × hours** up to 8 h. The fit also matches the unlabeled 16–20 values in the Pressing Machine, Sewing and Kitchen-stove tables.
- Very long timers get a discount: the cat would cost about 436 coins on the line.

### 7.4 Where the game deliberately slows progress, and what is sold against it

Cross-checked against the monetization doc §§3–5.

| Slowdown | Mechanism (sourced) | What is sold against it | Notes |
|---|---|---|---|
| Travel | Energy 200 cap, 1 per 5 min | Rations (shop/season), ads, VIP −10…−50%, Energy Drinks (events); coins historically (70 energy ≈ 25 coins, 2017) | Most-hated mechanic (monetization doc §7) |
| Station time | Real-time crafts; **max 1–2 per base**; 20-unit slot caps | **Coin skips** (formula above); VIP +10–30% bench speed; **a second Recycler and a second Refined Furnace sold in the shop** | Shop extra benches directly double throughput on the two slowest chains (steel, recycling) |
| Queue length | Slot cap 20, +20 per bench level | Bench upgrade blueprints for genome (grind, or Rations auto-dailies) | — |
| Storage | Small Box 15 → Chest 25 → Trunk 45 → Rack 75; specialised storages | **Fridges sold in the store** (L1 and a limited L4); storage blueprints for genome; Warehouse in shop | Monetization doc §3.9 |
| Inventory | 10 base slots + backpack | Tactical Backpack (+15) **uncraftable** but a **Path premium** reward; Military Backpack as premium too | — |
| Rare vehicle parts | Rare crate drops; 3-day Genesis cooldowns | Mechanic's / Specialist's packs; Path premium parts; season premium | Kefir's stock answer: "found in play" (monetization doc §3.10) |
| Tungsten tier | Recipe never enabled | AK-47 / VSS / Dragunov / Assault as **premium** Path and season rewards (e.g. Season 89) | **Inference:** a withheld material that turns craftable tiers into purchase-only tiers |
| Durability | Every tool, weapon and armor wears out; repair is late (genome / VIP) | Weapon and armor packs; "indestructible weapon 1 h/day" at VIP | Paid items also break (FAQ 32) |
| XP and leveling | No crafting XP | VIP +50%, Ultra +10/20%, XP boosters (2017) | — |
| Pet and ranch growth | 6 h – 4 d timers | 39–299 coin skips | — |
| Rerolls | 1-of-3 random skill choice | 10-coin rerolls | — |
| Death loss | Full inventory drop | 100-coin or ad loot restore; coin resurrection (1.52) | Core doc §12 |
| Gathering effort | Manual harvesting | **Rations auto-clear** a zone into the inbox | Core doc §4 |

### 7.5 Design reading

**Inference:**
- LDoE's grind is **layered fan-in**. Every tier needs one new region's raw material *plus* everything below it, and the final builds (ATV, C-4) multiply quantities by about 10×.
- Three throttles stack on top of that:
  1. Energy, for the player's runs.
  2. Max-1/2 stations with 20-slot caps, for base throughput.
  3. 3-day cooldowns on endgame parts.
- **Each throttle has a matching paid relief valve.** That is the pattern to avoid copying for anything that feeds PvP (monetization doc design implications 1–4).

---

## 8. Storage and inventory

### 8.1 Personal inventory

| Component | Size | Notes |
|---|---|---|
| Base inventory | **10 slots** | The wiki calls these "pockets": "10 pockets + 10 backpack slots" = 20 with a Military Backpack |
| Backpack | +5 (Basic) / +10 (Military) / +15 (Tactical) | Max total 25 |
| Quick-access pocket slot | 1 (+1 with the **Extra Pocket** skill) | Accepts only food, drinks, healing, weapons and tools; not auto-consumed |
| Equipment slots | Weapon, head, torso, legs, feet, backpack | Tools work from inventory |
| Default stack | **20** | Scrap Metal and coupons **50**; tools, weapons, armor and vehicle wheels, forks and tanks don't stack; Engine Part and ATV Transmission stack to 20 |
| Vehicle trunks | Chopper 4 slots; Motorboat 4; ATV 4 → 15 with modules | Core doc §13 |
| Remote storage | Bunker Alfa ground floor: 7 lockers, 140 slots, never resets | Core doc §9 |

### 8.2 General storage ladder (upgrade in place)

| Container | Slots | Upgrade cost from the previous tier | Floor req. | Max per base | Notes |
|---|---|---|---|---|---|
| Small Box | 15 | 3 Pine Log + 5 Plant Fiber (craft) | Wood L1 | 40 | Starter |
| Chest | 25 (+10) | 10 Pine Plank + 5 Iron Bar + 5 Bolts | Plank L2 | 40 | Used in the Gunsmith Bench formerly |
| Trunk | 45 | 15 Oak Plank + 15 Nails + 5 Steel Bar | Stone L3 | 40 | — |
| Rack | 75 | 15 Steel Plate + 20 Iron Plate + 30 Oak Plank | Stone L3 | 40 | **Levels 1–11:** each costs 40 Ash Plank + 20 Steel Plate + 30 Iron Plate and adds +5 per slot. Slot cap goes 20 → 70 (scrap 50 → 100); total 1,500 → 5,250 |
| Safe (removed 1.30.1) | 5 | Tungsten recipe; shop-only "pack for stash making" | Stone L3 | 5 | — |

All general containers can be repainted (Paint items; Alcohol removes paint), and their icon shows their dominant content.

### 8.3 Specialised storage

| Storage | Slots × stack | Accepts | Max | Source / upgrade |
|---|---|---|---|---|
| Warehouse | 20 × 300 | Building materials (logs, planks, bricks, bars, plates, cement, Floor/Wall/Door/Window kits); auto-used when building | 1 | Shop; S16 reward |
| Fridge | 10 × 300 (3,000) per the page; FAQ 1218: L1 8 × 100 … L4 10 × 300; "+600 per level to 3,600 at L5" (conflict) | Raw and cooked food | 2 | **Store item**; Genesis 800 (L1); 4 upgrade blueprints (800 each) |
| Tabletop Food Pantry | 10 × 40 | Cooked food | 1 | 1.49.5 |
| Fish Fridge | 15 × 60 | Fish | 1 | Genesis 1,300 (after 60 catches) or 2,700; upgrades 500 × 3 |
| Ore Storage | 8 × 50 (400) | Ores, sulfur, lead, halite | 1 | Genesis 1,600 (after 100 Ti ore) |
| Storage for Parts | 10 slots; stackables 40, non-stackables 5 | Chopper, ATV and boat parts | 1 | Genesis upgrades 900 × 5 |
| Storage for Explosives | 8 × 50 (C-4 10) → 100 (C-4 15) at L2 | Explosives | 1 | Genesis 600 |
| Storage for Equipment | ? | Equipment | 20 | Genesis 2,400 (10 Consilium kills) |
| Cargo Shelving | ? (+5 slots per level) | ? | 1 | Genesis upgrades 900 × 6 |
| Division Box | 10 × 300 | Mechanics recycler outputs | 2 | Event / shop |
| Electronics crate | ? × 300 | Electronics, drone parts | 1 | Event |
| Medicine cabinet | 10 × 300 | Meds | 2 | Event / VIP Marathon / shop |
| Sewing Rack | 15 × 200 | Fabrics, leathers, hides, fibers | 1 | Hunting Grounds rep 40; Genesis upgrades 800 × 2 |
| Bookshelf | 15 × 330 | Books, cards | 1 | Genesis upgrades 1,000 × 2 |
| "Another round" bar | 10 × 300 | Drinks | 1 | — |
| Weapon Rack | 3 sections × 20, one weapon type each | Weapons | — | — |
| Mannequin | 5 (4 clothes + 1 backpack) | Outfits | 4 | Shop |
| Junk Repository | ? × 200 | Junk | 1 | — |
| Triumph | 20 | Decor | 1 | — |
| Fuel Tank | 3,000 fuel | Gasoline | 1 | Genesis upgrade 1,200 |
| Benches | Their input, output and fuel slots | Recipe items | — | FAQ: "items can be left in workstations" as overflow |

**Inference:**
- Specialised storages are where LDoE hides **stack-size growth**: 50 → 300 per slot versus the general 20.
- Nearly all of them come from Genesis, events or the shop, rather than from crafting. Storage capacity is therefore an endgame-currency and monetization lever (monetization doc §3.9).

---

## 9. Conflicts and stale data

| Topic | Value A | Value B | Used here |
|---|---|---|---|
| Log fuel burn | 2 m (Furnace, Campfire pages) | 1 m 20 s (Fuel page) | Both shown |
| Ash Plank | 8 logs, 1 h (Woodworking page) | 5 logs, 30 m (Ash Plank page) | Both |
| Thick Fabric time | 2 m (Sewing Table) | 1 m (Thick Fabric) | Both |
| Woolen Fabric time | 2 m (Sewing Table) | 12 m (Woolen Fabric) | Both |
| Gunpowder time | 1 h (Chemistry) | 1 h 30 m (Gunpowder) | Both |
| Glass | 5 Sand (Furnace) | 4 Quartz (Quartz page) | Both, possibly two recipes |
| Copper Rock hits | 5 (text) | 10 (infobox) | Both |
| Chainsaw recipe | 1 / 1 / 2 / 3 (Blueprints) | 5 / 5 / 10 / 15 (Chainsaw page) | Both |
| Car Battery | 2 Ti Alloy (Laboratory) | 4 Ti Bar (Car Battery page) | Both |
| Chemistry Station cost | 10 Iodine (Blueprints) | 3 Acid (page) | Blueprints |
| Hydroponic unlock | "Expedition Begins" (Blueprints) | "Woodshop" (page) | Blueprints |
| Laboratory unlock | "Laboratory" (Blueprints) | "The finish line" (page) | Blueprints |
| Rain Catcher, Kitchen stove, Tanning Rack, Pressing Machine, Hydroponic costs | Blueprints table | Older station pages | Blueprints |
| Fridge capacity | 10 × 300 | 8 × 100 at L1 (FAQ 1218); "+600 per level" | All shown |
| Hunger damage at 0 | 2 HP/s | 5 HP/s | Core doc |
| Meter drain on the map | Doesn't drain (Hunger/Thirst pages) | Drains (FAQ) | Unresolved |
| Recycler odds at L50 | 89 / 15 / 5% (summary) | 100 / 75 / 20 / 20 (firearm table) | Both |
| All "Level: N, Craft Points: N" lines | Pre-1.18.14 | Replaced by quest unlocks | Legacy table only |
| C-4 fully-crafted cost | See §7.1 | — | Flagged, verify |

---

## Data model implications

The entities and fields our data tables need to reproduce this economy, using our own names. Types are indicative (Luau tables, ModuleScripts or DataStore schemas).

### ItemDef
| Field | Type | Why (LDoE evidence) |
|---|---|---|
| id, displayName, iconId | string | — |
| category | enum: raw, processed, part, tool, weapon, armor, backpack, consumable, furniture, vehicle_part, currency, quest | Recycler categories and storage filters key off category |
| tier | int | Ladder position (§4) |
| stackMax | int (default 20; 50 for scrap; 1 for gear) | §8.1 |
| durabilityMax | int? | Tools 10–100, armor 150–400 |
| toolType, toolTier | enum? / int | Hatchet vs iron hatchet vs chainsaw gates node types |
| equipSlot | enum? | Head, torso, legs, feet, weapon, backpack |
| armor | {defence, cold, spore, radiation} | Regional hazard stats (§4.4) |
| weapon | {damage, speed, range, sneakMult, damageType} | — |
| backpackSlots | int? | +5 / +10 / +15 |
| consumable | {hp, hunger, thirst, energy, buffId?, buffSeconds?} | §5 |
| storageTags | string[] | Which specialised storages accept it (Fridge, Ore Storage…) |
| recycleId | ref RecycleDef? | Not every item is recyclable |
| flags | {uncraftable, eventOnly, premiumSource, nonStackable, questItem} | The Tungsten pattern; event-only extractors |
| xpOnPickup | int | 10 per resource unit |

### RecipeDef
| Field | Type | Notes |
|---|---|---|
| id | string | — |
| stationId | ref StationDef or "hand" | Hand-crafted blueprints vs bench recipes |
| inputs | [{itemId, qty}] | Can include *items to upgrade* (Reinforced Jacket consumes Thick Jacket) |
| outputs | [{itemId, qty, chance?}] | 1 → 2 Nails; Crate → ranges |
| durationSec | int | 0 for hand crafts |
| requiresFuel | bool | Campfire and furnaces yes, Meat Dryer no |
| unlockGateId | ref ProgressionGate | Quest / Genesis / starter / recycler-drop |
| category / sortOrder | — | Blueprint menu tabs: Tools, Weapon, Equipment, Bench, Furniture, Special |
| skipCostOverride | int? | Otherwise derived from TimerDef |
| isFinalization | bool, parentBuildId | Two-phase builds (Chopper, ATV) |

### StationDef
| Field | Type | Notes |
|---|---|---|
| id, buildRecipeId, finalizeRecipeId? | — | Two-phase |
| footprint {w, h}, rotations | — | 1×1 … 4×3 |
| floorTierRequired | int | 0 = ground, 1 wood … 4 iron |
| placement | enum: groundOnly, floorOnly, any | Garden Bed and Rain Catcher are ground-only |
| maxPerBase | int, extraFromShop? | 1–2; we would drop the shop extra |
| slots | {input, output, fuel} | — |
| baseStackLimit | int (20) | — |
| acceptedFuels | [{itemId, burnSec}] | §3.2 |
| levels | [{level, upgradeCost [{itemId, qty}], blueprintItemId?, stackBonus, speedMult?}] | §3.3 |
| runsOffline, notifyOnComplete | bool | All LDoE stations |
| concurrency | enum: singleQueue, perSlot | LDoE is one recipe at a time per station |
| recipeIds | ref[] | §3.4 graph |

### ResourceNodeDef
| Field | Notes |
|---|---|
| id, nodeType (tree, rock, bush, pickup, deposit, buriedChest) | — |
| toolType, minToolTier | Oak needs T2, ash needs a chainsaw |
| hitsToBreak | 4–6 |
| drops [{itemId, min, max, chance}] | Iron Rock: 3 ore + rare bauxite |
| xpPerUnit | 10 |
| respawnRule: never / onZoneReset / timerSec | Home nodes never respawn; zone nodes reset on exit. For shared servers we'd use timerSec |
| bonusSkillId, bonusBuffId | Lumberjack, "Fish sticks" |
| durabilityCostPerHit | 1 (shovel digs cost 2) |

### CropDef / RanchDef
| Field | Notes |
|---|---|
| stationId, seedItemId, seedQty | 1 seed; 20 seeds for a turkey |
| outputItemId / outputEntityId, outputQty | 2 carrots; spawns a Turkey entity |
| growSec | 1 h – 8 h; sapling stage seconds |
| stages | Saplings have stages |
| outcomeTable | Turkey vs Wild Turkey (hostile) |
| populationCap | 5 birds |
| waterRequired, fertilizerMult | **Absent in LDoE.** An opportunity for us if we want deeper farming |

### AnimalDef / FishDef
- **AnimalDef:** hp, behaviour (flee / aggressive / charge), drops, xp, region.
- **FishDef:** rarity, qualityTier (bronze / silver / gold), spotIds, raw consumable stats.
- **FishingSpotDef:** durationSec (12 h), fishPool, restockItemId (Burley), coldRequirement.

### RecycleDef
| Field | Notes |
|---|---|
| inputItemId, recycleCategory (6) | — |
| durationSec | 10 m – 1 h 30 m |
| outputs [{itemId, qty, baseChance, levelStep, chancePerStep, cap}] | +1% per 3 / 5 / 10 levels |
| durabilityScalesChance | bool |
| skillXp | Per category; max level 50 |
| blueprintDrop | {recipeId, baseChance} | Gun → its blueprint |

### SkillDef
- id, type (active / passive), maxLevel, perLevel {stat, value}, cooldownSec, unlockFlags (extraPocket, fisherman…).
- PlayerSkillOffer config: choices = 3, rerollCost.

### PlayerLevelDef
- level, xpToNext (**we must author this; LDoE's curve is undocumented**), rewards {skillPoints: 1, fullHeal: true}, gatesUnlocked.

### ProgressionGate
| Field | Notes |
|---|---|
| id, type: questComplete / level / currencyPurchase / bossKills / itemCollected / regionUnlocked / starter | Covers Survivor's Path, Genesis, "Kill Borealis 10 times", "Obtain 100 Ti ore" |
| params | e.g. {questId} / {currency, cost, limit} / {bossId, count} |
| unlocks | {recipeIds[], zoneIds[], stationLevelIds[], shopItemIds[]} |

### QuestDef (Path / chapter)
- trackId (survival / settlement), chapterId, order.
- tasks [{type: craft / build / visit / kill / collect / talk, target, count}].
- freeRewards, premiumRewards (**we'd keep only free**), unlockGateIds.

### TimerDef
| Field | Notes |
|---|---|
| id, kind: craft / regen / reset / cooldown / growth / event / buff | §7.3 |
| durationSec or regenPerSec + cap | Energy: 1 per 300 s, cap 200 |
| scope: player / base / station / zone / global | — |
| resetAnchor | e.g. 00:00 UTC daily |
| offlineProgress | bool |
| skippable, skipCurrency, skipCostFn | LDoE ≈ 15 + 4.25 × h. **For us: probably false for anything PvP-relevant** |
| notify | bool |

### ContainerDef and InventoryConfig
- **ContainerDef:** slots, stackOverride, acceptedTags, floorTier, maxPerBase, upgradeTo {containerId, cost}, levelTable (Rack: 11 levels × +5 stack), isRaidable, autoUseForBuilding (Warehouse).
- **InventoryConfig:** baseSlots 10, quickSlots 1 (+1 via skill), equipment slots, default stack 20.

### VehicleDef
- frameRecipeId, finalizeRecipeId, fuelItemId, fuelPerItem (25), fuelCap (200 / 250 / 500), trunkSlots, levels [{pointsRequired}], feedItems [{itemId, points, dailyLimit}], specs (1-of-3 picks), moduleSlots.

### EconomyConfig (tunable)
- energyMax, energyRegen, adEnergy, adDailyCap; inboxDailyGift {items, untilLevel}; genomeCap; bossPayouts; genesisStorageCooldownSec (3 days); stationDefaultStack (20); upgradeStackBonus (20).

---

## Sources

**LDoE Fandom wiki** (read as wikitext via the MediaWiki API, 2026-11-07):
- **Hubs:** [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) · [Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path) · [Genesis Collection](https://last-day-on-earth-survival.fandom.com/wiki/Genesis_Collection) · [Recycler](https://last-day-on-earth-survival.fandom.com/wiki/Recycler) · [Fuel](https://last-day-on-earth-survival.fandom.com/wiki/Fuel) · [New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills) · [Craft Points](https://last-day-on-earth-survival.fandom.com/wiki/Craft_Points) · [General Tips/FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ) · [Beginner's Guide](https://last-day-on-earth-survival.fandom.com/wiki/Beginner%27s_Guide) · [Version](https://last-day-on-earth-survival.fandom.com/wiki/Version) · [Version/1.53.0](https://last-day-on-earth-survival.fandom.com/wiki/Version/1.53.0) · [Creatures Items Drop Chance chart](https://last-day-on-earth-survival.fandom.com/wiki/Creatures_Items_Drop_Chance_chart)
- **Chapter templates:** [New beginning](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_New_beginning) · [True friend](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_True_friend) · [Powershot](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Powershot) · [Iron Warrior](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Iron_Warrior) · [North](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_North) · [Off To New Shores](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Off_To_New_Shores) · [Islands](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Islands) · [Heavy Machinery](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Heavy_Machinery) · [Operation "Dead Water"](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Operation_%22Dead_Water%22) · [Expeditions](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Expeditions) · [New Home](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_New_Home) · [Engineering Networks](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Engineering_Networks) · [Air support](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_Air_support)
- **Stations:** [Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire) · [Meat Dryer](https://last-day-on-earth-survival.fandom.com/wiki/Meat_Dryer) · [Garden Bed](https://last-day-on-earth-survival.fandom.com/wiki/Garden_Bed) · [Rain Catcher](https://last-day-on-earth-survival.fandom.com/wiki/Rain_Catcher) · [Hand Pump](https://last-day-on-earth-survival.fandom.com/wiki/Hand_Pump) · [Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench) · [Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace) · [Refined Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Refined_Melting_Furnace) · [Stonecutter's Table](https://last-day-on-earth-survival.fandom.com/wiki/Stonecutter%27s_Table) · [Workbench](https://last-day-on-earth-survival.fandom.com/wiki/Workbench) · [Tanning Rack](https://last-day-on-earth-survival.fandom.com/wiki/Tanning_Rack) · [Sewing Table](https://last-day-on-earth-survival.fandom.com/wiki/Sewing_Table) · [Medical Table](https://last-day-on-earth-survival.fandom.com/wiki/Medical_Table) · [Chemistry Station](https://last-day-on-earth-survival.fandom.com/wiki/Chemistry_Station) · [Laboratory](https://last-day-on-earth-survival.fandom.com/wiki/Laboratory) · [Pressing Machine](https://last-day-on-earth-survival.fandom.com/wiki/Pressing_Machine) · [Hydroponic System](https://last-day-on-earth-survival.fandom.com/wiki/Hydroponic_System) · [Kitchen stove](https://last-day-on-earth-survival.fandom.com/wiki/Kitchen_stove) · [Gunsmith Bench](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith_Bench) · [Buzzsaw](https://last-day-on-earth-survival.fandom.com/wiki/Buzzsaw) · [Acid Bath](https://last-day-on-earth-survival.fandom.com/wiki/Acid_Bath) · [Electric Generator](https://last-day-on-earth-survival.fandom.com/wiki/Electric_Generator) · [Garage](https://last-day-on-earth-survival.fandom.com/wiki/Garage) · [Repair Station](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station) · [Extractors](https://last-day-on-earth-survival.fandom.com/wiki/Extractors) · [Aluminum Extractor](https://last-day-on-earth-survival.fandom.com/wiki/Aluminum_Extractor) · [Copper Extractor](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Extractor) · [Titanium Extractor](https://last-day-on-earth-survival.fandom.com/wiki/Titanium_Extractor) · [Seaweed Farm](https://last-day-on-earth-survival.fandom.com/wiki/Seaweed_Farm) · [Turkey Coop](https://last-day-on-earth-survival.fandom.com/wiki/Turkey_Coop) · [Caiman Farm](https://last-day-on-earth-survival.fandom.com/wiki/Caiman_Farm) · [Boar Farm](https://last-day-on-earth-survival.fandom.com/wiki/Boar_Farm) · [Home Brewery](https://last-day-on-earth-survival.fandom.com/wiki/Home_Brewery)
- **Resources and nodes:** [Pine Tree](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Tree) · [Oak Tree](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Tree) · [Ash Tree](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Tree) · [Dead Tree](https://last-day-on-earth-survival.fandom.com/wiki/Dead_Tree) · [Limestone Rock](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Rock) · [Iron Rock](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Rock) · [Copper Rock](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Rock) · [Quartz Rock](https://last-day-on-earth-survival.fandom.com/wiki/Quartz_Rock) · [Sulfur Rock](https://last-day-on-earth-survival.fandom.com/wiki/Sulfur_Rock) · [Marble Rock](https://last-day-on-earth-survival.fandom.com/wiki/Marble_Rock) · [Berry Bush](https://last-day-on-earth-survival.fandom.com/wiki/Berry_Bush) · [Northern Berry Bush](https://last-day-on-earth-survival.fandom.com/wiki/Northern_Berry_Bush) · [Saplings](https://last-day-on-earth-survival.fandom.com/wiki/Saplings) · [Oak seedling](https://last-day-on-earth-survival.fandom.com/wiki/Oak_seedling) · [Pine tree seedling](https://last-day-on-earth-survival.fandom.com/wiki/Pine_tree_seedling) · [Farming](https://last-day-on-earth-survival.fandom.com/wiki/Farming)
- **Materials and parts:** [Pine Log](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Log) · [Oak Log](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Log) · [Ash Billet](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Billet) · [Ash Plank](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Plank) · [Limestone](https://last-day-on-earth-survival.fandom.com/wiki/Limestone) · [Stone Brick](https://last-day-on-earth-survival.fandom.com/wiki/Stone_Brick) · [Brick](https://last-day-on-earth-survival.fandom.com/wiki/Brick) · [Iron Ore](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Ore) · [Scrap Metal](https://last-day-on-earth-survival.fandom.com/wiki/Scrap_Metal) · [Iron Bar](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Bar) · [Iron Plate](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Plate) · [Steel Bar](https://last-day-on-earth-survival.fandom.com/wiki/Steel_Bar) · [Steel Plate](https://last-day-on-earth-survival.fandom.com/wiki/Steel_Plate) · [Aluminum Ore](https://last-day-on-earth-survival.fandom.com/wiki/Aluminum_Ore) · [Aluminium Bar](https://last-day-on-earth-survival.fandom.com/wiki/Aluminium_Bar) · [Aluminium Plate](https://last-day-on-earth-survival.fandom.com/wiki/Aluminium_Plate) · [Aluminium Wire](https://last-day-on-earth-survival.fandom.com/wiki/Aluminium_Wire) · [Copper Ore](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Ore) · [Copper Bar](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Bar) · [Titanium Ore](https://last-day-on-earth-survival.fandom.com/wiki/Titanium_Ore) · [Titanium Bar](https://last-day-on-earth-survival.fandom.com/wiki/Titanium_Bar) · [Lead](https://last-day-on-earth-survival.fandom.com/wiki/Lead) · [Lead Bar](https://last-day-on-earth-survival.fandom.com/wiki/Lead_Bar) · [Sulfur](https://last-day-on-earth-survival.fandom.com/wiki/Sulfur) · [Quartz](https://last-day-on-earth-survival.fandom.com/wiki/Quartz) · [Charcoal](https://last-day-on-earth-survival.fandom.com/wiki/Charcoal) · [Nails](https://last-day-on-earth-survival.fandom.com/wiki/Nails) · [Bolts](https://last-day-on-earth-survival.fandom.com/wiki/Bolts) · [Wiring](https://last-day-on-earth-survival.fandom.com/wiki/Wiring) · [Rubber Parts](https://last-day-on-earth-survival.fandom.com/wiki/Rubber_Parts) · [Rubber](https://last-day-on-earth-survival.fandom.com/wiki/Rubber) · [Gun Oil](https://last-day-on-earth-survival.fandom.com/wiki/Gun_Oil) · [Duct Tape](https://last-day-on-earth-survival.fandom.com/wiki/Duct_Tape) · [Adhesive](https://last-day-on-earth-survival.fandom.com/wiki/Adhesive) · [Ball Bearing](https://last-day-on-earth-survival.fandom.com/wiki/Ball_Bearing) · [Engine Part](https://last-day-on-earth-survival.fandom.com/wiki/Engine_Part) · [Factory Parts](https://last-day-on-earth-survival.fandom.com/wiki/Factory_Parts) · [Spring](https://last-day-on-earth-survival.fandom.com/wiki/Spring) · [Pipes](https://last-day-on-earth-survival.fandom.com/wiki/Pipes) · [Cog](https://last-day-on-earth-survival.fandom.com/wiki/Cog) · [Carbon Composite](https://last-day-on-earth-survival.fandom.com/wiki/Carbon_Composite) · [Plastic](https://last-day-on-earth-survival.fandom.com/wiki/Plastic) · [Electronic Circuit](https://last-day-on-earth-survival.fandom.com/wiki/Electronic_Circuit) · [Batteries](https://last-day-on-earth-survival.fandom.com/wiki/Batteries) · [Car Battery](https://last-day-on-earth-survival.fandom.com/wiki/Car_Battery) · [Gasoline](https://last-day-on-earth-survival.fandom.com/wiki/Gasoline) · [Gas Cylinder](https://last-day-on-earth-survival.fandom.com/wiki/Gas_Cylinder) · [Gunpowder](https://last-day-on-earth-survival.fandom.com/wiki/Gunpowder) · [Glass](https://last-day-on-earth-survival.fandom.com/wiki/Glass) · [Sand](https://last-day-on-earth-survival.fandom.com/wiki/Sand) · [Cement](https://last-day-on-earth-survival.fandom.com/wiki/Cement) · [Animal Rawhide](https://last-day-on-earth-survival.fandom.com/wiki/Animal_Rawhide) · [Leather](https://last-day-on-earth-survival.fandom.com/wiki/Leather) · [Plant Fiber](https://last-day-on-earth-survival.fandom.com/wiki/Plant_Fiber) · [Rope](https://last-day-on-earth-survival.fandom.com/wiki/Rope) · [Piece of Cloth](https://last-day-on-earth-survival.fandom.com/wiki/Piece_of_Cloth) · [Thick Fabric](https://last-day-on-earth-survival.fandom.com/wiki/Thick_Fabric) · [Fur](https://last-day-on-earth-survival.fandom.com/wiki/Fur) · [Wolf Hair](https://last-day-on-earth-survival.fandom.com/wiki/Wolf_Hair) · [Piece of Wool](https://last-day-on-earth-survival.fandom.com/wiki/Piece_of_Wool) · [Woolen Fabric](https://last-day-on-earth-survival.fandom.com/wiki/Woolen_Fabric) · [Thick Hide](https://last-day-on-earth-survival.fandom.com/wiki/Thick_Hide) · [Peat](https://last-day-on-earth-survival.fandom.com/wiki/Peat) · [Halite](https://last-day-on-earth-survival.fandom.com/wiki/Halite) · [Antimony](https://last-day-on-earth-survival.fandom.com/wiki/Antimony) · [Thermite](https://last-day-on-earth-survival.fandom.com/wiki/Thermite) · [Iodine](https://last-day-on-earth-survival.fandom.com/wiki/Iodine) · [Alcohol](https://last-day-on-earth-survival.fandom.com/wiki/Alcohol) · [Spices](https://last-day-on-earth-survival.fandom.com/wiki/Spices) · [Acid](https://last-day-on-earth-survival.fandom.com/wiki/Acid) · [Fuel Briquette](https://last-day-on-earth-survival.fandom.com/wiki/Fuel_Briquette) · [Seeds](https://last-day-on-earth-survival.fandom.com/wiki/Seeds) · [Corn Seeds](https://last-day-on-earth-survival.fandom.com/wiki/Corn_Seeds) · [Sprout](https://last-day-on-earth-survival.fandom.com/wiki/Sprout) · [Fertilizer](https://last-day-on-earth-survival.fandom.com/wiki/Fertilizer) · [Watering can](https://last-day-on-earth-survival.fandom.com/wiki/Watering_can) · [Crate with Oak Logs](https://last-day-on-earth-survival.fandom.com/wiki/Crate_with_Oak_Logs) · [Ore Crate](https://last-day-on-earth-survival.fandom.com/wiki/Ore_Crate) · [Empty Canister](https://last-day-on-earth-survival.fandom.com/wiki/Empty_Canister)
- **Tools, weapons and armor:** [Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Hatchet) · [Pickaxe](https://last-day-on-earth-survival.fandom.com/wiki/Pickaxe) · [Iron Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Hatchet) · [Iron Pickaxe](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Pickaxe) · [Shovel](https://last-day-on-earth-survival.fandom.com/wiki/Shovel) · [Chainsaw](https://last-day-on-earth-survival.fandom.com/wiki/Chainsaw) · [Manual earth drill](https://last-day-on-earth-survival.fandom.com/wiki/Manual_earth_drill) · [Torch](https://last-day-on-earth-survival.fandom.com/wiki/Torch) · [Crowbar](https://last-day-on-earth-survival.fandom.com/wiki/Crowbar) · [Fishing Rod](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Rod) · [Professional fishing rod](https://last-day-on-earth-survival.fandom.com/wiki/Professional_fishing_rod) · [Category:Weapons](https://last-day-on-earth-survival.fandom.com/wiki/Category:Weapons) (all member pages) · [Category:Armor](https://last-day-on-earth-survival.fandom.com/wiki/Category:Armor) (all member pages) · [Basic Backpack](https://last-day-on-earth-survival.fandom.com/wiki/Basic_Backpack) · [Military Backpack](https://last-day-on-earth-survival.fandom.com/wiki/Military_Backpack) · [Tactical Backpack](https://last-day-on-earth-survival.fandom.com/wiki/Tactical_Backpack)
- **Vehicles:** [Chopper](https://last-day-on-earth-survival.fandom.com/wiki/Chopper) · [Chopper Wheel](https://last-day-on-earth-survival.fandom.com/wiki/Chopper_Wheel) · [Chopper Fork](https://last-day-on-earth-survival.fandom.com/wiki/Chopper_Fork) · [Chopper Gas Tank](https://last-day-on-earth-survival.fandom.com/wiki/Chopper_Gas_Tank) · [Motorboat](https://last-day-on-earth-survival.fandom.com/wiki/Motorboat) · [ATV Design](https://last-day-on-earth-survival.fandom.com/wiki/ATV_Design) · [ATV Transmission](https://last-day-on-earth-survival.fandom.com/wiki/ATV_Transmission) · [ATV Wheel](https://last-day-on-earth-survival.fandom.com/wiki/ATV_Wheel) · [Mechanic's Box](https://last-day-on-earth-survival.fandom.com/wiki/Mechanic%27s_Box) · [Repair Kit](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Kit)
- **Survival, food and healing:** [Category:Food](https://last-day-on-earth-survival.fandom.com/wiki/Category:Food) (all member pages) · [Bandages](https://last-day-on-earth-survival.fandom.com/wiki/Bandages) · [First Aid Kit](https://last-day-on-earth-survival.fandom.com/wiki/First_Aid_Kit) · [Inhaler](https://last-day-on-earth-survival.fandom.com/wiki/Inhaler) · [Warming First Aid Kit](https://last-day-on-earth-survival.fandom.com/wiki/Warming_First_Aid_Kit) · [Anti-radiation Pills](https://last-day-on-earth-survival.fandom.com/wiki/Anti-radiation_Pills) · [AntiRad](https://last-day-on-earth-survival.fandom.com/wiki/AntiRad) · [Sterile bandage](https://last-day-on-earth-survival.fandom.com/wiki/Sterile_bandage) · [Antibiotic](https://last-day-on-earth-survival.fandom.com/wiki/Antibiotic) · [Energy Drink](https://last-day-on-earth-survival.fandom.com/wiki/Energy_Drink) · [Energy](https://last-day-on-earth-survival.fandom.com/wiki/Energy) · [Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations) · [Hunger](https://last-day-on-earth-survival.fandom.com/wiki/Hunger) · [Thirst](https://last-day-on-earth-survival.fandom.com/wiki/Thirst) · [Health](https://last-day-on-earth-survival.fandom.com/wiki/Health) · [Bottle of Water](https://last-day-on-earth-survival.fandom.com/wiki/Bottle_of_Water) · [Berry Tincture](https://last-day-on-earth-survival.fandom.com/wiki/Berry_Tincture) · [Raw Meat](https://last-day-on-earth-survival.fandom.com/wiki/Raw_Meat) · [Deer](https://last-day-on-earth-survival.fandom.com/wiki/Deer) · [Boar](https://last-day-on-earth-survival.fandom.com/wiki/Boar) · [Bear](https://last-day-on-earth-survival.fandom.com/wiki/Bear) · [Fishing Spot](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Spot) · [Herbal Mix](https://last-day-on-earth-survival.fandom.com/wiki/Herbal_Mix)
- **Storage:** [Small Box](https://last-day-on-earth-survival.fandom.com/wiki/Small_Box) · [Chest](https://last-day-on-earth-survival.fandom.com/wiki/Chest) · [Trunk](https://last-day-on-earth-survival.fandom.com/wiki/Trunk) · [Rack](https://last-day-on-earth-survival.fandom.com/wiki/Rack) · [Safe](https://last-day-on-earth-survival.fandom.com/wiki/Safe) · [Warehouse](https://last-day-on-earth-survival.fandom.com/wiki/Warehouse) · [Fridge](https://last-day-on-earth-survival.fandom.com/wiki/Fridge) · [Fish Fridge](https://last-day-on-earth-survival.fandom.com/wiki/Fish_Fridge) · [Ore Storage](https://last-day-on-earth-survival.fandom.com/wiki/Ore_Storage) · [Storage for Parts](https://last-day-on-earth-survival.fandom.com/wiki/Storage_for_Parts) · [Storage for Explosives](https://last-day-on-earth-survival.fandom.com/wiki/Storage_for_Explosives) · [Storage for Equipment](https://last-day-on-earth-survival.fandom.com/wiki/Storage_for_Equipment) · [Cargo Shelving](https://last-day-on-earth-survival.fandom.com/wiki/Cargo_Shelving) · [Tabletop Food Pantry](https://last-day-on-earth-survival.fandom.com/wiki/Tabletop_Food_Pantry) · [Division box](https://last-day-on-earth-survival.fandom.com/wiki/Division_box) · [Sewing Rack](https://last-day-on-earth-survival.fandom.com/wiki/Sewing_Rack) · [Medicine cabinet](https://last-day-on-earth-survival.fandom.com/wiki/Medicine_cabinet) · [Bookshelf](https://last-day-on-earth-survival.fandom.com/wiki/Bookshelf) · [Weapon Rack](https://last-day-on-earth-survival.fandom.com/wiki/Weapon_Rack) · [Fuel Tank](https://last-day-on-earth-survival.fandom.com/wiki/Fuel_Tank) · [Storage Compartment](https://last-day-on-earth-survival.fandom.com/wiki/Storage_Compartment)
- **Systems:** [Exploration Experience](https://last-day-on-earth-survival.fandom.com/wiki/Exploration_Experience) (removed system) · [Unknown Box](https://last-day-on-earth-survival.fandom.com/wiki/Unknown_Box) · [In-Game Shop](https://last-day-on-earth-survival.fandom.com/wiki/In-Game_Shop) · [Coins](https://last-day-on-earth-survival.fandom.com/wiki/Coins) · [VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone) · [Zones guide](https://last-day-on-earth-survival.fandom.com/wiki/Zones_guide)

**Kefir official:**
- [Help Center FAQ 958 — How do I upgrade workbenches](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/958-how-do-i-upgrade-workbenches/)

**Internal documents cross-referenced:**
- [`docs/research/ldoe-core-systems.md`](../research/ldoe-core-systems.md): energy, resets, boss genome payouts, level gates, Tungsten, plot and walls.
- [`docs/research/ldoe-monetization.md`](../research/ldoe-monetization.md): shop SKUs, fridge FAQ 1218, coin sinks, Path premium.

**Searches that returned nothing usable** (listed so they are not repeated): an LDoE XP-per-level table, Chopper build-time reports, and 1.51 "Storage for Alloys" workbench levels. Reddit and AppGamer were blocked (HTTP 403).
