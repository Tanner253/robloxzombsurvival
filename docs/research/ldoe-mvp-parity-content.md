# LDoE MVP parity: content and feature gaps for v0.1

**Status:** audit, written 2026-11-08 before the v0.1 publish. It answers the developer's ask: "make sure that our game is up to Last Day on Earth MVP standards... we're going to need to balance progression and add some more handcrafted maps like the forest and quarry."

**What it compares:**
- **Ours, v0.1:** `main` at `4edcb60`, plus the six Forest and Mine maps on `origin/claude/m1-slice2b-fog-runs-9a5388` at `e38dcc6`, counted as planned. Data is read from `roblox/src/shared/Data/*`. Docs are [ECONOMY.md](../ECONOMY.md) §9–10, [MVP_LAUNCH.md](../MVP_LAUNCH.md) and [LDOE_PARITY.md](../LDOE_PARITY.md).
- **LDoE early game:** player levels 1–20, the first 1–2 weeks. Today that is Survivor's Path chapters 1–4 ("New beginning" through "Iron Warrior") and the zones open by level 15. **Inference:** LDoE publishes no XP curve, so the chapter-to-level mapping is an estimate.
- **LDoE at launch (2017):** v1.0 (27 May 2017) through v1.6.12 (Dec 2017). The game was a public beta all year; the wiki's own main page still called it "currently in Beta" on 27 Sep 2017. The sources are the wiki's own 2017 page revisions, read by revision ID.

