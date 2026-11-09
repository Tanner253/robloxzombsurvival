# Arsenal v0.1: guns, melee and armor (binding spec)

**Status:** binding, written 2026-11-08 by the weapons and monetization designer.

**Why this file exists:** the developer said v0.1 has too few guns (Worn Pistol, Scrap Shotgun, Flare Pistol, a bow and a few melee weapons).

**What it does:** it brings v0.1 to **15 guns in 3 tiers** (12 new), **7 Zona melee weapons** (4 new) and **4 armor sets**, each balanced against the Hollow and the pacing model's durability sink. Its companion, [SHOP_CATALOG.md](SHOP_CATALOG.md), sells them.

**Precedence:**
- [LDOE_PARITY.md](LDOE_PARITY.md) and [DECISIONS.md](DECISIONS.md) win over this file.
- This file wins over [ECONOMY.md](ECONOMY.md) §4.2 and over [GAME_DESIGN.md](GAME_DESIGN.md)'s weapon rollout for the guns it lists. ECONOMY's M2 Service Revolver, Pump Shotgun and Hunting Rifle, and its M3 SMG and Carbine, are pulled into v0.1 on v0.1 materials (§3.3). §8.7 lists the doc edits this implies.

**Binding rules carried in:**
- **No ammo** (DECISIONS 2026-11-08). A gun's durability is its shot count, and each shot costs 1 durability, hit or miss (`Tuning.combat.gunDurabilityPerShot`).
  - The magazine and reload stay, as a **pacing beat** only. A reload costs nothing, but it is the window where the Hollow close in.
  - Every `ammoItemId` is removed.
- **Realistic weapons from Zona meshes**, used for weapons only (DECISIONS; MVP_LAUNCH "Assets from the developer's Zona repo").
- **Generic names only:** no brand or model names in names, descriptions or textures (§8.1 covers stamped logos).
- **P2W is accepted.** Packs sell any tier to anyone (DECISIONS 2026-11-08 removed tier-capped weapon packs). A pack never teaches a recipe: crafting still needs the unlock.
- **Every pack is repurchasable;** guns and armor are durability items (MVP_LAUNCH).

**Sources:**
- Our data: `roblox/src/shared/Data/Items.luau`, `Recipes.luau`, `LootTables.luau` and `Products.luau` on `main`.
- The launch branch `claude/m1-launch-home-platform`, for the Reedweave and Padded sets, Tire Iron, Rail Mallet and chapter-3 quests.
- The S2B branch, for UAL clips and the Flare Pistol model.
- Zona's `assets-src/models/*/license.txt`, `_meta.json` and `CREDITS.md`.
- The **LDoE Fandom wiki**, read as raw wikitext through its MediaWiki API on 2026-11-08 (URLs in §7).

**Inference** marks my own analysis.

## 0. Orchestrator rulings (2026-11-08; these override any row below)

These come from the mesh repair and lineup review: every model graded from side and top renders.

1. **Pump Shotgun → `benelli_m3`.** `shotgun_set` turned out to be a single break-action with no textures in the source (grade C), so it's cut.
2. **Combat Shotgun → M2.** With the Benelli now the Pump Shotgun, there's no second grade-A shotgun model. Every Combat Shotgun recipe, schematic, loot row and pack slot waits for M2:
   - In `loot.mine_box_t3`, `item.bp_combat_shotgun` becomes `item.bp_tactical_smg`.
   - In the Heavy Loadout, the Combat Shotgun becomes the Tactical SMG.
   - The v0.1 roster is **14 guns**.
