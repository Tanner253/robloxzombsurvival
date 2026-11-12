# Content 2.0: past the Scrap tier (batch 4 spec)

Days 10 to 30 for a free player at 2.5 h a day, modelled on LDoE's mid-game (rec5's Survivor's Path "Radiation Protection" chapter, rec9's clothing tiers, helmets, masks, Military Backpack, bandage and first-aid kit). Flow review F-24 (nothing past Scrap, the trail ends) and F-37 (one craftable bag). Everything ships behind **`Tuning.features.content2 = false`**: while it is off, `Features.strip` removes every tagged recipe, station, build piece, quest and loot row, and the tagged items stay dormant (nothing gives them). `tests/Content2.spec` proves both states.

## 1. What the player chases

| Days | Chase | Gate |
|---|---|---|
| 5-10 | Hide Rucksack (+8), Field Knife, Hand Axe, Steel Helmet | quests 9, 11, 19 |
| 14-18 | Hidebound set (consumes Padded), Trauma Pouch | quest 21 |
| 17-21 | Riveted set (consumes Hidebound), the Blast Furnace and Steel Plate | quests 23, 25 |
| 19-26 | **Fortified tier**, the Apothecary, Ranger Pack (+15), the Gas Mask | chapter 4, quests 26-31 |
| 24-30 | Fortified walls, the deep Black (60 Depot crates, 1,000 Hollow) | quests 32-33 |
| any | Black jackpots: Combat Helmet, Plate Carrier, Ember Stim, Ranger Pack | Depot strongbox |

## 2. Base: the Fortified tier (tier 4) and two stations

LDoE's L4 Metal tier, on materials we already have plus **Steel Plate** (LDoE's Steel Bar). Pieces upgrade from Reinforced; HP doubles again; nothing is unbreachable.

| Piece | Upgrade cost | HP | Breach |
|---|---|---|---|
| Foundation | 8 steel plate, 6 stone block, 4 rivets | 4,800 | 12 |
| Wall, Window wall | 8 steel plate, 4 ironbark plank, 4 rivets, 2 copper wire | 3,200 / 2,800 | 6 / 5 |
| Doorway | 7 steel plate, 4 ironbark plank, 4 rivets, 2 copper wire | 2,800 | 6 |
| Door | 10 steel plate, 6 rivets, 4 copper wire, 2 coil spring | 2,400 | 5 |

