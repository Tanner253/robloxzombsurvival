# Economy and progression (binding spec)

**Status:** binding, written 2026-11-08. It is the "data rescale" pass that [DECISIONS.md](DECISIONS.md) (2026-11-08, "The free grind is long and gruelling") calls for. Workers implement it directly in `roblox/src/shared/Data/`. Where it conflicts with [CONTENT_MVP.md](CONTENT_MVP.md) or [CONTENT_S2.md](CONTENT_S2.md), this file wins. [LDOE_PARITY.md](LDOE_PARITY.md) still wins over this file.

**What the developer asked for (2026-11-08):**
- "have you well thought out the progression system? like the last day on earth?"
- "forge iron and manufacture and refine resources in an expensive way, etc. like 20 logs turns into 4 planks... we need to make the game very very grindy"
- "forest and mine locations lvl 1, 2 and 3, with varying loot tiers and loot nodes and resource nodes available, and more or less difficult zombies based on tier"
- "there are higher tier wood types and stone types, like the last day on earth"
- "item durability is huge for us, and the need to eat and drink etc. helps us drive micro txns. Guns break pretty quick in Last Day on Earth..." (added the same day; §8)

**The answer in one paragraph:**
- Three wood tiers (Timber, Ironbark, Gloamwood) and four stone and ore tiers (Fieldstone, Ironstone, Malachite, Tinstone) mirror LDoE's pine, oak and ash, and its limestone, iron, copper and aluminium.
- Every refinement step is LDoE's ratio or harsher. Ironbark is exactly the developer's "20 logs into 4 planks".
- The forge chain runs ore → ingot → plate → rivets, with a three-metal alloy, Ember Steel, as the mid-game gate.
- Six new resource locations: Forest L1–L3 and Mine L1–L3, copied from LDoE's Pine Bushes/Grove/Wood and Limestone Ridge/Cliffs/Spires. The three existing maps become loot-heavy POIs.
- **Sinks (§8):**
  - Every tool, weapon, gun and armor piece wears out at LDoE's values or faster: a Pipe Pistol lasts 50 shots, about 3 Black runs.
  - Re-crafts need rare parts.
  - Ammo, food, water and dressings drain constantly, each with a moment-of-need pack.
- A pacing model of a free player at 2–3 h a day, with every sink on, lands every milestone in its GAME_DESIGN band (§9).

**Sources and method:**
- **Primary:** our LDoE research in [`ldoe-systems/economy-progression.md`](ldoe-systems/economy-progression.md) ("econ doc") and [`ldoe-systems/world-content.md`](ldoe-systems/world-content.md) ("world doc").
- **New:** about 110 LDoE Fandom wiki pages, re-read as raw wikitext through the wiki's MediaWiki API on 2026-11-08: tree, rock, zone, wall, floor, door, station, material and enemy pages, plus every weapon, armor, repair, food and survival page used in §8. Each is cited inline.
- **Fan guides:** AppGamer, GameSkinny and Giga. All are pre-2021 and used only where noted.
- **Conflicts:** where sources disagree, the table says so and §12 lists every conflict.
- **Naming:** our names everywhere. Every table maps to the LDoE counterpart in its own column. No LDoE item or location name is used as one of ours (§1.5 covers older collisions).

---