**Method:**
- Our numbers were counted from the data files.
- LDoE numbers come from our earlier research ([ldoe-systems/economy-progression.md](../ldoe-systems/economy-progression.md), [ldoe-systems/world-content.md](../ldoe-systems/world-content.md), [ldoe-core-systems.md](ldoe-core-systems.md), [ldoe-base-building.md](ldoe-base-building.md)).
- New for this file: wiki wikitext read through the MediaWiki API on 2026-11-08. That covers the current [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) table, the [Version](https://last-day-on-earth-survival.fandom.com/wiki/Version) history, and 2017 revisions of Blueprints, the zone pages, Wall, Home, Crash Site and Global Map. It also includes category membership timestamps (what had a wiki page by 31 Dec 2017). All are listed in [Sources](#9-sources).
- **Inference:** marks my analysis. Everything else is sourced or counted.

**Naming:** every proposal uses our own names. LDoE names appear only in the "LDoE has" text.

---

## Contents
1. [Summary](#1-summary)
2. [Our v0.1 inventory](#2-our-v01-inventory)
3. [LDoE's early game and its 2017 launch](#3-ldoes-early-game-and-its-2017-launch)
4. [Category-by-category comparison](#4-category-by-category-comparison)
5. [Prioritized gap list](#5-prioritized-gap-list)
6. [The developer's examples, checked one by one](#6-the-developers-examples-checked-one-by-one)
7. [Balance risks](#7-balance-risks)
8. [Map list check](#8-map-list-check)
9. [Sources](#9-sources)

---

## 1. Summary

**Prerequisite (already planned, but launch fails without it):**
- Merge the six Forest and Mine maps.
- Set `Tuning.features.fogRuns = true`. It is `false` on `main` today.
- Every v0.1 pacing number in ECONOMY §9 assumes both (§7, BR-1).

**Launch-blocking: six gaps a player would notice in the first two hours.**

| # | Gap | Owner |
|---|---|---|
| LB-1 | No armor set: 2 pieces in 2 tiers, and the legs and feet slots are always empty. LDoE hands out a 4-piece set in the first hour | S1b (items, recipes, worn visuals); S2B (loot) |
| LB-2 | No starter weapon. The first weapon unlocks at quest 6 and needs Saw Bench planks, and no found-loot melee weapons exist. LDoE puts a bat in your hands in quest 1 | S1b (items, recipe); S2B (loot, combat) |
| LB-3 | No placeable light. Nights ship in v0.1, and checklist 9.9 (binding) requires early torches and lanterns | S1b |
| LB-4 | The Reed Doormat can be crafted but does nothing: it isn't placeable, and respawn isn't wired | S1b |
| LB-5 | No passive food or water station. LDoE's garden, rain catcher and meat dryer all arrive in chapter 2 | S1b |
| LB-6 | No one-time crash site. Quest 6 was meant to go to one, and LDoE's first trip is a 14-case loot site | S2B (map, loot); S1b (quest 6) |

**Map recommendation:**
- Keep all ten planned maps. The six zones copy LDoE's six farm zones count for count.
- **Add the Courier Wreck** (LB-6) for v0.1.
- **Add Cinder Lodge**, a Dense dungeon with a 36 h reset and a mini-boss (SH-11). It should come right after launch, or with v0.1 if the Brute lands.
- Switch on the Supply Drop, which is already built (SH-9).

**Top balance risks (§7):**
1. **The Black tier is empty.** It has the Light roster at ×2 HP, and no new enemy, weapon or armor arrives after day 4.
2. **Walls have no threat in v0.1:** no Horde, and raids come in M2. The 30-hour Reinforced grind protects nothing.
3. **The location dailies still pay Rations.** That is up to 5 a day, or 300 Energy, which is more than the daily regen.
4. **There is a content cliff around day 13.** The Trail ends at quest 13, level 20 is reached on day 12, and the Hauler is cheap and can't be driven.

---

## 2. Our v0.1 inventory

Counted from the data files on `main`, plus the branch's `Locations` and `LootTables`.

### 2.1 Items (69)

| Category | Count | Items |
|---|---|---|
| Raw resources | 12 | Sticks, Timber, Fieldstone, Rusted Scrap, Reed Fiber, Fatwood, Murky Water, Ironbark Log, Ironstone, Malachite, Niter Crust, Raw Hide |
| Refined materials | 11 | Hewn Plank, Reed Cord, Reedcloth, Stone Block, Scrap Plate, Ironbark Plank, Iron Ingot, Copper Ingot, Embercoal, Blackpowder, Tanned Leather |
| Parts | 7 | Copper Wire, Pitch Glue, Rivets, Coil Spring, Brass Gear, Steel Pipe, Trigger Group |
| Junk (Recycler fodder) | 3 | Cracked Lantern, Snarled Wire, Seized Motor |
| Tools | 4 | Stone Hatchet, Stone Pick, Forged Hatchet, Forged Pick |
| Melee weapons | 4 | Spiked Club (T1), Scrapblade (T2), Machete (T2), Fire Axe (T2) |
| Ranged weapons | 4 | Reed Shortbow (T1), Worn Pistol (T2), Scrap Shotgun (T2), Flare Pistol (T2) |
| Ammo | 4 | Fire-Hardened Arrow, Light Rounds, Scrap Shells, Signal Flare |
| Armor | **2** | Padded Hood (head, T1, def 3), Padded Vest (body, T2, def 6). **No legs or feet pieces, and no set.** `Types.EquipSlot` already has `legs` and `feet` |
| Bags | 2 | Reed Satchel (+5), Scrap Pack Frame (+10, from a schematic); the Pack Expansion pass adds +5 |
| Food | 7 | Emberberries, Ashroot, Roasted Ashroot, Sealed Tin, Hearth Stew, Raw Venison, Fire-Roasted Venison |
| Drink | 3 | Murky Water, Boiled Water, Ember Tea |
| Medicine | **1** | Field Dressing (40 HP) |
| Energy | 2 | Ember Tonic (+25), Trail Rations (+60) |
| Other | 4 | Ember Heart (revive), Reed Doormat (respawn: **not wired**), Pack Frame Schematic, Reinforcement Plans |

### 2.2 Recipes, stations and building

| Kind | Count | Detail |
|---|---|---|
| Recipes | 42 | 24 by hand, 18 station lines |
| Stations | 7, each with 3 levels (21 levels) | Saw Bench (2 lines), Stonecutter (1), Smelter (3, fuelled), Workbench (5: plate, wire, cloth, rivets, leather), Campfire (6, fuelled: water, ashroot, tea, glue, coal, venison), Recycler (13 salvage rows), Ammo Press (1, fuelled) |
| Floors / foundations | 3 | Timber, Scrap Metal, Reinforced |
| Walls | 3 + 1 | One per tier, plus the Palisade Fence (Timber only, Defense tab) |
| Doorways, doors, window walls | 3 each | One per tier |
| Roofs, stairs, second floors | 0 | `BuildPieceKind` reserves `roof`, but no data uses it |
| Gates | 0 | `BuildPieceKind` reserves `gate`. **The Palisade Fence has no gate** |
| Storage | 2 tiers | Timber Crate (15 slots) → Banded Crate (25) |
| Decor, lights, traps, beds | 0 | — |

### 2.3 World, enemies, quests

| Kind | Count | Detail |
|---|---|---|
| Hollow | 3 | Shambler (40 HP), Runner (70 HP, speed 18), Bloater (60 HP, burst cloud) |
| Wildlife | 2 | Fog Deer (flees), Ash Wolf (hunts) |
| Hostile NPC humans | 0 | Real players fill the role in lobbies (a deliberate deviation); AI raiders come in M2 |
| Fog Run locations | 10 active | **Light:** Pine Hollow (POI), Bracken Edge (Forest L1), Rockfall Slope (Mine L1). **Dense:** Rustwater (POI), Ironbark Stand, Greenvein Bluffs, Stranded Caravan (3 h in every 9). **Black:** Ashfall Depot (20 h reset), Gloaming Deep, Deepcut Pit |
| Other locations | 3 | Supply Drop (built, `features.airdrops = false`); Home (8-plot Neighbourhood); Haven Square (hub) |
| Loot tables | 35 on the branch (26 on `main`) | — |
| Ember Trail | 13 quests in 2 chapters | 7 home, 6 Fog |
| Location daily quests | 10 | 4 POI, 6 zones; paid once per UTC day |
| Haven | 9 contracts (3 a day), 1 chapter hand-in reward | The only hand-in is for chapter 1, "Ashes and Embers" |
| Projects | 1 | Wrecked Hauler |
| Levels | 20 | 11 of them carry a reward |
| Shop SKUs | 10 | — |

### 2.4 Hours of content (ECONOMY §9.2, reference player at 2.5 h a day, all sinks on)

| Milestone | When | Play time |
|---|---|---|
| The hook (hatchet, walls, benches, level 5) | 46 min | 0.8 h |
| Timber base | day 1 | about 1.7 h |
| Dense fog open | day 3 morning | — |
| First firearm | day 3.8 | — |
| Scrap tier | day 4.8 | about 9 h |
| Black fog open | day 7.3 | — |
| Level 20 (the cap) | day 12.3 | about 31 h |
| Reinforced tier | day 13.3 | about 30–33 h |

**Inference:** v0.1 holds about **30–33 hours** of guided progression. That is the same span as LDoE's early game (weeks 1–2), but in LDoE chapters 5–9 follow it. In ours, M2 has to follow it (BR-8).

---

## 3. LDoE's early game and its 2017 launch

### 3.1 Early game today (Survivor's Path chapters 1–4)

From the current [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) table, which gives the unlock quest for every recipe, and the chapter list in [economy-progression §4.7](../ldoe-systems/economy-progression.md).

| Chapter | Blueprints it unlocks |
|---|---|
| Starters | Hatchet, Pickaxe, Basic Backpack, Small Box |
| 1 New beginning (3 quests) | None. Rewards: 10 food, 10 water, logs and limestone, a **Cleaver** and **10 Bandages** |
| 2 True friend (5 quests) | Spear, Garden Bed, Woodworking Bench, Dog Crate, Makeshift Bat, Bandages, Rain Catcher, **Dad Hat, Shirt, Cargo Pants, Sneakers**, Campfire, Meat Dryer |
| 3 Powershot (7 quests) | Melting Furnace, Bow, Shower, Fishing Rod, Spike Trap, Stonecutter's Table, Trip Wire Trap, Kitchen stove, Houseplant, Bear Trap, Gunsmith Bench, Cleaver, Tanning Rack, Doormat. Free rewards: Zip Gun, Machete |
| 4 Iron Warrior (11 quests) | Reinforced Shirt/Trousers/Sneakers, Workbench, Iron Hatchet, Iron Pickaxe, Sewing Table, Makeshift crossbow, Recycler, Shovel, Beanie, Thick Jacket, Denim Jeans, Work Boots, Mirror, Metal Pipe, Dining Table, Medical Table, First Aid Kit, Machete, Reinforced Beanie/Jacket/Jeans/Boots, Electric Generator, Crowbar, Garage, Skull Crusher, Buzzsaw, Saw Blade Mace, Tactical set. Free rewards: Mini Uzi, Crowbar, chopper parts |

**Early-game locations** (gates per [world-content §2](../ldoe-systems/world-content.md)):
- **Farm zones:** Pine Bushes and Limestone Ridge (green); Pine Grove and Limestone Cliffs (yellow, L10); Limestone Spires (red, L15).
- **First trip:** the one-time Crash Site.
- **Events:** the Airdrop (up to 3 a day), the Destroyed convoy (every 4 days) and the Oak Clearing (every 5 days).
- **Dungeons:** the Motel (36 h reset, no gate), the Abandoned Factory (24 h), and Crooked Creek Farm (48 h, L15).
- **Raid practice:** the NPC Survivor Base.
- **Behind the L10 Eastern Watchtower:** Blackport PD and the Transport Hub.

**Early-game enemies:**
- **Zombies:** Roaming Zombie, Fast Biter, Toxic Spitter (yellow), Floater Bloater (yellow, and rarely green), Toxic Abomination (red).
- **Mini-bosses:** the Weeper (Motel) and the Ravager (Farm).
- **Animals:** Grey Wolf, Rabid Wolf, Deer, Wild Turkey.
- **Humans:** AI Survivors (green and up) and Raiders (Farm, convoy).

### 3.2 Launch year (2017)

The [Blueprints revision of 29 Sep 2017](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints?oldid=8619) lists **104 blueprints with level gates**:
- 31 at levels 0–20
- 25 at levels 21–40
- 48 at level 41 and above, many of them locked behind Tungsten and never craftable

The [29 Jun 2017 revision](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints?oldid=704) is the earliest list.

| Level (2017) | Blueprints |
|---|---|
| 0 | Hatchet, Pickaxe, Spear |
| 2 | Small Box, Campfire, Garden Bed, Basic Backpack, Woodworking Bench, Shower |
| 6 | Melting Furnace, CB Radio, Makeshift Bat, Rain Catcher, Chopper (frame) |
| 10 | Bandages, Dad Hat, Shirt, Cargo Pants, Sneakers |
| 14 | Stonecutter's Table, Torch, Chest, Iron Hatchet, Iron Pickaxe, Meat Dryer, Tanning Rack |
| 18 | Doormat, Spike Trap, Cleaver, Sewing Table, ATV (design) |
| 22 (just past 20) | Crowbar, Beanie, Thick Jacket, Denim Jeans, Work Boots |

**What else existed in 2017** (wiki pages tagged into categories by 31 Dec 2017):
- **Creatures (18):**
  - Roaming Zombie, Fast Biter, Toxic Spitter, Floater Bloater, Toxic Abomination
  - The Big One, Frenzied Giant, Crowd Zombie (the home Horde)
  - Grey Wolf, Rabid Wolf, Deer, Fox
  - Late-2017 bunker and North enemies
- **Locations (20):**
  - Launch set: Home, Pine Bushes/Grove/Wood, Limestone Ridge/Cliffs/Spires, Crash Site, Airdrop, Bunker Alfa (Bravo listed but closed)
  - Added by December: Oak Bushes and Grove, Frosty Backwoods, Wooded Foothills, Watchtower, Rest Stop, Smugglers' Camp, Wrecked ship, Infected Forest
- **Other categories:** 46 weapon pages (with about 7 loot-only melee weapons), 36 armor pages (about 9 sets), 45 furniture pages, 13 food items, 16 workstations.

**Zone contents in 2017** ([Pine rev 13737](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood?oldid=13737), [Limestone rev 13731](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires?oldid=13731)):

| Zone | Containers | Enemies | Nodes |
|---|---|---|---|
| Pine Bushes | 1–3 bags | Roamers, Grey Wolves, an occasional Fast Biter, a rare Floater Bloater | 27 pines |
| Pine Grove | 3–4 | 1–2 Bloaters, 1–2 Spitters, more Fast Biters, a rare Big One | — |
| Pine Wood | 4–5 | The Big One, AI with a VSS | 1–2 oak trees |
| Limestone zones | Same 1–3 / 3–4 / 4–5 split | Same ladder | 25/20/45 limestone rocks and 5/30/50 iron rocks |

**Building in 2017** ([Wall rev 8340](https://last-day-on-earth-survival.fandom.com/wiki/Wall?oldid=8340)):
- Floor, Wall, Door and Window, each in four tiers (log, plank, stone, metal). The fifth tier came in 2021.
- "Zombie Hordes also spawn every 24 hours" at Home ([Home rev 5751](https://last-day-on-earth-survival.fandom.com/wiki/Home?oldid=5751)).
- No quest book: unlocks were by level plus craft points. The Survivor's Path came in 1.20.9 (Aug 2023).

**Inference:** at launch, LDoE's first 20 levels held only **3 craftable melee weapons, no craftable gun, 1 armor set, 1 heal and 9 stations**. Our v0.1 already matches or beats that in most rows. **The bar that matters is today's early game, because that is what players compare us to.** The table in §4 shows both.

---

## 4. Category-by-category comparison

"Gap" points to the item in §5 that closes it.

| Category | LDoE early game (L1–20, Path ch. 1–4) | LDoE at launch (2017, L1–20 / whole year) | Ours v0.1 | Gap |
|---|---|---|---|---|
| Raw resources | about 10: Pine Log, Limestone, Iron Ore, Plant Fiber, Berry, Mushroom, Raw Meat, Rawhide, Oak Log, Seeds | about 9 | **12** | None |
| Refined materials and parts | about 11 refined (planks ×2, brick, bar, plate, nails, charcoal, leather, rope, cloth, thick fabric) and about 10 loot parts (duct tape, adhesive, bolts, spring, rubber, wiring, bearings, engine part...) | similar | 11 refined, 7 parts, 3 junk | None. Fewer loot-part types, by design: each one gates a step |
| Tools | 7 (Hatchet, Pickaxe, Iron Hatchet, Iron Pickaxe, Shovel, Fishing Rod, Crowbar) | 4 + Torch | 4 | Minor. Shovel and fishing need systems (post-launch) |
| Melee weapons | **8 craftable** (Spear, Makeshift Bat, Cleaver, Metal Pipe, Machete, Crowbar, Skull Crusher, Saw Blade Mace) **+ about 5 loot-only** (Hockey Stick, Paddle, Golf Club, Hammer, Baseball Bat); a bat equipped in quest 1 | 3 craftable by L20 (Spear L0, Bat L6, Cleaver L18) + about 7 loot-only | 4 craftable, T1–T2 only; **0 loot-only; no weapon until quest 6** | **LB-2**, SH-5 |
| Ranged weapons | 2 craftable (Bow, Makeshift crossbow) + free Zip Gun and Mini Uzi rewards; loot and premium guns | 0 craftable by L20 (Zip Gun L34, Glock L40); guns from AI survivors and the bunker | 4 (Shortbow, Worn Pistol, Scrap Shotgun, Flare Pistol) | None in count. SH-5 adds a tier-2 bow |
| Ammo | none: durability counts shots | none | 4 types | None (harsher by design) |
| Armor | **19 pieces in 5 four-slot sets** (Basic, Reinforced basic, Leather, Reinforced, Tactical); Basic set in chapter 2 | 4 pieces (Basic, L10) by L20; about 36 pieces in the year | **2 pieces, 0 sets; legs and feet empty** | **LB-1**, SH-4 |
| Bags | +5 craftable; +10 as a premium reward | +5 (L2); +10 (L64); +15 (L76) | +5, +10 (schematic), +5 pass | None |
| Food | about 10 | 9 (13 Food pages incl. drinks) | 7 | Minor: Smoked Venison in LB-5 |
| Drink | 4 (bottle of water, dirty water, Berry Tea, beer) | 4 | 3 | None |
| Medicine | 2: Bandages 40 HP (ch2), First Aid Kit 100 HP (ch4); Reanimator (premium) | 1 by L20 (Bandages L10); First Aid Kit L34 | 1 (Field Dressing 40 HP) + Ember Heart | SH-3 |
| Energy items | Rations | coins | Ember Tonic, Trail Rations | None |
| Production stations | about 15 (Campfire, Meat Dryer, Garden Bed, Rain Catcher, Woodworking, Furnace, Stonecutter, Kitchen stove, Gunsmith, Tanning Rack, Workbench, Sewing Table, Recycler, Medical Table, Buzzsaw) | 9 by L20 | 7, each with 3 levels | **LB-5**, SH-6, SH-13 |
| Passive food and water (no fuel) | Garden Bed, Rain Catcher, Meat Dryer, all in chapter 2 | L2, L6, L14 | **none**: everything goes through the fuelled Campfire | **LB-5**, SH-6 |
| Floors, walls, doors, windows | 4 piece types × L1–L3 reachable (L4–L5 later) | 4 × 4 tiers | 5 piece types (with doorway) × 3 tiers = 15 | None |
| Roofs, stairs, second floors | none (no second storey; roofs undocumented and not upgradeable) | none | none | **Not an LDoE gap** (§6). SH-8 adds roofs for Roblox players |
| Fences and gates | none early (Barbed Wire comes in ch5) | none | Palisade Fence; **no gate, so a fenced yard can't be entered** | SH-8 |
| Storage | Small Box 15 → Chest 25 (Trunk 45 mid-game) | Small Box L2, Chest L14, Trunk L46 | Timber Crate 15 → Banded Crate 25 | None |
| Specialised storage (fridge and the like) | none early; the Fridge is a 2021 store and Genesis item | none | none | **Not a gap** (§6) |
| Respawn point | Doormat (ch3) | Doormat L18 | Reed Doormat item: **not placeable, respawn not wired** | **LB-4** |
| Bed | decor only (Comfortable Bed: Settlement track; L58 in 2017) | L58 decor | none | **Not a gap** (§6). Bedroll in SH-7 |
| Lights | Torch (ch5 now), Floor Lamp | Torch L14, Floor Lamp L28 | **none** (checklist 9.9 requires them) | **LB-3** |
| Traps and defense | Spike Trap, Trip Wire, Bear Trap (ch3) | Spike Trap L18 | none | SH-2 |
| Home threat | The Horde every 24 h | The Horde from launch | **none in v0.1** | SH-2 |
| Decor | Shower, Houseplant, Mirror, Dining Table, Road Sign | Shower L2; about 15 furniture by L46 | none (the tab is hidden) | SH-7 |
| Zombies / Hollow | 5 field types (Roamer, Fast Biter, Spitter, Floater Bloater, Abomination) + Weeper and Ravager mini-bosses | 6 field types + Frenzied Giant (bunker) | **3** (Shambler, Runner, Bloater) | SH-1 |
| Wildlife | Grey Wolf, Rabid Wolf, Deer, Turkey | Grey Wolf, Rabid Wolf, Deer, Fox | Fog Deer, Ash Wolf | Minor |
| Hostile NPC humans | AI Survivors, Raiders | AI Survivors | none (real players in lobbies) | Not a gap (deviation); M2 |
| Locations | about 13 by L15 (6 zones, crash site, 3 events, 3 dungeons) | about 10 at launch, about 20 by December | 10 + Supply Drop (off) + Home + Haven | **LB-6**, SH-9, SH-11 (§8) |
| Quests | 26 Path quests in ch. 1–4, plus daily tasks | none (level gates) | 13 Trail quests + 10 location dailies + 3 contracts a day | SH-10 |
| Long-term project | Chopper frame from minute one; weeks to finish | Chopper frame L6 | Wrecked Hauler: cheap, and can't be driven | SH-12, BR-8 |
| Companions | puppy in ch2 | none (dogs came in 2018) | none (M3, a recorded deviation) | Not a gap |
| Vehicles | Chopper (weeks) | Chopper | none (M4) | Deferred by MVP_LAUNCH |
| Guided content | weeks 1–2 of a multi-month ladder | — | about 30–33 h (Reinforced on day 13.3) | BR-8 |

### 4.1 The first two hours, side by side

| | LDoE (new account today) | Ours v0.1 (ECONOMY §9.3, day 1) |
|---|---|---|
| First weapon | Bat in quest 1; Spear and Bat in chapter 2 | Tools as weak weapons; Spiked Club at quest 6 |
| Clothing | 4-piece Basic set (chapter 2, "Neighborhood") | Padded Hood (quest 8 reward), Padded Vest (quest 8 unlock) |
| First trip | Crash Site: 14 cases × 12 slots, then Pine Bushes | Pine Hollow (5–8 containers) |
| Food and water | Garden Bed, Rain Catcher, Meat Dryer, Campfire | Campfire only |
| Enemies met | Roamer, Fast Biter, Grey Wolf, Deer, AI Survivor, rare Floater Bloater | Shambler, Runner (band 2), Fog Deer, Ash Wolf |
| Night or home | Horde warning; the first Horde at 24 h | Readable nights, nothing to light, nothing to defend |
| Recipes unlocked | about 20 | about 35 (**Inference**, quests 1–9), so **we are richer in recipes and thinner in gear categories** |

---

## 5. Prioritized gap list

Owners:
- **S1b** owns home: items, recipes, stations, building and UI.
- **S2B** owns Fog Runs: maps, enemies and loot.

Art estimates count new models (3D) and icons (2D painted). Every visible model must grade A (checklist §0).

### 5.1 LAUNCH-BLOCKING

#### LB-1. Two full armor sets (legs and feet slots filled)
- **LDoE has:**
  - The 4-piece Basic set (cap, shirt, trousers, shoes) unlocks in chapter 2, "Neighborhood", in the first hour. It is made from fiber, cloth and rope, with defense 2/3/3/–.
  - By the end of chapter 4 there are five sets, the higher ones at 150–180 durability (Leather 3/6/5/2, Reinforced 4/7/6/3, Tactical 5/8/7/4).
  - In 2017 the Basic set unlocked at L10 and the Leather set at L22.
- **Ours:** the Padded Hood and Padded Vest only. The shop's Armorer's Bundle (§8.6) already promises "2 Padded sets" that don't exist.
- **Proposal:**

  | Set | Piece | Slot | Def | Fog resist | Durability | Recipe (hand) | Unlock |
  |---|---|---|---|---|---|---|---|
  | **Reedweave** (T1) | Reedweave Cap | head | 1 | 0.03 | 60 | 3 fiber, 1 reedcloth | quest.keep_the_fire |
  | | Reedweave Shirt | body | 2 | 0.04 | 60 | 4 fiber, 3 reedcloth | quest.keep_the_fire |
  | | Reedweave Trousers | legs | 2 | 0.04 | 60 | 4 fiber, 3 reedcloth, 2 cord | quest.keep_the_fire |
  | | Reedweave Wraps | feet | 1 | 0.03 | 60 | 3 fiber, 2 reedcloth, 2 cord | quest.keep_the_fire |
  | **Padded** (T2) | Padded Hood (existing) | head | 3 | 0.10 | 80 | unchanged | quest.hold_the_door |
  | | Padded Vest (existing) | body | 6 | 0.15 | 100 | unchanged | quest.stand_your_ground |
  | | **Padded Leggings** | legs | 5 | 0.12 | 100 | 4 reedcloth, 2 tanned leather, 2 cord, 1 pitch glue | quest.scavenger (with leather) |
  | | **Padded Boots** | feet | 2 | 0.08 | 80 | 2 reedcloth, 2 tanned leather, 2 cord | quest.scavenger |

  The set totals are 6 (Reedweave) and 16 (Padded), which sit between LDoE's Basic set (8) and its Leather set (16).
- **Data:**
  - 6 `ItemDef`s (`equipSlot = "legs"` / `"feet"`), 6 recipes and 6 Recycler salvage rows.
  - Loot rows: `loot.pine_pack`, `loot.zone_pack_t1`/`t2` and `loot.quarry_locker` (S2B).
  - The Armorer's Bundle definition, and the Pacing.spec armor-wear rerun (BR-4).
- **Art:**
  - 6 icons.
  - 6 worn visuals on the survivor rig: 2 headwear and 2 footwear accessory meshes, and 2 clothing textures (shirt and trousers) per set.
  - The Padded Leggings and Boots need 2 more visuals, so about **4 meshes and 4 clothing textures**.
- **Owner:** S1b (items, recipes, paperdoll, worn visuals); S2B (loot rows).

#### LB-2. A starter weapon and found melee loot
- **LDoE has:**
  - Quest 1 ("Settling In") has you equip a bat and kill a zombie.
  - The Spear (3 logs) unlocks in chapter 2; in 2017 it was available at L0.
  - Green-zone bags drop loot-only melee weapons (Hockey Stick, Paddle, Golf Club, Hammer, Baseball Bat).
- **Ours:**
  - No weapon until quest 6 unlocks the Spiked Club, which needs Hewn Planks from the Saw Bench.
  - Quest 1's kill objective switches on with Fog Runs, so the first kill is made with a tool (#34).
  - No loot-only weapons at all.
- **Proposal:**

  | Weapon | Kind | Stats | Source |
  |---|---|---|---|
  | **Sharpened Stake** | melee T1, reach | 10 damage, 1.1 attacks/s, range 7.5, durability 50 | Hand: 4 sticks, 1 reed cord. **Default unlock**, joining the hatchet, pick and satchel |
  | **Tire Iron** | melee T1, loot only | 15 damage, 1.2 attacks/s, durability 70 | Weight 3–5 in `loot.pine_pack`, `loot.pine_crate`, `loot.zone_pack_t1`, `loot.forest_crate_t1`, `loot.mine_box_t1` |
  | **Rail Mallet** | melee T2 heavy, loot only | 26 damage, 0.8 attacks/s, knockback 2, durability 50 | `loot.quarry_toolbox`, `loot.zone_pack_t2`, `loot.caravan_wagon` |

  Recycler rows: Stake → sticks; Tire Iron → 2–4 scrap; Rail Mallet → 1 scrap plate and 1 rivet.
- **Data:** 3 items, 1 recipe, 3 salvage rows, about 8 loot rows, and a quest 1 hint line.
- **Art:** 3 held models (reusing the existing melee animation set) and 3 icons.
- **Owner:** S1b (items, recipe, unlock); S2B (loot rows, combat feel).

#### LB-3. Placeable lights
- **LDoE has:** the Torch (2017 L14; a chapter-5 tool now) and the Floor Lamp (2017 L28).
- **Ours:**
  - Checklist 9.9 (binding, S1) says: "Placeable light sources (torches, lanterns on posts)... craftable early... 'light is territory'."
  - Nights ship in v0.1, and every Hollow has `lightFear`.
  - BuildPieces has nothing that gives off light.
- **Proposal:**

  | Piece | Cost | Light | Limits | Unlock |
  |---|---|---|---|---|
  | **Pitch Torch** (standing) | 3 sticks, 1 pitch glue, 1 reedcloth | warm, radius 14 | ground or any floor, max 12 | quest.keep_the_fire (the glue line opens there) |
  | **Post Lantern** | 2 hewn plank, 1 scrap plate, 1 pitch glue | radius 22 | max 8 | quest.hold_the_door |

  Both are permanent in v0.1 (no fuel). Their light pools feed the Hollow's light fear, which SH-2 then uses.
- **Data:** a `light = { radius, brightness, color }` field on `BuildPieceDef` (Types), 2 build pieces, and the Decor or Defense tray tab.
- **Art:** 2 models (each with a flame and a PointLight) and 2 tray icons.
- **Owner:** S1b.

#### LB-4. The Reed Doormat must work
- **LDoE has:** the Doormat sets your respawn and entry point, max 1 per base (2017 L18; chapter 3 now). Players wall it in as a safe room.
- **Ours:**
  - `item.doormat` has a recipe (8 fiber, 2 cord, unlocked at quest.scavenger) and promises "After a bad run, you wake up here".
  - No build piece places it.
  - DeathRecovery says "slice 1b wires the respawn itself", and that wiring doesn't exist.
  - A craftable item that does nothing is exactly the kind of gap the developer must never find.
- **Proposal:**
  - `build.doormat`: furniture, a 2×2 quarter-cell footprint, any floor, max 1 per plot. Placing it consumes the item.
  - Home spawn checks for it: after a run death, and on joining, you spawn on the mat.
- **Data:** 1 build piece, home spawn wiring, and dropping `feature = "fogRuns"` once Fog Runs ship.
- **Art:** 1 flat mat model (cheap); the icon exists.
- **Owner:** S1b.

#### LB-5. Passive food and water stations
- **LDoE has:**
  - Chapter 2 unlocks three no-fuel stations in the first hour:
    - the Garden Bed
    - the Rain Catcher (Empty Bottle → water, 10 min, max 2)
    - the Meat Dryer (Raw Meat → Jerky, 40 hunger, 10 min, max 2)
  - In 2017 they arrived at L2, L6 and L14.
  - Our research rates "water and food solved" as a **first-session** milestone ([economy-progression §7.2](../ldoe-systems/economy-progression.md)).
- **Ours:**
  - Every drink and cooked meal goes through the fuelled Campfire, which is also the Embercoal and Pitch Glue line.
  - The §9 model starved players on days 8–10 until a "food lines first" rule was added.
  - The Rain Catcher is parked in S3 (#36) and the Smoke Rack in M2.
- **Proposal:** harsher than LDoE, so the Field Provisions pack keeps its demand. Water still needs a trip to a Spring Pool.

  | Station | Converts | Build cost | Limits | Unlock |
  |---|---|---|---|---|
  | **Rain Barrel** | Murky Water → Boiled Water, 10 min, no fuel | 8 timber, 3 reedcloth, 2 scrap (LDoE: 5 log, 3 cloth, 2 scrap) | ground or Timber floor, max 2, slot 20 | quest.keep_the_fire |
  | **Smoke Rack** | Raw Venison → **Smoked Venison** (new item: 40 hunger, 15 HP, stack 20), 10 min, no fuel | 5 hewn plank, 10 cord, 10 fieldstone (LDoE Meat Dryer: 5 plank, 10 rope, 10 limestone) | max 2 | quest.stand_your_ground |

- **Data:** 2 `StationDef`s, 2 build pieces, 2 recipes, 1 item, and a Pacing.spec update (Campfire load drops; see BR-6).
- **Art:** 2 station models, 2 tray icons and 1 item icon.
- **Owner:** S1b.

#### LB-6. The Courier Wreck: a one-time first-trip crash site
- **LDoE has:**
  - The Crash Site: a one-time green location that triggers early in the FTUE.
  - It has **14 baggage cases × 12 slots** (22–44 in 2017), Roamers and a Grey Wolf, 20 dead trees and 30 loose logs.
  - It vanishes 15 minutes after you leave.
  - It is the game's first trip and its first loot spike (chapter 2).
- **Ours:**
  - DECISIONS (the S1b worker calls) says quest 6 points at a one-time Crash Site.
  - `Quests.luau` says it is "slice 2's to add".
  - Quest 6 still travels to Pine Hollow, and no location exists.
- **Proposal: `loc.courier_wreck`, "Courier Wreck".**
  - **Setting:** a supply hauler and its trailer have jackknifed off the old road, with cargo strewn through dead pines.
  - **Rules:** Light fog, level 1, Run 10 Energy, Walk 8 min. A new one-time reset kind: per player, and gone 15 min after you leave.
  - **Containers:** 14 cargo cases using `loot.wreck_cargo`, 2–4 rolls each:
    - sealed tins, boiled water, field dressings, cord, reedcloth, scrap and rivets
    - one Reedweave piece per case at weight 8
    - across the site: 1 guaranteed Tire Iron and 1 Coil Spring, in the cab strongbox (`loot.wreck_cab`)
  - **Nodes:** 12 pine, 15 fallen branches, 8 loose stones, 6 reed, 4 berry.
  - **Enemies:** Shambler 3–4, Ash Wolf 1.
  - **Map:** about 220 studs; the Stranded Caravan's builder can be reused.
  - **Quest 6:** travels to `loc.courier_wreck`. Quest 9 stays at Pine Hollow.
- **Data:** 1 `LocationDef`, 2 loot tables, a reset or availability kind, a FogRegions event pin, the quest 6 edit, and the location panel.
- **Art:**
  - 1 hero wreck set: the Projects hauler model, wrecked, can be the cab.
  - 1 cargo-case container model.
  - 1 panel painting and 1 map landmark sprite.
- **Owner:** S2B (map, loot, location kind); S1b (the quest 6 edit).

### 5.2 SHOULD-HAVE for v0.1

Ordered by impact on the tiers that feel thinnest.

| # | Gap | LDoE has | Proposal (our names) | Data | Art | Owner |
|---|---|---|---|---|---|---|
| **SH-1** | Dense and Black add no new enemy | Yellow zones add the Floater Bloater (240 HP slam) and Toxic Spitter (80 HP, 15 dmg spit); red zones add the Toxic Abomination (300 HP, 250–300 XP) and The Big One. All of them in 2017. A rare Bloater in green zones | **Brute:** 260 HP, a telegraphed 16-dmg slam (radius 6, 1.2 s windup), staggers, speed 9, 150 XP. Base spawn 1–2 in the three Black maps; 0–1 at band 3 in Dense. Drops: brass gear 15%, coil spring 25%, 1–2 scrap plate. **Retcher:** 70 HP, a lobbed bile glob (10 dmg + 3 s slow, range 30, 3 s cooldown), keeps its distance, 40 XP, drops niter and cloth. Spawns 1–2 in Dense and Black, 0–1 at band 3 in Light. Also: Bloater 0–1 at band 2 in the three Light maps | 2 `EnemyDef`s, 2 loot tables, about 12 spawn rows, HollowAI slam and ranged-lob behaviours, Tuning | **2 rigs + 2 animation sets** (checklist 13.1) + 1 projectile VFX: the biggest art item | S2B |
| **SH-2** | No home threat; walls do nothing until M2 | The Horde crosses Home every 24 h from launch. It hits walls only, and less when you're offline. L2 walls hurt it; L3 walls are horde-proof. Spike Trap (10 dmg; 2017 L18) | **Night Drift:** once per UTC day, on the first in-game night the owner is online at home, a column of 6–10 Shamblers and 2–3 Runners (plus a Brute at Reinforced plots) comes in from the road edge. It attacks walls, doors and fences only, never stations or storage. Timber takes full damage, Scrap takes half and hurts attackers, Reinforced holds. Offline plots are never hit (GAME_DESIGN). Kills give XP and loot. **Stake Trap:** 6 timber, 2 cord, 2 scrap; 10 dmg per contact; 20 hits; max 40. LB-3 light pools repel | `Tuning.nightDrift`, home spawn path, Domain/Grid damage rules, 1 build piece, a chapter 3 quest | 1 trap model; reuses the Hollow rigs | S1b (with S2B's Hollow AI) |
| **SH-3** | One heal for all three tiers | First Aid Kit: 2 Alcohol + 3 Bandages → 100 HP (ch4; 2017 L34). Alcohol is 5 berries → 1 at the Medical Table in 10 min | **Berry Antiseptic:** 5 Emberberries → 1 at the Campfire, 10 min. **Surgeon's Roll:** 3 Field Dressings + 2 Berry Antiseptic → 100 HP, stack 10. Unlock: quest.the_dense_fog. Drops from `depot_strongbox`, `caravan_wagon` and `airdrop_crate` | 2 items, 2 recipes, loot rows | 2 icons | S1b (S2B loot) |
| **SH-4** | Nothing to wear above Padded; fog resist peaks at 0.25, so #37 can't gate tiers | Leather and Reinforced sets (ch4), Tactical (end of ch4), 150–180 durability. "Reinforced" pieces consume the lower piece | **Hidebound set:** Hidebound Cap, Coat, Leggings, Boots. Def 4/8/6/3, fog resist 0.10/0.15/0.12/0.08, durability 150. Each consumes the matching Padded piece, plus 3–6 tanned leather, 1–3 scrap plate, 1–2 rivets and 1–2 glue. Unlock: quest.heartwood | 4 items, 4 recipes, salvage, loot rows | 4 icons + 4 worn visuals | S1b (S2B loot) |
| **SH-5** | The weapon chase ends at tier 2 by day 4 | 8 craftable melee up to Skull Crusher (45) and Saw Blade Mace (55); a crossbow in ch4 | **Recurve Bow** (GAME_DESIGN's ladder): 3 ironbark plank, 4 cord, 2 glue, 1 coil spring; 28 dmg, 1.0 s draw, 50 shots. Unlock: quest.heartwood. **Rebar Maul** (GAME_DESIGN): 6 scrap plate, 2 ironbark plank, 4 rivets, 1 steel pipe, 2 copper wire; 48 dmg, 0.7 attacks/s, staggers, 45 hits. Unlock: quest.into_the_black | 2 items, 2 recipes, salvage, loot rows | 2 held models + 2 icons | S1b (S2B combat tuning) |
| **SH-6** | No home crop | Garden Bed (ch2 "Resource collecting"; 2017 L2): 2×2, ground only, max 2, 1 seed → 2 carrots in 1 h | **Ashroot Bed:** 1 Ashroot → 2 Ashroot in 60 min, no fuel, ground only, max 2. Cost: 5 fieldstone, 2 reed fiber, 3 timber. Unlock: quest.a_place_to_work | 1 station, 1 piece, 1 recipe | 1 model | S1b |
| **SH-7** | No decor in Neighbourhood bases that everyone can see | Shower, Houseplant, Mirror, Dining Table (ch3–4), Road Sign; about 15 furniture pieces in 2017 | **Bedroll** (cosmetic bed), **Plank Table**, **Stump Stool**, **Hide Rug**, **Hollow Trophy** (wall mount, after your first Brute kill), each with a "Placed x/y" cap. Visible bases make decor social proof (GAME_DESIGN) | 5 build pieces | 5 models + 5 icons | S1b |
| **SH-8** | The fence can't be passed; rooms are roofless | No gates; roofs undocumented and not upgradeable; no stairs. LDoE is top-down | **Palisade Gate:** the fence's door, 6 timber and 3 cord, 300 HP. **Timber, Scrap Metal and Reinforced Roof:** an upgrade chain priced like floors, hidden while the survivor stands under it (checklist 2.3 and 6.7). No stairs | 4 build pieces, Grid roof rule, occlusion hook | 1 gate + 3 tileable roof sets | S1b |
| **SH-9** | The airdrop is built but switched off | Airdrop at launch in 2017 ("Humanitarian Aid"); today up to 3 a day at 140, 80 and 20 Energy | Turn on `features.airdrops`. Add the Supply Drop event pin and the map pop-up card (#43) | flag, FogRegions pin, UI | crate model, panel art, map icon | S2B |
| **SH-10** | The Trail ends around day 7; chapter 2 has no hand-in | Path chapters 1–4 hold 26 quests | **Chapter 3, "Hold the Line":** (14) craft the Padded set; (15) hold through a Night Drift; (16) kill a Brute; (17) craft a Surgeon's Roll; (18) Saw Bench and Smelter to level 2; (19) find the Reinforcement Plans; (20) build a Reinforced door. Each reward supplies the next quest. Add `Haven.chapterRewards["Into the Fog"]`: 300 coins, 3 Surgeon's Rolls, 2 Trail Rations | 7 `QuestDef`s, 2 chapter rewards | none | S1b |
| **SH-11** | No Dense dungeon: no reset timer, no mini-boss, no big container count | Motel (yellow, no gate, 36 h reset): 13 storages × 20 slots, 16 Roamers, 11 Fast Biters, 2 Bloaters, the Weeper mini-boss, a locked basement | **Cinder Lodge** (§8.3) | 1 location, 3 loot tables, a mini-boss variant, pin | lodge kit (or the reused Rustwater kit), panel art, landmark | S2B |
| **SH-12** | The visible long-term goal is cheap and leads nowhere | Chopper frame at home from minute one; 20 Engine Parts and rare unique parts make it weeks for a free player | **Hauler v0.1.5:** 60 scrap plate, 40 rivets, 16 coil spring, 10 brass gear, 4 seized motor, 30 copper wire, 20 ironbark plank, 2 trigger group, and 2 **Hauler Axles**. The axle is a unique from Black strongboxes and band 3, about 1 per 4 Depot clears. **Inference:** it lands around day 20–25; confirm in Pacing.spec. Finished, it becomes a plot centrepiece with a 12-slot trunk until M4 driving | Projects edit, 1 item, loot rows | 1 icon | S1b (S2B loot) |
| **SH-13** | The Workbench holds plates, rivets, wire, cloth and leather on the binding throttle | Sewing Table and Tanning Rack are separate stations (ch3–4; 2017 L14 and L18) | **Reed Loom** (fiber → reedcloth) and **Tanning Frame** (raw hide → tanned leather). Both lines move off the Workbench | 2 stations, 2 pieces, recipe moves, save migration | 2 models | S1b |

### 5.3 POST-LAUNCH

| Item | LDoE reference | When |
|---|---|---|
| Second floors and stairs | none in LDoE | M3 or later (it touches raids and pathing) |
| Specialised storage: pantry, ore bin, parts rack | Fridge, Ore Storage and the like are store or Genesis items (2021+) | M2, as capacity products (#17) |
| Ironbound Trunk (45 slots) | Trunk | M2 (ECONOMY §5.3) |
| Standard firearms, Plated set, Ember Steel, the Ember Forge | Glock/M16 ladder, Tactical/SWAT | M2 (ECONOMY §10.2) |
| Crossbow; throwables (Pitch Bomb); breach charge | Makeshift crossbow, Molotov, C-4 | M2 |
| Fog Wraith; named bosses; AI raiders | Weeper, Ravager, Witch; Raiders | M2–M3 |
| Companions | the puppy in chapter 2 | M3 (a recorded deviation) |
| Buff cooking (a Hearth Stove) | Kitchen stove (ch3) | M3 |
| Fishing; shovel digging | Fishing Rod, Shovel (ch3–4) | M3+ |
| Repair (the Mender's Bench); weapon mods | Repair Station; Gunsmith Bench | M3; M2–M3 |
| Driving the Hauler | Chopper | M4 |
| +15 bag | Tactical Backpack (premium) | season or premium |
| Level cap past 20; skills | 1 pick of 3 per level, cap 200 | S3 / M3 |
| Region towers (`regionGates`) | Watchtowers | M4 |
| Fortified 4th build tier | L4 Metal | M3 |
| Forest forage (Fog Cap mushroom); more wildlife (a boar or turkey analogue) | Edible Mushroom; Turkey, Boar | M2 content patch |

---

## 6. The developer's examples, checked one by one

| Example | Verdict | Why |
|---|---|---|
| No armor sets | **Launch-blocking** (LB-1) | LDoE gives a 4-piece set in the first hour; we have 2 loose pieces |
| Too few weapons | **Launch-blocking** for the starter weapon and loot variety (LB-2); should-have for tier 3 (SH-5) | The count is close (8 vs 8–10 craftable), but we have no weapon for the first quests and no found weapons |
| No second floors or roofs | **Not an LDoE gap.** Roofs are SH-8 for the Roblox audience; second floors are post-launch | LDoE Home has no stairs or second storey; roofs are undocumented and can't be upgraded ([ldoe-base-building §1](ldoe-base-building.md)) |
| Too few zombie types | **Should-have, top priority** (SH-1) | First two hours: our 2 Hollow + 2 animals against LDoE's 2–3 zombies + 2 animals + AI. That is close. The gap opens in Dense and Black (BR-2) |
| Missing medical items | **Should-have** (SH-3) | In LDoE's first two hours, bandages are the only heal too. The First Aid Kit is chapter 4 |
| No bed or respawn point | **Respawn is launch-blocking** (LB-4). A bed is not a gap | LDoE's respawn is the Doormat. Its Comfortable Bed is late decor (L58 in 2017; Settlement track today). A cosmetic Bedroll is in SH-7 |
| No fridge or food storage | **Not a gap as storage.** Passive food and water stations are launch-blocking (LB-5) | LDoE food doesn't spoil, and its Fridge is a 2021 store and Genesis item. What LDoE *does* have in the first hour is the no-fuel food and water trio |

---

## 7. Balance risks

Where the gaps break the pacing model (ECONOMY §9) or leave a tier feeling empty.

| # | Risk | Numbers | Fix |
|---|---|---|---|
| **BR-1** | The six zones aren't merged, and Fog Runs are off on `main` | Without Ironbark Stand and Gloaming Deep, Ironbark comes only from Rustwater's interim 4 trees (8 logs a run). The Reinforced base needs **595 logs**: about 74 Dense runs, or about 1,630 Energy (5.7 days of regen) for logs alone, against the model's about 12 Gloaming Deep runs. The 36 Copper Wire need 90 malachite, about 11 more runs. The Reinforced band (days 10–14) slips by more than a week | Merge `e38dcc6` and flip `features.fogRuns` before the publish build; rerun Pacing.spec on the merged data |
| **BR-2** | **Black is the Light roster with more HP** | A Black lobby at band 3 is HP ×2.03 (Shambler 81, Runner 142, Bloater 122) and damage ×1.89. Nothing new arrives on days 7–13 to fight, wear or craft: the gear chase ends with the Pipe Pistol (day 3.8), the Fire Axe and the Padded Vest. ECONOMY §9.3 already calls days 9–13 "an ironbark slog" | SH-1, SH-4, SH-5, SH-11 |
| **BR-3** | **Walls protect nothing in v0.1** | No Horde, and raids come in M2. The Scrap tier (72 plates) and the Reinforced tier (265 plates, 119 Ironbark Planks, 123 Workbench-hours, about 30 h of play) have no gameplay payoff. The 1,699-Robux Reinforced Room Kit sells protection against nothing. LDoE had the Horde at launch | SH-2 (Night Drift) |
| **BR-4** | The armor sink is narrow, and fog gating doesn't work | 2 pieces under wear: 2.2 re-crafts a day (§8.5). LB-1 puts 4 pieces under wear (armor wears every equipped piece per hit), which roughly doubles the cloth drain (about +40 reedcloth a day: 80 fiber and 80 Workbench-min) and adds leather. Fog resist peaks at 0.25, so #37 can't gate tiers by gear | Rerun Pacing.spec with LB-1; SH-4; SH-13 |
| **BR-5** | The healing ceiling against the tier scale | Field Dressing heals 40. At Black band 3 a Runner hit is about 11 (6 × 1.3 × 1.45). If the scale reaches the Bloater cloud, standing in it costs about 68 HP. The model's 1.5 dressings per Black run is likely low, so deaths and haul loss (the model uses 8%) run higher | SH-3; log real dressing use and death rates at launch |
| **BR-6** | The Campfire is overloaded | Two Campfires carry boiling (about 40 min a day), cooking (about 25), pitch glue, and **85–91 Embercoal a day on days 10–13 (about 6 Campfire-hours)**. The model needed a food-first rule to stop starvation on days 8–10. SH-3's Antiseptic adds load | LB-5 moves water and meat off the Campfire; SH-6 |
| **BR-7** | The Workbench is the binding throttle | It holds 123 bench-hours for Reinforced, and cloth and leather share the same bench. LB-1 and SH-4 add about 1–2 bench-hours a day | SH-13, or retune plate timers after LB-1 |
| **BR-8** | **A content cliff around day 13** | The Ember Trail ends at quest 13 (about day 7). Level 20, the cap, comes on day 12.3, and XP has no use after it (no skills in v0.1). Reinforced is done on day 13.3. The Hauler's checklist is cheap (ECONOMY §9.4 says "far too cheap"). **Inference:** its 6 springs and 4 gears are in hand around day 7–8, since §9.3's day 7 alone gathers 14 springs and 5 gears. It then pays 2 Ember Tonics and can't be driven | SH-10, SH-12. M2 must land within about two weeks of launch |
| **BR-9** | **The POI dailies still pay Rations** | Pine Hollow 1, Rustwater 1, Caravan 1, Ashfall Depot 2: up to **5 Rations, or 300 Energy, a day**, more than the 288-a-day regen. ECONOMY §6.2 says location quests never pay Rations, and the §9 model doesn't count them. A day-7 player gets about twice the runs, which undercuts the 99-Robux Energy Refill (100 Energy) | Data only: pay XP plus an item (springs, embercoal, plates), as the six zone quests do. S2B |
| **BR-10** | XP sources are thin | Level 15 lands on day 7.3, against CONTENT_S2's days 5–6, because kills give 10/25/30 XP and survival runs pay little | SH-1's Brute (150 XP) and Retcher (40), plus chapter 3 quest XP; then retune `Data/Levels` |
| **BR-11** | The first quest kill has no weapon | Quest 1's kill objective switches on with Fog Runs; the first weapon is quest 6's club | LB-2 |

---

## 8. Map list check

### 8.1 Our planned maps

Sizes are full widths in studs, from each map's `half` value. Node totals are the sums of the data counts. Containers are the min–max placed per lobby. "b2" and "b3" mean the spawn joins at that Fog-meter band.

| Map | Tier and role | Size | Nodes | Containers | Hollow and wildlife | Reset |
|---|---|---|---|---|---|---|
| Pine Hollow | Light loot POI (farmstead) | 250 | 52 | 5–8 | Shambler 6–9, Runner 0–2 (b2), Deer 2–3, Wolf 1–2 | per lobby |
| Bracken Edge | Forest L1 | 250 | 98 | 1–3 | Shambler 5–7, Runner 0–1, Deer 2–3, Wolf 1–2 | per lobby |
| Rockfall Slope | Mine L1 | 250 | 102 | 1–3 | Shambler 5–7, Runner 1–2, Deer 1–2, Wolf 1–2 | per lobby |
| Rustwater | Dense loot POI (town) | 360 | 32 | 7–10 | Shambler 8–10, Runner 3–5, Bloater 1–2 (b2) | per lobby |
| Ironbark Stand | Forest L2 | 250 | 140 | 3–4 | Shambler 6–8, Runner 3–4 (+1–2 b2), Bloater 1–2 (b2), Wolf 2–3 | per lobby |
| Greenvein Bluffs | Mine L2 | 250 | 147 | 3–4 | Shambler 6–8, Runner 3–5, Bloater 1–2 (b2) | per lobby |
| Stranded Caravan | Dense, rotating | 220 | 20 | 4–5 | Shambler 6–8, Runner 4–5, Bloater 1–2 (b2) | 3 h in every 9 h |
| Ashfall Depot | Black dungeon (rail yard) | 360 | 41 | 6–8 | Shambler 8–12, Runner 5–7 (+2–3 b3), Bloater 2–3 | 20 h |
| Gloaming Deep | Forest L3 | 332 | 177 | 4–5 | Shambler 8–10, Runner 5–7 (+2–3 b3), Bloater 2–3, Wolf 2–3 | per lobby |
| Deepcut Pit | Mine L3 | 332 | 230 | 4–5 | Shambler 8–12, Runner 5–7 (+2–3 b3), Bloater 2–3 | per lobby |
| Supply Drop | Light airdrop (off) | — | 0 | 1 strongbox | Shambler 4–6, Runner 1–2, Bloater 1 | per appearance |

### 8.2 LDoE's early-game locations

Sizes are LDoE map units (600 for green and yellow zones, 800 for red), so only the 1.33× L3 ratio carries over. Our maps keep it.

| LDoE location | Type, gate, reset | Nodes | Containers | Enemy mix | Our counterpart | Verdict |
|---|---|---|---|---|---|---|
| Pine Bushes | farm L1, none, on exit | about 103 (27+3 trees, 3 rocks, 19 loose logs, 21 loose limestone, 20 fiber, 10 bushes) | 1–3 bags | Roamer, 1 Fast Biter, Grey Wolf, AI Survivor, rare Floater Bloater; deer | Bracken Edge (98, 1–3) | Match. Add the rare Bloater (SH-1) |
| Limestone Ridge | farm L1 | about 100 (25 rocks, 5 iron, 7+3 trees...) | 1–3 | Roamer, Grey Wolf, 1–2 Fast Biter, rare Bloater | Rockfall Slope (102, 1–3) | Match |
| Pine Grove | farm L2, L10 | about 145 | 3–4 | More Fast Biters, 1–2 Bloater, 1–2 Spitter, Rabid Wolf, deer, turkey, rare Big One | Ironbark Stand (140, 3–4) | Nodes match. **No ranged enemy** (Retcher, SH-1) |
| Limestone Cliffs | farm L2, L10 | about 143 (30 iron rocks) | 3–4 | As Grove; rare Timmy the Bloat | Greenvein Bluffs (147 incl. 10 malachite, 3–4) | Nodes match; no ranged enemy |
| Pine Wood (removed 1.19.4) / Limestone Spires | farm L3, L15 | about 215 / 225 | 4–5 | Abominations, The Big One, armed AI | Gloaming Deep (177) / Deepcut Pit (230) | Nodes match. **No heavy** (Brute, SH-1) |
| Crash Site | one-time FTUE | 20 dead trees, 30 loose logs, 10 limestone | **14 baggage × 12 slots** (22–44 in 2017) | Roamer, Grey Wolf | **none** | **Add: Courier Wreck (LB-6)** |
| Airdrop | event, up to 3 a day | 15 pines, 10 logs | 1 Aid Box (20 slots) | Bloater, 2 Spitters, AI waves at 5 and 10 min | Supply Drop (built, off) | **Switch on (SH-9)** |
| Motel | dungeon, no gate, 36 h | few | **13 × 20 slots** | 16 Roamers, 11 Fast Biters, 2 Bloaters, **Weeper** mini-boss; locked basement | Pine Hollow and Rustwater reset every lobby; nothing timed in Dense | **Add: Cinder Lodge (SH-11)** |
| Destroyed convoy | rotating, every 4 days, 1 h | 21 pine | 3 military boxes, 4 storages, a soldier corpse | Raiders, or Roamers, Fast Biters, Spitters, a Bloater, an Abomination and a Frenzied Giant | Stranded Caravan (3 h in every 9, 4–5 containers) | Match. Add the Brute at b3 |
| Oak Clearing | rotating, every 5 days | about 10 oak | — | variants | Ironbark Stand (always open) | Covered |
| Abandoned Factory | dungeon, 24 h | — | boxes broken with an Iron Hatchet | Spitter, Fast Biter, Bloater; Exploders | Ashfall Depot (20 h) | Match. Add the Brute and Retcher |
| Crooked Creek Farm | red dungeon, L15, 48 h | — | 60-slot chest | Yokels, Savage Giant, Infected Bull, Ravager boss, Raiders | none | Post-launch (needs bosses) |
| NPC Survivor Base | raid practice, about L10 | — | chests behind walls | none | none | M2 (raids) |

**Reading:**
- **Resource zones:** our six copy LDoE's six farm zones count for count (ECONOMY §6.2). No more are needed for v0.1.
- **Container density:**
  - The zones match: 1–3, 3–4 and 4–5.
  - Our POIs (5–10 containers) are thinner than LDoE's dungeons (13–14). The Courier Wreck and Cinder Lodge fill the two missing kinds: the first-trip loot spike and the timed dungeon with a mini-boss.
- **Enemy mix:** this is the real gap. Light matches LDoE's green zones minus the rare Bloater. Dense lacks a ranged threat, and Black lacks a heavy.

### 8.3 Recommended additional handcrafted maps for v0.1

**1. Courier Wreck (launch-blocking, LB-6; S2B)**
- **Role:** the one-time first trip and quest 6's target.
- **Size and contents:** Light, about 220 studs, 14 cargo cases and a cab strongbox; Shambler 3–4, Ash Wolf 1; 45 nodes.
- **Lifetime:** gone 15 min after you leave.

**2. Cinder Lodge (should-have, SH-11; S2B)**
- **Setting:** a burned roadside lodge with four cabins, a stable and a locked cellar.
- **Rules:** Dense, level 8, Run 22 Energy, Walk 19 min, a **36 h timer** from first entry, about 360 studs.
- **Containers:**
  - 12 room containers (wardrobes, lockers, trunks) using `loot.lodge_room`
  - 1 cellar strongbox using `loot.lodge_cellar`, with a pity rule toward the Pack Frame Schematic and a Brass Gear
  - The cellar opens with a Cellar Key found in one random room
- **Enemies:** Shambler 12–16, Runner 6–8, Bloater 2, Retcher 1–2, and **"the Innkeeper"**, a Brute variant (+40% HP) guarding the cellar.
- **Nodes:** about 30 (fatwood, scrap heaps, a spring).
- **Why:** it gives days 3–7 a daily dungeon before the Depot opens. It needs SH-1's Brute, so it ships with SH-1 or right after launch.

**3. Turn on the Supply Drop (SH-9; S2B).** No new map is needed: the location and its loot table exist.

**Not recommended for v0.1:**
- A second Light POI. Pine Hollow, the two L1 zones and the Wreck cover it.
- A Farm-style red boss dungeon. It needs bosses, which are M2–M3.

---

## 9. Sources

**LDoE Fandom wiki (wikitext read through the MediaWiki API, 2026-11-08):**
- Current: [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) (every recipe with its Survivor's Path unlock), [Version](https://last-day-on-earth-survival.fandom.com/wiki/Version) (release history back to 1.0, 27 May 2017), [Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path), [Home](https://last-day-on-earth-survival.fandom.com/wiki/Home), [Crash Site](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site), [Airdrop](https://last-day-on-earth-survival.fandom.com/wiki/Airdrop), [Motel](https://last-day-on-earth-survival.fandom.com/wiki/Motel), [Destroyed convoy](https://last-day-on-earth-survival.fandom.com/wiki/Destroyed_convoy), [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood), [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires), [Doormat](https://last-day-on-earth-survival.fandom.com/wiki/Doormat), [Comfortable Bed](https://last-day-on-earth-survival.fandom.com/wiki/Comfortable_Bed), [Fridge](https://last-day-on-earth-survival.fandom.com/wiki/Fridge), [Torch](https://last-day-on-earth-survival.fandom.com/wiki/Torch), [Spike Trap](https://last-day-on-earth-survival.fandom.com/wiki/Spike_Trap), [First Aid Kit](https://last-day-on-earth-survival.fandom.com/wiki/First_Aid_Kit), [Bandages](https://last-day-on-earth-survival.fandom.com/wiki/Bandages), [Garden Bed](https://last-day-on-earth-survival.fandom.com/wiki/Garden_Bed), [Rain Catcher](https://last-day-on-earth-survival.fandom.com/wiki/Rain_Catcher), [Meat Dryer](https://last-day-on-earth-survival.fandom.com/wiki/Meat_Dryer), [Fast Biter](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter), [Toxic Spitter](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Spitter), [Floater Bloater](https://last-day-on-earth-survival.fandom.com/wiki/Floater_Bloater), [Toxic Abomination](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Abomination).
- 2017 revisions: [Blueprints, 29 Jun 2017 (rev 704)](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints?oldid=704), [Blueprints, 29 Sep 2017 (rev 8619)](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints?oldid=8619), [Pine Bushes, Grove and Wood, 14 Dec 2017 (rev 13737)](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood?oldid=13737), [Limestone Ridge, Cliffs and Spires, 14 Dec 2017 (rev 13731)](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires?oldid=13731), [Wall, 27 Sep 2017 (rev 8340)](https://last-day-on-earth-survival.fandom.com/wiki/Wall?oldid=8340), [Home, 19 Aug 2017 (rev 5751)](https://last-day-on-earth-survival.fandom.com/wiki/Home?oldid=5751), [Crash Site, 10 Nov 2017 (rev 11844)](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site?oldid=11844), [Global Map, 14 Dec 2017 (rev 13744)](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map?oldid=13744), and the wiki main page of 27 Sep 2017 ("currently in Beta").
- Category membership with tag dates (what had a page by 31 Dec 2017): [Creatures](https://last-day-on-earth-survival.fandom.com/wiki/Category:Creatures), [Location](https://last-day-on-earth-survival.fandom.com/wiki/Category:Location), [Weapons](https://last-day-on-earth-survival.fandom.com/wiki/Category:Weapons), [Armor](https://last-day-on-earth-survival.fandom.com/wiki/Category:Armor), [Furniture](https://last-day-on-earth-survival.fandom.com/wiki/Category:Furniture), [Food](https://last-day-on-earth-survival.fandom.com/wiki/Category:Food), [Workstations](https://last-day-on-earth-survival.fandom.com/wiki/Category:Workstations).

**Press (2017):** Multiplayer.it's review of Android 1.5.9, 19 Sep 2017: [The crafting dead](https://multiplayer.it/recensioni/188595-last-day-on-earth-survival-the-crafting-dead-la-recensione-di-last-day-on-earth-survival.html). It confirms the 2017 loop (emblem-based blueprint unlocks, Energy refills with coins, unfinished beta features) and adds no item counts.

**Our research and specs:**
- [ldoe-systems/economy-progression.md](../ldoe-systems/economy-progression.md) (stations, ladders, sets, Path chapters, storage)
- [ldoe-systems/world-content.md](../ldoe-systems/world-content.md) (locations, enemies)
- [ldoe-core-systems.md](ldoe-core-systems.md) (FTUE, building, update history)
- [ldoe-base-building.md](ldoe-base-building.md) (pieces, storeys, traps)
- [ECONOMY.md](../ECONOMY.md) §6, §8, §9 and §10
- [MVP_LAUNCH.md](../MVP_LAUNCH.md)
- [LDOE_PARITY.md](../LDOE_PARITY.md)
- [GAME_DESIGN.md](../GAME_DESIGN.md) (weapon ladder names, night assaults)
- [PLAYER_EXPERIENCE_CHECKLIST.md](../PLAYER_EXPERIENCE_CHECKLIST.md) 9.9 and 13.1
- [DECISIONS.md](../DECISIONS.md) (the S1b worker calls)

**Our data:** `roblox/src/shared/Data/{Items, Recipes, Stations, BuildPieces, Nodes, Locations, LootTables, Enemies, Quests, Products, FogRegions, Haven, Projects, Levels, Tuning}.luau` on `main` (`4edcb60`), and `Locations`, `LootTables`, `Tuning` and `server/FogRuns/Maps/*` on `origin/claude/m1-slice2b-fog-runs-9a5388` (`e38dcc6`).
