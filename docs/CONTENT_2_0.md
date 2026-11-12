# Content 2.0: past the Scrap tier (batch 4 spec)

Days 10 to 30 for a free player at 2.5 h a day, modelled on LDoE's mid-game (rec5's Survivor's Path "Radiation Protection" chapter, rec9's clothing tiers, helmets, masks, Military Backpack, bandage and first-aid kit). Flow review F-24 (nothing past Scrap, the trail ends) and F-37 (one craftable bag). Everything is behind **`Tuning.features.content2`**, on since batch 4b's Studio pass graded its models: if it is switched off, `Features.strip` removes every tagged recipe, station, build piece, quest and loot row, and the tagged items stay dormant (nothing gives them). `tests/Content2.spec` proves both states.

## 1. What the player chases (2.5 h a day, `tests/Pacing.spec`)

| Days | Chase | Gate |
|---|---|---|
| 5-10 | Field Knife, Hand Axe, Hide Rucksack (+8, about day 9), Steel Helmet | quests 9, 11, 13, 19 |
| 11-16 | Hidebound set (consumes Padded), Trauma Pouch | quest 21 |
| 13-18 | Riveted set (consumes Hidebound), the Blast Furnace and Steel Plate | quests 23, 25 |
| 18-25 | **Fortified tier** (done about day 25), Ranger Pack (+15), Gas Mask, Apothecary | chapter 4 |
| 25-28 | The Deep Black, then the level cap | quest 33 |
| any | Black jackpots: Combat Helmet, Plate Carrier, Ember Stim, Ranger Pack | Depot strongbox |

## 2. Base: the Fortified tier (tier 4) and two stations

LDoE's L4 Metal tier, on materials we already have plus **Steel Plate** (LDoE's Steel Bar). Pieces upgrade from Reinforced; HP doubles again; nothing is unbreachable. Floors unlock at quest 26, walls and doors at 28.

| Piece | Upgrade cost | HP | Breach |
|---|---|---|---|
| Foundation | 6 steel plate, 6 stone block, 4 rivets | 4,800 | 12 |
| Wall, Window wall | 6 steel plate, 4 ironbark plank, 4 rivets, 2 copper wire | 3,200 / 2,800 | 6 / 5 |
| Doorway | 5 steel plate, 4 ironbark plank, 4 rivets, 2 copper wire | 2,800 | 6 |
| Door | 8 steel plate, 6 rivets, 4 copper wire, 2 coil spring | 2,400 | 5 |

