# Economy v0.1: what S2B picks up

Written by the economy worker on 2026-11-08, after branch `claude/m1-economy-v01` landed the [ECONOMY.md](../ECONOMY.md) v0.1 data. Your brief owns the location maps, location node placement, loot tables, Hollow stats per tier and the personal-node lobby logic. This file lists exactly what is waiting for you, and the IDs you can now use.

## 1. Item, node and recipe IDs now in Data

**New items** (`Data/Items`; every icon is `""` until the painted icons exist):

| ID | Name | Notes |
|---|---|---|
| `item.ironbark_log` | Ironbark Log | from `node.ironbark_tree`, needs the Forged Hatchet |
| `item.ironbark_plank` | Ironbark Plank | 5 logs, Saw Bench L2 |
| `item.ironstone` | Ironstone | from `node.ironstone_rock`, stone pick |
| `item.iron_ingot` | Iron Ingot | Smelter: 2 ironstone or 5 scrap |
| `item.malachite` | Malachite | from `node.malachite_vein`, needs the Forged Pick |
| `item.copper_ingot` | Copper Ingot | 5 malachite, Smelter L2, 1 h |
| `item.copper_wire` | Copper Wire | 1 copper ingot → 2, Workbench L2 |
| `item.embercoal` | Embercoal | 2 timber, Campfire; fuel 5 m 20 s |
| `item.forged_hatchet`, `item.forged_pick` | Forged Hatchet, Forged Pick | tools, tier 2, durability 75 |

Existing IDs the §7 tables use are unchanged: `item.raw_meat` (Raw Venison), `item.cooked_meat`, `item.hide`, `item.sealed_tin`, `item.boiled_water`, `item.murky_water`, `item.rope` (Reed Cord), `item.cloth` (Reedcloth), `item.pitch_glue`, `item.scrap`, `item.scrap_plate`, `item.rivets`, `item.coil_spring`, `item.brass_gear`, `item.steel_pipe`, `item.trigger_group`, `item.blackpowder`, `item.light_rounds`, `item.shells`, `item.flare`, `item.seized_motor`, `item.snarled_wire`, `item.broken_lantern`, `item.bp_reinforced`, `item.bp_pack_frame`.

**New nodes** (`Data/Nodes`, each needs a model graded A in `Art.nodes`):

| ID | Tool | Hits | Yield | XP/hit | Respawn |
|---|---|---|---|---|---|
| `node.ironbark_tree` | hatchet 2 | 4 | 1 log on every 2nd hit (`yieldEvery = 2`): 2 a tree | 5 | 6 m |
| `node.ironstone_rock` | pick 1 | 3 | 1 ironstone a hit: 3 | 10 | 5 m |
| `node.malachite_vein` | pick 2 | 6 | 1 malachite every 3rd hit: 2 | 4 | 8 m |

`Domain/Gathering` and `Domain/AutoClear` already honour `yieldEvery`, and the validator checks that it divides `hits`. Pine and boulder now take 3 hits; the berry bush gives 3.

## 2. Interim node placements to replace

The validator fails any node no location or home plot places, so I placed the three new nodes as a stopgap:

| Location | Node | Count | What to do |
|---|---|---|---|
| `loc.sunken_quarry` | `node.ironbark_tree` | 4 | **Interim.** Remove once Ironbark Stand and Gloaming Deep place it |
| `loc.sunken_quarry` | `node.malachite_vein` | 4 | **Interim.** Remove once Greenvein Bluffs and Deepcut Pit place it |
| `loc.ashfall_depot` | `node.ironstone_rock` | 8 | **Final**: ECONOMY §6.3 ("the pit"). Keep it, and give it a map marker |

I made no other location changes: no node counts, containers, spawns, previews or quests.

## 3. Loot tables: ready to paste

