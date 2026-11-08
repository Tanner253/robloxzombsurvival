# MVP content (M1)

The human-readable view of `roblox/src/shared/Data/`. The data files are the source of truth; this page explains them. Numbers follow the LDoE systems catalog ([economy-progression](ldoe-systems/economy-progression.md), [world-content](ldoe-systems/world-content.md)) and are a little more generous, per the monetization guardrails in [GAME_DESIGN.md](GAME_DESIGN.md). Every deliberate deviation is listed in [Deviations from LDoE](#deviations-from-ldoe).

**Counts:** 39 items, 21 recipes, 10 salvage entries, 3 stations, 10 resource nodes, 3 Hollow types, 11 loot tables, 4 locations, 20 build pieces, 20 levels, 10 quests, 4 products.

**Checks:** `DataValidator` (Lune test and server boot) rejects any broken reference. It also fails the build when:
- a node can't be harvested by any tool
- a location's loot preview lists something that never drops there
- a build tier's cost doesn't chain (see [Build pieces](#build-pieces))
- an item can only be bought, not earned in play
- a blueprint unlocks nothing
- a loot table, node, enemy or station is unused

Units: seconds, studs (one build cell = 12 studs), chances 0–1.

## Items

| ID | Name | Category | Stack | Durability | Stats / effect |
|---|---|---|---|---|---|
| item.timber | Timber | resource | 30 | — | fuel 2 m |
| item.stone | Fieldstone | resource | 30 | — | — |
| item.scrap | Rusted Scrap | resource | 50 | — | — |
| item.fiber | Reed Fiber | resource | 30 | — | — |
| item.fatwood | Fatwood | resource (fuel) | 30 | — | fuel 6 m |
| item.murky_water | Murky Water | resource (water) | 10 | — | thirst +15 |
| item.plank | Hewn Plank | material | 30 | — | fuel 3 m |
| item.rope | Reed Cord | material | 30 | — | — |
| item.cloth | Reedcloth | material | 30 | — | — |
| item.stone_block | Stone Block | material | 30 | — | — |
| item.scrap_plate | Scrap Plate | material | 30 | — | — |
| item.pitch_glue | Pitch Glue | part | 20 | — | — |
| item.rivets | Rivets | part | 30 | — | — |
| item.coil_spring | Coil Spring | part | 20 | — | — |
| item.brass_gear | Brass Gear | part (rare) | 20 | — | — |
| item.broken_lantern | Cracked Lantern | junk | 10 | — | Recycler fodder |
| item.snarled_wire | Snarled Wire | junk | 10 | — | Recycler fodder |
| item.seized_motor | Seized Motor | junk | 5 | — | Recycler fodder |
| item.stone_hatchet | Stone Hatchet | tool | 1 | 60 | hatchet tier 1 |
| item.stone_pick | Stone Pick | tool | 1 | 60 | pick tier 1 |
| item.spiked_club | Spiked Club | melee T1 | 1 | 110 | 14 dmg, 1.0/s, 6 studs |
| item.scrapblade | Scrapblade | melee T2 | 1 | 120 | 24 dmg, 1.3/s, 7 studs |
| item.shortbow | Reed Shortbow | ranged | 1 | 60 | 18 dmg, 0.8/s, 60 studs, uses arrows |
| item.arrow | Fire-Hardened Arrow | ammo | 40 | — | — |
| item.padded_hood | Padded Hood | armor (head) | 1 | 120 | defense 3 |
| item.padded_vest | Padded Vest | armor (body) | 1 | 150 | defense 6 |
| item.satchel | Reed Satchel | bag | 1 | — | +6 backpack slots |
| item.pack_frame | Scrap Pack Frame | bag | 1 | — | +12 backpack slots |
| item.emberberry | Emberberries | food | 20 | — | HP +3, hunger +4, thirst +2 |
| item.ashroot | Ashroot | food | 20 | — | HP +2, hunger +6 |
| item.roasted_ashroot | Roasted Ashroot | food | 10 | — | HP +15, hunger +30, Energy +2 |
| item.sealed_tin | Sealed Tin | food (loot) | 10 | — | HP +10, hunger +25, thirst +5 |
| item.hearth_stew | Hearth Stew | food | 10 | — | HP +40, hunger +60, thirst +15, Energy +8 |
| item.boiled_water | Boiled Water | drink | 10 | — | thirst +45 |
| item.ember_tea | Ember Tea | drink | 10 | — | HP +5, hunger +5, thirst +35, Energy +3 |
| item.field_dressing | Field Dressing | medical | 10 | — | HP +40 |
| item.ember_tonic | Ember Tonic | consumable (rare) | 5 | — | Energy +25, ignores the food cap |
| item.bp_pack_frame | Pack Frame Schematic | blueprint | 5 | — | unlocks the Pack Frame recipe |
| item.bp_reinforced | Reinforcement Plans | blueprint | 5 | — | unlocks the Reinforced build tier |

Armor reduction is `defense / (defense + 16.7)`, LDoE's formula: the hood and vest together cut 35%.

## Recipes

| Recipe | Inputs → output | Where | Time | Unlock |
|---|---|---|---|---|
| stone_hatchet | 3 timber + 3 stone → Stone Hatchet | hand | 5 s | start |
| stone_pick | 3 timber + 3 stone → Stone Pick | hand | 5 s | start |
| rope | 2 fiber → 1 Reed Cord | hand | 3 s | start |
| satchel | 2 cord + 3 fiber → Reed Satchel | hand | 10 s | start |
| field_dressing | 3 cloth → 1 Field Dressing | hand | 5 s | L2 |
| plank | 4 timber → 4 planks | Workbench | 10 m | start |
| cloth | 4 fiber → 2 Reedcloth | Workbench | 3 m | L2 |
| spiked_club | 4 plank + 2 cord + 3 scrap → Spiked Club | Workbench | 1 m | L2 |
| stone_block | 4 stone → 2 Stone Blocks | Workbench | 5 m | L3 |
| scrap_plate | 6 scrap → 2 Scrap Plates | Workbench | 10 m | L4 |
| padded_hood | 4 cloth + 2 cord → Padded Hood | Workbench | 2 m | L4 |
| shortbow | 4 plank + 4 cord + 1 glue → Reed Shortbow | Workbench | 3 m | L5 |
| arrow | 1 plank + 2 scrap + 1 fiber → 5 arrows | Workbench | 1 m | L5 |
| padded_vest | 6 cloth + 3 cord + 2 plate → Padded Vest | Workbench | 5 m | L6 |
| scrapblade | 4 plate + 2 plank + 2 cloth + 2 rivets → Scrapblade | Workbench | 5 m | L8 |
| pack_frame | 6 cloth + 6 cord + 3 plate + 2 rivets + 1 gear → Pack Frame | Workbench L2 | 10 m | blueprint |
| boiled_water | 2 murky → 2 boiled | Campfire | 2 m | start |
| roasted_ashroot | 2 ashroot → 2 roasted | Campfire | 2 m | start |
| ember_tea | 3 berries + 1 boiled water → 1 tea | Campfire | 2 m | L3 |
| pitch_glue | 2 fatwood → 1 Pitch Glue | Campfire | 4 m | L5 |
| hearth_stew | 2 ashroot + 3 berries + 1 boiled water → 1 stew | Campfire L2 | 8 m | L8 |

Processed materials craft in **batches** (4 planks per job). A job is one queue slot, so a full Workbench queue runs 30–50 minutes unattended, like LDoE's 20-unit station inputs.

## Stations

| Station | Build cost | Level | Upgrade cost | Queue | Speed | Needs |
|---|---|---|---|---|---|---|
| Workbench | 10 timber, 6 stone, 2 cord (on a foundation, max 2) | 1 | — | 3 | ×1 | — |
| | | 2 | 20 plank, 10 block, 6 plate | 5 | ×1.25 | L10 |
| | | 3 | 30 plank, 20 block, 12 plate, 3 gear | 7 | ×1.5 | L16 |
| Campfire | 5 timber, 5 stone, 2 fiber (on the ground, max 2) | 1 | — | 3 | ×1 | — |
| | | 2 | 12 block, 4 plate | 5 | ×1.25 | L6 |
| Recycler | 15 plank, 6 plate, 6 rivets, 2 springs (Scrap foundation, max 1) | 1 | — | 2 | ×1 | L7 |
| | | 2 | 10 plate, 6 rivets, 2 springs | 3 | ×1.2, +5% chance | L12 |
| | | 3 | 16 plate, 10 rivets, 4 springs, 2 gears | 4 | ×1.4, +10% chance | L18 |

**Campfire fuel:** jobs only progress while fuel burns. It burns timber (2 m), planks (3 m) and fatwood (6 m), with 20 fuel slots.

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
| Fallen Branches | hand | 1 | 2 timber | 20 | 3 m |
| Loose Stones | hand | 1 | 2 stone | 20 | 3 m |
| Reed Patch | hand | 1 | 3 fiber | 20 | 2 m |
| Emberberry Bush | hand | 1 | 3 berries | 20 | 5 m |
| Ashroot Mound | hand | 2 | 1 ashroot | 10 | 4 m |
| Spring Pool | hand | 3 | 1 murky water | 5 | 3 m |
| Pine | hatchet 1 | 4 | 1 timber | 10 | 4 m |
| Fatwood Stump | hatchet 1 | 3 | 1 fatwood (+1 timber, 30%) | 12 | 6 m |
| Boulder | pick 1 | 5 | 1 stone | 10 | 5 m |
| Scrap Heap | pick 1 | 4 | 2 scrap (+wire 8%, +rivets 4%) | 12 | 6 m |

XP is about 10 per resource unit, as in LDoE. Respawn applies to shared instances and the home plot. "Reset on exit" locations are rebuilt on every visit anyway.

**Home plot** (`Tuning.home`): 6 branches, 6 loose stones, 10 pines, 6 boulders, 4 reed patches, 2 berry bushes and 1 spring pool. That covers the about 60 timber and 20 stone that quests 1–5 need.

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

| Table | Rolls | Entries (weight, count) | Guaranteed |
|---|---|---|---|
| enemy_shambler | 0–1 | fiber 30 (1–2), cord 25 (1), cloth 20 (1), scrap 25 (1–3) | — |
| enemy_runner | 1 | scrap 35 (2–4), cord 25 (1–2), cloth 25 (1–2), tin 10, wire 5 | — |
| enemy_brute | 1–2 | plate 30 (1–2), rivets 25 (1–2), tin 20, spring 15, motor 10 | 3 scrap |
| pine_pack | 1–3 | tin 20, cord 20 (1–3), murky 15 (1–2), cloth 15 (1–2), boiled 10, lantern 10, dressing 8, wire 8, club 2 | — |
| pine_crate | 2–3 | timber 25 (3–6), plank 25 (2–4), scrap 20 (2–4), cord 15 (1–2), glue 5, hatchet 5, lantern 5 | — |
| quarry_toolbox | 2–3 | scrap 25 (3–6), plate 15 (1–2), rivets 15 (1–3), wire 12, lantern 10, arrows 10 (4–8), spring 6, pick 5, glue 2 | — |
| quarry_locker | 2–3 | tin 25 (1–2), boiled 20 (1–2), dressing 15 (1–2), cloth 15 (2–3), motor 6, hood 4, tonic 3, bow 2 | — |
| depot_freight | 3–4 | plate 22 (2–4), rivets 18 (2–4), block 15 (2–4), springs 12 (1–2), motor 12, arrows 10 (6–10), tin 10 (1–2), stew 4, gear 4 | — |
| depot_strongbox | 1–2 | gear 20 (1–2), springs 20 (1–2), tonic 16, Pack Frame BP 14, Reinforced BP 12, bow 10, Scrapblade 8, vest 8 | 2 rivets |
| caravan_wagon | 2–4 | plank 15 (4–8), plate 15 (2–4), rivets 14 (2–4), block 12 (3–5), springs 10 (1–2), tin 10 (2–3), stew 8 (1–2), dressing 8 (2), tonic 4, motor 4 | — |
| caravan_strongbox | 1 | Pack Frame BP 30, Reinforced BP 30, tonic 20, gear 20 (1–2) | 4 plate, 3 rivets |

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
- **Placing a higher tier directly** costs the lower tier's cost plus the upgrade cost. The validator enforces this, so refunds stay simple.

| Kind | Wood: HP / breach / cost | → Scrap Metal upgrade | Scrap: HP / breach | → Reinforced upgrade | Reinforced: HP / breach |
|---|---|---|---|---|---|
| Foundation | 600 / 2 / 10 timber | 6 plank, 4 plate | 1200 / 4 | 10 block, 6 plate, 2 rivets | 2400 / 8 |
| Wall | 400 / 1 / 8 timber, 1 cord | 4 plank, 3 plate | 800 / 2 | 8 block, 4 plate, 2 rivets | 1600 / 4 |
| Doorway | 350 / 1 / 6 timber, 1 cord | 3 plank, 3 plate | 700 / 2 | 6 block, 4 plate, 2 rivets | 1400 / 4 |
| Door | 300 / 1 / 5 timber, 2 cord | 2 plank, 3 plate, 1 rivets | 600 / 2 | 6 plate, 3 rivets, 1 spring | 1200 / 3 |
| Window wall | 350 / 1 / 7 timber, 1 cord | 3 plank, 3 plate | 700 / 2 | 6 block, 4 plate, 2 rivets | 1400 / 3 |

**Other pieces:** Workbench, Campfire and Recycler (see [Stations](#stations)). The **Timber Crate** (16 slots, 8 timber + 4 cord) upgrades to the **Banded Crate** (28 slots, L9, +6 plank, 4 plate, 2 rivets).

## Player levels and XP

| Level | Total XP | Unlocks (from gates) | Reward |
|---|---|---|---|
| 1 | 0 | hand tools, cord, satchel, plank, boiled water, roasted ashroot; Wood pieces, Workbench, Campfire, Timber Crate; Pine Hollow | — |
| 2 | 600 | cloth, field dressing, Spiked Club | 2 dressings |
| 3 | 1,500 | stone block, ember tea | 3 tins |
| 4 | 2,800 | scrap plate, Padded Hood; **Sunken Quarry** | — |
| 5 | 4,500 | Shortbow, arrows, pitch glue | 10 arrows, 1 tonic |
| 6 | 6,700 | Padded Vest; **Scrap Metal tier**; Campfire L2; Stranded Caravan | 10 planks |
| 7 | 9,400 | **Recycler** | — |
| 8 | 12,700 | Scrapblade, Hearth Stew | 4 plates |
| 9 | 16,600 | Banded Crate | — |
| 10 | 21,200 | **Ashfall Depot**; Workbench L2 | 2 tonics, 4 rivets |
| 11 | 26,500 | — | — |
| 12 | 32,600 | Recycler L2 | 1 gear |
| 13 | 39,500 | — | — |
| 14 | 47,300 | — | 3 stews |
| 15 | 56,000 | — | 2 tonics, 1 gear |
| 16 | 65,700 | Workbench L3 | — |
| 17 | 76,400 | — | 4 springs |
| 18 | 88,200 | Recycler L3 | — |
| 19 | 101,100 | — | — |
| 20 | 115,200 | — | 3 tonics, 2 gears |

Every level-up fully heals and restores 20 Energy.

**Pacing estimates:**
- A full clear of Pine Hollow is worth about 2,000 XP (LDoE's Pine Bushes: about 2,050). A Dense clear is worth about 2,100.
- With about 2,850 XP from the questline, L6 lands in the first long session and L10 on day 2.
- L20 takes about 50 more Dense or Black runs: one to two weeks of regular play.
- L11–20 are thin on unlocks on purpose. M2's raid tools and further stations fill them.

## Starter questline

| # | Quest | Objectives | Rewards |
|---|---|---|---|
| 1 | First Light | gather 6 timber, 6 stone (hand pickups at home) | 150 XP, 2 tins |
| 2 | Tools of Survival | craft Stone Hatchet, Stone Pick | 150 XP, 6 fiber |
| 3 | Claim the Ground | build 2 Timber Foundations, 2 Timber Walls | 200 XP, 10 timber, 4 cord |
| 4 | A Place to Work | build a Workbench, craft planks | 250 XP, 2 murky water, 2 ashroot |
| 5 | Keep the Fire | build a Campfire, boil water, drink it | 250 XP, 3 fatwood |
| 6 | Into the Fog | craft and equip a satchel, travel to Pine Hollow | 300 XP, 10 Energy, 2 dressings |
| 7 | Scavenger | open 3 containers in Pine Hollow, gather 4 ashroot | 300 XP, 4 scrap, 4 cloth |
| 8 | Stand Your Ground | craft and equip a Spiked Club, defeat 5 Hollow | 400 XP, Padded Hood |
| 9 | Hold the Door | build a doorway, a door and a Timber Crate | 350 XP, 6 planks |
| 10 | The Dense Fog | reach level 4, travel to the Sunken Quarry | 500 XP, 1 tonic, 6 scrap |

Each reward covers the next quest's inputs. For example, quest 7's scrap pays for the Spiked Club in quest 8, so nobody stalls.

## Products

Every item grant goes into the **locked stash**, so nothing bought can be raided. Prices are display fallbacks: the live price comes from MarketplaceService, so Roblox price tests and regional pricing work. Nothing sold is a shield, raid immunity or a random box.

| Product | Type | Default price | Limit | Grants |
|---|---|---|---|---|
| Outpost Supply Bundle (`product.resource_pack`) | dev product | R$ 99 | — | 60 timber, 60 stone, 40 scrap, 30 planks, 10 plates |
| Energy Refill (`product.energy_refill`) | dev product | R$ 49 | — | +100 Energy (can overfill to 200) |
| Pack Expansion (`product.backpack_upgrade`) | game pass | R$ 149 | 1 | +6 backpack slots |
| Firestarter Kit (`product.starter_offer`) | dev product | R$ 99 | 1, offered up to L10 | Scrapblade, Padded Hood, Padded Vest, 10 dressings, 5 stews, 3 tonics, 30 planks, 10 plates |

## Tuning

| Area | Value |
|---|---|
| Energy | cap 100, +1 per 5 m (full in 8 h 20 m), overfill to 200 from tonics and purchases, +20 per level-up, food and drink energy capped at 40 per UTC day |
| Inventory | 10 pockets, 0 backpack slots without a bag (6 / 12 with bags, +6 with the pass, max 18), 30-slot locked stash |
| Player | 100 HP, walk 16, sprint 22, fists 6 dmg at 1.8/s |
| Survival | hunger −1 per 14 s (about 23 m from full), thirst −1 per 11 s (about 18 m), 1 HP/s damage at 0, +0.1 HP/s while both are ≥ 60, respawn at 60/60/60 |
| Combat | armor constant 16.7, 1 durability per weapon hit and per hit taken |
| Gathering | 0.8 s swing, 1 durability per hit |
| Travel | 3 s Run load; fog tiers Light / Dense / Black |
| Death | pockets and backpack drop and last 2 h, equipped gear is kept, only the latest drop is kept |
| Building | 12-stud cells, 12-stud walls, 10×10 plot, full refund within 30 s, 50% after |
| New player | 2 tins, 2 boiled water |

## Deviations from LDoE

| Area | LDoE | Ours | Why |
|---|---|---|---|
| Energy | cap 200, green/yellow/red runs 15/22/33 at 1 per 5 m | cap 100, runs 10/15/22 at the same regen | Each run pays back in two thirds of the time (the "slightly more generous" guardrail). A smaller cap suits shorter Roblox sessions: a full bar is 10 Light runs. |
| Walk times | 12 / 19 / 29 m | 4 / 7 / 12 m | Walking is dead time on Roblox. Free play should feel viable, not punitive. |
| Survival drain | 1 per 10 s both, 2–5 HP/s at 0 | 1 per 14 s / 11 s, 1 HP/s | More forgiving for new Roblox players and the Mild rating. Thirst still leads, so water stays a reason to build the Campfire. |
| Food gives Energy | no (energy drinks are event-only) | cooked food +2 to +8, capped at 40/day; Ember Tonic +25 | GAME_DESIGN asks for food and drink to restore Energy. The daily cap stops a berry-farming energy loop. |
| Stacks | 20 default, scrap 50 | 30 default, scrap 50 | Inventory stays a pressure point but less fiddly. |
| Bags | basic +5, military +10 | +6 / +12 | Slightly generous. The bigger bag stays blueprint-gated like LDoE's. |
| Tools | 50 durability, 3 logs per tree, 3 stone per rock | 60 durability, 4 per tree, 5 per boulder | Fewer tool re-crafts. Node hits match LDoE. |
| Processing | plank 4 m each; iron plate = 4 scrap through two stations, about 24 m | plank 2.5 m each; scrap plate = 3 scrap, 5 m, one station | The MVP has three stations, not LDoE's eleven, so the Workbench folds in the woodworking, stonecutter and furnace steps. |
| Station queues | 20-unit inputs, +20 per level | 3/5/7 batch jobs | Similar unattended time (30–50 m of planks or plates) in our queue model. |
| Recycler | unlocks around L32, 10 m – 1 h jobs | L7, 5–20 m jobs | The MVP compresses the ladder to 20 levels, and the Recycler is an MVP station. |
| Bandage | 5 cloth → 40 HP | 3 cloth → 40 HP | Generous on healing. |
| Enemies | Roaming 40 HP; Fast Biter 80 HP / 6 dmg; Bloater 240 HP / 30 slam | 40; 70 / 6; 220 / 18 | Slightly softer. The Brute's slam is lower because MVP armor tops out at 9. |
| Dungeon reset | 24–48 h | Depot 20 h | Under a day, so a daily player never finds it still locked. |
| Rotating event | convoy 1 h every 4 days | Caravan 3 h every 9 h | GAME_DESIGN wants a daily return trigger. The drifting window is fair across time zones. |
| XP curve | not published | 600 → 115,200 over 20 levels | Designed to the pacing targets above. XP per resource unit (10) matches LDoE. |
| Crafting XP | none | none | Kept. |

## Notes for the Studio wiring worker

- Content IDs are permanent. The placeholders `item.wood`, `item.hatchet`, `loc.pine_grove` and `product.resource_pack_small` were renamed before anything shipped.
- `LocationDef.lootTableIds` and `resetSeconds` became `containers`, `reset` and `availability`.
- What a level unlocks is never stored: scan `UnlockGate`s, `levelGate`s and `requiredLevel`s.
- Fuel burn time is `fuel.burnSeconds[itemId]`, or `fuel.secondsPerUnit` for an item not listed there.
- Recycler chances get `salvageChanceBonus` from the station level added on top, then are scaled by durability when `Tuning.salvage.durabilityScalesChance` is set.