- **Blast Furnace** (LDoE's Refined Melting Furnace): 2 Iron Ingots → 1 Steel Plate in 20 min, burns like the Smelter, 2 per plot. Needs a **Reinforced floor**. Build: 20 stone block, 8 plate, 6 rivets, 4 copper wire, 1 brass gear. Unlocked by quest 25.
- **Apothecary** (LDoE's Chemistry Station): 4 Emberberries → 1 Antiseptic Tablets in 10 min. Needs a **Fortified floor**. Build: 4 steel plate, 6 ironbark plank, 4 copper wire, 4 cloth. Unlocked by quest 30.
- A whole Fortified room (the Reinforced 4×4) is about 190 Steel Plate: 380 Iron Ingots and 63 furnace-hours.

## 3. Ember Trail chapter 4, "Iron Lungs" (quests 26-33)

Opens after Hold the Line (25), two lines side by side like chapter 3. Each build objective unlocks with the quest before it. Days are the 2.5 h model's.

| # | Quest | Asks | Pays | Day |
|---|---|---|---|---|
| 26 | Hotter Fires | the Blast Furnace, 6 Steel Plate batches | 20 embercoal, 8 rivets | 18.3 |
| 27 | Hide and Rivet | craft and wear the Riveted Cuirass and Legguards | 6 leather, 6 cloth | 17.8 |
| 28 | Steel Underfoot | 4 Fortified foundations | 6 copper wire, 8 rivets | 18.8 |
| 29 | Pack Mule | craft and wear the Ranger Pack, 10 Depot crates | 10 embercoal, 4 glue | 18.4 |
| 30 | The Last Wall | 8 Fortified walls and a Fortified door | 4 cloth, 4 copper wire | 22.3 |
| 31 | Breathe Easy | craft and wear the Gas Mask, 200 Hollow in Black fog | 2 First-Aid Kits, 1 tonic | 24.8 |
| 32 | A Clean Room | the Apothecary, 4 Antiseptic batches, 2 First-Aid Kits | 3 brass gear, 2 coil spring, 5 dressings | 22.4 |
| 33 | The Deep Black | 30 Depot crates, 300 more Hollow, level 28 | 2 trigger groups, 3 brass gear | 27.8 |

## 4. Items (23 new)

**Melee (ARSENAL §4, exact):** Hand Axe (20 dmg, 1.4/s, 70; crafted, quest 11; `structureMultiplier` 1.5 for M2), Hardwood Bat (18, 1.0/s, 80; loot), Field Knife (11, 2.0/s, 120, backstab ×4, noise 6; crafted, quest 9), Hay Fork (16, 0.9/s, reach 8.5, 60; loot). From the parked melee WIP we keep the design, not the code: each weapon names its animation class (`melee.class`: blade, axe, pick, blunt, heavy, stab, fists), each class a 2-3 swing combo plus a heavy; the clips and timing wait for batch 1.

**Armor levels (ARSENAL §5, exact):** L1 Reedweave, L2 Padded, **L3 Hidebound** (21 defence, 0.55 fog; consumes Padded; quest 21), **L4 Riveted** (28, 0.67; consumes Hidebound; quest 23), the **Plate Carrier** (body 12, fog 0.08; Black loot). **Helmets** trade fog for defence: Steel Helmet (5, 0.04; quest 19 and loot), Combat Helmet (7, 0.06; Depot strongbox).

**Gas Mask:** head slot, defence 1, fog resist 0.35, a **900-second filter** that wears 1 a second in Dense or Black fog (`FogExposure.filterWear`): about one Black run, then re-crafted (2 leather, 2 cloth, 1 copper wire, 4 embercoal, 1 glue; quest 29). Black fog fills the meter in 4 min bare; with the mask and Padded 13.3, Hidebound 18.2, Riveted 20 (the 0.8 cap). **For the economy batch:** that cap now binds, so a geared player stops taking Black-fog damage; consider 0.75.

**Bags (F-37):** Satchel +5 → **Hide Rucksack +8** (4 leather, 3 rope, 2 cloth; quest 13: at quest 9 the model's Reinforced fell under its band) → Pack Frame +10 → **Ranger Pack +15** (consumes the Pack Frame; 6 leather, 4 cloth, 4 plate, 4 rivets; quest 27). `maxBackpackSlots` 15 → 20.

**Meds** (instant, then over time, `Domain/Meds`, 3 at once): Field Dressing 40 → **Trauma Pouch** 25 + 40/10 s (quest 21) → **First-Aid Kit** 40 + 60/12 s (quest 30) → **Ember Stim** 60 + 50/5 s (strongbox). **Materials:** Steel Plate, Antiseptic Tablets (also rare loot).

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
| `depot_strongbox` (Black) | Riveted Helm 1, Combat Helmet 1, Plate Carrier 1, Ranger Pack 1, Ember Stim 2 (all `rarity = "rare"` here, so the blueprint pity keeps its meaning) |

## 6. Pacing

`tests/Pacing.spec` models it: the rucksack from quest 13, the Ranger Pack from 29, a Gas Mask re-made when a Black run spends its filter, chapter 4, and a Fortified goal (the Reinforced room, two furnaces, the Apothecary) that waits for the trail. Every existing band stays green on 21 days. On 30 days at 2.5 h a day chapter 4 runs from day 17.8 to 27.8 with no gap over 4 days and Fortified lands on day 24.8; at 3 h it ends on 23.8; at 2 h, 7 of 8 by day 30. Loot-only and side-grade items are listed as extras; a spec keeps the list complete.

## 7. Models and icons (batch 4b's Studio pass)

What ships, graded in the lineup beside the survivor and the approved kit (`docs/milestones/m1-launch` C21-C31). Every icon is the model itself (`Art.items`, rendered by ItemIcon); body, legs and feet armor tint the survivor's clothes as Padded does (`Art.worn`), headwear and bags sit on the body as models (`Art.wornModels`).

| Item | Model | Source | Licence | Credit |
|---|---|---|---|---|
| Hand Axe, Hardwood Bat, Field Knife, Hay Fork | `EO_HandAxe`, `EO_HardwoodBat`, `EO_FieldKnife`, `EO_HayFork` | Studio mesh generator | ours | - |
| Hidebound Cap, Coat, Leggings, Boots | `EO_Hidebound*` | Studio mesh generator | ours | - |
| Riveted Helm, Cuirass, Legguards, Boots | `EO_Riveted*` | Studio mesh generator | ours | - |
| Hide Rucksack | `EO_HideRucksack` | Studio mesh generator | ours | - |
| Steel Plate, Antiseptic Tablets | `EO_SteelPlate`, `EO_AntisepticBottle` | Studio mesh generator | ours | - |
| Blast Furnace, Apothecary | `EO_BlastFurnace`, `EO_Apothecary` | Studio mesh generator | ours | - |
| Fortified tier (5 pieces) | `EO_Deck_Fortified` MaterialVariant on the exact geometry | Studio material generator | ours | - |
| Gas Mask | `gear/old_gas_mask.glb` | Zona | CC0 | Poly Haven "Old Gas Mask", Michał Wiśniewski |
| Steel Helmet | `gear/helmet_m1.glb` | Zona | CC-BY 4.0 | "M1 Helmet", Melvin Stubbe |
| Combat Helmet | `gear/helmet_k63.glb` | Zona | CC-BY 4.0 | "Combat helmet K6-3", shamanoff |
| Plate Carrier | `gear/plate_carrier.glb` (icon; worn as a tint) | Zona | CC-BY 4.0 | "Tactical Plate Carrier Vest - Game Ready", Exactly |
| Ranger Pack | `gear/military_backpack.glb` (olive tint) | Zona | CC-BY 4.0 | "Military Backpack", Neslihan Çakmak |
| Trauma Pouch | `meds/aid_pouch.glb` | Zona | CC-BY 4.0 | "Tactical FIRST AID KIT", Ruslan Koschey |
| First-Aid Kit | `meds/medical_box.glb` | Zona | CC0 | Poly Haven "Medical Box", Ulan Cabanilla |
| Ember Stim | `meds/syringe.glb` | Zona | CC-BY 4.0 | "Medical syringe healing FPS Animation", BURNER |

Not used: the four `wip-v3` melee files (they are Git LFS pointers in batch 4's approved upload folder, so they couldn't be uploaded from it; Studio generations replaced them), the camping backpack (it read as black nylon, not hide) and the 12-triangle pill box (a blank white card as an icon). Their credits are dropped.

## 8. SKU ideas (not created)

Fortified Starter (Steel Plate ×20, Rivets ×20), Riveted Armor Pack (already in ARSENAL), Medic Crate (First-Aid Kit ×5, Ember Stim ×2), Ranger Loadout (Ranger Pack, Gas Mask ×2, Combat Helmet). No random boxes without odds; nothing that shields a base or stash.