`roblox/tests/Pacing.spec.luau` holds every §7 table in `Data/LootTables` shape, in its `LOOT` block. The block is generated from `tools/economy/pacing.py`, so it is exactly what the pacing model assumes:
- the 9 new tables: `loot.zone_pack_t1..t3`, `loot.forest_crate_t1..t3` and `loot.mine_box_t1..t3`
- the nested `loot.junk` they open (Cracked Lantern 45, Snarled Wire 40, Seized Motor 15)
- the §7.4 versions of `loot.pine_pack`, `loot.pine_crate`, `loot.quarry_toolbox`, `loot.quarry_locker`, `loot.quarry_band2` and `loot.quarry_band3`, plus the band, depot and strongbox tables

Two things are missing from that block:
- **Pity on `loot.quarry_band2`:** add `pity = { rarity = "epic", every = 15 }`, with the Trigger Group entry carrying `rarity = "epic"` (§7.4).
- **Rarity on the Pack Frame Schematic:** in `loot.forest_crate_t3`, give it `rarity = "epic"`.

Food and water are already thinned in those tables (§7.4).

**When your tables and locations are in Data:**
- Point `Pacing.spec`'s `lootTables` at `Data/LootTables`, and its `locations` at the real maps (or keep the model copy and assert that they match).
- Re-run `PACING_VERBOSE=1 lune run tests/run`.
- Every band must still hold. `Domain/Loot.expected` reads either source.

## 4. Locations (ECONOMY §6)

`Pacing.spec`'s `LOCATIONS` block carries the model's node counts, containers (as average counts), Hollow and wildlife averages, band tables and gates for all six new maps and the three POIs:
- **Forests:** Bracken Edge, Ironbark Stand and Gloaming Deep.
- **Mines:** Rockfall Slope, Greenvein Bluffs and Deepcut Pit.
- **POIs:** Pine Hollow, Rustwater (`loc.sunken_quarry`, which should display as Rustwater) and Ashfall Depot.

Use it as the checklist against §6.2–6.3 when you author `Data/Locations`. Leave Gloamwood and Tinstone out of v0.1: neither the nodes nor the items exist.

## 5. Daily location quests (§6.2)

The cap is built and tested, but nothing feeds it yet, because nothing tracks location quests:
- `Tuning.locationQuests = { period = "daily" }`
- `PlayerData.locationQuests` (questId → UTC day it last paid), added in save v8
- `Domain/Quests.locationQuestOpen(log, questId, now, config)` and `markLocationQuest(...)`

**When you wire location quests on the run server:** check `locationQuestOpen` before paying, then `markLocationQuest` into `PlayerData.locationQuests`. The existing S2 quests may keep their Rations, because the cap stops the Energy loop (DECISIONS 2026-11-08). The six new §6.2 quests pay XP and items only.

## 6. Quest 13's travel objective

`quest.into_the_black` uses the new form `{ kind = "travel", fogTier = 3 }`, meaning any Black location:
- `Domain/Quests.Event` has a `fogTier` field.
- When your arrival code fires the quest `travel` event, send the location's `fogTier` with it. The existing quests 6 and 10 still match by `locationId`.

## 7. Everything else on your list

- **Hollow tier scale:** `Tuning.hollowTierScale = { health = { 1, 1.2, 1.4 }, damage = { 1, 1.15, 1.3 } }` (§6.4) is not added. It is your Hollow-stats pass. The pacing model already assumes HP ×1/1.2/1.4 (`hpScale` in `Pacing.spec`).
- **Personal nodes:** `Tuning.runs = { personalNodes = true, nodesRegrow = false }` (§1, §11.1) is not added. It belongs with your lobby logic.
- **Map markers:** validator check (b), "map node markers equal data counts", needs your marker contract. Add it with the maps.
- **Previews:** keep `mainLoot` and `possibleLoot` to items that really drop there. The validator enforces it.
- **Gun wear (already live):** guns now wear 1 per round fired, hit or miss, and heavy swings wear 2 (`Tuning.combat`, server `Combat.wear`). Black-run balance in your lobbies should expect a Pipe Pistol to last about 3 runs.