## Contents
1. [Material ladder](#1-material-ladder)
2. [Refinement chains](#2-refinement-chains)
3. [Stations](#3-stations)
4. [Tools and weapons ladder](#4-tools-and-weapons-ladder)
5. [Building tiers](#5-building-tiers)
6. [Locations](#6-locations)
7. [Loot tables](#7-loot-tables)
8. [Sinks: durability and survival](#8-sinks-durability-and-survival)
9. [Pacing check](#9-pacing-check)
10. [v0.1 subset](#10-v01-subset)
11. [Implementation notes](#11-implementation-notes)
12. [Conflicts in the sources](#12-conflicts-in-the-sources)

---

## 1. Material ladder

**Two rules govern all gathering, as in LDoE:**
- Home nodes never respawn (LDOE_PARITY #30).
- Fog Run nodes come back fresh with every lobby.

**New rule (decided here): resource nodes in Fog Run lobbies are personal.**
- **What it means:**
  - Each player has their own depletion state for every node on the map, in every fog tier. Another survivor chopping "your" tree takes nothing from you.
  - Within one lobby a node never regrows. The next lobby is a fresh copy, like LDoE's reset on exit.
- **Why:**
  - LDoE's farm zones are single-player ([world doc §1.2](ldoe-systems/world-content.md)).
  - With shared nodes, a 12-seat lobby would cut each player's haul by up to 12×, and every ratio in this file would collapse.
- **What stays contested:** containers keep their tier rules (personal in Light, shared in Dense and Black), and so do PvP and extraction.

### 1.1 Wood: three tiers

| Tier | Our resource (ID) | Node (ID) | Tool gate | Hits | Yield per node | Found in | LDoE counterpart | LDoE numbers |
|---|---|---|---|---|---|---|---|---|
| 1 | **Timber** (`item.timber`, existing) | **Pine** (`node.pine_tree`, existing) | Hatchet tier 1 | **3** (was 4) | 3 timber (1 per hit; was 4) | Home (20), every location | Pine Log from Pine Tree | 4 hits, 3 logs ([Pine Tree](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Tree)); a zone page counts 27 trees as 51 logs (conflict, §12) |
| 2 | **Ironbark Log** (`item.ironbark_log`, new) | **Ironbark** (`node.ironbark_tree`, new) | **Hatchet tier 2** (Forged Hatchet) | 4 | **2 logs** (one every 2nd hit) | Forest L2 (15), Forest L3 (25) | Oak Log from Oak Tree | 4 hits, 2 logs, Iron Hatchet only ([Oak Tree](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Tree)). [Oak Clearing](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Clearing) says 8 hits (conflict) |
| 3 (M2) | **Gloamwood Log** (`item.gloamwood_log`) | **Gloamwood** (`node.gloamwood_tree`) | **Hatchet tier 3** (Felling Saw) | 6 | 2 logs (one every 3rd hit) | Forest L3 (12), M2 | Ash Log / Ash Billet from Ash Tree | Chainsaw only, 2 per tree, hits "???" ([Ash Tree](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Tree)) |
| fuel | **Fatwood** (`item.fatwood`, existing) | Fatwood Stump (existing) | Hatchet tier 1 | 3 | 3 fatwood, plus 30% a timber per hit | Forests, Dense and Black POIs | no node; burns like Charcoal | — |
| hand | **Sticks** (`item.sticks`, existing) | Fallen Branches (existing) | none | 1 | 2 sticks | Home, every location | loose Pine Logs on the ground | Pine Bushes has 19 loose logs ([Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood)) |

**Why loose logs become sticks:**
- LDoE lets you pick up loose logs by hand.
- We keep the 2026-11-08 ruling instead: sticks come by hand and timber needs a hatchet (DECISIONS, "Sticks split from Timber").

### 1.2 Stone and ore: four tiers

| Tier | Our resource (ID) | Node (ID) | Tool gate | Hits | Yield per node | Found in | LDoE counterpart | LDoE numbers |
|---|---|---|---|---|---|---|---|---|
| Stone 1 | **Fieldstone** (`item.stone`, existing) | **Boulder** (`node.boulder`, existing), Loose Stones (hand, 2 each) | Pick tier 1 | **3** (was 5) | 3 stone | Home (7), every location; Mine L1 has 25 | Limestone | 5 hits, 3 limestone ([Limestone Rock](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Rock)) |
| Ore 1 | **Ironstone** (`item.ironstone`, new) | **Ironstone Outcrop** (`node.ironstone_rock`, new) | Pick tier 1 | 3 | 3 ironstone | Mine L1 (5), Mine L2 (30), Mine L3 (50), Ashfall Depot (8) | Iron Ore | 5 hits, 3 ore ([Iron Rock](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Rock)) |
| Ore 2 | **Malachite** (`item.malachite`, new) | **Malachite Vein** (`node.malachite_vein`, new) | **Pick tier 2** (Forged Pick) | 6 | **2 malachite** (one every 3rd hit) | Mine L2 (10), Mine L3 (20) | Copper Ore | 10 hits, 1 ore (infobox) vs 5 hits, 1–3 ore (text); Iron Pickaxe only ([Copper Rock](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Rock)) |
| Ore 3 (M2) | **Tinstone** (`item.tinstone`) | **Tinstone Seam** (`node.tinstone_seam`) | Pick tier 2 | 6 | 2 tinstone (one every 3rd hit) | Mine L3 (15), M2 | Bauxite (Aluminum Ore) | Not a node: loot in Wooded Foothills, NPC bases and the Recycler ([Aluminum Ore](https://last-day-on-earth-survival.fandom.com/wiki/Aluminum_Ore)); once a rare Iron Rock drop, removed in 1.30.1 ([Iron Rock](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Rock)) |
| Salvage | **Rusted Scrap** (`item.scrap`, existing, stack 50) | Scrap Heap (existing) | Pick tier 1 | 4 | 8 scrap (2 per hit), +8% Snarled Wire, +4% Rivets per hit | Home (5), Mine L1–L3, Rustwater, Ashfall Depot, loot | Scrap Metal (stack 50) | Loot only; 4 scrap make 1 iron bar ([Scrap Metal](https://last-day-on-earth-survival.fandom.com/wiki/Scrap_Metal)) |
| — | **Niter Crust** (`item.niter`, existing) | Niter Seam (existing) | Pick tier 1 | 3 | 3 | Mine L2, Mine L3, Dense and Black POIs | Sulfur | 6 hits, 2 sulfur (econ doc §1.1) |

**Why Tinstone has a tool gate when LDoE's bauxite has none:**
- Ember Steel needs tin, and the tier-3 tools need Ember Steel. A tier-3 gate on tinstone would be circular.
- The Forged Pick (tier 2) is therefore its gate. The tier-3 Ember Pick gates the next ore, which arrives after M2.

### 1.3 Parity check: the home plot is LDoE's set, exactly

The current `Tuning.home` counts give LDoE's home yields once the new node numbers apply:

| Node | Ours | LDoE | Source |
|---|---|---|---|
| Pine | 20 pines × 3 = **60 timber** | 20 pine trees = 60 logs | [Home](https://last-day-on-earth-survival.fandom.com/wiki/Home) |
| Boulder | 7 × 3 = **21 stone** | 7 limestone rocks = 21 limestone | Home |
| Scrap Heap | 5 × 8 = **40 scrap**, which smelts to 8 Iron Ingots | 5 iron rocks = 15 iron ore, which smelts to 7.5 bars | Home |

### 1.4 Rare components that gate progression

These are loot-only. None of them can be crafted, except Pitch Glue and Copper Wire, which also drop as loot. §7.5 lists the drop rate per location.

| Ours (ID) | Gates | LDoE counterpart | LDoE role |
|---|---|---|---|
| **Coil Spring** (`item.coil_spring`) | Dense tower, Recycler, Pipe Pistol, Reinforced door, Black tower | Spring | Guns, mechanisms; loot and recycling only ([Spring](https://last-day-on-earth-survival.fandom.com/wiki/Spring)) |
| **Brass Gear** (`item.brass_gear`) | Black tower, every station's L3, Pack Frame, Ammo Press L2 | Cog | ATV (200), loot only (econ doc §1.3) |
| **Steel Pipe** (`item.steel_pipe`) | Black tower, every firearm | Pipes / Factory Parts | Loot (econ doc §1.3) |
| **Trigger Group** (`item.trigger_group`) | Every firearm: the gun bottleneck | Factory Parts | Recycled guns, bunkers (econ doc §1.3) |
| **Pitch Glue** (`item.pitch_glue`) | Forged tools, Shortbow, Flare Pistol | Adhesive and Duct Tape | Iron tools need 5 duct tape ([Duct Tape](https://last-day-on-earth-survival.fandom.com/wiki/Duct_Tape)); adhesive is loot ([Adhesive](https://last-day-on-earth-survival.fandom.com/wiki/Adhesive)) |
| **Copper Wire** (`item.copper_wire`) | Reinforced tier, Recycler output | Wiring (and the Bolts role) | Common loot, also made from a copper bar ([Wiring](https://last-day-on-earth-survival.fandom.com/wiki/Wiring)) |
| **Seized Motor** (`item.seized_motor`) | Recycled into gears, springs and wire; the hauler | Rusty Engine → Engine Part | The "one more run" part ([Engine Part](https://last-day-on-earth-survival.fandom.com/wiki/Engine_Part)) |
| **Reinforcement Plans** (`item.bp_reinforced`) | The Reinforced tier | Survivor's Path blueprint gate | Quest-gated in LDoE; a Black-fog find for us |
| **Pack Frame Schematic** (`item.bp_pack_frame`) | The +10 bag | Military Backpack blueprint | Path quest and premium reward (econ doc §4.5) |
| **Solder** (`item.solder`, M2) | Standard firearms, tier-3 tools | Bolts | Craftable from an aluminium plate and also common loot ([Bolts](https://last-day-on-earth-survival.fandom.com/wiki/Bolts)) |

### 1.5 Name collisions in existing data

- **Rename:** the "Woodworking Bench" is LDoE's exact name ([Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench)). Its display name becomes **Saw Bench**; the ID `station.woodworking_bench` and `build.woodworking_bench` stay.
- **Keep:** dictionary words are not LDoE coinages: Workbench, Campfire, Recycler, Machete, Stonecutter (LDoE's is "Stonecutter's Table"), Rivets.
- **Fix:** the Hewn Plank description says "sawn flat at the Workbench". It now reads "sawn at the Saw Bench".

---

## 2. Refinement chains

**Rule:** every conversion is LDoE's ratio and timer or harsher. Stations are converters (LDOE_PARITY #18): one input stack becomes one output stack, a batch at a time.

The input slot holds **items, not batches**. The slot cap is therefore a real throttle: at the L2 cap of 40, a Saw Bench holds only 8 Ironbark Planks' worth of logs.

### 2.1 Every conversion

| Output (ID) | Input → output | Station, min level | Timer | Fuel | Unlock | LDoE counterpart | vs LDoE |
|---|---|---|---|---|---|---|---|
| Hewn Plank (`item.plank`) | **2 Timber → 1** | Saw Bench L1 | 4 m | — | quest.claim_the_ground | 1 Pine Log → 1 Pine Plank, 4 m ([Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench)) | **2× harsher** |
| Ironbark Plank (`item.ironbark_plank`, new) | **5 Ironbark Log → 1** | **Saw Bench L2** | 20 m | — | quest.heartwood (new) | 3 Oak Log → 1 Oak Plank, 20 m (same page) | 1.67× harsher. A full L1 slot of 20 logs makes 4 planks: the developer's "20 logs turns into 4 planks" |
| Gloamwood Plank (M2) | **8 Gloamwood Log → 1** | Saw Bench L3 | 1 h | — | M2 quest | 8 Ash Log → 1 Ash Plank, 1 h (bench page); 5 logs, 30 m on [Ash Plank](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Plank) (conflict) | equal to the harsher LDoE figure |
| Stone Block (`item.stone_block`) | **3 Fieldstone → 1** | Stonecutter L1 | 5 m | — | quest.a_place_to_work | 2 Limestone → 1 Stone Brick, 4 m ([Stone Brick](https://last-day-on-earth-survival.fandom.com/wiki/Stone_Brick), [Stonecutter's Table](https://last-day-on-earth-survival.fandom.com/wiki/Stonecutter%27s_Table)) | 1.5× harsher, +25% time |
| Iron Ingot (`item.iron_ingot`, new) | **2 Ironstone → 1** | Smelter L1 | 4 m | yes | quest.into_the_fog | 2 Iron Ore → 1 Iron Bar, 4 m ([Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace)) | equal |
| Iron Ingot (`recipe.iron_ingot_from_scrap`) | **5 Rusted Scrap → 1** | Smelter L1 | 4 m | yes | quest.into_the_fog | 4 Scrap Metal → 1 Iron Bar, 4 m (same page) | 1.25× harsher: mining ore pays better than scrap |
| Copper Ingot (`item.copper_ingot`, new) | **5 Malachite → 1** | **Smelter L2** | 1 h | yes | quest.green_vein (new) | 5 Copper Ore → 1 Copper Bar, 1 h ([Copper Bar](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Bar)) | equal ratio, plus a station-level gate |
| Tin Ingot (M2) | **4 Tinstone → 1** | Smelter L2 | 1 h | yes | M2 quest | 4 Bauxite → 1 Aluminium Bar, 1 h ([Aluminium Bar](https://last-day-on-earth-survival.fandom.com/wiki/Aluminium_Bar)) | equal |
| Scrap Plate (`item.scrap_plate`, recipe changed) | **1 Iron Ingot → 1** | Workbench L1 | **20 m** | — | quest.into_the_fog | 1 Iron Bar → 1 Iron Plate, 20 m ([Workbench](https://last-day-on-earth-survival.fandom.com/wiki/Workbench), [Iron Plate](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Plate)) | equal. **Was 3 scrap → 1 in 4 m**: one plate now costs 4 m smelting plus 20 m at the bench |
| Rivets (`item.rivets`) | 1 Scrap Plate → 2 | Workbench L1 | 4 m | — | quest.hold_the_door | 1 Iron Plate → 2 Nails, 4 m ([Nails](https://last-day-on-earth-survival.fandom.com/wiki/Nails)) | equal |
| Copper Wire (`item.copper_wire`, new) | 1 Copper Ingot → 2 | **Workbench L2** | 10 m | — | quest.green_vein | 1 Alu Plate → 2 Bolts, 10 m (Workbench); Wiring = 1 Copper Bar + 1 Cloth + 1 Duct Tape ([Wiring](https://last-day-on-earth-survival.fandom.com/wiki/Wiring)) | equal timer |
| Tin Sheet (M2) | 2 Tin Ingot → 1 | Workbench L3 | 1 h | — | M2 quest | 2 Alu Bar → 1 Alu Plate, 1 h ([Aluminium Plate](https://last-day-on-earth-survival.fandom.com/wiki/Aluminium_Plate)) | equal |
| Solder (M2) | 1 Tin Sheet → 2 | Workbench L2 | 10 m | — | M2 quest | 1 Alu Plate → 2 Bolts, 10 m | equal |
| **Ember Steel** (M2) | **1 Iron Ingot + 1 Copper Ingot + 1 Tin Ingot + 2 Embercoal → 1** | **Ember Forge L1** (max 1) | **1 h 30 m** | yes | M2 quest | 1 Iron Bar + 1 Alu Bar + 1 Copper Bar + 2 Charcoal → 1 Steel Bar, 1 h 30 m ([Refined Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Refined_Melting_Furnace), [Steel Bar](https://last-day-on-earth-survival.fandom.com/wiki/Steel_Bar)) | equal: the three-metal fan-in gate |
| Ember Steel Plate (M2) | 1 Ember Steel → 1 | Workbench L3 | 1 h 30 m | — | M2 quest | 1 Steel Bar → 1 Steel Plate, 1 h 30 m ([Steel Plate](https://last-day-on-earth-survival.fandom.com/wiki/Steel_Plate)) | equal |
| **Embercoal** (`item.embercoal`, new) | **2 Timber → 1** | Campfire L1 | 4 m | yes | quest.keep_the_fire | 1 Pine Log → 1 Charcoal, 4 m ([Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire), [Charcoal](https://last-day-on-earth-survival.fandom.com/wiki/Charcoal)) | 2× harsher |
| Pitch Glue (existing) | 2 Fatwood → 1 | Campfire L1 | 4 m | yes | quest.keep_the_fire | (Adhesive is loot only) | unchanged |
| Reedcloth (existing) | 2 Reed Fiber → 1 | Workbench L1 | 2 m | — | quest.keep_the_fire | 2 Plant Fiber → 1 Cloth, 2 m (econ doc §1.2) | equal |
| Reed Cord (existing, hand) | 2 Reed Fiber → 1 | hand | 3 s | — | default | 2 Plant Fiber → 1 Rope, 4 m at the Tanning Rack | kept by hand: the hook needs it |

**Forge chain at a glance.** Station minutes are per unit of output.

```text
Ironstone ×2 ─┐
              ├─ Smelter 4 m ─► Iron Ingot ── Workbench 20 m ─► Scrap Plate ── Workbench 4 m ─► 2 Rivets
Rusted Scrap ×5 ┘                    │
                                     ├───────────────┐
Malachite ×5 ─ Smelter L2, 1 h ─► Copper Ingot ──────┼── Workbench L2, 10 m ─► 2 Copper Wire
                                     │               │
Tinstone ×4 ── Smelter L2, 1 h ─► Tin Ingot (M2) ────┤
                                                     ▼
              Timber ×2 ── Campfire 4 m ─► Embercoal ×2 ─► Ember Forge 1 h 30 m ─► Ember Steel (M2)
                                                                 └─ Workbench L3, 1 h 30 m ─► Ember Steel Plate
```

**What one unit really costs** (station time, all inputs included):

| Unit | Raw input | Station time |
|---|---|---|
| Scrap Plate | 2 ironstone + 2 timber of fuel | 24 m |
| Ironbark Plank | 5 ironbark logs (2.5 trees, 10 Forged Hatchet durability) | 20 m |
| Copper Wire ×2 | 5 malachite (7.5 Forged Pick durability) + about 11 Embercoal or 30 timber of fuel | 1 h 10 m |
| Ember Steel Plate (M2) | 2 ironstone + 5 malachite + 4 tinstone + 4 timber (coal) + about 40 timber-equivalent of fuel | 2 h 4 m furnace + 3 h forge and bench |

### 2.2 Fuel

| Fuel (ID) | Burn time | LDoE counterpart | LDoE burn |
|---|---|---|---|
| Sticks | 1 m | — | — |
| Timber, Ironbark Log | 2 m | Pine, Oak or Ash Log | 2 m on station pages, 1 m 20 s on [Fuel](https://last-day-on-earth-survival.fandom.com/wiki/Fuel) (conflict) |
| Hewn Plank | 3 m | Pine Plank | 3 m |
| Fatwood, **Embercoal** | 5 m 20 s | Charcoal | 5 m 20 s ([Charcoal](https://last-day-on-earth-survival.fandom.com/wiki/Charcoal)) |
| (Ironbark and Gloamwood planks are not fuel; nobody should burn them by accident) | — | Oak and Ash Plank 3 m | — |

**Why Embercoal exists (Inference, from LDoE's design):**
- Coal is a net loss in burn-minutes: 4 timber of input and fuel make one 5 m 20 s coal, against 8 m of burn if the timber is burned directly.
- Its value is **density in a 20-slot fuel slot**:
  - 20 timber burn for 40 m.
  - 20 Embercoal burn for 1 h 47 m.
- Long smelts need coal. With timber, an L2 Smelter on copper stops after 1 h 20 m; with 40 Embercoal it runs 3 h 33 m. In M2, coal is also the alloy's carbon.

### 2.3 How long one refill runs (queue length per visit)

Converters run offline. The input and fuel slot caps (20 at L1, 40 at L2) set how long a station runs between visits, which sets how often players come back.

| Line | L1 (cap 20) | L2 (cap 40) | Note |
|---|---|---|---|
| Hewn Plank | 10 planks, 40 m | 20 planks, 1 h 20 m | |
| Ironbark Plank | (needs L2) | **8 planks, 2 h 40 m** | Only 4 at a 20 slot |
| Stone Block | 6 blocks, 30 m | 13 blocks, 1 h 5 m | |
| Iron Ingot (ore) | 10, 40 m | 20, 1 h 20 m | Fuel matches exactly: 20 timber = 40 m |
| Iron Ingot (scrap) | 4, 16 m | 8, 32 m | |
| Copper Ingot | (needs L2) | 8 batches, 8 h of work, but **fuel-limited**: 3.5 ingots on 40 Embercoal | The reason to make coal |
| Scrap Plate | **20 plates, 6 h 40 m** | 40 plates, 13 h 20 m | The overnight line |
| Rivets | 10 batches, 40 m (output cap 20) | 20 batches, 1 h 20 m | |
| Copper Wire | (needs L2) | 20 batches, 3 h 20 m | |

---

## 3. Stations

All stations are converters with one input slot, one output slot (the Recycler has 4) and a fuel slot when fuelled.

**Slot cap:** 20 at L1, 40 at L2 and 60 at L3, as in LDoE: input, output and fuel stack limits of 20, +20 per level ([Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace), [Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench)). `speedMultiplier` stays 1 at every level, also as in LDoE.

**Floor tiers:** "ground" means no foundation is needed. Tier 1 is a Timber foundation, tier 2 Scrap and tier 3 Reinforced.

| Station (ID; display) | Role | Floor | Max | Build cost | L2 upgrade | L3 upgrade | LDoE counterpart (cost, floor, max) |
|---|---|---|---|---|---|---|---|
| `station.campfire`; Campfire | Cooking, **Embercoal**, Pitch Glue (fuelled) | ground | 2 | 6 sticks, 5 stone, 2 fiber (unchanged) | 12 block, 4 plate (unchanged) | 20 block, 8 plate, 2 spring (unchanged) | Campfire: 5 log, 5 limestone, 1 fiber; ground; max 2; L2 10 Woolen Fabric + 15 Oak Plank ([Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire)) |
| `station.woodworking_bench`; **Saw Bench** | Hewn Plank; Ironbark Plank at **L2**; Gloamwood Plank at L3 (M2) | Timber | 2 | 10 timber, 6 stone, 2 cord (unchanged) | **20 plank, 6 plate, 4 rivets** | **20 ironbark plank, 12 plate, 2 gear** | Woodworking Bench: 5 log, 5 iron ore; wood floor L1; max 2; L2 15 Steel Plate + 20 Oak Plank + a Genesis blueprint ([Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench)) |
| `station.stonecutter`; Stonecutter | Stone Block | Timber | 2 | **8 timber, 10 stone, 2 cord** (was 8 plank, 10 stone, 2 cord: the hook needs it before planks) | 20 block, 6 plate (unchanged) | 30 block, 12 plate, 2 gear (unchanged) | Stonecutter's Table: 10 plank, 5 iron bar, 5 scrap (Blueprints) or 20 plank, 10 iron bar, 5 scrap (station page; conflict); floor L1; max 2 ([Stonecutter's Table](https://last-day-on-earth-survival.fandom.com/wiki/Stonecutter%27s_Table)) |
| `station.smelter`; Smelter | Iron Ingot (ore or scrap); Copper Ingot at **L2**; Tin Ingot at L2 (M2) (fuelled) | ground | 2 | 12 stone, 4 block, 6 sticks (unchanged) | **20 block, 10 plate, 4 rivets** | 30 block, 16 plate, 3 gear (unchanged) | Melting Furnace: 10 limestone, 5 iron ore; ground; max 2; L2 15 Thermite + 15 Steel Bar ([Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace)) |
| `station.workbench`; Workbench | Scrap Plate, Rivets, Reedcloth, Tanned Leather (S2); Copper Wire at **L2**; Tin Sheet and Ember Steel Plate at L3 (M2); Workbench L2 also gates firearms (S2) | Timber | 2 | **6 plank, 3 block, 4 cord** (was 10 plank, 6 block, 4 cord: the hook) | 20 plank, 10 block, 6 plate (unchanged) | 30 plank, 20 block, 12 plate, 3 gear (unchanged) | Workbench: 15 plank, 10 iron bar, 10 stone brick, 5 adhesive; plank floor L2; max 2 ([Workbench](https://last-day-on-earth-survival.fandom.com/wiki/Workbench)) |
| `station.recycler`; Recycler | Junk and gear → parts, 4 output slots | Scrap | 1 | 15 plank, 6 plate, 6 rivets, 2 spring (unchanged) | unchanged (+5% chance) | unchanged (+10%) | Recycler: 20 plank, 5 iron plate, 20 bolts, 10 duct tape, 10 rubber parts; plank floor L2; max 1 (econ doc §2.6) |
| `station.ammo_press`; Ammo Press (S2) | Blackpowder (fuelled) | Scrap | 1 | unchanged (CONTENT_S2) | unchanged | unchanged | none (ours) |
| `station.ember_forge`; **Ember Forge** (M2, new) | Ember Steel: **3 input slots** (fuelled) | Scrap | **1** | **20 ironbark plank, 20 block, 20 iron ingot, 10 plate** | 20 gloamwood plank, 10 ember steel plate, 2 gear (M3) | — | Refined Melting Furnace: 20 Oak Plank, 20 Stone Brick, 20 Iron Bar, 10 Iron Plate; any floor; max 1 (2 if bought) ([Refined Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Refined_Melting_Furnace)) |

**Rulings:**
- **Station levels gate tier-2 lines** (`RecipeDef.stationLevel`). LDoE gates its oak and copper lines only by tool and region, and uses bench levels for capacity. Gating the line makes each L2 upgrade a build goal on the way to the next tier, which is the grind the developer asked for.
- **Upgrade costs use only lower-tier materials.** That prevents chicken-and-egg stalls. For example, the Saw Bench L2 costs Hewn Planks, not Ironbark Planks.
- **Max per plot follows LDoE:** 2 for basic benches, 1 for the Recycler and the Forge. The Forge's single slot is the steel throttle (econ doc §7.1). The shop's "+1 Recycler" and "+1 Forge" placement packs (GAME_DESIGN shop) double that throughput; that is the LDoE lever.
- **The fuel list for the Campfire and Smelter** (and the Forge in M2) is sticks, timber, ironbark log, hewn plank, fatwood and embercoal, with the burn times in §2.2.

### 3.1 Recycler outputs: additions and changes

Chances scale with the input's remaining durability (existing rule).

| Input | Time | Outputs (count, chance) | Change |
|---|---|---|---|
| Seized Motor | 20 m | scrap plate 1–2 (100%), coil spring 1–2 (60%), **copper wire 1–2 (35%)**, brass gear 1 (25%) | + copper wire |
| Snarled Wire | 5 m | scrap 1–3 (100%), **copper wire 1 (30%)**, **rivets 1 (30%)** | Was rivets 2–3 (60%) |
| Forged Hatchet, Forged Pick (new) | 10 m | iron ingot 2–3 (100%), rivets 1 (50%), plank 1 (40%) | new |
| Cracked Lantern, Spiked Club, Scrapblade, Shortbow, Padded Hood and Vest, both blueprints | unchanged | unchanged | — |

---

## 4. Tools and weapons ladder

### 4.1 Tools: stone, then forged, then Ember Steel

Tools don't take a weapon slot; gathering auto-equips the right one (GAME_DESIGN). A tool of tier N harvests nodes of tier N or below.

| Tool (ID) | Tier | Recipe (hand) | Durability | Gates | Return on one tool | Unlock | LDoE counterpart |
|---|---|---|---|---|---|---|---|
| Stone Hatchet (`item.stone_hatchet`) | hatchet 1 | 3 sticks, 3 stone | **40** (was 60) | Pine, Fatwood | 13 pines → 40 timber: about 13× its cost | default | Hatchet: 3 log + 3 limestone, durability 50; "2 hatchets ≈ 25 trees" ([Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Hatchet)) |
| Stone Pick (`item.stone_pick`) | pick 1 | 3 sticks, 3 stone | **40** (was 60) | Boulder, Ironstone, Scrap Heap, Niter | 13 rocks → 40 stone or ironstone | default | Pickaxe: same recipe, 50 ([Pickaxe](https://last-day-on-earth-survival.fandom.com/wiki/Pickaxe)) |
| **Forged Hatchet** (`item.forged_hatchet`, new) | hatchet 2 | **5 iron ingot, 3 plank, 2 rivets, 2 pitch glue** | 75 | **Ironbark** (and all tier 1) | 18 ironbark → 37 logs → 7.5 Ironbark Planks | quest.the_dense_fog | Iron Hatchet: 5 Iron Bar + 3 Pine Plank + 2 Nails + 5 Duct Tape, durability 75, needed for oak ([Iron Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Hatchet)) |
| **Forged Pick** (`item.forged_pick`, new) | pick 2 | same as the Forged Hatchet | 75 | **Malachite**, Tinstone (M2) | 12 veins → 25 malachite → 5 Copper Ingots | quest.the_dense_fog | Iron Pickaxe: same recipe, 75, needed for copper ([Iron Pickaxe](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Pickaxe)) |
| **Felling Saw** (M2) | hatchet 3 | 3 ember steel plate, 4 ironbark plank, 4 solder, 1 coil spring | 100 | **Gloamwood** | 16 trees → 33 logs → 4 Gloamwood Planks | M2 quest | Chainsaw: Genesis-only, needed for ash (econ doc §4.1) |
| **Ember Pick** (M2) | pick 3 | 3 ember steel plate, 3 ironbark plank, 4 solder | 120 | Durability only in M2; the M3 ore | — | M2 quest | Manual earth drill: 1 Steel Bar + 3 Engine Part + 2 Thermite + 15 Wiring + 2 Gasoline, durability 40 (econ doc §4.1) |

### 4.2 Weapons

> **Superseded for guns by [ARSENAL.md](ARSENAL.md) (2026-11-08).** The standard guns, the SMGs and the Carbine are pulled into v0.1 on v0.1 materials, with no ammo. M2's Ember Steel recipes become the guns' M2 re-tune. Plated armor consumes Riveted (ARSENAL §5), not Padded.

Damage is the current item data (CONTENT_MVP, CONTENT_S2). **Durability is rescaled** per §8.1, and recipes marked "+" gain the rare-part costs in §8.2. Every weapon is crafted by hand (LDOE_PARITY #20). The Workbench level is a "known recipe" gate, not a station line.

| Weapon (ID) | Class, tier | Recipe | Durability (new; was) | Unlock | LDoE counterpart |
|---|---|---|---|---|---|
| Spiked Club (`item.spiked_club`) | melee 1 | 4 plank, 2 cord, 3 scrap | **80** hits (110) | quest.into_the_fog | Makeshift Bat: 5 plank + 3 duct tape, 100 |
| Reed Shortbow (`item.shortbow`) | bow 1 | 4 plank, 4 cord, **2 glue** (+) | **40** shots (60) | quest.stand_your_ground | Bow: 5 plank + 1 iron bar + 5 rope + 3 duct tape + 3 adhesive, 50 shots |
| Scrapblade (`item.scrapblade`) | melee 2 | 4 plate, 2 plank, 2 cloth, 2 rivets, **1 glue** (+) | **80** hits (120) | quest.scavenger | Cleaver: 5 iron bar + 5 plank + 4 bolts, 100 |
| Machete (`item.machete`, S2) | melee 2 | 5 plate, 3 rivets, 2 cloth, **1 glue** (+) | **70** hits (130) | quest.the_dense_fog | Machete: 15 iron bar + 3 plank + 12 leather, 80 |
| Fire Axe (`item.fire_axe`, S2) | melee 2, heavy | 6 plate, 3 plank, 4 rivets, 1 steel pipe | **50** hits (150) | quest.the_dense_fog | Skull Crusher 45, Saw Blade Mace 30, Metal Pipe 90 |
| Pipe Pistol (`item.pipe_pistol`, S2) | gun, improvised | 1 steel pipe, 1 trigger group, 2 plank, 4 rivets, 1 coil spring | **50** shots (140) | quest.the_dense_fog (Workbench L2) | Zip Gun: 16 iron plate + 4 spring + 5 duct tape + 3 bolts + 1 oak plank + 8 adhesive, 100 shots |
| Scrap Shotgun (S2) | gun, improvised | unchanged (CONTENT_S2) | **30** shells (120) | quest.the_dense_fog | Shotgun, 40 shots ([Shotgun](https://last-day-on-earth-survival.fandom.com/wiki/Shotgun)) |
| Flare Pistol (S2) | gun, light | unchanged (CONTENT_S2) | **24** flares (100) | quest.the_dense_fog | Flare Gun, 32 ([Flare Gun](https://last-day-on-earth-survival.fandom.com/wiki/Flare_Gun)) |
| **Service Revolver** (M2) | gun, standard | 4 ember steel plate, 1 trigger group, 2 coil spring, 2 ironbark plank, 4 solder | **80** shots | M2 quest (Workbench L3) | Colt Python, 100 ([Colt Python](https://last-day-on-earth-survival.fandom.com/wiki/Colt_Python)); Glock 17, 100 shots ([Glock 17](https://last-day-on-earth-survival.fandom.com/wiki/Glock_17)) |
| **Pump Shotgun** (M2) | gun, standard | 6 ember steel plate, 2 steel pipe, 1 trigger group, 2 coil spring, 3 ironbark plank, 6 solder | **35** shells | M2 quest | Shotgun, 40 shots (uncraftable Tungsten in LDoE) |
| **Hunting Rifle** (M2) | gun, standard | 6 ember steel plate, 2 steel pipe, 1 trigger group, 1 brass gear, 3 gloamwood plank, 4 solder | **40** shots | M2 quest | VSS 60, Dragunov 36 (econ doc §4.3) |
| SMG, Carbine (M3) | gun, advanced | M3 | **150 / 130** rounds | M3 | Mini Uzi 200 ([Mini Uzi](https://last-day-on-earth-survival.fandom.com/wiki/Mini_Uzi)); M16 and AK-47 170 ([M16](https://last-day-on-earth-survival.fandom.com/wiki/M16), [AK-47](https://last-day-on-earth-survival.fandom.com/wiki/AK-47)) |
| **Plated armor set** (M2: hood, jacket, trousers, boots) | armor 3 | each piece **consumes the matching Padded piece** at any durability, plus: jacket 3 ember steel plate + 6 leather + 6 cloth + 4 rivets; hood 2/3/3/2; trousers 2/4/4/2; boots 1/3/2/2 | **150** hits taken | M2 quest | Tactical / SWAT, 150; Reinforced Jacket consumes a Thick Jacket ([Reinforced Jacket](https://last-day-on-earth-survival.fandom.com/wiki/Reinforced_Jacket)) |

**Ember Steel per "standard firearm and armor set" milestone:**
- The set is a revolver, a shotgun, the four Plated pieces and a Felling Saw: 4 + 6 + 8 + 3 = **21 Ember Steel**.
- Making it takes 31.5 forge-hours, 42 Smelter-hours of copper and tin, and 31.5 Workbench-hours.
- §9.4 turns that into days.

---

## 5. Building tiers

### 5.1 Mapping our three tiers onto LDoE's five

LDoE's ladder ([Wall](https://last-day-on-earth-survival.fandom.com/wiki/Wall), [Floor](https://last-day-on-earth-survival.fandom.com/wiki/Floor), [Door](https://last-day-on-earth-survival.fandom.com/wiki/Door)). Windows cost the same as walls.

| LDoE level | Wall | Floor | Door | Horde / breach | Our tier |
|---|---|---|---|---|---|
| L1 Wall | 1 Pine Log | 1 Pine Log | 1 Pine Log | breaks on contact; stone Hatchet | **Timber** (placed directly) |
| L2 Plank | 5 Stone Brick + 10 Pine Plank | 5 Stone Brick + 5 Pine Plank | 10 Stone Brick + 20 Pine Plank | deals 50; Iron Hatchet | **Scrap** (an upgrade from Timber) |
| L3 Stone | 15 Stone Brick + 10 Oak Plank | 15 Stone Brick + 10 Iron Plate | 20 Stone Brick + 20 Oak Plank | horde-proof; C-4 | **Reinforced** (an upgrade from Scrap) |
| L4 Metal | 20 Steel Plate + 15 Alu Plate | 15 Steel Plate + 20 Iron Plate | 25 Steel Plate + 20 Alu Plate | Metal Cutter (event only) | **Fortified**: a future 4th tier on Ember Steel (M3). Not in this file's numbers |
| L5 Brick | 20 Brick + 10 Steel Plate | 20 Ash Plank + 10 Titanium Bar | 15 Brick + 30 Steel Plate | indestructible | none: nothing is unbreachable (DECISIONS) |

**Rulings:**
- **Scrap blends LDoE L2 and L3.** It takes LDoE L2's plank and block recipe and adds L3's iron-plate floor.
- **Reinforced is LDoE L3 and harsher.** Ironbark Plank stands in for Oak Plank, and it adds plates, rivets and copper wire.
- **Our tiers double HP** (DECISIONS); unchanged.

### 5.2 Per-piece costs

- **Timber** pieces are placed with this cost.
- **Scrap and Reinforced** costs are the upgrade step from the tier below. Refunds walk the chain (Domain/Grid, unchanged).

| Piece | Timber (place) | Scrap (upgrade) | Reinforced (upgrade) |
|---|---|---|---|
| Foundation | 10 timber | **6 plank, 4 block, 3 plate** | **12 block, 8 plate, 4 rivets** |
| Wall | 8 timber, 1 cord | **8 plank, 4 block, 2 plate** | **12 block, 7 ironbark plank, 4 plate, 4 rivets, 2 copper wire** |
| Window wall | 7 timber, 1 cord | **8 plank, 4 block, 2 plate** | **12 block, 7 ironbark plank, 4 plate, 4 rivets, 2 copper wire** |
| Doorway | 6 timber, 1 cord | **6 plank, 4 block, 2 plate** | **10 block, 7 ironbark plank, 4 plate, 4 rivets, 2 copper wire** |
| Door | 5 timber, 2 cord | **6 plank, 3 plate, 4 rivets** | **7 ironbark plank, 6 plate, 6 rivets, 4 copper wire, 1 coil spring** |
| Palisade Fence | 6 timber, 1 cord (no upgrade) | — | — |

- Timber costs are unchanged.
- Scrap and Reinforced replace the current BuildPieces costs: Scrap was 4 plank + 3 plate, Reinforced 8 block + 4 plate + 2 rivets.
- HP and breach costs are unchanged.

**Raw cost of one piece, all refining included** (from the §9 model):

| Piece | Raw | Station hours |
|---|---|---|
| Scrap wall | 16 timber, 12 stone, 4 ironstone, plus 4 timber of fuel | 1.6 h |
| Scrap foundation | 12 timber, 12 stone, 6 ironstone | 1.9 h |
| Reinforced wall | 36 stone, 35 ironbark logs (17.5 trees), 12 ironstone, 5 malachite, plus 42 timber of fuel | 7.0 h |
| Reinforced door | 35 ironbark logs, 18 ironstone, 10 malachite, 1 coil spring, plus 78 timber of fuel | 8.4 h |

### 5.3 Storage

| Piece | Cost | Slots | Floor | Unlock | LDoE counterpart |
|---|---|---|---|---|---|
| Timber Crate | 8 timber, 4 cord | 15 | Timber | default | Small Box: 3 log + 5 fiber, 15 ([Small Box](https://last-day-on-earth-survival.fandom.com/wiki/Small_Box)) |
| Banded Crate (upgrade) | 6 plank, 4 plate, 2 rivets | 25 | Timber | quest.hold_the_door | Chest: 10 plank + 5 iron bar + 5 bolts, 25 |
| **Ironbound Trunk** (M2 upgrade) | 12 ironbark plank, 12 rivets, 4 copper wire | 45 | Scrap | M2 | Trunk: 15 Oak Plank + 15 Nails + 5 Steel Bar, 45 (econ doc §8.2) |

### 5.4 What a whole base costs

These are the GAME_DESIGN milestone bases. The intermediate list is what the build menu shows. Raw and station hours expand every recipe.

| Milestone base | Intermediate materials | Raw | Station hours |
|---|---|---|---|
| **Hook:** 2 foundations, 2 walls, Campfire, Saw Bench, Stonecutter, Workbench, satchel | 54 timber, 12 cord, 21 stone, 6 plank, 3 block | 66 timber, 30 stone, 29 fiber, 6 sticks | 0.6 |
| **Timber base:** the 3×3 room (9 foundations, 9 walls, 2 windows, doorway and door), 2 crates, the second Campfire, Saw Bench and Smelter, the Spiked Club | 213 timber, 26 cord, 23 stone, 4 block, 4 plank | 221 timber, 54 fiber, 35 stone, 12 sticks | 0.6 |
| **Scrap tier:** that room at Scrap, Workbench L2, Recycler, Dense tower, Pipe Pistol, the second Workbench and Stonecutter | 217 plank, 101 block, 72 plate, 14 rivets, 4 spring, 1 pipe, 1 trigger | 442 timber, 325 stone, 158 ironstone (or 395 scrap), 158 timber of fuel, 4 springs, 1 pipe, 1 trigger | Saw Bench 14.5, Stonecutter 8.4, **Workbench 26.8**, Smelter 5.3 |
| **Reinforced base:** a 4×4 (16 foundations, 13 walls, 2 windows, doorway and door) at Reinforced, Saw Bench L2 ×2, Smelter L2, Black tower | 446 block, 265 plate, 158 rivets, 119 ironbark plank, 114 plank, 102 timber, 36 copper wire, 5 spring, 2 gear, 2 pipe | 1,338 stone, 688 ironstone, **595 ironbark logs**, 90 malachite, 330 timber + about 1,230 timber of fuel, 5 springs, 2 gears, 2 pipes, the Plans | Saw Bench 47, Stonecutter 37, **Workbench 123**, Smelter 41 |

**Inference:**
- In the Reinforced tier the binding throttle is the Workbench's 123 hours. Two benches at about 16 effective hours a day each is about 4 days, so a full base is a multi-day goal even with the materials in hand.
- The §8 sinks add their own load on the same benches every day: weapon and armor re-crafts, dressings and cloth.

---

## 6. Locations

**Every location is fixed and handcrafted:** the same layout every visit (GAME_DESIGN, corrected 2026-11-08). Only container rolls, the Hollow and the Fog meter vary.

**Each map's node markers equal the data's node counts.** The Map marker contract has a "node" spot with a NodeId; the validator should check the count.

### 6.1 The location roster

| ID | Name | Role | Fog tier | Level gate | Region gate | Run (Energy) | Walk | Reset | LDoE counterpart |
|---|---|---|---|---|---|---|---|---|---|
| `loc.bracken_edge` | **Bracken Edge** | Forest L1 | Light | 1 | — | 15 | 12 m | per lobby | Pine Bushes (green): 15 energy, 12 m walk |
| `loc.ironbark_stand` | **Ironbark Stand** | Forest L2 | Dense | 8 | Quarry Signal Tower | 22 | 19 m | per lobby | Pine Grove (yellow, L10): 22, 19 m 25 s; plus Oak Bushes' oak |
| `loc.gloaming_deep` | **Gloaming Deep** | Forest L3 | Black | 15 | Depot Signal Tower | 33 | 29 m | per lobby | Pine Wood (red, L15, removed 1.19.4): 26, 22 m 19 s; plus Oak Grove |
| `loc.rockfall_slope` | **Rockfall Slope** | Mine L1 | Light | 1 | — | 15 | 12 m | per lobby | Limestone Ridge (green): 15, 12 m 30 s |
| `loc.greenvein_bluffs` | **Greenvein Bluffs** | Mine L2 | Dense | 8 | Quarry Signal Tower | 22 | 19 m | per lobby | Limestone Cliffs (yellow, L10): 22, 19 m 35 s; plus Frosty Backwoods' copper |
| `loc.deepcut_pit` | **Deepcut Pit** | Mine L3 | Black | 15 | Depot Signal Tower | 33 | 29 m | per lobby | Limestone Spires (red, L15): 33, 29 m 5 s |
| `loc.pine_hollow` (existing) | Pine Hollow (farmstead) | loot POI, Light | Light | 1 | — | 15 | 12 m | per lobby | Crash Site / Motel-style beginner loot hub |
| `loc.sunken_quarry` (existing; display Rustwater) | Rustwater (roadside town) | loot POI, Dense | Dense | 8 | Quarry Signal Tower | 22 | 19 m | per lobby | Motel (13 storages) / The Highway |
| `loc.ashfall_depot` (existing) | Ashfall Depot (quarry pit, rail yard) | loot POI, Black | Black | 15 | Depot Signal Tower | 33 | 29 m | **20 h** after first entry | Abandoned Factory (24 h) / Crooked Creek Farm (48 h) |
| `loc.stranded_caravan`, `loc.supply_drop` | unchanged (CONTENT_S2) | rotating, airdrop | Dense / Light | 8 / 1 | — | 22 / 10 | 19 m / 8 m | per appearance | Destroyed convoy / Airdrop |

**Sources for the LDoE energy and walk times:** [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood), [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires), [Oak Bushes](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Bushes) (51 energy, 49 m walk, Watchtower), [Frosty Backwoods](https://last-day-on-earth-survival.fandom.com/wiki/Frosty_Backwoods).

**Rulings:**
- **Energy and walk times** are LDOE_PARITY #38's 15/22/33 and 12/19/29 by tier, which are also LDoE's green, yellow and red.
- **Level gates** are GAME_DESIGN's (Dense 8+, Black 15+). LDoE uses L10 and L15.
- **The existing three maps keep their IDs and their region towers**, and move to the loot-POI role (§6.3).

### 6.2 Resource zones: nodes, containers, Hollow

Counts copy LDoE's zone pages: [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood), [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires), [Oak Bushes](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Bushes), [Frosty Backwoods](https://last-day-on-earth-survival.fandom.com/wiki/Frosty_Backwoods). In the node columns, "a + b" means our count for each node type.

**Forests**

| | **Bracken Edge** (Forest L1) | **Ironbark Stand** (Forest L2) | **Gloaming Deep** (Forest L3) |
|---|---|---|---|
| LDoE source counts | Pine Bushes: 27 pine + 3 dead trees, 3 limestone rocks, 19 loose logs, 21 loose limestone, 20 fiber, 10 berry bushes, 1–3 storages, ~2,050 XP | Pine Grove: 55 + 5 trees, 5 rocks, 20 + 20 loose, 30 fiber, 10 bushes, 3–4 storages, ~3,450 XP. Oak Bushes: 15 oak (30 logs), 3–4 storages | Pine Wood: 90 + 10 trees, 5 rocks, 45 + 15 loose, 40 fiber, 10 bushes, 4–5 storages, 1–3 oak, ~5,350 XP |
| Pine | 30 | 40 | 50 |
| Ironbark | — | **15** (30 logs) | **25** (50 logs) |
| Gloamwood (M2) | — | — | 12 (M2) |
| Boulder, Fatwood Stump | 3, 4 | 5, 6 | 5, 10 |
| Fallen Branches, Loose Stones | 12, 12 | 15, 12 | 20, 10 |
| Reed Patch, Emberberry Bush, Ashroot, Spring Pool | 20, 10, 6, 1 | 30, 10, 6, 1 | 40, 10, 6, 1 |
| Containers | `loot.zone_pack_t1` ×1–2 (pack, 3 s); `loot.forest_crate_t1` ×0–1 (crate, 5 s) | `loot.zone_pack_t2` ×2; `loot.forest_crate_t2` ×1–2 | `loot.zone_pack_t3` ×2–3; `loot.forest_crate_t3` ×2 |
| Fog-meter band loot | band 2: `loot.pine_band2` | band 2: `loot.quarry_band2` | band 2: `loot.depot_band2` |
| Hollow (base) | Shambler 5–7, Runner 0–1 | Shambler 6–8, Runner 3–4, Bloater 1–2 (band 2), Runner +1–2 (band 2) | Shambler 8–10, Runner 5–7, Bloater 2–3, Runner +2–3 (band 3) |
| Wildlife | Fog Deer 2–3, Ash Wolf 1–2 | Ash Wolf 2–3 | Ash Wolf 2–3 |
| Gear score; extraction | 40; any edge | 90; 3 points (Logging Road, Creek Ford, Ranger Hut), 1 closed per run | 140; 3 points (Old Trail, Fire Lookout, Burnt Bridge), 1 closed per run, plus the flare extract |
| Travel bonus | `loot.road_light` | `loot.road_dense` | `loot.road_black` |
| Main loot | timber, sticks, fiber, emberberries, fatwood, stone | timber, ironbark log, fatwood, fiber, sticks | ironbark log, timber, fatwood, fiber, pitch glue |
| Possible loot | plank, cord, cloth, sealed tin, boiled water, field dressing, pitch glue, stone hatchet, coil spring, snarled wire, raw venison, raw hide | plank, rivets, embercoal, iron ingot, coil spring, steel pipe, trigger group, forged hatchet, seized motor, ember tonic | ironbark plank, rivets, embercoal, scrap plate, coil spring, brass gear, steel pipe, trigger group, forged hatchet, Pack Frame Schematic, hearth stew |
| Location quest (daily) | Kindling: gather 30 timber → 150 XP, 2 cord | Hard Grain: gather 10 ironbark logs → 300 XP, 2 pitch glue | Into the Gloam: search 5 containers → 500 XP, 1 coil spring |

**Mines**

| | **Rockfall Slope** (Mine L1) | **Greenvein Bluffs** (Mine L2) | **Deepcut Pit** (Mine L3) |
|---|---|---|---|
| LDoE source counts | Limestone Ridge: 7 pine + 3 dead, 25 limestone rocks (75), 5 iron rocks (15), 10 loose logs, 20 loose limestone, 20 fiber, 10 bushes, 1–3 storages, ~2,500 XP | Limestone Cliffs: 10 + 3 trees, 20 rocks (60), **30 iron rocks (90)**, 10 + 30 loose, 30 fiber, 10 bushes, 3–4 storages, ~3,820 XP. Frosty Backwoods: 10 copper rocks | Limestone Spires: 10 + 10 trees, 45 rocks (135), 50 iron rocks (150), 15 + 45 loose, 40 fiber, 10 bushes, 4–5 storages, ~6,650 XP |
| Boulder | 25 | 20 | 45 |
| Ironstone Outcrop | 5 | **30** | **50** |
| Malachite Vein | — | **10** | **20** |
| Tinstone Seam (M2) | — | — | 15 (M2) |
| Scrap Heap, Niter Seam | 3, 0 | 4, 4 | 6, 6 |
| Pine | 10 | 13 | 20 |
| Fallen Branches, Loose Stones | 8, 20 | 10, 15 | 10, 22 |
| Reed Patch, Emberberry Bush, Spring Pool | 20, 10, 1 | 30, 10, 1 | 40, 10, 1 |
| Containers | `loot.zone_pack_t1` ×1–2; `loot.mine_box_t1` ×0–1 (crate, 5 s) | `loot.zone_pack_t2` ×2; `loot.mine_box_t2` ×1–2 | `loot.zone_pack_t3` ×2–3; `loot.mine_box_t3` ×2 |
| Fog-meter band loot | band 2: `loot.pine_band2` | band 2: `loot.quarry_band2` | band 2: `loot.depot_band2` |
| Hollow (base) | Shambler 5–7, Runner 1–2 | Shambler 6–8, Runner 3–5, Bloater 1–2 (band 2) | Shambler 8–12, Runner 5–7, Bloater 2–3, Runner +2–3 (band 3) |
| Wildlife | Fog Deer 1–2, Ash Wolf 1–2 | — | — |
| Gear score; extraction | 40; any edge | 90; 3 points (Haul Road, Ore Chute, Switchback), 1 closed per run | 140; 3 points (Pit Ramp, Conveyor Head, Spoil Heap), 1 closed per run, plus the flare extract |
| Travel bonus | `loot.road_light` | `loot.road_dense` | `loot.road_black` |
| Main loot | stone, ironstone, scrap, timber, fiber | ironstone, stone, malachite, scrap, niter | ironstone, malachite, stone, scrap, niter |
| Possible loot | iron ingot, rivets, pitch glue, stone pick, cord, coil spring, cracked lantern, snarled wire, seized motor | iron ingot, stone block, rivets, copper ingot, coil spring, brass gear, forged pick, steel pipe, trigger group, blackpowder | scrap plate, iron ingot, copper ingot, copper wire, rivets, coil spring, brass gear, forged pick, steel pipe, trigger group, blackpowder |
| Location quest (daily) | Loose Rock: gather 30 fieldstone → 150 XP, 4 scrap | Green Seam: gather 6 malachite → 300 XP, 4 embercoal | Bottom of the Pit: gather 20 ironstone → 500 XP, 1 brass gear |

**Location quests are daily:** once per UTC day per player, paying XP and a small item. They never pay **Rations**: a Ration is +60 Energy and would refund the Run, so a quest paying one every lobby turns Energy into a loop. The existing S2 location quests pay Rations. If they repeat per lobby, cap them to once a day in the same pass.

**Map size, same rule as LDoE:** L1 and L2 maps share the Pine Hollow footprint; L3 maps are about 1.33× per side. LDoE's green and yellow zones are 600 × 600 units, red zones 800 × 800.

### 6.3 The three existing maps as loot-heavy POIs

LDoE separates farm zones (nodes, a few weak bags) from dungeons and hubs (many good containers, few nodes: Motel 13 storages × 20 slots, the Farm's 60-slot chest; world doc §2.2). Our existing maps take the second role:

| Location | Containers (was → now) | Nodes (was → now) | Hollow | Note |
|---|---|---|---|---|
| **Pine Hollow** (farmstead, barn, silo, orchard) | packs 2–3 → **3–5**; crates 1–2 → **2–3** | pine 16 → 8, boulder 10 → 4, branches 8, stones 8, reeds 10, bushes 6, ashroot 6, pools 2 | unchanged (CONTENT_S2) | The Light place for a **Coil Spring**: about 0.45 per run, which unlocks the Dense tower on day 2 |
| **Rustwater** (roadside town) | cabinets 1–2 → **3–4**, trunks 1 → **2–3**, lockers 1–2 → **2–3** | boulder 18 → 6, scrap heap 8, fatwood 6 → 4, pine 6 → 4, ashroot 4, niter 4, pools 2 | unchanged | Dense parts town: about 0.7 springs, 0.64 pipes, 0.14 trigger groups and 0.6 motors per run |
| **Ashfall Depot** (quarry pit, rail yard) | freight 4–5 → **5–6**; strongboxes 1–2 | scrap heap 14, fatwood 6, boulder 6, **ironstone 8 (new: the pit)**, niter 6, pool 1 | unchanged | The Black dungeon: **Reinforcement Plans**, gears, springs. Its 20 h reset makes it one full clear a day |

### 6.4 Hollow mix and scaling by tier

**Scaling:**
- **LDoE scales by mix and count, not stats.** The same Fast Biter has 80 HP in every zone ([Fast Biter](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter)). Green zones get 1 Fast Biter and rarely a Bloater; yellow gets more Biters, 1–2 Bloaters and Spitters; red gets Spitters that outnumber Biters, plus Abominations ([Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood)).
- **We copy the mix and count (§6.2) and add a modest per-tier stat scale**, since the developer asked for "more or less difficult zombies based on tier".
- **New:** `Tuning.hollowTierScale = { health = { 1, 1.2, 1.4 }, damage = { 1, 1.15, 1.3 } }` by fog tier.
- **Stacking:** it multiplies on top of the lobby's Fog-meter bands (1 / 1.2 / 1.45). The worst case, a Black lobby at band 3, is HP ×2.03 and damage ×1.89.
- **Wildlife** (deer, wolf) ignores the tier scale.

| Ours | Base HP / dmg | Light (L1) | Dense (L2) | Black (L3) | LDoE counterpart (HP / dmg / XP) |
|---|---|---|---|---|---|
| Shambler | 40 / 5 | 40 / 5 | 48 / 5.8 | 56 / 6.5 | Roaming Zombie 40 / 6; 50 XP per its page, 10 per the econ doc (conflict) ([Roaming Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Roaming_Zombie)) |
| Runner | 70 / 6 | 70 / 6 | 84 / 6.9 | 98 / 7.8 | Fast Biter 80 / 6 / 100 XP ([Fast Biter](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter)) |
| Bloater | 60 / 4 + cloud 6/s | 60 | 72 | 84 | Floater Bloater 240 / 10, slam 30, 250 XP ([Floater Bloater](https://last-day-on-earth-survival.fandom.com/wiki/Floater_Bloater)); Toxic Spitter 80 / 6, spit 15 ([Toxic Spitter](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Spitter)) |
| Brute (M2) | — | — | — | — | Toxic Abomination 300 / 10, slam 30 ([Toxic Abomination](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Abomination)); Frenzied Giant 500 / 200 ([Frenzied Giant](https://last-day-on-earth-survival.fandom.com/wiki/Frenzied_Giant)) |

Our XP per kill (10 / 25 / 30) is unchanged. The XP curve (§9.3) is built on it.

---

## 7. Loot tables

**Format:** item, weight, quantity (min–max).
- Rolls are uniform between min and max, and each roll picks one entry by weight (Domain/Loot).
- **JUNK** means one open of `loot.junk`: Cracked Lantern 45, Snarled Wire 40, Seized Motor 15.
- **Light** rolls containers per player. **Dense and Black** share one contested roll (unchanged).

**The LDoE pattern being copied:** green zone storages hold "a couple of items each" of food, water, bandages and low parts, with rare adhesive, scrap and wiring, very rare melee, and extremely rare bats or a CAC A card. Yellow zones have 3–4 storages and "vehicle parts spawn more frequently". Red zones have the best loot, with guns ([Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood), [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires)).

### 7.1 Abandoned Pack (both biomes, by tier)

| `loot.zone_pack_t1`: rolls 1–3 | | `loot.zone_pack_t2`: rolls 2–3 | | `loot.zone_pack_t3`: rolls 2–4 | |
|---|---|---|---|---|---|
| Sealed Tin | 10 (1) | Sealed Tin | 10 (1–2) | Field Dressing | 14 (2–3) |
| Boiled Water | 8 (1) | Boiled Water | 8 (1–2) | Sealed Tin | 8 (2) |
| Reedcloth | 14 (1–2) | Field Dressing | 12 (1–2) | Hearth Stew | 10 (1) |
| Murky Water | 12 (1–2) | Reedcloth | 12 (2–3) | Boiled Water | 6 (2) |
| Reed Cord | 12 (1–2) | Reed Cord | 10 (2–3) | Pitch Glue | 10 (1–2) |
| Field Dressing | 8 (1) | Pitch Glue | 8 (1–2) | Iron Ingot | 10 (2–3) |
| Pitch Glue | 5 (1) | Rusted Scrap | 8 (3–6) | Scrap Plate | 8 (1–2) |
| Rusted Scrap | 5 (2–4) | Iron Ingot | 6 (1–2) | Rivets | 8 (2–4) |
| Snarled Wire | 3 (1) | Coil Spring | 4 (1) | Coil Spring | 8 (1–2) |
| Coil Spring | 2 (1) | Snarled Wire | 4 (1) | Ember Tonic | 4 (1) |
| | | Seized Motor | 2 (1) | Brass Gear | 3 (1) |
| | | Ember Tonic | 2 (1) | Steel Pipe | 3 (1) |

### 7.2 Woodcutter's Crate (forests)

| `loot.forest_crate_t1`: rolls 2–3 | | `loot.forest_crate_t2`: rolls 2–3 | | `loot.forest_crate_t3`: rolls 3–4 | |
|---|---|---|---|---|---|
| Timber | 24 (3–6) | Timber | 18 (5–8) | Hewn Plank | 16 (4–6) |
| Sticks | 18 (4–8) | Hewn Plank | 18 (3–5) | Ironbark Log | 16 (3–6) |
| Hewn Plank | 14 (2–3) | Fatwood | 14 (3–4) | Fatwood | 12 (4–6) |
| Reed Cord | 14 (1–2) | Ironbark Log | 12 (2–4) | Embercoal | 10 (3–5) |
| Fatwood | 12 (2–3) | Pitch Glue | 10 (1–2) | Pitch Glue | 10 (2) |
| Pitch Glue | 8 (1) | Reed Cord | 10 (2–3) | Rivets | 10 (2–4) |
| Stone Hatchet | 6 (1) | Rivets | 8 (1–2) | Ironbark Plank | 8 (1–2) |
| Cracked Lantern | 4 (1) | Embercoal | 6 (2–4) | Coil Spring | 6 (1) |
| | | Forged Hatchet | 2 (1) | Forged Hatchet | 4 (1) |
| | | Coil Spring | 2 (1) | Brass Gear | 3 (1) |
| | | | | Seized Motor | 3 (1) |
| | | | | Pack Frame Schematic | 2 (1), rarity epic |

### 7.3 Miner's Box (mines)

| `loot.mine_box_t1`: rolls 2–3 | | `loot.mine_box_t2`: rolls 2–3 | | `loot.mine_box_t3`: rolls 3–4 | |
|---|---|---|---|---|---|
| Fieldstone | 20 (4–8) | Ironstone | 18 (4–6) | Iron Ingot | 16 (2–4) |
| Ironstone | 18 (2–4) | Rusted Scrap | 14 (5–8) | Malachite | 12 (3–5) |
| Rusted Scrap | 18 (3–6) | Iron Ingot | 14 (1–3) | Scrap Plate | 12 (2–3) |
| JUNK | 10 (1) | Malachite | 10 (2–3) | Stone Block | 10 (3–5) |
| Reed Cord | 10 (1–2) | Stone Block | 10 (2–3) | Rivets | 10 (3–5) |
| Pitch Glue | 6 (1) | Rivets | 10 (2–3) | Coil Spring | 8 (1–2) |
| Stone Pick | 6 (1) | JUNK | 10 (1) | Copper Ingot | 8 (1–2) |
| Iron Ingot | 6 (1) | Coil Spring | 6 (1) | JUNK | 8 (1) |
| Rivets | 4 (1–2) | Forged Pick | 3 (1) | Copper Wire | 6 (2–3) |
| Coil Spring | 2 (1) | Copper Ingot | 3 (1) | Brass Gear | 4 (1) |
| | | Niter Crust | 2 (1–2) | Forged Pick | 4 (1) |
| | | Brass Gear | 2 (1) | Blackpowder | 2 (1–2) |

### 7.4 Changes to existing tables

| Table | Change | Why |
|---|---|---|
| `loot.pine_pack` | + Coil Spring 4 (1); Sealed Tin 20 → **10**; Boiled Water 10 → **6** | Pine Hollow is the Light-tier spring source for the Dense tower. Food in containers is thinned so it has to be hunted (§8.4) |
| `loot.quarry_locker` (Rustwater) | Sealed Tin 25 → **12**; Boiled Water 20 → **10** | Same: tins are a top-up, not a diet |
| `loot.pine_crate` | + Ironstone 6 (2–4) | The farmstead's tool shed: the first ore before the Mine |
| `loot.quarry_toolbox` (Rustwater) | Scrap Plate 15 → 10; + Iron Ingot 15 (1–2); + Copper Wire 4 (1–2) | Ingots are the new plate input |
| `loot.quarry_band2` | Trigger Group 8 → **3**, rarity epic; add `pity = { rarity = "epic", every = 15 }` | Rustwater's container count went up. This holds the first firearm at day 3 (§9) |
| `loot.quarry_band3` | Trigger Group 14 → **5** | Same |
| `loot.depot_freight` | + Iron Ingot 10 (2–4); + Ironbark Plank 6 (2–3); + Copper Ingot 4 (1) | Black loot carries the Reinforced tier's inputs |
| Enemy, animal, airdrop, caravan, depot band and road tables | unchanged | — |

### 7.5 Where the gating parts come from

Expected count per run, from the §9 model.
- **Assumptions:** Dense and Black containers are shared, so a player reaches about 60% of them. About 45% of containers are searched in Fog band 2+ and 15% in band 3.
- **Scope:** containers only; enemy drops and the Recycler are extra.

| Location | Coil Spring | Brass Gear | Steel Pipe | Trigger Group | Pitch Glue | Seized Motor | Plans | Pack Frame BP |
|---|---|---|---|---|---|---|---|---|
| Bracken Edge | 0.09 | — | — | — | 0.36 | — | — | — |
| Rockfall Slope | 0.12 | — | — | — | 0.33 | 0.02 | — | — |
| Pine Hollow | **0.49** | — | 0.10 | — | 0.40 | — | — | — |
| Ironbark Stand | 0.21 | — | 0.14 | 0.03 | 0.87 | 0.08 | — | — |
| Greenvein Bluffs | 0.31 | 0.05 | 0.14 | 0.03 | 0.48 | 0.12 | — | — |
| Rustwater | 0.70 | — | **0.64** | **0.14** | 0.18 | **0.69** | — | — |
| Gloaming Deep | 0.96 | 0.31 | 0.55 | 0.26 | **1.81** | 0.14 | — | 0.10 |
| Deepcut Pit | 1.25 | 0.36 | 0.55 | 0.26 | 0.84 | 0.06 | — | — |
| Ashfall Depot (first clear of the day) | **2.28** | **0.94** | 0.60 | **0.69** | — | 0.22 | **0.17** (pity: at least one epic per 5 strongboxes) | 0.20 |

**Food in containers per run** after the §7.4 thinning: Sealed Tins 0.5 (Light zones) to 1.5 (Ashfall Depot); Boiled Water 0.35 to 1.0. In the §9 reference run, loot tins are about 7 of the 25 food items eaten a day, and loot water about 6 of 19 drinks. The rest is hunted, picked and boiled (§8.4).

**Bad-luck protection:** pity counters are per player, per table (unchanged). The new `quarry_band2` pity guarantees a Trigger Group by the 15th band-2 Dense container.

---

## 8. Sinks: durability and survival

**The developer, 2026-11-08:** "item durability is huge for us, and the need to eat and drink etc. helps us drive micro txns. Guns break pretty quick in Last Day on Earth, and weapons etc., which makes you need to craft more or farm more or simply buy more because it's much easier."

**The rule:**
- Every tool, melee weapon, gun and armor piece wears out at LDoE's values or faster, and nothing is repaired early.
- Ammo, food, water and dressings are spent every minute of play.
- Each drain is a steady demand. A free player meets it by farming and re-crafting; a paying player meets it with a pack offered at the moment of need (§8.6).
- The pacing model runs with every sink switched on (§8.7, §9).

### 8.1 Durability: every item wears out

**What LDoE does** (wiki weapon and armor pages, re-read 2026-11-08):
- **Guns have no ammo item.** Durability counts shots, so the gun itself is the ammunition: the Glock 17 is "100 shots/2000 damage" ([Glock 17](https://last-day-on-earth-survival.fandom.com/wiki/Glock_17)) and the Shotgun "70*40 shots = 2800 damage" ([Shotgun](https://last-day-on-earth-survival.fandom.com/wiki/Shotgun)).
- **Other guns and bows:** the M16 and AK-47 last 170, the Mini Uzi 200, the Zip Gun 100, the Flare Gun 32, the Crossbow 35 and the Bow "50 shots" ([M16](https://last-day-on-earth-survival.fandom.com/wiki/M16), [AK-47](https://last-day-on-earth-survival.fandom.com/wiki/AK-47), [Mini Uzi](https://last-day-on-earth-survival.fandom.com/wiki/Mini_Uzi), [Zip Gun](https://last-day-on-earth-survival.fandom.com/wiki/Zip_Gun), [Flare Gun](https://last-day-on-earth-survival.fandom.com/wiki/Flare_Gun), [Crossbow](https://last-day-on-earth-survival.fandom.com/wiki/Crossbow), [Bow](https://last-day-on-earth-survival.fandom.com/wiki/Bow)).
- **Melee:** durability counts hits: Spear, Makeshift Bat, Cleaver and Crowbar 100, Metal Pipe 90, Machete 80, Katana 70, Skull Crusher 45, Saw Blade Mace 30 ([Makeshift Bat](https://last-day-on-earth-survival.fandom.com/wiki/Makeshift_Bat), [Cleaver](https://last-day-on-earth-survival.fandom.com/wiki/Cleaver), [Machete](https://last-day-on-earth-survival.fandom.com/wiki/Machete), [Skull Crusher](https://last-day-on-earth-survival.fandom.com/wiki/Skull_Crusher), [Saw Blade Mace](https://last-day-on-earth-survival.fandom.com/wiki/Saw_Blade_Mace)).
- **Armor:** durability "decreases as the player takes damage from attacks". It is 150 for most sets (Thick, Tactical, SWAT, Kevlar) and 180 for the Reinforced set ([Armor and Armor Points](https://last-day-on-earth-survival.fandom.com/wiki/Armor_and_Armor_Points)).

**Our rules** (most already in `Tuning.combat`; the new ones are bold):

| What wears | Cost |
|---|---|
| Melee | 1 per landed hit; **2 per heavy swing** |
| Gun | **1 per round fired, hit or miss**; the shotgun pays 1 per shell, so both barrels cost 2 |
| Bow | 1 per arrow released |
| Tool | 1 per gather hit, and 1 per hit when used as a weapon |
| Armor | 1 per hit taken, on every equipped piece |

- **At 0 the item breaks and is destroyed** (LDoE).
  - The active slot switches to the other weapon, or to fists, with a toast (LDOE_PARITY #45).
  - Recycling before the break returns parts, at a chance scaled by the durability left.
- **HUD warnings:** the weapon circle's durability ring (#1) turns amber at 25% and red at 10%, and a toast fires at 10% and on the break.
- **We keep ammo and also wear the gun per shot,** so every shot is two sinks. That is harsher than LDoE.

| Item | Durability (new; was) | Unit | LDoE counterpart | Uses per typical run (§9 model) | Runs per item |
|---|---|---|---|---|---|
| Stone Hatchet, Stone Pick | **40** (60) | gather hits | Hatchet, Pickaxe 50 | 45–90 hits on a full forest or mine clear | 0.5–1 |
| Forged Hatchet, Forged Pick | 75 (new) | gather hits | Iron Hatchet, Iron Pickaxe 75 | 60 (15 ironbark) to 120 (20 malachite veins) | 0.6–1.2 |
| Spiked Club | **80** (110) | hits | Makeshift Bat 100 | 15–19 hits (Light, 14 damage) | about 4.5 |
| Scrapblade | **80** (120) | hits | Cleaver 100 | 20 (Dense), 34 (Black, melee only) | 4 / 2.4 |
| Machete (S2) | **70** (130) | hits | Machete 80 | 22 (Dense, 22 damage) | 3 |
| Fire Axe (S2) | **50** (150) | hits | Skull Crusher 45 | 14 (Dense, 36 damage) | 3.5 |
| Reed Shortbow | **40** (60) | arrows | Bow 50 | 10–15 | 3 |
| **Pipe Pistol** (S2) | **50** (140) | shots | Zip Gun 100, Glock 17 100 | 15 (Black), 20–25 (gun-only Dense) | **2–3.3** |
| **Scrap Shotgun** (S2) | **30** (120) | shells | Shotgun 40 | 10–12 | **2.5–3** |
| **Flare Pistol** (S2) | **24** (100) | flares | Flare Gun 32 | 4–6 | 4–6 |
| Service Revolver / Pump Shotgun / Hunting Rifle (M2) | 80 / 35 / 40 | shots | Colt Python 100 / Shotgun 40 / VSS 60 | 15–25 | 2–4 |
| Padded Hood | **80** (120) | hits taken | basic clothes (unlisted); Beanie 150 | 4 (Light), 9 (Dense), 16 (Black) | 5–20 |
| Padded Vest | **100** (150) | hits taken | Thick Jacket 150 | same | 6–25 |
| Plated set (M2) | 150 | hits taken | Tactical, SWAT 150 | same | 9–37 |

**How "uses per run" is computed:** the model kills 60% of each location's Hollow at tier-scaled HP (§6.4). Melee hits are that HP divided by the weapon's damage. Armor hits are 0.8 / 1.2 / 1.5 per kill by tier.

**Result:** a gun loses about a third of its life on every Black run, and a Scrapblade a quarter to two fifths. That is "guns break pretty quick".

### 8.2 Re-crafting instead of repair

**No early repair** (LDOE_PARITY #21). A worn item is re-crafted with the full recipe, so the rare parts in each recipe are what makes the sink hurt.

**Recipe changes:**

| Recipe | Change | LDoE counterpart |
|---|---|---|
| Reed Shortbow | Pitch Glue 1 → **2** | Bow takes 3 duct tape + 3 adhesive, both loot-only |
| Scrapblade | **+1 Pitch Glue** | — |
| Machete | **+1 Pitch Glue** | — |
| Padded Vest | **+1 Pitch Glue** | — |
| Field Dressing | **5 Reedcloth** (was 3) | Bandages: 5 Piece of Cloth → 40 HP ([Bandages](https://last-day-on-earth-survival.fandom.com/wiki/Bandages)) |

| Re-craft | Rare parts in it | Refining it takes | What it means for a free player |
|---|---|---|---|
| Spiked Club | none | 8 timber, 20 m at the Saw Bench | Cheap on purpose: tier 1 |
| Scrapblade | 1 Pitch Glue | 5 ingots (10 ironstone), about 2 h of Smelter and Workbench time | About 1.4 a day; the Workbench queue feels it (§8.5) |
| Pipe Pistol | **1 Trigger Group, 1 Steel Pipe, 1 Coil Spring** | 3 plates of Workbench time | The Trigger Group drops 0.14 per Rustwater run and 0.69 per Depot clear (§7.5). A free player keeps one gun alive only by farming Black fog: about 1 pistol per Black-fog day in the reference run |
| Scrap Shotgun | **2 Trigger Groups, 2 Steel Pipes** | 6 plates | A luxury: 30 shells per 2 Trigger Groups |
| Padded Vest | 1 Pitch Glue | 6 cloth (12 fiber), 2 plates | About 1 a day |

**Partial salvage:** recycling a worn item before it breaks returns a share of its parts (§3.1, chance × durability). A Pipe Pistol recycled at 40% durability is the only cheap way to stretch a Trigger Group.

**Late repair (M3): the Mender's Bench.**
- **LDoE counterpart:** the Repair Station costs 3,600 Infected Genome and needs 10 Borealis kills. It repairs a percentage per unit of material, or adds a duplicate item's remaining durability ([Repair Station](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station)).
- **Unlock:** an M3 Black-fog boss.
- **Build cost:** 6 ember steel plate, 10 ironbark plank, 20 copper wire, 10 solder, 10 scrap.
- **Speed:** a job takes 30 minutes; LDoE's take "a few minutes".

| Item class | Material 1 (% per unit) | Material 2 (% per unit) | LDoE reference row |
|---|---|---|---|
| Stone tools | Timber 25% | Fieldstone 25% | Hatchet: Pine Log 25%, Limestone 25% |
| Forged tools | Iron Ingot 7% | Rivets 5% | Iron Hatchet: Iron Bar 7%, Duct Tape 5% |
| Melee, tiers 1–2 | Scrap Plate 6% | Rivets 4% | Cleaver: Iron Bar 6%, Bolts 4%; Machete: Iron Bar 5%, Leather 4% |
| Bows | Pitch Glue 9% | Reed Cord 7% | Bow: Adhesive 9%, Duct Tape 7% |
| Improvised guns | Coil Spring 8% | Pitch Glue 4% | Glock 17: Factory Parts 8%, Gun Oil 6%; Zip Gun: Iron Plate 3%, Spring 4% |
| Standard guns (M2) | Trigger Group 10% | Solder 3% | M16: Factory Parts 7%, Gun Oil 5% |
| Armor | Reedcloth 6% | Tanned Leather 8% | — |
| Any item | a duplicate adds its remaining % | — | "repaired with another one of the item" |

- **Repair is never the cheap path:** a full Pipe Pistol repair takes 12.5 Coil Springs. It exists for guns carrying mods (M2–M3), as in LDoE.
- **VIP (S3):**
  - Free repair at the Haven VIP Lounge, 12 h per item. LDoE's VIP 5 gives a free Repair Workbench at 12–24 h ([VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone)).
  - The top VIP tier adds a daily 1-hour indestructible weapon, as LDoE's Prestige does.
  - Neither is a shield or immunity, so both are inside the raid rules.

### 8.3 Ammo: the steady gun sink

**Rulings:**
- **The Ammo Press stays a converter** (one input, one output): Niter → Blackpowder.
- **Rounds, shells and flares become hand recipes.** CONTENT_S2's data binds them to the press with 2–3 inputs, which the converter rule (§11.1, validator) forbids.

| Recipe | Was | Now | Where | Cost per shot | LDoE reference |
|---|---|---|---|---|---|
| Blackpowder | 2 niter → 2, 6 m | **2 niter → 1**, 6 m | Ammo Press (fuelled) | — | Gunpowder: 20 Sulfur + 20 Charcoal → 1, 1 h ([Gunpowder](https://last-day-on-earth-survival.fandom.com/wiki/Gunpowder)) |
| Light Rounds | 2 scrap + 1 powder → 6 | **2 scrap + 1 powder → 4** | hand | 0.5 scrap + 0.5 niter | none: LDoE guns spend durability instead |
| Scrap Shells | 3 scrap + 2 powder + 1 cloth → 4 | **→ 3** | hand | 1 scrap, 1.33 niter, 0.33 cloth | — |
| Signal Flare | 2 powder + 1 glue + 1 cloth → 2 | unchanged | hand | 2 niter, 0.5 glue, 0.5 cloth | — |
| Fire-Hardened Arrow | 2 sticks + 2 scrap + 1 fiber → 5 | unchanged; 60% of arrows recovered | hand | about 0.16 sticks + 0.16 scrap net | — |

**Consumption against supply (Inference):**
- **What shooting costs:** a Black run with a Pipe Pistol fires 15 rounds, which is 7.5 niter, 7.5 scrap and 22 minutes of Press time. A gun-led Dense run fires 20–25 rounds, which is 10–13 niter.
- **What a run gives:** Greenvein Bluffs and Rustwater have 4 Niter Seams (12 niter); Deepcut Pit and Ashfall Depot have 6 (18 niter). Bloaters add about 0.4 niter each.
- **Result:** shooting eats about what a run's seams give. Ammo breaks even only for a player who mines every seam, so a gun-heavy player buys the Ammo Box (§8.6).

### 8.4 Hunger and thirst

**Rates** (LDoE, binding: LDOE_PARITY #33):
- −1 hunger and −1 thirst every 10 s while in the world, at home and on Fog Runs. Neither drains on the Fog map or loading screens.
- Warning at 20; 2 HP/s at 0 ([Hunger](https://last-day-on-earth-survival.fandom.com/wiki/Hunger), [Thirst](https://last-day-on-earth-survival.fandom.com/wiki/Thirst)).
- That is **360 of each per real hour**; a full meter lasts 16 m 40 s.

| Food or drink (ID) | Hunger | Thirst | HP | Source and cooking | LDoE counterpart |
|---|---|---|---|---|---|
| Fire-Roasted Venison (`item.cooked_meat`) | 40 | — | 10 | 2 Raw Venison → 2, Campfire 3 m | Jerky 40 (Meat Dryer 10 m, no fuel); Juicy Steak 30 (Campfire 2 m) ([Jerky](https://last-day-on-earth-survival.fandom.com/wiki/Jerky), [Juicy Steak](https://last-day-on-earth-survival.fandom.com/wiki/Juicy_Steak)) |
| Raw Venison (`item.raw_meat`) | 6 | — | — | Fog Deer 3 each, Ash Wolf 1 (+30% a second) | Raw Meat 5 |
| Hearth Stew | 60 | 15 | 40 | hand: 2 Roasted Ashroot + 3 berries + 1 Boiled Water | — |
| Roasted Ashroot | 30 | — | 15 | 1 Ashroot, Campfire 2 m | Carrot Stew 25 |
| Sealed Tin | 25 | 5 | 10 | loot only (thinned, §7.4) | Canned Food 25 / 5 / 15 ([Canned Food](https://last-day-on-earth-survival.fandom.com/wiki/Canned_Food)) |
| Emberberries | 4 | 2 | 3 | bush, **3 per bush** (was 2) | Berry 2 / 1; a bush gives 3 |
| Boiled Water | — | 45 | — | 1 Murky Water, Campfire 2 m | Bottle of Water 50; Rain Catcher 10 m, no fuel ([Bottle of Water](https://last-day-on-earth-survival.fandom.com/wiki/Bottle_of_Water)) |
| Ember Tea | 5 | 35 | 5 | 3 berries, Campfire 2 m | Berry Tea 5 / 30, 3 berries, 2 m ([Berry Tea](https://last-day-on-earth-survival.fandom.com/wiki/Berry_Tea)) |
| Murky Water | — | 15 | — | Spring Pool: 3 hits → 1, refills in 3 m | Bottle with dirty water 23 |

**A day's need (2.5 h of play):** 900 hunger and 900 thirst. That is about **23 Fire-Roasted Venison and 20 Boiled Water**, or any mix.

**Where it comes from** (the reference run in §9, 14-day average):
- **Eaten:** 17 Roasted Venison, 7 Sealed Tins and 1 Hearth Stew a day for hunger; 19 Boiled Water for thirst.
- **Meat:** deer live in the Light zones: Pine Hollow 2–3, Bracken Edge 2–3, Rockfall Slope 1–2. A Light run gives about 5–6 Raw Venison (60% of deer and wolves).
- **Water:** the home Spring Pool (1 per home visit, since it refills in 3 m), each location's 1–2 pools, and loot.

**Campfire load and its ruling:**
- Food costs about 40 Campfire-minutes of boiling and 25 of cooking a day, plus about 33 timber of fuel.
- The Campfire is also the Embercoal and Pitch Glue line. **Ruling:** food lines sort to the top of the Campfire's ALL RECIPES list, and the pacing policy loads them first.
- Without that, the model starved players on days 8–10 while both Campfires made coal. A Smoke Rack (LDoE's no-fuel Meat Dryer) is the M2 relief valve.

**Time cost:** about **7% of run time** goes to food: deer stalks, berry and pool stops, and runs picked mainly for meat. On top of that come about 65 Campfire-minutes and 33 timber a day. The reference player starves for 0 minutes.

**Not in the v0.1 model:**
- `features.dailyGift` stays off in v0.1 (MVP_LAUNCH). When it turns on (LDOE_PARITY #58) it gives 2 tins and 2 Boiled Water a day until level 10; LDoE gives 3 and 3 until about level 100.
- The Rain Catcher (S3, #36) refills an Empty Bottle in 10 m with no fuel, max 2, as LDoE's does. It cuts spring trips when it ships, and the S3 pacing test adds it.

**Medicine:**
- Field Dressing: 5 Reedcloth → 40 HP.
- Used per run: Light 0.3, Dense 0.8, Black 1.5.
- That is about 8 a day: 40 cloth, which is 80 fiber and 80 Workbench-minutes.

### 8.5 What the drains cost a free player

From the §9 reference run (2.5 h a day, all sinks on), over 14 days:

| Drain | Per day (average) | 14-day total | What it pulls |
|---|---|---|---|
| Food | 17 Roasted Venison, 7 Sealed Tins, 1 Hearth Stew | 233 / 102 / 17 | Light-zone hunting, 25 Campfire-minutes |
| Water | 19 Boiled Water | 265 | 19 Murky Water, 40 Campfire-minutes, about 20 timber of fuel |
| Melee weapons | 2 re-crafts (1.4 Scrapblades, 0.6 Spiked Clubs) | 19 Scrapblades, 8 Spiked Clubs | Each Scrapblade: 4 plates, 2 rivets, 2 planks, 2 cloth, 1 glue, about 2 h of station time |
| Armor | 2.2 pieces | 18 hoods, 13 vests | 40 cloth, 2 plates, 1 glue a day |
| Dressings | 8 | 113 | 40 cloth (80 fiber), 80 Workbench-minutes |
| Guns (days 7–14, once Black fog is open) | 1.1 Pipe Pistols, 52 rounds fired | 9 pistols, 420 shots | 1 Trigger Group, 1 Steel Pipe and 1 Coil Spring per pistol; about 26 niter and 26 scrap of rounds |
| Broken mid-run | **22% of runs** end with the melee weapon broken and no spare at home | 40 of 178 runs | Mostly day 1 (before the club unlocks) and days 7–9 (plates committed to building) |

The sinks cost the free player about a day and a half across the Scrap and Reinforced tiers. §9 includes them, with building costs tuned so the GAME_DESIGN bands still hold.

### 8.6 Monetization tie-ins

**Packs:**
- Every pack below has fixed contents, so no odds disclosure is needed.
- Each lands in the raid-proof inbox and counts toward have/need at once (GAME_DESIGN).
- Contents are the design; **prices are the developer's call**. The S3 shop sets them in `Data/Products`.

| Drain | Moment of need (trigger) | Where the offer shows | Pack (contents) |
|---|---|---|---|
| Melee weapon breaks with no spare in the bag (22% of runs) | the break toast | a "Restock" button on the toast | **Blade Bundle:** 2 Scrapblades, 1 Machete |
| Gun breaks, or a re-craft is short a Trigger Group | the break toast, or the craft panel's Fill-up | toast; Fill-up | **Gunsmith's Kit:** 2 Trigger Groups, 2 Steel Pipes, 2 Coil Springs, 60 Light Rounds |
| Magazine empty with 0 rounds in the bag | the HUD ammo count turns red | an offer chip on the weapon circle | **Ammo Box:** 120 Light Rounds, 30 Scrap Shells, 10 Signal Flares |
| Armor piece breaks, or death | the break toast; the death screen (GAME_DESIGN) | toast; death-screen gear offer | **Armorer's Bundle:** 2 Padded sets, 10 Field Dressings (the Plated set from M2) |
| Hunger or thirst at 20 or below with no food or water in the bag | the pulsing HUD food or water icon (LDOE_PARITY #2) becomes tappable | an offer card from the icon | **Field Provisions:** 10 Fire-Roasted Venison, 10 Boiled Water, 3 Hearth Stew (about 60% of a day) |
| Low HP and the meds button is empty | the meds button (#1) | an offer chip | **Medic's Satchel:** 15 Field Dressings |
| Any craft or re-craft is short | the craft panel | Fill-up with premium currency (existing) | per item |

**Demand math (Inference):**
- A free player's average day drains about one Blade Bundle of weapons and half of Field Provisions in food and water. On Black-fog days it also drains about one Gunsmith's Kit of gun parts.
- Each pack is therefore about a day of grind saved, offered at the minute the player feels the drain. That is the LDoE pattern the developer described: "craft more or farm more or simply buy more because it's much easier".
- Daily Deals (M2) rotate these items singly.

### 8.7 The sinks in the pacing simulation

The §9 model and the §11.4 Lune test run every sink:
- **Meters:** drain 6 per minute each; the player eats when a meter falls below 55, best item first.
- **Campfire:** cooking and boiling, with food lines first.
- **Meat:** from deer and wolves.
- **Weapons:** melee hits from tier-scaled enemy HP ÷ weapon damage; re-crafts from stock, with a spare kept.
- **Armor:** hits per kill.
- **Dressings:** per run.
- **Guns:** the Pipe Pistol on Black runs (15 shots), with Light Rounds from Ammo Press powder.

**The test asserts** (for the reference player):
- 0 starving minutes.
- Food time at most 15% of run time.
- At least 10% of runs ending with a broken weapon, so the sink bites.
- A Pipe Pistol lasting at most 4 Black runs.

---

## 9. Pacing check

### 9.1 The model

A deterministic expected-value simulation of one free player. It is spelled out in §11.4, so the Lune test reproduces it.

- **Play time:** two sessions a day of 75 minutes each, at 08:00 and 19:00. That is 2.5 hours, the middle of GAME_DESIGN's 2–3 h. 2 × 60 and 2 × 90 are the band edges.
- **Energy:** cap 120 (200 until the 2.0 economy batch, F-16), +1 every 5 minutes, +20 on each level-up, starting full. Run costs 15/22/33; Walk is free but takes 12/19/29 minutes. Returning home after extraction is free.
- **Runs:**
  - **Overhead:** 2.5 minutes in Light, 3.5 in Dense and Black (matchmaking, teleport, crossing the map), plus extraction at 15 s or 45 s.
  - **Gathering time:** a tool node takes 0.8 s per hit + 4 s of walking; a hand node 2.5 s; a container its search time + 15 s.
  - **Kills:** 60% of the spawns (5 s for a shambler, 8 s for a runner or wolf, 9 s for a bloater, 12 s to stalk a deer). Deer give 3 Raw Venison, wolves 1.3, bloaters 0.7 niter.
  - **Cap:** 14 minutes of activity.
- **Sinks (§8):** every one is on.
  - **Meters** drain 6 a minute each through the whole session; the player eats or drinks the best item when a meter drops below 55.
  - **Campfires** boil and cook first.
  - **Gear:** melee weapons, armor, dressings, the Pipe Pistol (15 shots per Black run) and its rounds wear out and are re-crafted from stock. A spare of each is part of every milestone's shopping list.
- **Bag:** 10 pockets + 5 (satchel), minus 3 slots for tools, meds and food. The Pack Frame adds 5 when its schematic drops.
- **Loot:**
  - **Containers:** expected value of the §7 tables, ×1.15 for the band multiplier. Dense and Black containers are shared (60% reach).
  - **Haul lost to deaths:** 5% in Dense, 8% in Black.
  - **Ashfall Depot:** full only on its first clear each day (the 20 h reset).
- **Home:** 3 minutes a visit.
  - **Stations:** refilled at every visit during a session, then run offline on their last load. Both copies of every max-2 station are built as soon as they're affordable.
  - **Building order:** the region towers and station upgrades come first, then the cheapest pieces.
  - **Recycler:** strips motors, wire and lanterns.
- **Run choice:** the player picks the location with the best rate: the value of the materials still missing for the current milestone, plus a small weight on XP, divided by (minutes + 0.5 × Energy spent).
- **The rescaled data in this file** is used throughout.

### 9.2 Results against the GAME_DESIGN bands

All results below run with **every §8 sink on**.

| Milestone (GAME_DESIGN) | Target, free player | 2 h/day | **2.5 h/day (reference)** | 3 h/day | Spread across 3 policy weights |
|---|---|---|---|---|---|
| Hatchet, first walls, Workbench, first queue, level 5 | first 30–60 min | 46 min | **46 min** (level 5 at 46 min) | 46 min | 46 min |
| Timber tier: walled 3×3 base with Campfire, Workbench and crates | end of day 1 | day 1 (106 play-min) | **day 1** (103 play-min) | day 1 (109) | day 1 (103–109 play-min) |
| Dense fog open (level 8 + Quarry tower) | day 2 (CONTENT_S2) | day 3 | **day 3 morning** (L8 day 2, tower day 3 08:00) | day 2 evening | days 2.8–3.8 |
| First firearm (Pipe Pistol) | days 3–5 | day 4 | **day 3.8** | day 3.4 | days 3.4–4.8 |
| Scrap tier: Scrap walls, Recycler, first firearm | **days 3–5** | day 5.8 | **day 4.8** | day 5.0 | days 4.3–5.8 |
| Black fog open (level 15 + Depot tower) | days 5–6 (CONTENT_S2) | day 9 | **day 7.3** | day 7.8 | days 4.8–10.3 |
| Reinforced tier: a fully reinforced 4×4 base | **days 10–14** | day 14.8 | **day 13.3** | day 11.3 | days 10.8–16.8 |
| Level 20 | — | day 15.3 | day 12.3 | day 10.4 | days 9.8–15.3 |
| Standard firearms and armor set (M2) | weeks 2–3 | — | **about day 17–19** (analytic, §9.4) | — | — |
| First vehicle (M4) | weeks 4–6+ | — | **about day 30–40** (analytic, §9.4) | — | — |

**Total play time:** the reference player reaches the Scrap tier after about 9 h of play and the Reinforced tier after about 30 h. That includes the sinks: about 7% of run time on food and water, and two re-crafts a day (§8.5).

**At the edges:**
- **The 2 h/day player** sits on the outer edges: Scrap day 5.8, Reinforced day 14.8. That is acceptable for the low end of "about 2–3 h".
- **Black fog opens a day later than CONTENT_S2's day 5–6.** Survival and re-crafting runs earn less XP. The Reinforced band still holds, so the later Black is accepted and level 15 is not lowered further.

**What binds each tier** (from the model):

| Tier | Binding constraint |
|---|---|
| **Timber** | Timber supply. Home's 60 plus two or three Forest or Mine L1 runs. Cord, from fiber, is the second limit, now shared with Reedcloth for dressings |
| **Scrap** | The Dense tower's single Coil Spring (Pine Hollow), then **Workbench hours**: 72 plates at 20 m is 27 bench-hours across two benches, plus the Scrapblade, vest and dressing re-crafts |
| **Reinforced** | Level 15 and the Depot tower open Black around day 7, then the Plans (about 1.5 Depot clears with pity). After that, **Workbench hours (123)** and Ironbark (595 logs, 47 Saw Bench hours, about 12 Gloaming Deep or 20 Ironbark Stand runs) |

### 9.3 A free player's day

From the 2.5 h reference run, with sinks on. Energy goes above the 288-a-day regen on Black-fog days thanks to level-ups (+20 each) and Energy banked earlier.

| Day | Runs | Energy spent | Gathered | Refined | Built | Consumed (sinks) |
|---|---|---|---|---|---|---|
| 1 | 14: home clear, 5 Rockfall Slope, 4 Bracken Edge, 5 Pine Hollow | 210 | 323 timber, 209 stone, 55 ironstone, 39 raw venison, 30 murky water, 3 springs | 35 planks, 32 blocks, 38 boiled water, 34 venison, 7 tea | The hook (46 min), then the 3×3 Timber room with a 2-cell porch; 2 each of Campfire, Saw Bench, Stonecutter, Workbench and Smelter; 2 crates | 19 venison, 19 water, 5 tins; 2 clubs, 1 hood, 4 dressings |
| 2 | 14: 12 Rockfall, 2 Pine Hollow | 210 | 264 timber, 261 stone, 162 ironstone, 80 scrap, 25 venison | 76 blocks, 65 planks, 58 ingots, 40 plates, 22 venison | Workbench L2, Scrap doorway and first wall | 23 venison, 20 water; 2 clubs, 1 hood, 4 dressings |
| 4 | 15: 8 Rockfall, 4 Pine Hollow, 3 Greenvein Bluffs | 246 | 263 ironstone, 194 stone, 165 scrap, 113 timber, 32 venison, 4 springs | 83 planks, 32 blocks, 28 venison, 12 plates | Last Scrap walls and windows (**Scrap tier done**, day 4 evening), 5 Timber foundations for the 4×4 | 22 venison, 20 water; 2 Scrapblades, 1 club, 1 hood, 6 dressings |
| 7 | 11: 4 Ashfall Depot, 6 Deepcut Pit, 1 Pine Hollow | 330 | 14 springs, 5 gears, 3 trigger groups, 5 pipes, 13 malachite, 20 niter | 78 blocks, 36 plates, 40 rivets, 2 copper wire | Black tower | 24 tins, 17 water, 4 stews, 3 venison; 2 hoods, 1 vest, 15 dressings; **10 runs ended with the blade broken** |
| 10 | 11: 5 Bracken Edge, 2 Ironbark Stand, 2 Gloaming Deep, 2 Ashfall Depot | 251 | 623 timber, 157 ironbark logs, 212 scrap, 46 fatwood | 91 embercoal, 67 plates, 65 ingots, 31 Ironbark Planks, 16 powder | Ammo Press, second Saw Bench L2, Reinforced doorway and 2 walls | 20 venison, 20 water, 2 stews; 2 Scrapblades, 1 hood, 1 vest, 9 dressings; **1 Pipe Pistol, 45 shots** |
| 13 | 12: 11 Rockfall, 1 Pine Hollow | 180 | 853 stone, 289 scrap, 175 ironstone, 360 timber | 85 embercoal, 16 venison, 12 water | Last Reinforced window (**Reinforced tier done**, day 13 morning) | 23 venison, 21 water; 2 Scrapblades, 1 hood, 1 vest, 4 dressings |

**Shape of the grind (Inference):**
- **Days 1–2:** fast and varied, with hunting runs to Pine Hollow mixed in.
- **Days 3–5:** Workbench-bound. Players log in to refill the plate queue (6 h 40 m per load), while the same benches turn out blades, vests and dressings.
- **Days 6–9:** Black-fog parts hunting, where guns and blades break fastest.
- **Days 9–13:** an ironbark slog in the forest with the benches running overnight.

That matches the LDoE pattern of layered fan-in plus station throttles (econ doc §7.5), with LDoE's constant upkeep on top.

**XP curve (`Data/Levels`, rescaled):**
- Levels 1–5 are unchanged so the hook still lands.
- From level 6 the curve follows the model's XP with sinks on: about 15–19k on day 1, then 10–20k a day.
- Level 8 (Dense) arrives on day 2 and level 15 (Black) about day 7.
- Level 20 lands at 115,000, the current curve's 115,200.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Total XP | 0 | 600 | 1,500 | 2,800 | 4,500 | **7,000** | **11,000** | **16,000** | **21,000** | **26,000** |

| Level | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|
| Total XP | **32,000** | **38,000** | **44,000** | **50,000** | **57,000** | **66,000** | **76,000** | **88,000** | **101,000** | **115,000** |

**Level rewards** stay as they are, on the same levels.

LDoE has no published XP curve (econ doc §6). Its legacy unlock spacing put iron tools at about L14 and the Workbench at L28; ours unlocks through quests.

### 9.4 Milestones past v0.1 (analytic, to be confirmed when the content ships)

**Standard firearms and armor (M2), from the reference player's day-13 state:**
- **Needs:** 21 Ember Steel (§4.2), which means 21 Tin Ingots (84 tinstone, about 3 Deepcut Pit runs) and 21 Copper Ingots (105 malachite).
- **Smelter time:** 42 smelter-hours, fuel-limited at about 3.5 ingots per refill. That is about 2 days with two Smelters.
- **Forge time:** 31.5 forge-hours on the single Forge, about 1.5 days at 20 batches per load.
- **Workbench time:** 31.5 hours of Ember Steel plates, overlapping the forge.
- **Plus:** about 3 Trigger Groups, from Depot and band 3.
- **Sinks:** gun and Plated-armor wear starts the moment the set exists, so the milestone counts the first set. Keeping it running costs about 1 Trigger Group and 1–2 Ember Steel plates a day (§8.5).
- **Result:** **day 17–19**, inside "weeks 2–3". A second Forge from the shop roughly halves the forge leg.

**First vehicle (M4):**
- The Projects hauler checklist is far too cheap for "weeks 4–6": 20 plate, 16 rivets, 6 springs, 4 gears, a motor and 10 cord.
- **When M4 ships, it becomes:** 40 ember steel plate, 30 solder, 20 coil spring, 12 brass gear, 6 seized motor, 60 copper wire, 40 gloamwood plank, plus 2 Hauler Wheels and 1 Drive Chain. The wheels and chain are unique Vault and Black-strongbox drops at about 1 per 4 Depot clears.
- **Bottleneck:** the uniques, about 12 Depot clears or 12+ days, plus about 6 days of steel. That puts the hauler at **about day 30–40**.
- This is LDoE's Chopper pattern: common parts plus rare uniques (econ doc §4.6).

### 9.5 The paying player

GAME_DESIGN's target is hours per tier for a paying player (days 2–3 for Reinforced). Every throttle above has its shop valve:
- Fill-up at the moment of need, on plates, Ironbark Planks and Copper Wire.
- Speed-ups priced by time left.
- "+1 Workbench", "+1 Forge" and Recycler capacity packs.
- Energy refills and Rations.
- The Pack Expansion.

**Inference:**
- Buying the Reinforced tier's 265 plates, 119 Ironbark Planks and 36 wire through Fill-up removes the 123 Workbench hours and the 595-log slog.
- What remains is about 2 days (level 15 and the Plans), which matches GAME_DESIGN's paying column.
- The §8.6 packs remove the upkeep: weapons, armor, food, water, ammo.
- The S3 shop sim prices all of it. This file proposes pack contents (§8.6) but sets no prices.

---

## 10. v0.1 subset

**Scope rule:**
- **Ships in v0.1:** two wood tiers, two ore tiers on top of Fieldstone, and the forge chain to plates and rivets.
- **Gloamwood and Tinstone** are absent from v0.1. The validator would fail a node no tool can harvest, and Ember Steel can't exist without tin.
- **Art:** every new node needs a model graded A (checklist §0).

### 10.1 In v0.1

| Kind | Items |
|---|---|
| **New items (10)** | `item.ironbark_log`, `item.ironbark_plank`, `item.ironstone`, `item.iron_ingot`, `item.malachite`, `item.copper_ingot`, `item.copper_wire`, `item.embercoal`, `item.forged_hatchet`, `item.forged_pick` (each needs an icon) |
| **Changed items** | Durability per §8.1: stone tools 40, Spiked Club 80, Scrapblade 80, Shortbow 40, Padded Hood 80, Padded Vest 100; with Fog Runs, Machete 70, Fire Axe 50, Pipe Pistol 50, Scrap Shotgun 30, Flare Pistol 24. Descriptions of Hewn Plank and Scrap Plate |
| **Sinks (§8)** | Recipe changes: Shortbow 2 glue; +1 glue on Scrapblade, Machete and Padded Vest; Field Dressing 5 cloth. Ammo: Blackpowder 2 niter → 1; Light Rounds → 4 and Scrap Shells → 3, both moved to hand recipes. Emberberry Bush 3 per hit. Food and water thinned in loot (§7.4). Campfire food lines sort first. Heavy swings cost 2 durability, and guns 1 per round fired |
| **New nodes (3 models)** | `node.ironbark_tree`, `node.ironstone_rock`, `node.malachite_vein` |
| **Changed nodes** | Pine hits 4 → 3; Boulder hits 5 → 3 |
| **New recipes (8)** | `recipe.ironbark_plank`, `recipe.iron_ingot`, `recipe.iron_ingot_from_scrap`, `recipe.copper_ingot`, `recipe.copper_wire`, `recipe.embercoal`, `recipe.forged_hatchet`, `recipe.forged_pick` |
| **Changed recipes** | `recipe.plank` (2 → 1); `recipe.stone_block` (3 → 1, 5 m, back on the Stonecutter); `recipe.scrap_plate` (1 iron ingot → 1, 20 m, at the Workbench) |
| **Stations: all six, Smelter and Stonecutter required at launch** | Campfire, Saw Bench, Stonecutter, Smelter, Workbench, Recycler (+ Ammo Press with Fog Runs). Changed costs and levels per §3 |
| **Build pieces** | Scrap and Reinforced costs per §5.2; Stonecutter and Workbench build costs per §3 |
| **Locations (6 new maps + 3 POIs + 2 existing events)** | Bracken Edge, Ironbark Stand, Gloaming Deep, Rockfall Slope, Greenvein Bluffs, Deepcut Pit; the POI changes for Pine Hollow, Rustwater and Ashfall Depot; Stranded Caravan and Supply Drop unchanged |
| **Loot tables (9 new + 7 changed)** | `loot.zone_pack_t1..t3`, `loot.forest_crate_t1..t3`, `loot.mine_box_t1..t3`; the §7.4 changes |
| **Quests (3 new)** | 11 `quest.heartwood`, 12 `quest.green_vein`, 13 `quest.into_the_black` (§11.2) |
| **Levels** | The §9.3 curve |
| **Tuning** | `hollowTierScale`; fuel entries for Embercoal and Ironbark Log; `runs.personalNodes = true`; daily location quests |

**Why the Smelter and Stonecutter are now launch requirements:**
- MVP_LAUNCH lets both fall back to the Workbench if their models miss.
- The Smelter is now fuelled and holds the whole ore → ingot step; the Workbench fallback has no fuel and would erase the fuel economy.
- Their models are on the art list (DECISIONS, Higgsfield allocation).
- **If a model still misses:** iron and copper ingots fall back to the **Campfire** (fuelled, slot 20), and stone blocks to the Workbench. The pacing test runs both layouts.

### 10.2 Deferred

> The standard and advanced firearms listed under M2 below are now **v0.1** per [ARSENAL.md](ARSENAL.md). The Combat Shotgun stays M2 (ARSENAL §0).

**M2 (with raids and the standard firearms):**
- Gloamwood (node, log, plank, the Saw Bench L3 line).
- Tinstone (node, Tin Ingot, Tin Sheet, Solder).
- The Ember Forge, with a **multi-input converter** (Converter and validator change), Ember Steel and Ember Steel Plate.
- The Felling Saw and Ember Pick.
- Service Revolver, Pump Shotgun, Hunting Rifle and the Plated set.
- Ironbound Trunk, and Gloaming Deep's gloamwood and Deepcut Pit's tinstone placements.

**M2 sinks:**
- The Smoke Rack (LDoE's Meat Dryer: raw meat → jerky in 10 m, no fuel), which relieves the Campfire.

**S3 (the shop):**
- The §8.6 packs (Blade Bundle, Gunsmith's Kit, Ammo Box, Armorer's Bundle, Field Provisions, Medic's Satchel) and their moment-of-need triggers.
- The Rain Catcher.
- The VIP free repair.

**M3:**
- The Fortified 4th build tier on Ember Steel.
- Ember Forge L2.
- The Mender's Bench (late repair, §8.2).

**M4:**
- Hauler checklist v2, Hauler Wheel and Drive Chain uniques.

**With each:** the pacing test gains the matching milestone assertion (§11.4).

---

## 11. Implementation notes

### 11.1 Data files that change

| File | Change |
|---|---|
| `Data/Items.luau` | 10 new items (§10.1), plus the M2 items behind `feature` flags once their recipes exist. **Durability per §8.1** for every tool, weapon and armor piece. Descriptions. Fuel items need no item change |
| `Data/Nodes.luau` | 3 new nodes. Pine hits 3; Boulder hits 3; `yieldEvery` on Ironbark (2) and Malachite (3). XP per hit: Pine, Boulder and Ironstone 10; Ironbark 5; Malachite 4 (about 10 XP per unit). Respawn for new nodes is 6 m (Ironbark), 5 m (Ironstone) and 8 m (Malachite); it is unused in lobbies (personal, no regrow). **Emberberry Bush 3 per hit** |
| `Data/Recipes.luau` | New and changed recipes per §2.1 and §4.1. **Delete the v0.1 constants** `STONE_STATION` and `PLATE_STATION`: stone blocks go back to `station.stonecutter`, and `recipe.scrap_plate` is a Workbench recipe by design. Unlock gates per §2.1. **Sinks (§8.2, §8.3):** the glue additions; Field Dressing 5 cloth; `recipe.blackpowder` 2 → 1. `recipe.light_rounds` (→ 4), `recipe.shells` (→ 3) and `recipe.flare` become hand recipes (`stationId = nil`), because the converter rule rejects their current multi-input station form |
| `Data/Stations.luau` | Saw Bench display name. Level costs per §3. Fuel list adds `item.embercoal` (320 s) and `item.ironbark_log` (120 s). Recycler salvage per §3.1 |
| `Data/BuildPieces.luau` | Scrap and Reinforced costs per §5.2; Stonecutter and Workbench build costs |
| `Data/Locations.luau` | 6 new locations per §6.2 (nodes, containers, spawns, `run` blocks, mainLoot and possibleLoot, daily quests); POI changes per §6.3 |
| `Data/LootTables.luau` | 9 new tables, 7 changed (§7, including the food and water thinning) |
| `Data/Quests.luau` | 3 new quests (§11.2) |
| `Data/Levels.luau` | The §9.3 curve |
| `Data/Tuning.luau` | `hollowTierScale = { health = {1, 1.2, 1.4}, damage = {1, 1.15, 1.3} }`; `runs = { personalNodes = true, nodesRegrow = false }`; `locationQuests = { period = "daily" }`. `combat.heavyDurabilityPerHit = 2`; `combat.gunDurabilityPerShot = 1` (per round fired, hit or miss); `combat.durabilityWarn = { 0.25, 0.10 }` |
| Campfire converter UI | Food lines (cooked meat, boiled water, roasted ashroot, tea) sort above Embercoal and Pitch Glue in ALL RECIPES (§8.4) |
| `Data/Enemies.luau`, `Products.luau`, `Projects.luau` | unchanged in v0.1. The §8.6 packs land in Products with the S3 shop; Projects v2 in M4 |
| `Types.luau` | `ResourceNodeDef.yieldEvery: number?` (default 1). `ToolStats.tier` up to 3. `TuningDef` fields above. M2: `RecipeDef.inputs` may hold up to 3 stacks on a station flagged `multiInput` |
| `Domain/Gathering.luau` | Grant `yields` only on hits where `(def.hits - hitsLeft + 1) % yieldEvery == 0`; XP stays per hit |
| `Domain/DataValidator.luau` | (a) A node's `hits` must be a multiple of `yieldEvery`. (b) Map node markers equal data counts. (c) Station recipes keep "one input → one output", except M2 multi-input stations. (d) Every station level's upgrade cost uses only items craftable below that level (the no-circularity rule, §3) |
| Run-server Gathering (`server/Services/Gathering` in the run role) | Per-player node state in lobbies (§1). Clients hide nodes the local player depleted. The server checks the requesting player's own copy |

### 11.2 The three new Ember Trail quests

All three are in chapter "Into the Fog".

| # | ID | After | Objectives | Rewards | Unlocks |
|---|---|---|---|---|---|
| 11 | `quest.heartwood` | the_dense_fog | craft the Forged Hatchet; gather 10 Ironbark Logs (*fogRuns*) | 600 XP, 4 pitch glue | `recipe.ironbark_plank` |
| 12 | `quest.green_vein` | the_dense_fog | craft the Forged Pick; gather 6 Malachite (*fogRuns*) | 600 XP, 10 embercoal | `recipe.copper_ingot`, `recipe.copper_wire` |
| 13 | `quest.into_the_black` | green_vein | reach level 15; travel to any Black location (*fogRuns*) | 1,000 XP, 2 coil springs | — (the Plans are found) |

**Quest 10, `quest.the_dense_fog`, also unlocks** `recipe.forged_hatchet` and `recipe.forged_pick`, as LDoE's "Limestone Cliffs" quest unlocks the iron tools (econ doc §4.7).

**Other unlocks:**
- Quest 6, "Into the Fog", unlocks `recipe.iron_ingot` and `recipe.iron_ingot_from_scrap`, alongside `recipe.scrap_plate`.
- Quest 5, "Keep the Fire", unlocks `recipe.embercoal`.

### 11.3 ID scheme and migration

**IDs:**
- **Kept:** every existing ID, including `loc.sunken_quarry` for Rustwater and `station.woodworking_bench` for the Saw Bench.
- **New IDs follow the existing patterns:**
  - `item.<snake>`, `node.<snake>`, `station.<snake>`, `loc.<snake>`, `quest.<snake>`.
  - `recipe.<output>`; an alternative input is `recipe.<output>_from_<input>`.
  - `loot.<biome>_<container>_t<tier>`; `loot.zone_*` is shared by both biomes.

**Migrations** (each with a Lune test that a pre-migration fixture comes out valid):
- **PlayerSchema v7 → v8:**
  - Any saved station whose loaded input no longer matches its line's recipe input is settled into the inbox, using the v7 rule: the finished batches as outputs, the input and fuel returned. The `recipe.scrap_plate` line held scrap and now takes ingots.
  - Stack counts never change.
  - Any item whose durability is above its new maximum is clamped to it: every §8.1 change, such as a Pipe Pistol at 120 of 140 becoming 50 of 50. It is a one-time loss for pre-launch test saves only.
- **OutpostSchema v2 → v3:** home node saves (`nodes`) with `hitsLeft` above the node's new `hits` are clamped (pine to 3, boulder to 3). Depleted nodes stay depleted.
- **No migration:**
  - Build pieces keep their tier. Refunds use current costs, which is accepted: the 30 s full refund and the 50% late refund are unchanged.
  - New items, nodes and locations are additive.
  - The quest chain gains entries after quest 10. Saves that already finished quest 10 see quests 11 and 12 open.

### 11.4 The Lune pacing simulation

- **Files:** `roblox/src/shared/Domain/PacingSim.luau` (pure, reads `Data`) and `roblox/tests/Pacing.spec.luau`.
- **Determinism:** expected values, no RNG, so it is deterministic and fast (well under a second for 18 simulated days at one-minute station ticks).
- **The model:** exactly §9.1's assumptions, written as parameters in the spec file, not hard-coded in the domain.
  - **Clock:** minute ticks.
  - **Sessions:** a list of (start, minutes).
  - **Energy:** from `Tuning.energy`.
  - **Runs:** `plan(location)` returns the expected haul, XP and minutes given the bag and the node, container and enemy data.
  - **Loot:** expected values come from `Data/LootTables` through a `Domain/Loot.expected(tableId)` helper (new, pure). Band and contested multipliers are parameters.
  - **Stations:** `Domain/Converter` itself, so slot caps, fuel and output caps are the real code paths.
  - **Building:** `Domain/Grid` costs.
  - **XP:** `Data/Levels`.
  - **Sinks:** as §8.7 lists them. Meters drain from `Tuning.survival`, and food values come from `Item.consume`. Durability comes from item data and §8.1's per-run uses; re-craft costs come from `Data/Recipes`.
- **Stock rule:** fractional expected stock is floored whenever the player checks "have", so a 0.97 Trigger Group does not build a gun.
- **Run-choice policy:** as in §9.1, with the weights as parameters: material value table, XP weight 0.015 (0.03 while a level gate blocks the next tier), Energy weight 0.5 minutes per point, demand floor 6 units.
- **Milestones**, as goal lists of build pieces, crafts and flags (Plans, towers):

| Milestone | Goal list |
|---|---|
| hook | satchel, Campfire, 2 Timber foundations, 2 Timber walls, Saw Bench, Stonecutter, Workbench, and level 5 |
| timber | the 3×3 room, 2 crates, the second Campfire, Saw Bench and Smelter, the Spiked Club |
| scrap | the room at Scrap, Workbench L2, Recycler, Dense tower, Pipe Pistol, the second Workbench and Stonecutter |
| reinforced | expand to 4×4, Saw Bench L2 ×2, Smelter L2, Black tower, every piece at Reinforced, and the Plans |

**Assertions** (days are 1-based; "day 4.4" is day 4 at about 10:00):

| Case | Hook | Timber | Dense open | Scrap | Black open | Reinforced |
|---|---|---|---|---|---|---|
| **2.5 h (2 × 75 min)** | ≤ 60 play-min | ≤ end of day 1 | ≤ day 3.5 | in [day 3.0, day 5.99] | in [day 5.0, day 8.0] | in [day 10.0, day 14.99] |
| 2 h (2 × 60) | — | ≤ end of day 1 | — | ≤ day 6.5 | — | ≤ day 15.99 |
| 3 h (2 × 90) | — | — | — | ≥ day 3.0 | — | ≥ day 10.0 |

**Sink assertions** (2.5 h case; §8.7): 0 starving minutes; food time ≤ 15% of run time; at least 10% of runs end with a broken weapon; a Pipe Pistol lasts at most 4 Black runs; at least one Scrapblade re-craft per day once the Scrap tier is done.

**Invariant checks** (cheap, data-only, same spec file):
- Every refinement ratio is LDoE's or harsher. The spec embeds the LDoE reference table from §2.1: input-per-output ≥ LDoE's, and the timer ≥ LDoE's.
- Home stock covers the hook but is below the Timber base: 60 timber against 221 needed.
- One stone tool returns at least 10× its cost.
- Every station level's upgrade cost is craftable before that level exists.
- Each tier-2 node is harvestable only by a tier-2 tool, and the tier-2 tool is craftable from tier-1 materials.

**Existing tests to update:**
- `Economy.spec.luau`'s hook check now counts 54 timber for the hook (plus the 10 from "Claim the Ground").
- The `CONTENT_MVP` home timber figure (about 80) becomes 60.
- Any data test pinned to the old plank (1:1) or stone block (2:1) ratios, the old durability values or the old ammo yields.

**DevSpeed** (Studio only) is unchanged. It compresses timers, not ratios, so playtests see the real ratios faster.

---

## 12. Conflicts in the sources

| Topic | Source A | Source B | Used here |
|---|---|---|---|
| Logs per pine | Pine Bushes: 27 trees = 51 logs ([zone page](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood)) | 3 logs per tree ([Pine Tree](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Tree), [Home](https://last-day-on-earth-survival.fandom.com/wiki/Home)) | 3 per tree |
| Oak hits | 4 hits, 2 logs ([Oak Tree](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Tree)) | 8 hits for 2 logs ([Oak Clearing](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Clearing)); the [Iron Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Hatchet) page's "9 oak trees" for 75 durability implies 8 | 4 hits, 2 logs (one per 2 hits) |
| Copper rock | infobox: 10 hits, 1 ore | text: 5 hits, 1–3 ore ([Copper Rock](https://last-day-on-earth-survival.fandom.com/wiki/Copper_Rock)) | 6 hits, 2 malachite |
| Ash plank | 8 logs, 1 h ([Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench), [Ash Log](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Log)) | 5 logs, 30 m ([Ash Plank](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Plank)); bench history "1 → 5 in 1.15" | 8 logs, 1 h (the harsher) |
| Ash tree hits | "???" ([Ash Tree](https://last-day-on-earth-survival.fandom.com/wiki/Ash_Tree)) | Iron Hatchet page implies 8 for oak or ash | 6 hits, 2 logs |
| Log burn time | 2 m ([Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace), [Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire)) | 1 m 20 s ([Fuel](https://last-day-on-earth-survival.fandom.com/wiki/Fuel)) | 2 m |
| Stonecutter cost | 10 plank, 5 iron bar, 5 scrap (Blueprints, econ doc §3.1) | 20 plank, 10 iron bar, 5 scrap, legacy L14 ([Stonecutter's Table](https://last-day-on-earth-survival.fandom.com/wiki/Stonecutter%27s_Table)) | ours is early-game: 8 timber, 10 stone, 2 cord |
| Kill XP | Roaming Zombie 50, Fast Biter 100, Spitter 150, Bloater 250 (creature pages) | Crowd zombie 10 (econ doc §6) | ours unchanged (10 / 25 / 30); the XP curve is fitted to them |
| Iron rock bauxite | removed 1.30.1 ([Iron Rock](https://last-day-on-earth-survival.fandom.com/wiki/Iron_Rock)) | "removed in 1.30" ([Limestone zones](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires)); GameSkinny (2019) still says Spires iron drops bauxite ([GameSkinny](https://www.gameskinny.com/98d10/how-to-get-aluminum-in-last-day-on-earth-survival)) | Tinstone is its own node |
| When aluminium unlocks | furnace blueprint at level 6 ([GameSkinny](https://www.gameskinny.com/98d10/how-to-get-aluminum-in-last-day-on-earth-survival)) | aluminium bars from level 34 ([Giga](https://www.giga.de/spiele/last-day-on-earth-survival/tipps/last-day-on-earth-survival-bauxit-finden-und-aluminiumbarren-herstellen/)) | both are legacy craft-point values; recipes now unlock by quest (econ doc §4) |
| Red-zone Energy | Spires 33 now | 33 → 35 in 1.11.8, later back to 33 (zone page trivia) | 33 |
| Fan guides | [AppGamer Melting Furnace guide](https://www.appgamer.com/last-day-on-earth-survival/strategy-guide/what-can-i-make-using-the-melting-furnace) confirms 5 copper ore → 1 bar | Most fan guides predate 2021 and contradict current recipes | wiki first; guides only as corroboration |

**Gaps:** no source gives Ash tree hits, LDoE's XP-per-level table or current Oak Bushes node counts after 1.30.1. The Oak Bushes counts used here are the page's own and may be stale. Each gap above is filled with a stated decision, never an invented "LDoE number".