3. **Marksman Rifle → `sniper`** (DJMaesen, CC-BY), as written. **`vssk` is never used:** its Sketchfab Standard licence doesn't fit Roblox, where anyone can download meshes. The VSSK upload (103273183249174) is retired.
4. **Compact Rifle → `9a91`,** as written, with the silencer **stripped** (§8.1 #8). The current upload still has the silencer and must be replaced.
5. **Spares uploaded but not in v0.1:** `aks74u` (83463879353370) and `colt_1911` (87782571500480; CC-BY AlexChuchvaga). They are kept for later variants.

**Uploaded and graded A** (the Roblox asset IDs; all CC-BY unless marked):

| Gun | Kit | Asset ID | Notes |
|---|---|---|---|
| Duty Pistol | `EO_DutyPistol` | 72665632302595 | |
| Hand Cannon | `EO_HandCannon` | 138247092065639 | Paint out the slide stamp (§8.1) |
| Pump Shotgun | `EO_PumpShotgun` | 102438923048838 | `benelli_m3`, no optic and no silencer |
| Hunting Rifle | `EO_HuntingRifle` | 99562708864658 | CC0 |
| Machine Pistol | `EO_MachinePistol` | 109481505500458 | v2: posed, one magazine |
| Patrol Carbine | `EO_PatrolCarbine` | 75563310459171 | Re-check that it's at most 8k triangles |
| Assault Rifle | `EO_AssaultRifle` | 129256241328198 | v2: posed, one magazine |
| Tactical SMG | `EO_TacticalSMG` | 138864024632624 | v2: no red dot, no suppressor |
| Anti-Materiel Rifle | `EO_AntiMaterielRifle` | 93078334956668 | v3: carry handle and monopod removed, bipod folded |
| Compact Rifle | `EO_CompactRifle` | *pending re-extract* | without the silencer |
| Marksman Rifle | `EO_MarksmanRifle` | *pending extract* | `sniper` |

**Orientation of the v2 and v3 GLBs:** muzzle +X, top +Y, right +Z, in metres, centred on the bounding box. Confirm how Roblox maps the axes on import for `Art.held`.

**Dead uploads; never reference them:**
- 87273802704697, 112557069701253, 99838449574262, 124307241329393, 109217049271999, 101143506328630 (v1, broken)
- 107836528763914 (break-action)
- 87043412758876 (Barrett v2)
- 103273183249174 (VSSK)

---

## Contents
1. [The roster at a glance](#1-the-roster-at-a-glance)
2. [Design rules for the ladder](#2-design-rules-for-the-ladder)
3. [Guns](#3-guns)
4. [Melee](#4-melee)
5. [Armor sets](#5-armor-sets)
6. [Balance](#6-balance)
7. [LDoE reference stats](#7-ldoe-reference-stats)
8. [Implementation list](#8-implementation-list)
9. [Risks and open items](#9-risks-and-open-items)

---

## 1. The roster at a glance

| Tier (item `tier`) | Guns (ID) → Zona mesh | When a free player gets it |
|---|---|---|
| **Early, improvised** (2) | Worn Pistol (`item.pipe_pistol`) → `service_pistol`; Scrap Shotgun (`item.scrap_shotgun`) → `sawnoffs`; Flare Pistol (`item.flare_pistol`) → generated model (no Zona match) | Days 3–5 (ECONOMY §9.2: first firearm day 3.8) |
| **Standard, mid-game** (3) | Duty Pistol (`item.duty_pistol`) → `pistol_m9`; Hand Cannon (`item.hand_cannon`) → `desert_eagle`; Pump Shotgun (`item.pump_shotgun`) → `benelli_m3` (§0); Hunting Rifle (`item.hunting_rifle`) → `bolt_action_rifle_7_62`; Machine Pistol (`item.machine_pistol`) → `scorpion` | Quest-unlocked days 7–13, crafted days 8–16 (weeks 2–3, DECISIONS) |
| **Advanced, Black** (4) | Patrol Carbine (`item.patrol_carbine`) → `ar15`; Assault Rifle (`item.assault_rifle`) → `ak74m`; Compact Rifle (`item.compact_rifle`) → `9a91`; Tactical SMG (`item.tactical_smg`) → `mp7a1`; ~~Combat Shotgun~~ (M2, §0); Marksman Rifle (`item.marksman_rifle`) → `sniper` | A schematic from Black loot, then Workbench L3; days 14–21+ |
| **Black jackpot** (4, legendary) | Anti-Materiel Rifle (`item.anti_materiel_rifle`) → `barrett` | Loot only, about 1 per 30–40 Depot clears; or the shop |

**Melee (Zona):**
- Tire Iron → `crowbar_01`
- Rail Mallet → `sledgehammer_01`
- Machete → `machete`
- Hand Axe → `hatchet`
- Hardwood Bat → `baseball_bat`
- Field Knife → `knife_animated`
- Hay Fork → `pitchfork`

**Armor:** Reedweave (T1), Padded (T2), Hidebound (T3) and **Riveted (T4, new)**, with four pieces each.

**Mapped to GAME_DESIGN's ladder slots** ("Combat and the arsenal"):
- Semi-auto Pistol → Duty Pistol.
- Service Revolver → Hand Cannon. Zona has no revolver mesh, so the heavy-handgun slot uses a big-bore semi-auto.
- Pump Shotgun, Hunting Rifle and Marksman Rifle keep their names.
- SMG → Machine Pistol and Tactical SMG.
- Carbine (assault rifle) → Patrol Carbine and Assault Rifle.
- Drum Shotgun → Combat Shotgun.
- New: Compact Rifle and the Anti-Materiel Rifle.

---

## 2. Design rules for the ladder

1. **Each tier roughly doubles damage throughput and halves free sustainability.**
   - Sustained DPS: improvised 24–37, standard 44–61, advanced 61–110, jackpot 155.
   - The melee reference is Scrapblade 31, Machete 35 and Fire Axe 32.
   - LDoE's own ladder is Zip Gun 14 DPS, Glock 66, M16 100, AK 125 (§7).
2. **Durability = shots, sized so every gun lasts 2–4 Black runs** under the §6.5 model. ECONOMY §8.7's sink assertion ("a Pipe Pistol lasts at most 4 Black runs") applies to every gun.
3. **The Trigger Group is the gun bottleneck** (ECONOMY §1.4):
   - Improvised guns need 1–2.
   - Standard guns need 1–2, plus Copper Wire (Workbench L2, Smelter L2).
   - Advanced guns need 3, plus 2–3 Brass Gears.
   - §6.5 shows that a free player can keep one improvised or bolt-action gun running, but not an automatic. That gap is the shop's lever.
4. **Noise is the price of a gun** (GAME_DESIGN).
   - Every gun is louder than melee (10) and the bow (6), except the suppressed Marksman Rifle (55).
   - The Anti-Materiel Rifle (220) wakes the whole map.
5. **No one-shots on players:** `Tuning.combat.pvpMaxHitFraction = 0.6` caps any hit at 60 HP (§6.6).
6. **Advanced guns are loot-gated, like LDoE's.** The AK-47, FN SCAR, Mini Uzi, VSS, Dragunov and Shotgun are all "Craftable: No" on the wiki. Ours need a schematic found in Black fog. The jackpot is never craftable.

---

## 3. Guns

### 3.1 Identity, mesh and licence

**Licences:**
- All CC-BY 4.0 meshes need the exact credit line from their `license.txt` in our `CREDITS.md` and in `Data/Credits.luau` (the in-game Credits panel, a launch requirement).
- CC0 meshes are credited anyway, as Zona does.

| # | Name (ID) | Tier | Anim class | Zona source (`Zona/assets-src/models/…`) | Licence (author) | LDoE counterpart |
|---|---|---|---|---|---|---|
| 1 | **Worn Pistol** (`item.pipe_pistol`, existing) | 2 improvised | pistol | `service_pistol` (already `EO_WornPistol`, id 137577727330156) | CC0, Poly Haven (Mateusz Sadek) | Zip Gun |
| 2 | **Scrap Shotgun** (`item.scrap_shotgun`, existing) | 2 improvised | shotgun | `sawnoffs` (already `EO_ScrapShotgun`, id 72894953650046) | CC-BY 4.0 (DJMaesen) | Handmade Shotgun / sawed-off |
| 3 | **Flare Pistol** (`item.flare_pistol`, existing) | 2 light | pistol | none in Zona. The S2B branch's generated model `EO_FlarePistol` (id 130325429565330) | our Higgsfield art (orchestrator's pool) | Flare Gun |
| 4 | **Duty Pistol** (`item.duty_pistol`) | 3 standard | pistol | `pistol_m9` (already staged: `art/zona/guns/zona_pistol_m9.glb`) | CC-BY 4.0 (DJMaesen, "animated pistol") | Glock 17 |
| 5 | **Hand Cannon** (`item.hand_cannon`) | 3 standard | pistol (heavy recoil) | `desert_eagle` | CC-BY 4.0 (ELIZION) | Colt Python |
| 6 | **Pump Shotgun** (`item.pump_shotgun`) | 3 standard | shotgun | `benelli_m3` (§0) | CC-BY 4.0 (Amapsis) | Shotgun |
| 7 | **Hunting Rifle** (`item.hunting_rifle`) | 3 standard | rifle (bolt) | `bolt_action_rifle_7_62` | CC0, Poly Haven (Mateusz Sadek) | Hunter Rifle |
| 8 | **Machine Pistol** (`item.machine_pistol`) | 3 standard | smg | `scorpion` | CC-BY 4.0 (1Matzh) | Mini Uzi |
| 9 | **Patrol Carbine** (`item.patrol_carbine`) | 4 advanced | rifle | `ar15` | CC-BY 4.0 (wafla) | M16 |
| 10 | **Assault Rifle** (`item.assault_rifle`) | 4 advanced | rifle | `ak74m` | CC-BY 4.0 (Cransh) | AK-47 |
| 11 | **Compact Rifle** (`item.compact_rifle`) | 4 advanced | rifle (compact) | `9a91` | CC-BY 4.0 (valterjherson1) | FN SCAR (fast handling) |
| 12 | **Tactical SMG** (`item.tactical_smg`) | 4 advanced | smg | `mp7a1` | CC-BY 4.0 (TheParaziT) | MP5K / Mini Uzi |
| 13 | **Combat Shotgun** (`item.combat_shotgun`): **M2** (§0) | 4 advanced | shotgun | needs a new model | — | modded Shotgun |
| 14 | **Marksman Rifle** (`item.marksman_rifle`) | 4 advanced | rifle (bolt, suppressed) | `sniper` (DJMaesen's `b48999a2…`, with its silencer) | CC-BY 4.0 (DJMaesen) | VSS Vintorez / Dragunov |
| 15 | **Anti-Materiel Rifle** (`item.anti_materiel_rifle`) | 4 jackpot (legendary) | rifle (heavy) | `barrett` | CC-BY 4.0 (Gintoki1234) | Milkor MGL's jackpot role; Dragunov's damage |

**Meshes considered and not used:**
- **`aks74u`:** reads as a second AK from the top-down camera. The `9a91` is a distinct silhouette.
- **`vssk`:** Sketchfab Standard licence. It is usable in a game, but Roblox meshes can be extracted, so CC-BY options are preferred. It stays a reserve for a later variant.
- **`m32`:** a grenade launcher, also Sketchfab Standard. Explosives are a raid lever (M2 breach charges), so it waits for M2.
- **`dualsmg` and `dualmac`:** akimbo needs its own clips.
- **`colt_1911`, `pistol_43` and `sniper50`:** spares for later variants. For example, `sniper50` could be a bolt .50 for the M2 season pass.

### 3.2 Combat stats

**Notes on the columns:**
- **Fire interval:** seconds between shots within a magazine.
- **Magazine:** shots before the reload beat.
- **Range, falloff and noise:** in studs. `falloff` means damage drops linearly from the start distance to the full-range multiplier.
- **Durability:** shots.
- **Sustained DPS:** shot damage × rounds per (magazine + reload) cycle, against one target, every pellet landing.

| Gun | Damage per shot | Fire interval (mode) | Magazine; reload beat | Durability (shots) | Range | Spread (°) | Noise | Falloff | Knockback | Swap (s) | Sustained DPS | Total damage |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Worn Pistol | 34 | 0.5 (single; jams) | 1; 1.4 s clear (existing) | **50** | 70 | 4 | 90 | 45 → 0.7 | 1 | default | 24 | 1,700 |
| Scrap Shotgun | 6 × 9 = 54 | 0.35 (both barrels) | 2; 2.6 s break-open | **30** | 28 | 18 | 120 | 10 → 0.35 | 3 | 0.7 | 37 | 1,620 |
| Flare Pistol | 12 + burn 6/s × 5 s | 1.0 (single) | 1; 2.0 s | **24** | 60 | 2 | 30 | — | — | default | utility | 1,008 with burn |
| Duty Pistol | 22 | 0.30 (semi) | 12; 1.6 s | **90** | 70 | 5 | 85 | 45 → 0.7 | 1 | default | 54 | 1,980 |
| Hand Cannon | 48 | 0.70 (semi) | 7; 2.0 s | **45** | 80 | 3 | 110 | 55 → 0.75 | 2.5 | 0.6 | 54 | 2,160 |
| Pump Shotgun | 8 × 10 = 80 | 0.90 (pump) | 5; 3.0 s (0.6 s a shell) | **28** | 32 | 14 | 125 | 12 → 0.35 | 3.5 | 0.8 | 61 | 2,240 |
| Hunting Rifle | 70 | 1.30 (bolt) | 5; 2.8 s | **32** | 120 | 1 | 140 | none | 2 | 0.9 | 44 | 2,240 |
| Machine Pistol | 9 | 0.09 (auto) | 20; 1.8 s | **240** | 45 | 9 | 95 | 25 → 0.6 | 0.3 | 0.4 | 51 | 2,160 |
| Patrol Carbine | 16 | 0.07 in a **3-round burst**, 0.35 between bursts | 30; 2.2 s | **190** | 95 | 3 | 115 | 70 → 0.8 | 0.5 | 0.7 | 71 | 3,040 |
| Assault Rifle | 17 | 0.12 (auto) | 30; 2.4 s | **160** | 90 | 6 | 125 | 60 → 0.75 | 0.6 | 0.8 | 87 | 2,720 |
| Compact Rifle | 13 | 0.10 (auto) | 20; 1.8 s | **200** | 70 | 6 | 120 | 40 → 0.65 | 0.5 | **0.5** (fastest long gun) | 70 | 2,600 |
| Tactical SMG | 11 | 0.075 (auto) | 40; 2.0 s | **240** | 55 | 8 | 100 | 30 → 0.6 | 0.3 | 0.5 | 89 | 2,640 |
| Combat Shotgun | 8 × 11 = 88 | 0.35 (semi) | 7; 3.5 s (0.5 s a shell) | **30** | 34 | 12 | 130 | 14 → 0.4 | 3.5 | 0.8 | 110 (point-blank) | 2,640 |
| Marksman Rifle | 110 | 1.50 (bolt) | 5; 3.0 s | **26** | 140 | 0.5 | **55** (suppressed) | none | 3 | 1.0 | 61 | 2,860 |
| Anti-Materiel Rifle | 220, **pierces 2 targets** | 0.90 (semi) | 5; 3.5 s | **15** | 160 | 0.5 | **220** | none | 6 | 1.1; walk ×0.7 while aiming | 155 | 3,300 |

**Rulings:**
- **Existing guns keep their stats.** Only `ammoItemId` goes.
- **Burst on the Patrol Carbine:** it rewards taps on touch and keeps the carbine accurate (spread 3) without out-DPSing the Assault Rifle.
- **Reload as a pacing beat:** a magazine refills for free; the reload time is the risk. Pump and Combat Shotgun reloads are shell by shell and can be cut short by firing. That gives them their own rhythm, and touch players can still play them.
- **Ranges past about 100 studs** only matter with the aim look-ahead (§8.4 `aimLookAhead`): the lobby camera is clamped near LDoE framing.
- **Crits** stay global: 8% chance, ×1.5 (`Tuning.combat`), rolled once per shot, not per pellet.

### 3.3 Crafting and unlocks

**How crafting works:**
- Guns are crafted by hand in the catalogue (LDOE_PARITY #20).
- The Workbench level is a "known recipe" gate, not a station line (ECONOMY §4.2).
- **Grind value** is the free-player grind-minutes of the inputs, using the unit values in [SHOP_CATALOG.md §5.1](SHOP_CATALOG.md#51-unit-values).

| Gun | Recipe (hand) | Gate | Unlock | Grind value |
|---|---|---|---|---|
| Worn Pistol | 1 steel pipe, 1 trigger group, 2 plank, 4 rivets, 1 coil spring (existing) | Workbench L2 | `quest.the_dense_fog` (existing) | 1.9 h |
| Scrap Shotgun | 2 steel pipe, 2 trigger group, 4 plank, 4 scrap plate, 6 rivets (existing) | Workbench L2 | `quest.the_dense_fog` | 4.4 h |
| Flare Pistol | 1 steel pipe, 1 trigger group, 3 scrap plate, 2 pitch glue (existing) | Workbench L2 | `quest.the_dense_fog` | 2.0 h |
| Duty Pistol | 1 steel pipe, 1 trigger group, 3 scrap plate, 4 rivets, 2 coil spring, 2 copper wire, 1 pitch glue | Workbench L2 | **`quest.into_the_black`** (13, about day 7.3) | 3.6 h |
| Pump Shotgun | 2 steel pipe, 2 trigger group, 4 scrap plate, 3 ironbark plank, 6 rivets, 2 coil spring, 2 copper wire | Workbench L2 | **`quest.the_plans`** (15) | 6.1 h |
| Hunting Rifle | 2 steel pipe, 1 trigger group, 1 brass gear, 4 ironbark plank, 3 scrap plate, 4 rivets, 2 copper wire, 1 tanned leather | Workbench L2 | **`quest.copper_lines`** (17) | 5.4 h |
| Hand Cannon | 2 steel pipe, 1 trigger group, 4 scrap plate, 6 rivets, 2 coil spring, 2 copper wire, 2 tanned leather | Workbench L2 | **`quest.walls_that_hold`** (19) | 4.75 h |
| Machine Pistol | 1 steel pipe, 2 trigger group, 4 scrap plate, 6 rivets, 3 coil spring, 2 copper wire, 1 brass gear | Workbench L2 | **`quest.padded_through`** (21) | 5.4 h |
| Patrol Carbine | 2 steel pipe, 3 trigger group, 2 brass gear, 6 scrap plate, 8 rivets, 4 copper wire, 3 coil spring, 2 ironbark plank | **Workbench L3** | **Patrol Carbine Schematic** (`item.bp_patrol_carbine`, Black loot); also the reward of `quest.hold_the_line` (25) | 9.1 h |
| Assault Rifle | as the Patrol Carbine, with 3 ironbark plank | Workbench L3 | `item.bp_assault_rifle` (Black loot) | 9.4 h |
| Compact Rifle | 1 steel pipe, 3 trigger group, 2 brass gear, 5 scrap plate, 8 rivets, 4 copper wire, 3 coil spring, 1 ironbark plank | Workbench L3 | `item.bp_compact_rifle` | 8.1 h |
| Tactical SMG | 1 steel pipe, 3 trigger group, 2 brass gear, 5 scrap plate, 8 rivets, 5 copper wire, 4 coil spring | Workbench L3 | `item.bp_tactical_smg` | 8.25 h |
| Combat Shotgun | 2 steel pipe, 3 trigger group, 2 brass gear, 6 scrap plate, 8 rivets, 4 copper wire, 3 coil spring, 2 ironbark plank | Workbench L3 | `item.bp_combat_shotgun` | 9.1 h |
| Marksman Rifle | 3 steel pipe, 3 trigger group, 3 brass gear, 6 scrap plate, 6 rivets, 4 copper wire, 2 coil spring, 4 ironbark plank, 2 tanned leather | Workbench L3 | `item.bp_marksman_rifle` | 10.1 h |
| Anti-Materiel Rifle | **not craftable** | — | Loot (§3.4) or the shop | valued at 16 h (1.6 × the Marksman Rifle, for pack pricing) |

**Why these unlocks:**
- The standard guns ride the launch branch's chapter-3 main line (`into_the_black` → `the_plans` → `copper_lines` → `walls_that_hold` → `padded_through`), one gun per quest, days 7–13.
- With Copper Wire and Trigger Groups as the throttle, the first standard gun is crafted around day 8–9 and the set by days 13–16: **"standard guns in weeks 2–3"** (DECISIONS).
- **If chapter 3 isn't merged when this ships:** all five standard guns unlock at `quest.into_the_black`.
- Schematics follow the existing found-blueprint pattern (`item.bp_pack_frame`, `item.bp_reinforced`): reading one consumes it and unlocks the recipe for good.
- **LDoE precedent:** iron-tier gear unlocks by Path quest; the top guns are loot or season-only (§7).

**Recycler salvage** (new rows; chances scale with durability left, as now; LDoE recycles guns into Spring, Factory Parts and Carbon Composite in 1 h, §7):

| Class | Time | Outputs |
|---|---|---|
| Standard guns | 30 m | scrap plate 1–2 (100%), coil spring 1 (60%), steel pipe 1 (40%), trigger group 1 (25%) |
| Advanced guns | 30 m | scrap plate 2–3 (100%), coil spring 1–2 (60%), brass gear 1 (35%), trigger group 1 (35%) |
| Anti-Materiel Rifle | 45 m | brass gear 1–2 (100%), trigger group 1–2 (50%), steel pipe 1–2 (60%) |
| Schematics | — | not recyclable |

### 3.4 Loot sources and weights

**Conventions:**
- Weights are in the table's own units (Domain/Loot), and **epic** rows count toward the table's existing `pity`.
- The **no-ammo pass** removes every `blackpowder`, `light_rounds`, `shells` and `flare` row. Where a table lost ammo rows, they are replaced as shown here, so the totals stay near their current size.
- New tables `loot.enemy_brute` and `loot.enemy_retcher` come with SH-1 ([parity audit](research/ldoe-mvp-parity-content.md)).

**`loot.depot_band3`** (Ashfall Depot, Fog band 3; existing pity: an epic every 10) becomes, in full:

| Entry | Weight | Rarity |
|---|---|---|
| Trigger Group | 20 | — |
| Brass Gear | 10 | — |
| Coil Spring (replaces Blackpowder) | 10 | — |
| Steel Pipe (replaces Shells) | 10 | — |
| Fire Axe | 8 | — |
| Worn Pistol / Flare Pistol / Scrap Shotgun (existing) | 6 / 6 / 3 | epic |
| Duty Pistol / Hand Cannon / Pump Shotgun / Machine Pistol | 4 / 3 / 3 / 3 | epic |
| Each advanced gun (6 rows) | 1 each | epic |
| Each advanced schematic (6 rows) | 1 each | epic |
| Anti-Materiel Rifle | 1 | legendary |

**Additions to other tables:**

| Table | Add |
|---|---|
| `loot.depot_strongbox` (pity: epic every 5) | the 6 advanced schematics at 2 each (epic); Hand Cannon 4; Anti-Materiel Rifle 1 (legendary). **Reinforcement Plans 12 → 14**, so its share stays about 11% |
| `loot.quarry_band3` (Rustwater band 3) | Worn Pistol 3, Scrap Shotgun 2, Duty Pistol 2, Pump Shotgun 1 (all epic). Coil Spring 20, Rivets 14 and Scrap Plate 12 replace the 54 weight of ammo rows |
| `loot.caravan_band3` | Duty Pistol 4, Hand Cannon 3, Pump Shotgun 4. Coil Spring 20, Steel Pipe 20 and Scrap Plate 10 replace the 60 weight of ammo rows |
| `loot.airdrop_crate` | Duty Pistol 3, Pump Shotgun 2, Hunting Rifle 2, Machine Pistol 2, and `loot.schematics_advanced` 1 |
| `loot.forest_crate_t3` (Gloaming Deep) | Hunting Rifle 2, Hand Axe 3 |
| `loot.forest_crate_t2` (Ironbark Stand) | Hand Axe 2 |
| `loot.mine_box_t3` (Deepcut Pit) | Machine Pistol 1, `item.bp_combat_shotgun` 1 |
| `loot.depot_freight` | Hunting Rifle 1 |
| `loot.zone_pack_t3` | Duty Pistol 1, Field Knife 2 |
| `loot.zone_pack_t2`, `loot.quarry_locker` | Field Knife 3 and 2 |
| `loot.pine_crate` (Pine Hollow barn) | Hay Fork 4, Hardwood Bat 3 |
| `loot.zone_pack_t1`, `loot.forest_crate_t1` | Hardwood Bat 2 and 3 |
| `loot.enemy_brute` (new, SH-1) | `loot.schematics_advanced` 5%, Duty Pistol 3%, Anti-Materiel Rifle 0.5% (on top of SH-1's gear, spring and plate drops) |
| `loot.schematics_advanced` (new sub-table) | the 6 advanced schematics, weight 1 each |

**Expected yields (Inference, from the ECONOMY §7.5 container counts):**
- **An advanced schematic:** about 0.21 per Depot first clear from strongboxes, plus band-3 freight and Brutes. That is **about one every 4 Depot clears**, so the first advanced gun is learnable around day 11–14 and crafted around days 14–21 (Trigger Groups and Brass Gears are the throttle).
- **The Anti-Materiel Rifle:** strongbox about 1.8% and band-3 freight about 0.9% per Depot clear, plus Brutes about 0.45% per Black run. That is **about 1 per 30–40 days of daily Depot clears**: a miserable free path that exists, per the playbook's rule 1 ([playbook §5.4](research/ldoe-monetization-playbook.md)).

### 3.5 Packs each gun appears in

Full contents and prices are in [SHOP_CATALOG.md](SHOP_CATALOG.md).

| Gun | Packs |
|---|---|
| Worn Pistol, Scrap Shotgun, Flare Pistol | none. The shop's cheapest gun is the Duty Pistol, so paying skips the improvised tier, as LDoE's packs sell a Glock rather than a Zip Gun |
| Duty Pistol | Gunrunner Pack (249) |
| Hand Cannon | Raider Arms (1,199) |
| Pump Shotgun | Shotgun Pack (399) |
| Hunting Rifle | Rifle Pack (799), Marksman Pack (1,199) |
| Machine Pistol, Tactical SMG | SMG Pack (799) |
| Patrol Carbine | Rifle Pack (799), Raider Arms (1,199) |
| Assault Rifle, Combat Shotgun | Heavy Loadout (2,499) |
| Compact Rifle | Anti-Materiel Crate (1,699) |
| Marksman Rifle | Marksman Pack (1,199) |
| Anti-Materiel Rifle | Anti-Materiel Crate (1,699) |

---

## 4. Melee

**Base rules:**
- Melee costs 1 durability per landed hit and 2 per heavy swing.
- Noise is 10 (`Tuning.noise.melee`) unless stated.
- Heavy swings are ×1.8 (`Tuning.melee`).
- **Tire Iron and Rail Mallet** are already built on the launch branch (S1b, LB-2). The rows below confirm their meshes and add sources and packs.

| Name (ID) | Zona mesh; licence | Tier | Damage | Rate (interval) | Range | Durability (hits) | Special | Recipe | Unlock | Loot | Packs | LDoE counterpart |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Tire Iron** (`item.tire_iron`, launch branch) | `crowbar_01`; CC0, Poly Haven (Alexander Otterbeck) | 1 | 15 | 1.2/s (0.83 s) | 6 | 70 | — | loot only | — | weight 3–5 in `pine_pack`, `pine_crate`, `zone_pack_t1`, `forest_crate_t1`, `mine_box_t1` (LB-2) | Scout's Kit | Crowbar 17 / 1.6 / 100 |
| **Rail Mallet** (`item.rail_mallet`, launch branch) | `sledgehammer_01`; CC0, Poly Haven (Zona's own notes; its yellow fibreglass head is tinted) | 2 heavy | 26 | 0.8/s (1.25 s) | 6.5 | 50 | knockback, swap 0.6 | loot only | — | `quarry_toolbox`, `zone_pack_t2`, `caravan_wagon` (LB-2) | Heavy Loadout | Skull Crusher 45 / 0.7 / 45 |
| **Machete** (`item.machete`, existing) | `machete`; CC0, Poly Haven (Ulan Cabanilla), already `EO_Machete` | 2 | 22 | 1.6/s (0.63 s) | 6.5 | 70 | crit 0.12 | existing (5 plate, 3 rivets, 2 cloth, 1 glue) | `quest.the_dense_fog` | `quarry_band2/3`, `caravan_band3` (existing) | — | Machete 30 / 1.3 / 80 |
| **Hand Axe** (`item.hand_axe`, new) | `hatchet`; CC0, Poly Haven (James Ray Cock, Ulan Cabanilla) | 2 | 20 | 1.4/s (0.71 s) | 6 | 70 | heavy knockback 2; **+50% damage to build pieces** (`melee.structureMultiplier`, used by M2 raids) | 3 iron ingot, 2 ironbark plank, 2 rivets, 1 pitch glue | `quest.heartwood` | `forest_crate_t2` 2, `forest_crate_t3` 3 | — | Iron Hatchet as a weapon; no LDoE fighting hatchet |
| **Hardwood Bat** (`item.hardwood_bat`, new) | `baseball_bat`; CC0, Poly Haven (Enrique Martín) | 1 | 18 | 1.0/s (1.0 s) | 6.5 | 80 | knockback 2.5 | loot only | — | `pine_crate` 3, `zone_pack_t1` 2, `forest_crate_t1` 3 | — | Baseball Bat 20 / 1.0 / 80, loot only |
| **Field Knife** (`item.field_knife`, new) | `knife_animated` (its standalone 30.5 cm copy); CC-BY 4.0 (DJMaesen) | 2 | 11 | 2.0/s (0.5 s) | 4.5 | 120 | crit 0.20; sneak backstab **×4** (default ×3); noise **6** | 2 iron ingot, 1 scrap plate, 1 tanned leather, 1 cord | `quest.scavenger` | `zone_pack_t2` 3, `quarry_locker` 2, `zone_pack_t3` 2 | — | none (Hammer 8 / 1.7 / 100 is the nearest fast weapon) |
| **Hay Fork** (`item.hay_fork`, new) | `pitchfork`; CC-BY 4.0 (DJMaesen) | 1 | 16 | 0.9/s (1.1 s) | **8.5** (longest reach) | 60 | knockback 2 | loot only | — | `pine_crate` 4 (the Pine Hollow barn) | — | Scythe 60 / 0.7 / 30, Crooked Creek Farm chest only |

**Melee DPS ladder:**
- Stake 11, Spiked Club 14, Hay Fork 14, Tire Iron 18, Hardwood Bat 18, Field Knife 22 (×4 from stealth).
- Rail Mallet 21, plus stagger.
- Hand Axe 28, Scrapblade 31, Fire Axe 32, Machete 35.

The new pieces fill gaps without topping the Machete:
- **found T1 variety** for Light fog (LB-2)
- **a stealth knife**
- **a breaching axe** for M2

---

## 5. Armor sets

**Formula:** reduction = defense ÷ (defense + 50/3), from `Tuning.combat.armorConstant`. It is LDoE's formula ([Armor and Armor Points](https://last-day-on-earth-survival.fandom.com/wiki/Armor_and_Armor_Points)).

**Rules:**
- Durability counts hits taken (1 per hit, on every equipped piece).
- Fog resist sums across pieces and is capped at `Tuning.fogExposure.maxResist = 0.8`.
- Each higher piece **consumes the matching lower piece** at any durability, as LDoE's Reinforced Jacket consumes a Thick Jacket (ECONOMY §4.2).

| Set (tier) | Piece (ID) | Slot | Defense | Fog resist | Durability | Recipe (hand) | Unlock |
|---|---|---|---|---|---|---|---|
| **Reedweave** (1, launch branch) | Cap (`item.reedweave_cap`) | head | 1 | 0.03 | 60 | 3 fiber, 1 reedcloth | `quest.keep_the_fire` |
| | Shirt (`item.reedweave_shirt`) | body | 2 | 0.04 | 60 | 4 fiber, 3 reedcloth | same |
| | Trousers (`item.reedweave_trousers`) | legs | 2 | 0.04 | 60 | 4 fiber, 3 reedcloth, 2 cord | same |
| | Wraps (`item.reedweave_wraps`) | feet | 1 | 0.03 | 60 | 3 fiber, 2 reedcloth, 2 cord | same |
| **Padded** (2) | Hood (existing) | head | 3 | 0.10 | 80 | 4 reedcloth, 2 cord | `quest.hold_the_door` |
| | Vest (existing) | body | 6 | 0.15 | 100 | 6 reedcloth, 3 cord, 2 scrap plate, 1 glue | `quest.stand_your_ground` |
| | Leggings (launch branch) | legs | 5 | 0.12 | 100 | 4 reedcloth, 2 leather, 2 cord, 1 glue | `quest.scavenger` |
| | Boots (launch branch) | feet | 2 | 0.08 | 80 | 2 reedcloth, 2 leather, 2 cord | `quest.scavenger` |
| **Hidebound** (3, new; parity SH-4) | Cap (`item.hidebound_cap`) | head | 4 | 0.12 | 150 | Padded Hood + 3 leather, 1 scrap plate, 1 rivet, 1 glue | **`quest.padded_through`** (21) |
| | Coat (`item.hidebound_coat`) | body | 8 | 0.18 | 150 | Padded Vest + 6 leather, 3 scrap plate, 2 rivets, 2 glue | same |
| | Leggings (`item.hidebound_leggings`) | legs | 6 | 0.15 | 150 | Padded Leggings + 5 leather, 2 scrap plate, 2 rivets, 1 glue | same |
| | Boots (`item.hidebound_boots`) | feet | 3 | 0.10 | 150 | Padded Boots + 3 leather, 1 scrap plate, 1 rivet, 1 glue | same |
| **Riveted** (4, new, Black) | Helm (`item.riveted_helm`) | head | 5 | 0.15 | 180 | Hidebound Cap + 3 scrap plate, 4 rivets, 2 copper wire | **`quest.black_fog_regular`** (23) |
| | Cuirass (`item.riveted_cuirass`) | body | 10 | 0.22 | 180 | Hidebound Coat + 6 scrap plate, 8 rivets, 4 copper wire, 1 brass gear | same |
| | Legguards (`item.riveted_legguards`) | legs | 9 | 0.18 | 180 | Hidebound Leggings + 5 scrap plate, 6 rivets, 3 copper wire | same |
| | Boots (`item.riveted_boots`) | feet | 4 | 0.12 | 180 | Hidebound Boots + 2 scrap plate, 4 rivets, 2 copper wire | same |

**Set totals and their LDoE counterparts:**

| Set | Defense | Reduction | Fog resist | LDoE counterpart |
|---|---|---|---|---|
| Reedweave | 6 | 26.5% | 0.14 | below Normal Clothes (8) |
| Padded | 16 | 49.0% | 0.45 | Thick Clothes (16) |
| Hidebound | 21 | 55.8% | 0.55 | Reinforced Thick Clothes (20) |
| Riveted | 28 | 62.7% | 0.67 | between Tactical (24) and SWAT (32); durability 180 like LDoE's Reinforced set |

**Why a fourth, Black set is needed (decided):**
1. **Fog gating (LDOE_PARITY #37).** Black fog fills an unprotected meter in 4 minutes of a 15-minute run.
   - Padded stretches that to 7.3 minutes, Hidebound to 8.9 and Riveted to **12.1**.
   - Only Riveted makes a near-full Black run possible without fog damage. That is the gear gate #37 asks for, and it is what "Black is empty" (parity BR-2) lacked.
2. **Days 11–16 need a craft goal.** BR-2 and BR-8 flag a content cliff after day 13. The Riveted set costs 21.5 grind-hours (14 Copper Wire, 16 plates of Workbench time), which keeps the benches busy into week 3.
3. **The big shop loadout needs a top set.** LDoE's Heavy equipment pack is built around its top set, Kevlar ([Heavy equipment](https://last-day-on-earth-survival.fandom.com/wiki/Heavy_equipment)).
4. **M2 PvP:** against advanced automatics, Hidebound is the floor and Riveted the ceiling (§6.6).

**Fit with ECONOMY's M2 Plated set:** M2's Plated set (Ember Steel) should consume **Riveted** pieces, not Padded. §8.7 lists that edit.

**Loot (armor):**
- Existing: Padded Hood in `quarry_locker` and `pine_band3`; Padded Vest in `depot_strongbox`.
- Add Hidebound Cap 3 and Hidebound Boots 3 to `caravan_wagon` and `loot.zone_pack_t3`.
- Add Hidebound Coat 2 to `depot_freight`.
- Add one Riveted Helm 1 (epic) to `depot_strongbox`.
- Riveted is otherwise craft or shop only, so the set stays a Black-fog grind.

**Packs:**

| Set | Packs |
|---|---|
| Reedweave | Scout's Kit (79) |
| Padded | Padded Armor Pack (199); the Padded Hood also in Scavenger's Kit (79); Hood and Vest in the Firestarter Kit (99) |
| Hidebound | Hidebound Armor Pack (399), Raider Arms (1,199); three pieces in the Marksman Pack (1,199) |
| Riveted | Riveted Armor Pack (1,199), Heavy Loadout (2,499); the Helm in the Anti-Materiel Crate (1,699) |

---

## 6. Balance

### 6.1 The Hollow, by fog tier

**HP sources:**
- Base HP: `Data/Enemies` (Shambler 40, Runner 70, Bloater 60).
- SH-1's proposed Brute (260 HP, 16-damage telegraphed slam) and Retcher (70 HP, 10-damage bile glob).

**Scaling (both multiply):**
- **Tier scale:** ECONOMY §6.4, `hollowTierScale` health {1, 1.2, 1.4} and damage {1, 1.15, 1.3}.
- **Lobby band scale:** `Tuning.lobby.bands`, `hollowStrength` 1, 1.2 and 1.45.
- The worst case is Black at band 3: HP ×2.03, damage ×1.89.

| HP | Shambler | Runner | Bloater | Retcher | Brute |
|---|---|---|---|---|---|
| Light (×1) | 40 | 70 | 60 | 70 | 260 |
| Dense (×1.2) | 48 | 84 | 72 | 84 | 312 |
| Black (×1.4) | 56 | 98 | 84 | 98 | 364 |
| Black, band 3 (×2.03) | 81 | 142 | 122 | 142 | 528 |

### 6.2 Shots to kill

**Assumptions:** body hits, no crit, inside the falloff start, every pellet landing for shotguns.

**Reading the cells:** each is Shambler / Runner / Bloater / Retcher / Brute. "Black b3" is Black at band 3.

| Gun | Light | Dense | Black | Black b3 |
|---|---|---|---|---|
| Worn Pistol (34) | 2 / 3 / 2 / 3 / 8 | 2 / 3 / 3 / 3 / 10 | 2 / 3 / 3 / 3 / 11 | 3 / 5 / 4 / 5 / 16 |
| Scrap Shotgun (54) | 1 / 2 / 2 / 2 / 5 | 1 / 2 / 2 / 2 / 6 | 2 / 2 / 2 / 2 / 7 | 2 / 3 / 3 / 3 / 10 |
| Flare Pistol (12 hit, + 30 burn) | 4 / 6 / 5 / 6 / 22 on hit damage; the burn and the flee radius are the point | | | |
| Duty Pistol (22) | 2 / 4 / 3 / 4 / 12 | 3 / 4 / 4 / 4 / 15 | 3 / 5 / 4 / 5 / 17 | 4 / 7 / 6 / 7 / 24 |
| Hand Cannon (48) | 1 / 2 / 2 / 2 / 6 | 1 / 2 / 2 / 2 / 7 | 2 / 3 / 2 / 3 / 8 | 2 / 3 / 3 / 3 / 11 |
| Pump Shotgun (80) | 1 / 1 / 1 / 1 / 4 | 1 / 2 / 1 / 2 / 4 | 1 / 2 / 2 / 2 / 5 | 2 / 2 / 2 / 2 / 7 |
| Hunting Rifle (70) | 1 / 1 / 1 / 1 / 4 | 1 / 2 / 2 / 2 / 5 | 1 / 2 / 2 / 2 / 6 | 2 / 3 / 2 / 3 / 8 |
| Machine Pistol (9) | 5 / 8 / 7 / 8 / 29 | 6 / 10 / 8 / 10 / 35 | 7 / 11 / 10 / 11 / 41 | 10 / 16 / 14 / 16 / 59 |
| Patrol Carbine (16) | 3 / 5 / 4 / 5 / 17 | 3 / 6 / 5 / 6 / 20 | 4 / 7 / 6 / 7 / 23 | 6 / 9 / 8 / 9 / 33 |
| Assault Rifle (17) | 3 / 5 / 4 / 5 / 16 | 3 / 5 / 5 / 5 / 19 | 4 / 6 / 5 / 6 / 22 | 5 / 9 / 8 / 9 / 32 |
| Compact Rifle (13) | 4 / 6 / 5 / 6 / 20 | 4 / 7 / 6 / 7 / 24 | 5 / 8 / 7 / 8 / 28 | 7 / 11 / 10 / 11 / 41 |
| Tactical SMG (11) | 4 / 7 / 6 / 7 / 24 | 5 / 8 / 7 / 8 / 29 | 6 / 9 / 8 / 9 / 34 | 8 / 13 / 12 / 13 / 48 |
| Combat Shotgun (88) | 1 / 1 / 1 / 1 / 3 | 1 / 1 / 1 / 1 / 4 | 1 / 2 / 1 / 2 / 5 | 1 / 2 / 2 / 2 / 6 |
| Marksman Rifle (110) | 1 / 1 / 1 / 1 / 3 | 1 / 1 / 1 / 1 / 3 | 1 / 1 / 1 / 1 / 4 | 1 / 2 / 2 / 2 / 5 |
| Anti-Materiel Rifle (220, pierces 2) | 1 / 1 / 1 / 1 / 2 | 1 / 1 / 1 / 1 / 2 | 1 / 1 / 1 / 1 / 2 | 1 / 1 / 1 / 1 / 3 |

**Reading it:**
- **Improvised guns** two-shot most of the Light roster and still take 8–11 shots for a Brute. They are a panic button, not a Brute answer.
- **Standard guns** split by role:
  - The Hand Cannon, Pump Shotgun and Hunting Rifle two-shot every Black regular.
  - The Duty Pistol and Machine Pistol trade per-shot damage for volume.
- **Advanced automatics** take 4–7 rounds per Black regular, at 4–8 rounds a second. They kill crowds, not single targets: their edge is time to kill. The Assault Rifle drops a band-3 Brute in about 6.3 s, against 10.7 s for the Duty Pistol.
- **Precision guns** (Marksman, Anti-Materiel) one-shot every Black regular. They are slow, and the Anti-Materiel is loud enough to pull the map, so a lone sniper still has to deal with what comes.

### 6.3 Melee hits to kill

Cells are Shambler / Runner / Bloater / Retcher / Brute, light swings, no crit.

| Weapon (damage) | Light | Black | Black b3 |
|---|---|---|---|
| Sharpened Stake (10) | 4 / 7 / 6 / 7 / 26 | 6 / 10 / 9 / 10 / 37 | 9 / 15 / 13 / 15 / 53 |
| Spiked Club (14) | 3 / 5 / 5 / 5 / 19 | 4 / 7 / 6 / 7 / 26 | 6 / 11 / 9 / 11 / 38 |
| Tire Iron (15) | 3 / 5 / 4 / 5 / 18 | 4 / 7 / 6 / 7 / 25 | 6 / 10 / 9 / 10 / 36 |
| Hay Fork (16) | 3 / 5 / 4 / 5 / 17 | 4 / 7 / 6 / 7 / 23 | 6 / 9 / 8 / 9 / 33 |
| Hardwood Bat (18) | 3 / 4 / 4 / 4 / 15 | 4 / 6 / 5 / 6 / 21 | 5 / 8 / 7 / 8 / 30 |
| Field Knife (11; ×4 backstab) | 4 / 7 / 6 / 7 / 24 (backstab: 1 / 2 / 2 / 2 / 6) | 6 / 9 / 8 / 9 / 34 | 8 / 13 / 12 / 13 / 48 |
| Hand Axe (20) | 2 / 4 / 3 / 4 / 13 | 3 / 5 / 5 / 5 / 19 | 5 / 8 / 7 / 8 / 27 |
| Machete (22) | 2 / 4 / 3 / 4 / 12 | 3 / 5 / 4 / 5 / 17 | 4 / 7 / 6 / 7 / 24 |
| Scrapblade (24) | 2 / 3 / 3 / 3 / 11 | 3 / 5 / 4 / 5 / 16 | 4 / 6 / 6 / 6 / 22 |
| Rail Mallet (26) | 2 / 3 / 3 / 3 / 10 | 3 / 4 / 4 / 4 / 14 | 4 / 6 / 5 / 6 / 21 |
| Fire Axe (36) | 2 / 2 / 2 / 2 / 8 | 2 / 3 / 3 / 3 / 11 | 3 / 4 / 4 / 4 / 15 |

### 6.4 Armor against the Hollow

**Inputs:**
- Damage per hit at Black band 3: Runner 6 × 1.3 × 1.45 = **11.3**; Retcher glob **18.9**; Brute slam **30.2**.
- Fog: Dense fills an unprotected meter in 10 min and Black in 4 (`Tuning.fogExposure`).

| Worn set | Runner hit | Retcher glob | Brute slam | Runner hits to down 100 HP | Brute slams to down | Dense fog meter full | Black fog meter full |
|---|---|---|---|---|---|---|---|
| none | 11.3 | 18.9 | 30.2 | 9 | 4 | 10.0 min | 4.0 min |
| Reedweave | 8.3 | 13.9 | 22.2 | 13 | 5 | 11.6 min | 4.7 min |
| Padded | 5.8 | 9.6 | 15.4 | 18 | 7 | **18.2 min** (covers a Dense run) | 7.3 min |
| Hidebound | 5.0 | 8.3 | 13.3 | 20 | 8 | 22.2 min | 8.9 min |
| Riveted | 4.2 | 7.0 | 11.3 | 24 | 9 | 30.3 min | **12.1 min** (most of a Black run) |

**The gates:**
- Padded is the Dense gate: it covers a full 15-minute run.
- Riveted is the Black gate.
- The Field Dressing (40 HP) ceiling from parity BR-5 eases by about 2× for Riveted wearers. That makes Black survivable for geared players, without making the dressing sink vanish (§6.5).

### 6.5 The durability sink: shots, runs and Trigger Groups

**The model (Inference, matched to ECONOMY §8.1 and §9):**
- **HP killed per run:** 60% of the §6.2 roster.
  - Black run: Shambler 9.25, Runner 8.5, Bloater 2.5, Brute 1.5 and Retcher 1.5 at ×1.4, with the average band ×1.15. That is **1,555 HP**.
  - Dense run: **737 HP**.
- **Share of that damage done by the gun:** improvised 1/3, standard 0.4, advanced 0.5. The rest is melee.
- **Hit rate:** pistols 0.85, bolt rifles 0.9, automatics 0.6–0.75, shotguns 0.7 (pellets).
- **Check against ECONOMY:** the Worn Pistol comes out at 18 shots a Black run. ECONOMY §8.1 uses 15, so the model is consistent.

| Gun | Shots per Black run | Black runs per gun | Dense runs per gun | Trigger Groups burned per Black run |
|---|---|---|---|---|
| Worn Pistol | 18 | 2.8 | 5.9 | 0.36 |
| Scrap Shotgun | 14 | 2.2 | 4.6 | 0.91 |
| Flare Pistol | 4–6 (ECONOMY §8.1) | 4–6 | — | 0.2 |
| Duty Pistol | 33 | 2.7 | 5.7 | 0.37 |
| Hand Cannon | 15 | 3.0 | 6.2 | 0.34 |
| Pump Shotgun | 11 | 2.5 | 5.3 | 0.79 |
| Hunting Rifle | 10 | 3.2 | 6.8 | 0.31 |
| Machine Pistol | 115 | 2.1 | 4.4 | 0.96 |
| Patrol Carbine | 65 | 2.9 | 6.2 | 1.02 |
| Assault Rifle | 65 | 2.5 | 5.2 | 1.23 |
| Compact Rifle | 85 | 2.3 | 4.9 | 1.28 |
| Tactical SMG | 118 | 2.0 | 4.3 | 1.47 |
| Combat Shotgun | 13 | 2.4 | 5.0 | 1.26 |
| Marksman Rifle | 8 | 3.3 | 7.0 | 0.91 |
| Anti-Materiel Rifle | 4 | 3.8 | 8.1 | — (loot only) |

**What it means:**
- **Every gun lasts 2–4 Black runs.** That satisfies ECONOMY §8.7's "at most 4" sink assertion.
- **Trigger Group supply per Black run:** about 0.26 in Deepcut Pit or Gloaming Deep; 0.69 on the day's first Ashfall Depot clear (ECONOMY §7.5); plus Brutes and the Recycler.
- **What a free player can sustain:**
  - One improvised gun, the Duty Pistol, the Hand Cannon or the Hunting Rifle can be kept alive from Black runs alone (0.3–0.4 Trigger Groups a run).
  - **Every advanced automatic burns 1.0–1.5 a run**, about 4–5× free supply, so free players save them for Brutes and bad moments.
  - Paying players feed them from the Gun Parts Pack (149: 2 Trigger Groups) and the gun packs.
- This is ECONOMY §8.2's rule ("a free player keeps one gun alive only by farming Black fog"), extended up the ladder, and it is LDoE's "do not use guns at yellow and green zones" tip ([Glock 17](https://last-day-on-earth-survival.fandom.com/wiki/Glock_17)).
- **The pacing test needs one new assertion:** a free player's Trigger Group stock never sustains an advanced automatic for more than 2 consecutive Black days.

### 6.6 PvP (M2: Dense and Black)

**Cap:** `pvpMaxHitFraction = 0.6` caps every hit at 60 HP, applied after armor.

| Hits to down a 100-HP survivor | No armor | Padded | Hidebound | Riveted |
|---|---|---|---|---|
| Duty Pistol | 5 | 9 | 11 | 13 |
| Assault Rifle | 6 | 12 | 14 | 16 |
| Pump Shotgun (all 8 pellets) | 2 | 3 | 3 | 4 |
| Hunting Rifle | 2 | 3 | 4 | 4 |
| Marksman Rifle | 2 | 2 | 3 | 3 |
| Anti-Materiel Rifle | 2 | 2 | 2 | 2 |

- No gun one-shots, and the jackpot is always 2 hits.
- Armor matters most against automatics.
- Power-band matchmaking (`Matchmaking.gearScore`, item tier) keeps tier-4 loadouts among themselves. §8.4 adds the weight check.

### 6.7 When each tier lands for a free player (2.5 h a day; Inference on ECONOMY §9.2)

| Milestone | Day |
|---|---|
| First improvised gun | 3.8 (ECONOMY) |
| Black fog open | 7.3 |
| First standard gun unlocked (`into_the_black`) | about 7.3 |
| First standard gun crafted | about 8–9 (Copper Wire from Smelter L2 and Workbench L2; 1 Trigger Group) |
| All five standard guns unlocked | about 13 (`padded_through`) |
| Hidebound set | about 11–13 |
| First advanced schematic | about 11–14 (about one per 4 Depot clears) |
| First advanced gun crafted | about 14–21 (3 Trigger Groups, 2 Brass Gears) |
| Riveted set | about 14–17 |
| Anti-Materiel Rifle from loot | about day 35+ |

**A paying player** buys the Gunrunner Pack on the day Dense opens, and Raider Arms or the Heavy Loadout from the first Black run: hours instead of weeks (GAME_DESIGN's paying column).

---

## 7. LDoE reference stats

All figures are the wiki's own infobox and section text, read 2026-11-08.
- "Level" is LDoE's legacy craft level; recipes now unlock through Survivor's Path quests ([Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints)).
- Speed is attacks per second.

| LDoE weapon | Damage | Speed | DPS | Durability (shots) | Craftable; blueprint and parts | Level; where found |
|---|---|---|---|---|---|---|
| [Zip Gun](https://last-day-on-earth-survival.fandom.com/wiki/Zip_Gun) | 18 | 0.8 | 14.4 | 100 | Yes: 16 Iron Plate, 4 Spring, 5 Duct Tape, 3 Bolts, 1 Oak Plank, 8 Adhesive | L34; AI survivors, Rest Stop |
| [Handmade Gun](https://last-day-on-earth-survival.fandom.com/wiki/Handmade_Gun) / [Handmade Shotgun](https://last-day-on-earth-survival.fandom.com/wiki/Handmade_Shotgun) | 13 / 36 | 2 / 1.3 | 26 / 46.8 | — | Yes (Crater): Smooth barrel, Springs, Bolts, Oak Plank | multiplayer storages; Raider's Pack |
| [Flare Gun](https://last-day-on-earth-survival.fandom.com/wiki/Flare_Gun) | 10 (35 burning) | 1.0 | 10 | 32 | Yes: 5 Aluminium Plate, 5 Plastic, 4 Thermite, 10 Iron Plate | Crooked Creek Farm, events |
| [Glock 17](https://last-day-on-earth-survival.fandom.com/wiki/Glock_17) | 20 | 3.3 | 66 | 100 ("100 shots/2000 damage") | Yes: 15 Titanium Bar, 15 Bolts, 8 Spring, 5 Gunpowder, 3 Carbon Composite, 2 Factory Parts | L40; yellow and red zone boxes, Bunker Alfa, Police Station, airdrops, Gunsmith's crate |
| [Colt Python](https://last-day-on-earth-survival.fandom.com/wiki/Colt_Python) | 25 | 1.4 | 35 | 100 | No | Specialist reward, Crooked Creek Farm chest, Packs |
| [Shotgun](https://last-day-on-earth-survival.fandom.com/wiki/Shotgun) | 70 | 0.9 | 63 | 40 ("70*40 shots = 2800 damage") | Formerly: 2 Spring, 5 Tungsten Bar, 3 Ash Plank, 2 Duct Tape | L70; red zones, Bunker Alfa, Police Station, Zombie Warfare Pack |
| [Winchester](https://last-day-on-earth-survival.fandom.com/wiki/Winchester) | 21 | 0.9 | 18.9 | 30 | No | Gunsmith's crate |
| [Hunter Rifle](https://last-day-on-earth-survival.fandom.com/wiki/Hunter_Rifle) | 55 | 1.0 | 55 | 60 | No | Hunting grounds rewards; shop |
| [Mini Uzi](https://last-day-on-earth-survival.fandom.com/wiki/Mini_Uzi) | 8 | 8.3 | 66.4 | 200 | No | Gunsmith's crate, quest rewards |
| [MP5K](https://last-day-on-earth-survival.fandom.com/wiki/MP5K) | 8 | 10 | 80 | — | No | multiplayer storages; Scout's Pack |
| [M16](https://last-day-on-earth-survival.fandom.com/wiki/M16) | 12 | 8.3 | 99.6 | 170 | Yes: 17 Titanium Bar, 4 Spring, 5 Ash Plank, 5 Gunpowder, 5 Carbon Composite, 3 Factory Parts | L94; Bunker Alfa, packs |
| [AK-47](https://last-day-on-earth-survival.fandom.com/wiki/AK-47) | 15 | 8.3 | 124.5 | 170 | No (legacy: 4 Spring, 7 Tungsten Bar, 5 Ash Plank) | L82; Bunker Alfa floors 2–4, coupon crates |
| [FN SCAR](https://last-day-on-earth-survival.fandom.com/wiki/FN_SCAR) | 18 | 8.3 | 149.4 | 170 | No | Specialist L9, Season tasks, packs |
| [VSS Vintorez](https://last-day-on-earth-survival.fandom.com/wiki/VSS_Vintorez) | 50 | 2 | 100 | 60 ("60 shots/3000 damage") | No (legacy: 14 Spring, 8 Tungsten Bar, 5 Steel Bar, 10 Ash Plank, 10 Factory Parts, 10 Gunpowder) | L58; red-zone AI, Police Station, Raider's Starter Pack |
| [The Dragunov](https://last-day-on-earth-survival.fandom.com/wiki/The_Dragunov) | 130 | 1.0 | 130 | 36 | No (season reward) | L130; Season Pass |
| [Milkor MGL](https://last-day-on-earth-survival.fandom.com/wiki/Milkor_MGL) | 200 | 1.1 | 220 | 16 | No | Specialist L15, seasons, Gunsmith's crate, Week Pack |
| [Bow](https://last-day-on-earth-survival.fandom.com/wiki/Bow) | 8–20 | 0.6–1.0 | 4.8–12 | 50 | Yes: 5 Pine Plank, 1 Iron Bar, 5 Rope, 3 Duct Tape, 3 Adhesive | L10 |
| [Crossbow](https://last-day-on-earth-survival.fandom.com/wiki/Crossbow) | 70 | 0.6 | 42 | 35 | Yes: 5 Aluminium Wire, 4 Factory Parts, 3 Steel Plate, 3 Oak Plank, 5 Spring, 10 Duct Tape | Season 8, Transport Hub |
| [Crowbar](https://last-day-on-earth-survival.fandom.com/wiki/Crowbar) | 17 | 1.6 | 27.2 | 100 | Yes: 7 Iron Bar, 3 Leather | L22 |
| [Baseball Bat](https://last-day-on-earth-survival.fandom.com/wiki/Baseball_Bat) | 20 | 1.0 | 20 | 80 | No (loot only) | crates |
| [Machete](https://last-day-on-earth-survival.fandom.com/wiki/Machete) | 30 | 1.3 | 39 | 80 | Yes: 15 Iron Bar, 3 Pine Plank, 12 Leather | L52; airdrops, Weapon Crates, packs |
| [Hatchet](https://last-day-on-earth-survival.fandom.com/wiki/Hatchet) | 7 | 0.9 | 6.3 | 50 | Yes: 3 Pine Log, 3 Limestone | start |
| [Scythe](https://last-day-on-earth-survival.fandom.com/wiki/Scythe) | 60 | 0.7 | 42 | 30 | No | Crooked Creek Farm chest |
| [Hammer](https://last-day-on-earth-survival.fandom.com/wiki/Hammer) | 8 | 1.7 | 13.6 | 100 | No | loot |
| [Skull Crusher](https://last-day-on-earth-survival.fandom.com/wiki/Skull_Crusher) | 45 | 0.7 | 31.5 | 45 | Yes: 12 Iron Bar, 12 Nails, 2 Stone Brick, 5 Leather, 4 Duct Tape | L46 |

**Armor:**
- Thick 16 (6 on the Jacket), Reinforced 20 at durability 180, Tactical 24 (5/8/7/4), SWAT 32 (7/10/10/5), Kevlar 38 (8/12/12/6).
- Durability is 150 for most sets ([Armor and Armor Points](https://last-day-on-earth-survival.fandom.com/wiki/Armor_and_Armor_Points)).

---

## 8. Implementation list

**Owners (MVP_LAUNCH, checklist 13.4):**
- **The orchestrator** extracts and uploads meshes.
- **S2B** owns guns, gun loot, combat params and gun animation.
- **S1b** owns melee, armor, recipes and quests.

### 8.1 Meshes to extract and upload (orchestrator)

**For every mesh:**
- Stage the GLB under `art/zona/guns/` or `art/zona/melee/`, the approved upload directories already used for `zona_pistol_m9.glb`.
- Keep only the weapon. **Strip Zona's FPS arms**, which every animated pack carries as `arms`, `armmesh`, `Mannequin` or body meshes.
- Shrink textures to 1024.
- **Decimate to ≤ 8,000 triangles:** guns are seen small from the top-down camera, and they must hold 30 fps on mid-range phones.
- **Paint out stamped brand text** on every diffuse texture (slides, receivers, suppressors). Then confirm in a close render.
- Upload, add to `Art.kitNames`, `Art.uploaded` (yaw, axis, size), `Art.items` and `Art.held`, and **grade against the LDoE frame** before keeping (checklist §0, side-by-side rule).

| # | Kit name | Zona source | Keep | Strip | Source tris → target | Held length (studs) | Holster |
|---|---|---|---|---|---|---|---|
| 1 | `EO_DutyPistol` | `pistol_m9` (staged) | base, slide, mag, hammer, trigger | arms, shells, loose bullets | 7.8k → 6k | 1.15 | belt |
| 2 | `EO_HandCannon` | `desert_eagle` | all body parts | — | 12.8k → 6k | 1.4 | belt |
| 3 | `EO_PumpShotgun` | `benelli_m3` (§0) | base, forend, feeder, trigger | optic, silencer | 22k → 8k | 3.4 | back |
| 4 | `EO_HuntingRifle` | `bolt_action_rifle_7_62` | base, bolt, trigger, scope, wrap | bullet | 20k → 8k | 3.8 | back |
| 5 | `EO_MachinePistol` | `scorpion` | `CZScorpion` mesh | Mesh_Body, Cloths, Gloves, Watch, Skybox | 10.7k → 6k | 2.2 | belt |
| 6 | `EO_PatrolCarbine` | `ar15` | base, mag, sight, brake, foregrip | silencer, light | **102k → 8k** (heaviest) | 3.0 | back |
| 7 | `EO_AssaultRifle` | `ak74m` | `Ak` and `Mag_2` | arms | 23k → 8k | 3.3 | back |
| 8 | `EO_CompactRifle` | `9a91` | base, stock, butt, mag, trigger | **silencer** (the Marksman is our quiet gun), bullet | 11.2k → 6k | 2.6 | back |
| 9 | `EO_TacticalSMG` | `mp7a1` | the 3 `mp7a1_Object` slots | Viewer_Cube, Mannequin arms | 24k → 6k | 2.4 | back |
| 10 | ~~`EO_CombatShotgun`~~ | M2 (§0) | — | — | — | — | — |
| 11 | `EO_MarksmanRifle` | `sniper` | base, scope, glass, bolt, boltrear, cheekrest, mag, trigger, **silencer** | arms, bullet | 11.1k → 8k | 4.0 | back |
| 12 | `EO_AntiMaterielRifle` | `barrett` | body, mag, scope | — (bipod folded, if it is a separate node) | 48.6k → 8k | 4.4 | back |
| 13 | `EO_HardwoodBat` | `baseball_bat` | all | — | 2.7k | 2.8 | back |
| 14 | `EO_FieldKnife` | `knife_animated` (standalone knife copy) | `knife` | arms | 2.8k | 0.95 | belt |
| 15 | `EO_HandAxe` | `hatchet` | all | — | 5.3k | 1.6 | belt |
| 16 | `EO_HayFork` | `pitchfork` | `base` | arms | 1k | 3.7 | back |

**Already uploaded or on a branch:**
- `EO_WornPistol` (`service_pistol`), `EO_ScrapShotgun` (`sawnoffs`) and `EO_Machete` (`machete`).
- `EO_FlarePistol` (S2B branch, generated).
- `EO_TireIron` (`crowbar_01`) and `EO_RailMallet` (`sledgehammer_01`) on the launch branch.

**Icons:** 12 guns, 4 melee weapons, 8 armor pieces and 6 schematics.
- Render the 3D icons from the kit models, as the existing gun icons are.
- The six schematics share one blueprint-sheet base with the gun's silhouette overlaid.
- The 8 armor pieces need **worn visuals:**
  - Hidebound is dark oiled leather.
  - Riveted is dull plate with copper rivets.
  - Both follow the `Art.worn` recolour path from the launch branch, plus a helm accessory mesh for the Riveted Helm.

### 8.2 Credits

Add these lines to `CREDITS.md` and `Data/Credits.luau`, copied verbatim from each `license.txt`:

| Mesh | Credit |
|---|---|
| `pistol_m9` | "animated pistol" by DJMaesen |
| `desert_eagle` | "Desert Eagle" by ELIZION. **Our display name never uses the title**; the credit line must, because CC-BY requires the title |
| `benelli_m3` | "Benelli M3 Tactical" by Amapsis. Our display name never uses the title |
| `scorpion` | "Scorpion \| First Person Animations (2026 Remake)" by 1Matzh |
| `ar15` | "AR-15" by wafla |
| `ak74m` | "FPS AK-74m animations" by Cransh |
| `9a91` | "9A-91 Assault Rifle Gameready Lowpoly" by valterjherson1 |
| `mp7a1` | "MP7A1 Animations" by TheParaziT |
| `benelli_m3` | "Benelli M3 Tactical" by Amapsis |
| `sniper` | "sniper animated" by DJMaesen |
| `barrett` | "Barrett-M82 (Optimized)" by Gintoki1234 |
| `knife_animated` | "knife Animated" by DJMaesen |
| `pitchfork` | "pitchfork Animated" by DJMaesen |

**Every CC-BY entry:**
- carries "licensed under CC-BY-4.0" and a "Changes made" line: arms removed, decimated, textures resized, logos painted out
- lists real model names **only in the Credits panel**, never on an item

**CC0 (Poly Haven), credited anyway:** `bolt_action_rifle_7_62` (Mateusz Sadek), `baseball_bat` (Enrique Martín), `hatchet` (James Ray Cock, Ulan Cabanilla), `crowbar_01` (Alexander Otterbeck), `sledgehammer_01` (Poly Haven).

### 8.3 Data entries

| File | Change |
|---|---|
| `Data/Items.luau` | **12 guns** (§3.2): `category = "weapon"`, `equipSlot = "weapon"`, `tier` per §1, rarity uncommon (standard), rare (advanced), legendary (Anti-Materiel). **4 melee** (§4). **8 armor** (§5). **6 schematics** (`item.bp_*`, category `blueprint`, rarity epic). Remove `ammoItemId` from the 3 existing guns, and delete the ammo items in the no-ammo pass |
| `Data/Recipes.luau` | 11 gun recipes, 2 melee recipes (Hand Axe, Field Knife), 8 armor recipes (consuming the lower piece), and 6 schematic unlocks (`unlock = { kind = "item", itemId = "item.bp_*" }`, the `bp_reinforced` pattern). Workbench L2 / L3 known-recipe gate, as the Worn Pistol has |
| `Data/Quests.luau` | Unlock lists on `into_the_black`, `the_plans`, `copper_lines`, `walls_that_hold` and `padded_through` (standard guns); `padded_through` (Hidebound); `black_fog_regular` (Riveted); `heartwood` (Hand Axe); `scavenger` (Field Knife). `hold_the_line`'s rewards add `item.bp_patrol_carbine` |
| `Data/LootTables.luau` | §3.4 and §5 rows; the new `loot.schematics_advanced`; Brute and Retcher tables with SH-1 |
| `Data/Stations.luau` | Recycler salvage rows (§3.3) |
| `Art.luau` | §8.1 kit entries; `Art.held` axis, edge, grip, length, holster and drop per gun, read from front and side renders as for the existing two; `Art.worn` for Hidebound and Riveted |
| `Data/Products.luau` | Per [SHOP_CATALOG.md §9](SHOP_CATALOG.md#9-implementation-notes) |
| Sounds (`Art.sounds`) | One shot sound per class: pistol (existing), heavy pistol, shotgun (existing), pump rack, rifle, bolt cycle, auto loop, suppressed shot, .50 boom. Plus reload and dry-click (existing). From the licensed Creator Store packs already in use (PSE) |

### 8.4 Types and combat parameters

| Field (`Types.luau`) | Purpose |
|---|---|
| `FirearmStats.animClass: "pistol" \| "smg" \| "rifle" \| "shotgun"` | Picks the §8.5 clip set |
| `FirearmStats.mode: "single" \| "semi" \| "auto" \| "burst"` and `burst: { count: number, interval: number, cooldown: number }?` | The Patrol Carbine's 3-round burst; auto means fire while held at `fireInterval` |
| `FirearmStats.shellReload: number?` | Seconds per shell; firing cancels the reload (Pump and Combat Shotgun) |
| `FirearmStats.pierce: number?` | Extra targets a projectile passes through (Anti-Materiel 2) |
| `FirearmStats.aimMoveMultiplier: number?` | Walk speed while firing or aiming (Anti-Materiel 0.7) |
| `FirearmStats.aimLookAhead: number?` and `lockRange: number?` | The camera leans toward the aim, and soft-lock reaches further. Rifles 30 and 70; Marksman and Anti-Materiel 45 and 110 (CombatControl's `LOCK_RANGE` is 46 today) |
| `FirearmStats.recoilScale: number?` | Animation amplitude per class: pistol 1, heavy pistol 1.6, SMG 0.35, rifle 0.5, shotgun 1.2, .50 2.0 |
| `MeleeStats.backstabMultiplier: number?` | Field Knife 4 (overrides `Tuning.sneak.backstabMultiplier`) |
| `MeleeStats.structureMultiplier: number?` | Hand Axe 1.5 against build pieces (read by M2 raids) |
| `WeaponStats.noise: number?` | Melee noise override (Field Knife 6) |
| Weapon and armor `tier` up to **4** | `DataValidator` must accept 4. Check `Tuning.matchmaking.weights` so a tier-4 loadout lands one band above tier 3 (one band = 60 power, about one gear tier) |
| `ammoItemId` | Removed from `WeaponStats` with the no-ammo pass |

**Domain/Combat:**
- `sustainedRate` handles burst and shell reloads.
- Durability is paid per round fired, hit or miss (existing rule).
- A pierce round spends 1 durability, not one per target.

### 8.5 Animation classes (UAL, retargeted to R15)

**What exists:** S2B's retarget pipeline (`roblox/tools/ual`, `Data/UalClips`) already plays UAL's `Pistol_Aim_Neutral` (a two-handed hold), `Pistol_Shoot`, `Pistol_Reload`, `Hit_Chest` and `Death01`. CombatControl converts them per joint and registers them at runtime, with no animation upload.

**What's missing:** UAL Standard has **no rifle or shotgun clips**. The full clip list is in Zona's GLB: `Pistol_Aim_Down`, `Pistol_Aim_Neutral`, `Pistol_Aim_Up`, `Pistol_Idle_Loop`, `Pistol_Reload`, `Pistol_Shoot`, plus melee, roll and locomotion. So every class is the UAL pistol set plus a **hand-keyed additive pose layer** in CombatControl's `SPECS` (the same mechanism as `swing`, `heavy` and `draw`).

| Class | Guns | Base UAL clips | Additive layer (hand-keyed) | Recoil |
|---|---|---|---|---|
| **pistol** | Worn Pistol, Flare Pistol, Duty Pistol, Hand Cannon | `Pistol_Idle_Loop` (carry), `Pistol_Aim_Neutral`, `Pistol_Shoot`, `Pistol_Reload` (as today) | none. The Worn Pistol keeps its jam-clear on `Pistol_Reload` at 1.4 s | `Pistol_Shoot` per shot; the Hand Cannon at ×1.6 plus a 0.1 s torso kick |
| **smg** | Machine Pistol, Tactical SMG | `Pistol_Aim_Neutral`, `Pistol_Reload` at ×1.2 speed | left hand forward to the fore-grip or mag (LeftUpperArm and LeftLowerArm offset), elbows tucked | `Pistol_Shoot` at ×0.35, retriggered every 0.25 s while firing (not every round) |
| **rifle** | Hunting Rifle, Patrol Carbine, Assault Rifle, Compact Rifle, Marksman Rifle, Anti-Materiel Rifle | `Pistol_Aim_Neutral`, `Pistol_Reload` | **shoulder mount:** right upper arm lowered and drawn back (stock at the shoulder), left arm extended under the handguard, head canted 8°. **Bolt guns** (Hunting, Marksman) add a 0.35 s bolt cycle: right hand to the bolt and back, after each shot. **Heavy** (Anti-Materiel): a step back on fire, slower raise | `Pistol_Shoot` at ×0.5 per burst or shot; ×2.0 for the Anti-Materiel |
| **shotgun** | Scrap Shotgun, Pump Shotgun, Combat Shotgun | as rifle | the rifle shoulder mount. **Pump:** a 0.25 s left-arm rack stroke after each shot. **Break-open** (Scrap Shotgun): existing. **Shell reloads:** `Pistol_Reload`'s insert segment (about frames 6–14) looped per shell | `Pistol_Shoot` at ×1.2 |

**Other rules:**
- The `Pistol_Aim_Up` and `Pistol_Aim_Down` clips are unused (the camera is top-down).
- The idle carry for long guns is `Pistol_Idle_Loop` with the rifle layer at 50% weight (muzzle down).
- All clips fall back to the hand-keyed `aim` spec when a rig lacks a UAL part (existing behaviour).
- **Melee additions:**
  - Hardwood Bat, Hay Fork and Hand Axe use the existing `swing` and `heavy` specs.
  - The Hay Fork adds a forward thrust variant.
  - The Field Knife uses a quick 0.3 s jab (`Punch_Jab` retargeted from UAL) and a backstab lunge.
  - This is S1b's checklist 13.4 per-class set.

### 8.6 Tests and validator

- **`DataValidator`:**
  - Every gun has `firearm.animClass` and has no `ammoItemId`.
  - Every `tier` is 1–4.
  - Every schematic unlocks exactly one recipe.
  - Every armor recipe consumes the lower piece in the same slot.
  - Every Zona-sourced kit has a `Data/Credits` entry.
- **`Pacing.spec`:**
  - Each gun lasts 2–4 Black runs under §6.5's model.
  - The free reference player crafts a standard gun by day 10 and no advanced gun before day 13.
  - Riveted fog resist (0.67) is below `maxResist` (0.8).
- **`Combat.spec`:** shots to kill for one cell per class against §6.2 (for example, the Duty Pistol needs 5 shots for a Black Runner), and no PvP hit above 60.

### 8.7 Doc edits this implies (orchestrator; not made here)

- **ECONOMY §4.2 and §10.2:** the standard guns, SMG and Carbine are v0.1 per ARSENAL. M2's Ember Steel recipes become the guns' M2 re-tune. Plated armor consumes Riveted, not Padded.
- **GAME_DESIGN "Combat and the arsenal":** the ladder names from §1, and the rollout (standard and advanced guns in v0.1; PvP stays M2).
- **MVP_LAUNCH:** "Combat with melee, bow, Pipe Pistol, Scrap Shotgun and Flare Pistol, plus the Ammo Press" becomes the §1 roster with no Ammo Press.
- **DECISIONS:** a row for this file and for the Riveted set.

---

## 9. Risks and open items

| Risk | Mitigation |
|---|---|
| The `ar15` (102k tris) and `barrett` (48.6k) are heavy | Decimate before upload (§8.1). If an 8k decimation reads badly in the side-by-side, fall back to `sniper50` for the jackpot, or `aks74u` for the carbine |
| Brand text baked into textures | §8.1 paint-out step, plus a close-up render checked at review |
| SH-1 (Brute, Retcher) isn't built yet | §6 still holds without them: their rows are the upper bound. The schematic and Anti-Materiel drop rates then come from Depot loot only, about 25% slower |
| Chapter 3 quests live only on the launch branch | Fallback in §3.3: every standard gun unlocks at `quest.into_the_black` |
| The `hollowTierScale` from ECONOMY §6.4 may not be in `Tuning` yet | The §6.2 Light column is unaffected; the Dense and Black columns assume it, as the pacing model does |
