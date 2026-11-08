# MVP content (M1)

The human-readable view of `roblox/src/shared/Data/`. The data files are the source of truth; this page explains them. Numbers follow the LDoE systems catalog ([economy-progression](ldoe-systems/economy-progression.md), [world-content](ldoe-systems/world-content.md)) and are a little more generous, per the monetization guardrails in [GAME_DESIGN.md](GAME_DESIGN.md). Every deliberate deviation is listed in [Deviations from LDoE](#deviations-from-ldoe).

**Counts:** 39 items, 22 recipes, 10 salvage entries, 6 stations, 10 resource nodes, 3 Hollow types, 12 loot tables, 5 locations, 23 build pieces, 20 levels, 10 quests, 4 products, 1 project and the starter shelter.

**LDoE parity (2026-11-08):** the binding rulings in [LDOE_PARITY.md](LDOE_PARITY.md) reshaped this content: stations are converters (#18-19), gear is crafted by hand (#20), stacks are 20 (#15), survival uses LDoE's numbers (#33), home nodes are finite (#30), and blueprints unlock through the Ember Trail quests (#48-49).

**Checks:** `DataValidator` (Lune test and server boot) rejects any broken reference. It also fails the build when:
- a node can't be harvested by any tool
- a location's loot preview lists something that never drops there
- a build tier chain breaks: an upgraded tier with no lower tier, or two pieces upgrading into one (see [Build pieces](#build-pieces))
- nested loot tables loop, or a pity can never pay out
- an item can only be bought, not earned in play
- a blueprint unlocks nothing
- a loot table, node, enemy or station is unused
- a station recipe isn't one input stack → one output stack, or a recipe or piece uses a level gate
- an Ember Trail quest asks for a recipe or piece no earlier quest unlocks
- the starter shelter can't be built on either row of plots

Units: seconds, studs (one build cell = 12 studs), chances 0–1.

## Items

| ID | Name | Category | Stack | Durability | Stats / effect |
|---|---|---|---|---|---|
| item.sticks | Sticks | resource | 20 | — | fuel 1 m |
| item.timber | Timber (logs) | resource | 20 | — | fuel 2 m |
| item.stone | Fieldstone | resource | 20 | — | — |
| item.scrap | Rusted Scrap | resource | 50 | — | — |
| item.fiber | Reed Fiber | resource | 20 | — | — |
| item.fatwood | Fatwood | resource (fuel) | 20 | — | fuel 5 m 20 s |
| item.murky_water | Murky Water | resource (water) | 20 | — | thirst +15 |
| item.plank | Hewn Plank | material | 20 | — | fuel 3 m |
| item.rope | Reed Cord | material | 20 | — | — |
| item.cloth | Reedcloth | material | 20 | — | — |
| item.stone_block | Stone Block | material | 20 | — | — |
| item.scrap_plate | Scrap Plate | material | 20 | — | — |
| item.pitch_glue | Pitch Glue | part | 20 | — | — |
| item.rivets | Rivets | part | 20 | — | — |
| item.coil_spring | Coil Spring | part | 20 | — | — |
| item.brass_gear | Brass Gear | part (rare) | 20 | — | — |
| item.broken_lantern | Cracked Lantern | junk | 20 | — | Recycler fodder |
| item.snarled_wire | Snarled Wire | junk | 20 | — | Recycler fodder |
| item.seized_motor | Seized Motor | junk | 20 | — | Recycler fodder |
| item.stone_hatchet | Stone Hatchet | tool | 1 | 60 | hatchet tier 1 |
| item.stone_pick | Stone Pick | tool | 1 | 60 | pick tier 1 |
| item.spiked_club | Spiked Club | melee T1 | 1 | 110 | 14 dmg, 1.0/s, 6 studs |
| item.scrapblade | Scrapblade | melee T2 | 1 | 120 | 24 dmg, 1.3/s, 7 studs |
| item.shortbow | Reed Shortbow | ranged | 1 | 60 | 18 dmg, 0.8/s, 60 studs, uses arrows |
| item.arrow | Fire-Hardened Arrow | ammo | 20 | — | — |
| item.padded_hood | Padded Hood | armor (head) | 1 | 120 | defense 3 |
| item.padded_vest | Padded Vest | armor (body) | 1 | 150 | defense 6 |
| item.satchel | Reed Satchel | bag | 1 | — | +5 backpack slots |
| item.pack_frame | Scrap Pack Frame | bag | 1 | — | +10 backpack slots |
| item.emberberry | Emberberries | food | 20 | — | HP +3, hunger +4, thirst +2 |
| item.ashroot | Ashroot | food | 20 | — | HP +2, hunger +6 |
| item.roasted_ashroot | Roasted Ashroot | food | 20 | — | HP +15, hunger +30 |
| item.sealed_tin | Sealed Tin | food (loot) | 20 | — | HP +10, hunger +25, thirst +5 |
| item.hearth_stew | Hearth Stew | food | 20 | — | HP +40, hunger +60, thirst +15 |
| item.boiled_water | Boiled Water | drink | 20 | — | thirst +45 |
| item.ember_tea | Ember Tea | drink | 20 | — | HP +5, hunger +5, thirst +35 |
| item.field_dressing | Field Dressing | medical | 20 | — | HP +40 |
| item.ember_tonic | Ember Tonic | consumable (rare) | 20 | — | Energy +25, ignores the food cap |
| item.bp_pack_frame | Pack Frame Schematic | blueprint | 20 | — | unlocks the Pack Frame recipe |
| item.bp_reinforced | Reinforcement Plans | blueprint | 20 | — | unlocks the Reinforced build tier |

Armor reduction is `defense / (defense + 16.7)`, LDoE's formula: the hood and vest together cut 35%.

## Recipes

**By hand** (the crafting catalogue, LDOE_PARITY #20): every tool, weapon, armor piece, bag and food mix. Only the hatchet, pick, satchel and its cord start unlocked; the rest unlock on the Ember Trail (#49).

| Recipe | Inputs → output | Time | Unlock |
|---|---|---|---|
| stone_hatchet | 3 sticks + 3 stone → Stone Hatchet | 5 s | start |
| stone_pick | 3 sticks + 3 stone → Stone Pick | 5 s | start |
| rope | 2 fiber → 1 Reed Cord | 3 s | start |
| satchel | 2 cord + 3 fiber → Reed Satchel | 10 s | start |
| field_dressing | 3 cloth → 1 Field Dressing | 5 s | Keep the Fire |
| spiked_club | 4 plank + 2 cord + 3 scrap → Spiked Club | 10 s | The Crash Site |
| padded_hood | 4 cloth + 2 cord → Padded Hood | 10 s | Hold the Door |
| hearth_stew | 2 roasted ashroot + 3 berries + 1 boiled water → 1 stew | 5 s | Hold the Door |
| shortbow | 4 plank + 4 cord + 1 glue → Reed Shortbow | 10 s | Stand Your Ground |
| arrow | 2 sticks + 2 scrap + 1 fiber → 5 arrows | 5 s | Stand Your Ground |
| padded_vest | 6 cloth + 3 cord + 2 plate → Padded Vest | 10 s | Stand Your Ground |
| scrapblade | 4 plate + 2 plank + 2 cloth + 2 rivets → Scrapblade | 10 s | Into the Fog |
| pack_frame | 6 cloth + 6 cord + 3 plate + 2 rivets + 1 gear → Pack Frame | 15 s | Pack Frame Schematic |

**At stations** (converter lines, #18): one input stack → one output stack, a batch at a time, at LDoE's pace.

| Recipe | Input → output (per batch) | Station | Time | Unlock |
|---|---|---|---|---|
| plank | 1 timber → 1 plank | Woodworking Bench | 4 m | Claim the Ground |
| stone_block | 2 stone → 1 Stone Block | Stonecutter | 4 m | A Place to Work |
| scrap_plate | 3 scrap → 1 Scrap Plate | Smelter (fuel) | 4 m | The Crash Site |
| cloth | 2 fiber → 1 Reedcloth | Workbench | 2 m | Keep the Fire |
| rivets | 1 Scrap Plate → 2 Rivets | Workbench | 4 m | Hold the Door |
| boiled_water | 1 murky → 1 boiled | Campfire (fuel) | 2 m | Tools of Survival |
| roasted_ashroot | 1 ashroot → 1 roasted | Campfire (fuel) | 2 m | Tools of Survival |
| ember_tea | 3 berries → 1 tea | Campfire (fuel) | 2 m | Keep the Fire |
| pitch_glue | 2 fatwood → 1 Pitch Glue | Campfire (fuel) | 4 m | Keep the Fire |

There is no repair yet (#21): worn gear is re-crafted. Repair comes later from a Repair Station or as a VIP perk.

## Stations

Every station is an LDoE converter (Domain/Converter): drag a stack into the input slot and it converts a batch at a time into the output slot; fuelled stations also take fuel and stop when it runs out (fuel burns only while converting). Each slot holds **20 at level 1, +20 per level**. Upgrading needs the station idle. Offline time counts.

| Station | Build cost | Floor | Max | Unlock | Converts | L2 / L3 upgrade |
|---|---|---|---|---|---|---|
| Woodworking Bench | 10 timber, 6 stone, 2 cord | Timber | 2 | Claim the Ground | timber → planks | 20 plank, 6 plate / 30 plank, 12 plate, 2 gears |
| Stonecutter | 8 plank, 10 stone, 2 cord | Timber | 2 | A Place to Work | stone → blocks | 20 block, 6 plate / 30 block, 12 plate, 2 gears |
| Smelter | 12 stone, 4 block, 6 sticks | ground | 2 | The Crash Site | scrap → plate (fuel) | 20 block, 10 plate / 30 block, 16 plate, 3 gears |
| Workbench | 10 plank, 6 block, 4 cord | Timber | 2 | Keep the Fire | fiber → cloth, plate → rivets | 20 plank, 10 block, 6 plate / 30 plank, 20 block, 12 plate, 3 gears |
| Campfire | 6 sticks, 5 stone, 2 fiber | ground | 2 | Tools of Survival | cooking (fuel) | 12 block, 4 plate / 20 block, 8 plate, 2 springs |
| Recycler | 15 plank, 6 plate, 6 rivets, 2 springs | Scrap | 1 | Into the Fog | junk and gear → parts, 4 output slots | 10 plate, 6 rivets, 2 springs (+5%) / 16 plate, 10 rivets, 4 springs, 2 gears (+10%) |

**Fuel** (Campfire, Smelter): sticks 1 m, timber 2 m, planks 3 m, fatwood 5 m 20 s (LDoE's log, plank and charcoal times).

**Recycler outputs.** Chances scale with the input's remaining durability, as in LDoE.

| Input | Time | Outputs (count, chance) |
|---|---|---|
| Cracked Lantern | 6 m | scrap 2–4 (100%), glue 1 (50%), rivets 1–2 (40%) |
| Snarled Wire | 5 m | scrap 1–3 (100%), rivets 2–3 (60%) |
| Seized Motor | 20 m | plate 1–2 (100%), springs 1–2 (60%), brass gear 1 (25%) |
| Spiked Club | 5 m | plank 1–2 (100%), scrap 1–2 (50%) |
| Scrapblade | 10 m | plate 1–2 (100%), rivets 1 (50%) |
| Reed Shortbow | 10 m | plank 1–2 (100%), cord 1–2 (60%), spring 1 (15%) |
| Padded Hood | 8 m | cloth 1–2 (100%), cord 1 (50%) |
| Padded Vest | 10 m | cloth 2–3 (100%), plate 1 (40%) |
| Either blueprint (spares) | 10 m | rivets 2–3, brass gear 1 (100%) |

## Resource nodes

| Node | Tool | Hits | Yield per hit | XP per hit | Respawn |
|---|---|---|---|---|---|
| Fallen Branches | hand | 1 | 2 sticks | 20 | 3 m |
| Loose Stones | hand | 1 | 2 stone | 20 | 3 m |
| Reed Patch | hand | 1 | 3 fiber | 20 | 2 m |
| Emberberry Bush | hand | 1 | 3 berries | 20 | 5 m |
| Ashroot Mound | hand | 2 | 1 ashroot | 10 | 4 m |
| Spring Pool | hand | 3 | 1 murky water | 5 | 3 m |
| Pine | hatchet 1 | 4 | 1 timber | 10 | 4 m |
| Fatwood Stump | hatchet 1 | 3 | 1 fatwood (+1 timber, 30%) | 12 | 6 m |
| Boulder | pick 1 | 5 | 1 stone | 10 | 5 m |
| Scrap Heap | pick 1 | 4 | 2 scrap (+wire 8%, +rivets 4%) | 12 | 6 m |

XP is about 10 per resource unit, as in LDoE. Respawn applies to Fog Run locations only: **home nodes never respawn** (LDOE_PARITY #30), except the spring pool, which refills like a well. "Reset on exit" locations are rebuilt on every visit anyway.

**Progression ladder:** hands → sticks + stone → hatchet → timber (logs) → planks. Sticks come only from Fallen Branches at home; timber only from pines and fatwood stumps, which need a hatchet.

**Home plot** (`Tuning.home`, LDoE's set): 20 pines, 7 boulders, 5 scrap heaps, 7 berry bushes, 20 reed patches, 12 fallen branches, 10 loose stones and the spring. It is finite and saved per outpost: about 80 timber and 55 stone in all, enough for the tools, the first stations and the shelter's repairs, and far short of a Timber-tier base. The bulk comes from Fog Runs.

**Starter shelter** (`Data/StarterShelter`, #56): every new plot starts with a damaged timber room: 9 foundations, 5 broken walls, a cold Campfire and a Timber Crate, open to the road. **Wrecked hauler** (`Data/Projects`): its parts checklist (20 plate, 16 rivets, 6 springs, 4 gears, a seized motor, 10 cord) is the long-term goal; its model waits on the art gate.

## Locations

| | Pine Hollow | Sunken Quarry | Ashfall Depot | Stranded Caravan (event) |
|---|---|---|---|---|
| Fog | Light | Dense | Black | Dense |
| Level gate | 1 | 4 | 10 | 6 |
| Run (Energy) | 10 | 15 | 22 | 14 |
| Walk | 4 m | 7 m | 12 m | 8 m |
| Reset | on exit | on exit | 20 h after first entry | each appearance |
| Availability | always | always | always | 3 h open in every 9 h |
| Containers | 2–3 Abandoned Pack, 1–2 Woodcutter's Crate | 2–3 Toolbox, 1–2 Supply Locker | 4–5 Freight Crate, 1–2 Strongbox | 3–4 Wagon, 1 Strongbox |
| Nodes | 16 pine, 10 boulder, 8 branches, 8 stones, 10 reeds, 6 bushes, 6 ashroot, 2 pools | 18 boulder, 8 scrap, 6 fatwood, 6 pine, 4 ashroot, 2 pools | 14 scrap, 6 fatwood, 6 boulder, 1 pool | 6 scrap, 4 fatwood |
| Hollow | 6–9 Shambler, 0–2 Runner | 8–10 Shambler, 3–5 Runner, 0–1 Brute | 8–12 Shambler, 5–7 Runner, 2–3 Brute | 6–8 Shambler, 4–5 Runner, 1–2 Brute |
| Main loot | timber, stone, fiber, berries, ashroot, water | stone, scrap, fatwood, timber | scrap, plate, rivets, springs, fatwood | plank, block, plate, rivets |
| Possible loot | plank, cord, cloth, scrap, tins, dressings, lantern, hatchet, club | plate, rivets, springs, arrows, tins, dressings, motor, hood, bow, tonic | block, motor, gear, stew, tonic, Scrapblade, vest, both blueprints | springs, stew, dressings, tonic, gear, both blueprints |

The Caravan opens 3 hours in every 9. Nine doesn't divide 24, so the window drifts through the day and every time zone gets an evening window within three days.

**Blueprint odds:**
- Each Depot run has about a 27% chance of a Pack Frame Schematic and 23% of Reinforcement Plans.
- Each Caravan strongbox is 30% for either.
- A player who does one of each per day gets Reinforcement Plans in about 2 days on average.

## Loot tables

*Junk* means one open of the shared `loot.junk` sub-table (an entry with `tableId`).

| Table | Rolls | Entries (weight, count) | Guaranteed | Pity |
|---|---|---|---|---|
| enemy_shambler | 0–1 | fiber 30 (1–2), cord 25 (1), cloth 20 (1), scrap 25 (1–3) | — | — |
| enemy_runner | 1 | scrap 35 (2–4), cord 25 (1–2), cloth 25 (1–2), tin 10, wire 5 | — | — |
| enemy_brute | 1–2 | plate 30 (1–2), rivets 25 (1–2), tin 20, spring 15, junk 10 | 3 scrap | — |
| pine_pack | 1–3 | tin 20, cord 20 (1–3), murky 15 (1–2), cloth 15 (1–2), boiled 10, lantern 10, dressing 8, wire 8, club 2 | — | — |
| pine_crate | 2–3 | timber 20 (3–6), sticks 15 (4–8), plank 20 (2–4), scrap 20 (2–4), cord 15 (1–2), glue 5, hatchet 5, lantern 5 | — | — |
| quarry_toolbox | 2–3 | scrap 25 (3–6), junk 22, plate 15 (1–2), rivets 15 (1–3), arrows 10 (4–8), spring 6, pick 5, glue 2 | — | — |
| quarry_locker | 2–3 | tin 25 (1–2), boiled 20 (1–2), dressing 15 (1–2), cloth 15 (2–3), motor 6, hood 4, tonic 3, bow 2 | — | — |
| depot_freight | 3–4 | plate 22 (2–4), rivets 18 (2–4), block 15 (2–4), junk 14, springs 12 (1–2), arrows 10 (6–10), tin 10 (1–2), stew 4, gear 4 | — | — |
| depot_strongbox | 1–2 | gear 20 (1–2), springs 20 (1–2), tonic 16, Pack Frame BP 14\*, Reinforced BP 12\*, bow 10, Scrapblade 8, vest 8 | 2 rivets | epic every 5 |
| caravan_wagon | 2–4 | plank 15 (4–8), plate 15 (2–4), rivets 14 (2–4), block 12 (3–5), springs 10 (1–2), tin 10 (2–3), stew 8 (1–2), dressing 8 (2), junk 6, tonic 4 | — | — |
| caravan_strongbox | 1 | Pack Frame BP 30\*, Reinforced BP 30\*, tonic 20, gear 20 (1–2) | 4 plate, 3 rivets | epic every 3 |
| junk (sub-table) | 1 | lantern 45, wire 40, motor 15 | — | — |

\* The entry's `rarity` is overridden to epic, so the pity guarantees a blueprint: at least one in every 5 Depot strongboxes and every 3 Caravan strongboxes. Pity counters are per player.

## Enemies (the Hollow)

| Hollow | HP | Damage | Attack every | Speed | Aggro | XP | Loot |
|---|---|---|---|---|---|---|---|
| Shambler | 40 | 5 | 1.6 s | 8 | 28 | 10 | enemy_shambler |
| Runner | 70 | 6 | 1.0 s | 18 | 42 | 25 | enemy_runner |
| Brute | 220 | 18 | 2.4 s | 10 | 34 | 80 | enemy_brute |

Speeds and aggro radius are in studs. The player walks at 16 and sprints at 22, so a Runner can only be escaped by sprinting. In keeping with the Mild rating, the Hollow dissolve into ash and leave their loot.

## Build pieces

12-stud grid. Wood is free to start, Scrap Metal unlocks at L6, and Reinforced unlocks with the Reinforcement Plans blueprint.

**Rules:**
- **Wall tier:** walls, doorways, doors and windows set `minFoundationTier` to their own tier, so a wall can never out-tier its floor.
- **Costs follow Domain/Grid.** A Wood piece's `cost` is its placement price. A Scrap Metal or Reinforced piece's `cost` is the price of upgrading into it from the tier below, and demolish refunds walk the whole chain. Upgraded tiers are reached only by upgrading, never placed directly.
- **Chain checks:** the validator makes sure every upgraded tier has exactly one lower tier upgrading into it.

| Kind | Wood: HP / breach / cost | Scrap Metal cost (upgrade) | Scrap: HP / breach | Reinforced cost (upgrade) | Reinforced: HP / breach |
|---|---|---|---|---|---|
| Foundation | 600 / 2 / 10 timber | 6 plank, 4 plate | 1200 / 4 | 10 block, 6 plate, 2 rivets | 2400 / 8 |
| Wall | 400 / 1 / 8 timber, 1 cord | 4 plank, 3 plate | 800 / 2 | 8 block, 4 plate, 2 rivets | 1600 / 4 |
| Doorway | 350 / 1 / 6 timber, 1 cord | 3 plank, 3 plate | 700 / 2 | 6 block, 4 plate, 2 rivets | 1400 / 4 |
| Door | 300 / 1 / 5 timber, 2 cord | 2 plank, 3 plate, 1 rivets | 600 / 2 | 6 plate, 3 rivets, 1 spring | 1200 / 3 |
| Window wall | 350 / 1 / 7 timber, 1 cord | 3 plank, 3 plate | 700 / 2 | 6 block, 4 plate, 2 rivets | 1400 / 3 |

**Other pieces:** the stations (see [Stations](#stations)). The **Timber Crate** (LDoE's Small Box: 15 slots, 8 timber + 4 cord, unlocked from the start) upgrades to the **Banded Crate** (LDoE's Chest: 25 slots, +6 plank, 4 plate, 2 rivets, unlocked by Hold the Door). Scrap tier: Stand Your Ground. Reinforced tier: the Reinforcement Plans schematic.

## Player levels and XP

| Level | Total XP | Location unlocked | Reward |
|---|---|---|---|
| 1 | 0 | Pine Hollow, the Crash Site | — |
| 2 | 600 | — | 2 dressings |
| 3 | 1,500 | — | 3 tins |
| 4 | 2,800 | **Sunken Quarry** | — |
| 5 | 4,500 | — | 10 arrows, 1 tonic |
| 6 | 6,700 | Stranded Caravan | 10 planks |
| 7 | 9,400 | — | — |
| 8 | 12,700 | — | 4 plates |
| 9 | 16,600 | — | — |
| 10 | 21,200 | **Ashfall Depot** | 2 tonics, 4 rivets |
| 11 | 26,500 | — | — |
| 12 | 32,600 | — | 1 gear |
| 13 | 39,500 | — | — |
| 14 | 47,300 | — | 3 stews |
| 15 | 56,000 | — | 2 tonics, 1 gear |
| 16 | 65,700 | — | — |
| 17 | 76,400 | — | 4 springs |
| 18 | 88,200 | — | — |
| 19 | 101,100 | — | — |
| 20 | 115,200 | — | 3 tonics, 2 gears |

Levels gate only locations (LDOE_PARITY #49): recipes, pieces and station levels unlock on the Ember Trail or with schematics.

Every level-up fully heals and restores 20 Energy.

**Pacing estimates:**
- A full clear of Pine Hollow is worth about 2,000 XP (LDoE's Pine Bushes: about 2,050). A Dense clear is worth about 2,100.
- With about 2,850 XP from the questline, L6 lands in the first long session and L10 on day 2.
- L20 takes about 50 more Dense or Black runs: one to two weeks of regular play.
- L11–20 are thin on unlocks on purpose. M2's raid tools and further stations fill them.

## The Ember Trail (starter questline)

LDoE calls its own questline "Survivor's Path"; ours is the **Ember Trail** (#48). A quest completes by itself on its last objective; its rewards go to the inbox and it unlocks the blueprints that the next quests need (#49-50). The trail branches after quest 2 (the building line 3, 4, 7 and the fire line 5, 6, 8), so the tracker shows two or three quests. Objectives marked *(Fog)* wait on Fog Runs (S2) and are left out until then; quests 1-8 are playable at home.

| # | Quest | After | Objectives | Rewards | Unlocks |
|---|---|---|---|---|---|
| 1 | First Light | — | gather 6 sticks, 6 stone; *(Fog)* put down a Hollow, search its body | 150 XP, 2 tins | Timber Foundation, Timber Wall |
| 2 | Tools of Survival | 1 | craft the Stone Hatchet and Stone Pick | 150 XP, 6 fiber | Campfire, boiled water, roasted ashroot |
| 3 | Claim the Ground | 2 | build 2 foundations, 2 walls | 200 XP, 10 timber, 4 cord | Woodworking Bench, planks, doorway, door |
| 4 | A Place to Work | 3 | build the Woodworking Bench, make planks | 250 XP, 2 murky water, 2 ashroot | Stonecutter, stone blocks, window wall, palisade |
| 5 | Keep the Fire | 2 | boil water at the shelter's campfire, drink it | 250 XP, 6 fatwood | Workbench, cloth, dressings, ember tea, pitch glue |
| 6 | The Crash Site | 5 | craft and equip a satchel; *(Fog)* reach the crash site | 300 XP, 2 dressings, 6 scrap | Smelter, scrap plate, Spiked Club |
| 7 | Hold the Door | 4 | build a doorway, a door and a Timber Crate | 350 XP, 6 planks, 4 cloth | Banded Crate, rivets, Padded Hood, Hearth Stew |
| 8 | Stand Your Ground | 6 | craft and equip a Spiked Club; *(Fog)* put down 5 Hollow | 400 XP, Padded Hood | Scrap tier, Shortbow, arrows, Padded Vest |
| 9 | Into the Fog | 8 | *(Fog)* reach Pine Hollow, search 3 containers, gather 4 ashroot | 300 XP, 10 Energy, 4 scrap, 4 cloth | Recycler, Scrapblade |
| 10 | The Dense Fog | 9 | reach level 4; *(Fog)* reach the Sunken Quarry | 500 XP, 1 tonic, 6 scrap | — |

## Products

Every item grant goes into the **locked stash**, so nothing bought can be raided. Prices are display fallbacks: the live price comes from MarketplaceService, so Roblox price tests and regional pricing work. Nothing sold is a shield, raid immunity or a random box.

| Product | Type | Default price | Limit | Grants |
|---|---|---|---|---|
| Outpost Supply Bundle (`product.resource_pack`) | dev product | R$ 99 | — | 60 timber, 60 stone, 40 scrap, 30 planks, 10 plates |
| Energy Refill (`product.energy_refill`) | dev product | R$ 49 | — | +100 Energy (can overfill to 200) |
| Pack Expansion (`product.backpack_upgrade`) | game pass | R$ 149 | 1 | +5 backpack slots |
| Firestarter Kit (`product.starter_offer`) | dev product | R$ 99 | 1, offered up to L10 | Scrapblade, Padded Hood, Padded Vest, 10 dressings, 5 stews, 3 tonics, 30 planks, 10 plates |

## Tuning

| Area | Value |
|---|---|
| Energy | cap 100, +1 per 5 m (full in 8 h 20 m), overfill to 200 from tonics and purchases, +20 per level-up; food never restores Energy (#33), only the rare Ember Tonic |
| Inventory | 10 pockets, 0 backpack slots without a bag (+5 / +10 with bags, +5 with the pass, max 15; a +15 bag comes with Fog Run loot), the quick slot, stacks of 20 (scrap 50), the unlimited inbox |
| Player | 100 HP, walk 16, sprint 22, fists 6 dmg at 1.8/s |
| Survival | LDoE's numbers (#33): both meters drain 1 per 10 s in the world (about 17 minutes from full), 2 HP/s at 0, the HUD warns at 20. +0.1 HP/s while both are ≥ 60. Death resets every meter to full |
| Combat | armor constant 16.7, 1 durability per weapon hit and per hit taken |
| Gathering | 0.8 s swing, 1 durability per hit |
| Travel | 3 s Run load; fog tiers Light / Dense / Black |
| Death | pockets and backpack drop and wait 2 h at the location (`keepPockets = false`); equipped gear is kept |
| Building | 12-stud cells, 12-stud walls, 10×10 plot, full refund within 30 s of placing or upgrading, 50% after |
| New player | 2 tins, 2 boiled water |

## Deviations from LDoE

| Area | LDoE | Ours | Why |
|---|---|---|---|
| Energy | cap 200, green/yellow/red runs 15/22/33 at 1 per 5 m | cap 100, runs 10/15/22 at the same regen | Each run pays back in two thirds of the time (the "slightly more generous" guardrail). A smaller cap suits shorter Roblox sessions: a full bar is 10 Light runs. |
| Walk times | 12 / 19 / 29 m | 4 / 7 / 12 m | Walking is dead time on Roblox. Free play should feel viable, not punitive. |
| Tools | 50 durability, 3 logs per tree, 3 stone per rock | 60 durability, 4 per tree, 5 per boulder | Fewer tool re-crafts. Node hits match LDoE. |
| Recycler | unlocks around L32, 10 m – 1 h jobs | quest 9, 5–20 m batches | The MVP compresses the ladder, and the Recycler is an MVP station. |
| Bandage | 5 cloth → 40 HP | 3 cloth → 40 HP | Generous on healing. |
| Enemies | Roaming 40 HP; Fast Biter 80 HP / 6 dmg; Bloater 240 HP / 30 slam | 40; 70 / 6; 220 / 18 | Slightly softer. The Brute's slam is lower because MVP armor tops out at 9. |
| Dungeon reset | 24–48 h | Depot 20 h | Under a day, so a daily player never finds it still locked. |
| Rotating event | convoy 1 h every 4 days | Caravan 3 h every 9 h | GAME_DESIGN wants a daily return trigger. The drifting window is fair across time zones. |
| XP curve | not published | 600 → 115,200 over 20 levels | Designed to the pacing targets above. XP per resource unit (10) matches LDoE. |
| Crafting XP | none | none | Kept. |

## Notes for the Studio wiring worker

- Content IDs are permanent. The placeholders `item.wood`, `item.hatchet`, `loc.pine_grove` and `product.resource_pack_small` were renamed before anything shipped.
- `LocationDef.lootTableIds` and `resetSeconds` became `containers`, `reset` and `availability`.
- What unlocks what is never stored: scan `UnlockGate`s (Domain/Unlocks.byQuest lists a quest's blueprints) and location `levelGate`s.
- Tuning sections can be passed as is: `energy` to Energy, `survival` to Survival, `death` to Death, `building` to Grid and `travel` to Travel.
- Fuel burn time is `fuel.burnSeconds[itemId]`, or `fuel.secondsPerUnit` for an item not listed there (Domain/Converter.burnSeconds).
- Placement is limited to chain bases (BuildRules `notBase`), so an upgraded tier can't be placed for the price of its upgrade step.
- Recycler chances get `salvageChanceBonus` from the station level added on top, then are scaled by durability when `Tuning.salvage.durabilityScalesChance` is set.