- **Blast Furnace** (LDoE's Refined Melting Furnace): 3 Iron Ingots → 1 Steel Plate in 30 min, burns Embercoal only. Needs a **Reinforced floor**. Build: 20 stone block, 8 plate, 6 rivets, 4 copper wire, 1 brass gear. Unlocked by quest 25.
- **Apothecary** (LDoE's Chemistry Station): 4 Emberberries → 1 Antiseptic Tablets in 10 min. Needs a **Fortified floor**. Build: 6 steel plate, 6 ironbark plank, 4 copper wire, 4 cloth. Unlocked by quest 28.

## 3. Ember Trail chapter 4, "Iron Lungs" (quests 26-33)

Opens after Hold the Line (25), two lines side by side like chapter 3.

| # | Quest | Asks | Pays |
|---|---|---|---|
| 26 | Hotter Fires | build the Blast Furnace, 6 Steel Plate batches | 20 embercoal, 8 rivets |
| 27 | Hide and Rivet | craft and wear the Riveted Cuirass and Legguards | 6 leather, 6 cloth |
| 28 | Steel Underfoot | 4 Fortified foundations | 6 copper wire, 1 brass gear |
| 29 | Pack Mule | craft and wear the Ranger Pack | 10 embercoal, 4 glue |
| 30 | A Clean Room | build the Apothecary, 4 Antiseptic batches, 2 First-Aid Kits | 5 dressings, 4 steel plate |
| 31 | Breathe Easy | craft and wear the Gas Mask, walk into Black fog | 2 First-Aid Kits, 1 tonic |
| 32 | The Last Wall | 8 Fortified walls and a Fortified door | 3 brass gear, 2 coil spring |
| 33 | The Deep Black | 60 Depot crates, 1,000 Hollow, level 28 | 2 trigger groups, 3 brass gear |

## 4. Items (23 new)

**Melee (ARSENAL §4, exact):** Hand Axe (20 dmg, 1.4/s, 70 hits; crafted, quest 11; `structureMultiplier` 1.5 for M2 raids), Hardwood Bat (18, 1.0/s, 80, knockback 2.5; loot), Field Knife (11, 2.0/s, 120, crit 0.2, backstab ×4, noise 6; crafted, quest 9), Hay Fork (16, 0.9/s, reach 8.5, 60; loot). **From the parked melee WIP** (`worktree-agent-a3c75eb84c6644ce1`) we keep its design, not its code: every melee weapon names its animation class (`melee.class`: blade, axe, pick, blunt, heavy, stab, fists; the knife and fork are `stab`, the axe `axe`, the bat `blunt`), and each class gets a 2-3 swing light combo plus a heavy, timed by prep, windup, contact, follow, cycle and length marks. The clips, poses and timing tables wait for the animation worker (batch 1).

**Armor levels (ARSENAL §5, exact):** L1 Reedweave, L2 Padded, **L3 Hidebound** (21 defence, 0.55 fog; each piece consumes its Padded piece; quest 21), **L4 Riveted** (28, 0.67; consumes Hidebound; quest 23), and the **Plate Carrier** (body 12, fog 0.08, 240; Black loot only).

**Helmets:** Steel Helmet (head 5, fog 0.04, 200; crafted from quest 19 and found), Combat Helmet (head 7, fog 0.06, 240; Depot strongbox only). A helmet trades fog resistance for defence against the set caps.

**Gas Mask:** head slot, defence 1, **fog resist 0.35**, and a **filter of 900 seconds**: it loses 1 durability a second in Dense or Black fog (`FogExposure.filterWear`), so it lasts about one full Black run and is re-crafted (2 leather, 2 cloth, 1 copper wire, 4 embercoal, 1 glue; quest 29). Black fog fills an unprotected meter in 4 min; mask plus Padded body pieces 13.3 min, plus Hidebound 18.2 min, plus Riveted the 0.8 cap (20 min, a full run without fog damage).
- **For the economy batch (not retuned here):** with the mask, `maxResist` 0.8 now binds for Hidebound and Riveted wearers, so Black fog stops hurting a geared player. Consider 0.75 (16 min) or a rising `ratePerTier` in band 3.

**Bags (F-37):** Reed Satchel +5 → **Hide Rucksack +8** (4 leather, 3 rope, 2 cloth; quest 9) → Scrap Pack Frame +10 (schematic) → **Ranger Pack +15** (consumes the Pack Frame, plus 6 leather, 4 cloth, 2 steel plate, 2 rivets; quest 27). `maxBackpackSlots` rises from 15 to 20 (the +15 bag and the Pack Expansion).

**Meds ladder** (instant, then healing over time, `Domain/Meds`; up to 3 heal at once): Field Dressing 40 (LDoE's bandage, unchanged) → **Trauma Pouch** 25 + 40 over 10 s (2 dressings, 1 leather, 1 glue; quest 21) → **First-Aid Kit** 40 + 60 over 12 s (2 pouches, 2 Antiseptic Tablets, 1 plate; quest 28) → **Ember Stim** 50 + 50 over 5 s (Depot strongbox; a shop SKU later).

**Materials:** Steel Plate, Antiseptic Tablets (both also rare loot, so neither waits on its station).

## 5. Loot rows (all `feature = "content2"`)

| Table (band) | New rows (weight) |
|---|---|
| `pine_crate` (Light) | Hardwood Bat 3, Hay Fork 4 |
| `zone_pack_t1`, `forest_crate_t1` (Light) | Hardwood Bat 2, 3 |
| `zone_pack_t2` (Dense) | Field Knife 3, Trauma Pouch 2, Antiseptic 2, Hide Rucksack 1 |
| `quarry_locker` (Dense) | Field Knife 2, Steel Helmet 2 |
| `forest_crate_t2`, `forest_crate_t3` | Hand Axe 2, 3 |
| `zone_pack_t3` (Black) | Field Knife 2, Hidebound Cap 3, Hidebound Boots 3, Steel Helmet 2, Trauma Pouch 3, Antiseptic 3 |
| `caravan_wagon` (Dense event) | Hidebound Cap 3, Hidebound Boots 3, Steel Helmet 2, Gas Mask 1, Trauma Pouch 3 |
| `depot_freight` (Black) | Hidebound Coat 2, Gas Mask 1, First-Aid Kit 2, Steel Plate 2 |
| `depot_strongbox` (Black) | Riveted Helm 1, Combat Helmet 1, Plate Carrier 1, Ranger Pack 1, Ember Stim 2 (all `rarity = "rare"` for pity, so the blueprint pity keeps its meaning) |

## 6. Pacing

`tests/Pacing.spec` keeps every existing band on the 21-day model and adds a 30-day run with the content: the Hide Rucksack from quest 9, the Ranger Pack from quest 29, Gas Mask upkeep on Black runs, chapter 4's quests, and a fifth goal (the Fortified tier: 4 foundations, 8 walls, doorway and door, the Blast Furnace and the Apothecary). Asserts: chapter 4 opens within 2 days of quest 25, no gap over 4 days, ends by day 30; the Fortified goal lands in days 22-30. Loot-only items (bat, fork, helmets, Plate Carrier, stims) are extras the model doesn't count; the knife and hand axe don't beat the Scrapblade the model carries.

## 7. Models and icons for the Studio pass (nothing uploaded here)

| Item | File (`art/content2/`) | Licence | Credit |
|---|---|---|---|
| Hand Axe | `melee/hatchet.glb` | CC0 | Poly Haven "Hatchet", James Ray Cock, Ulan Cabanilla |
| Hardwood Bat | `melee/baseball_bat.glb` | CC0 | Poly Haven "Baseball Bat", Enrique Martín |
| Field Knife | `melee/knife_animated.glb` | CC-BY 4.0 | "knife Animated", DJMaesen |
| Hay Fork | `melee/pitchfork.glb` | CC-BY 4.0 | "pitchfork Animated", DJMaesen |
| Gas Mask | `gear/old_gas_mask.glb` | CC0 | Poly Haven "Old Gas Mask", Michał Wiśniewski |
| Steel Helmet | `gear/helmet_m1.glb` | CC-BY 4.0 | "M1 Helmet", Melvin Stubbe |
| Combat Helmet | `gear/helmet_k63.glb` | CC-BY 4.0 | "Combat helmet K6-3", shamanoff |
| Plate Carrier | `gear/plate_carrier.glb` | CC-BY 4.0 | "Tactical Plate Carrier Vest - Game Ready", Exactly |
| Hide Rucksack | `gear/camping_backpack.glb` (at 0.72 scale) | CC-BY 4.0 | "Large Camping BackPack", Sebastian Webster |
| Ranger Pack | `gear/military_backpack.glb` (decimate to ~8k tris) | CC-BY 4.0 | "Military Backpack", Neslihan Çakmak |
| Trauma Pouch | `meds/aid_pouch.glb` | CC-BY 4.0 | "Tactical FIRST AID KIT", Ruslan Koschey |
| First-Aid Kit | `meds/medical_box.glb` | CC0 | Poly Haven "Medical Box", Ulan Cabanilla |
| Ember Stim | `meds/syringe.glb` | CC-BY 4.0 | "Medical syringe healing FPS Animation", BURNER |
| Antiseptic Tablets | `meds/pill_box.glb` | CC-BY 4.0 | "Food Collection - Game Ready" (its pill box), Melon Polygons |

No CC0 or CC-BY Zona model fits the Hidebound and Riveted pieces, Steel Plate, the Fortified pieces, the Blast Furnace or the Apothecary: those need Studio-generated meshes (free Studio MCP, graded side by side against rec9 and rec8). Skipped from Zona on licence: every Higgsfield-made or unlicensed (`?`) model, `heavy_armor` and `combat_helmet` (300k+ triangles).

## 8. SKU ideas (not created)

Fortified Starter (Steel Plate ×20, Rivets ×20), Riveted Armor Pack (already in ARSENAL), Medic Crate (First-Aid Kit ×5, Ember Stim ×2), Ranger Loadout (Ranger Pack, Gas Mask ×2, Combat Helmet). No random boxes without odds; nothing that shields a base or stash.
