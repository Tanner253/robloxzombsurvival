# Shop catalog v0.1 (binding spec)

**Status:** binding, written 2026-11-08 by the weapons and monetization designer.

**Why this file exists:** the developer said the shop "went lite on listings". This is the full LDoE-style v0.1 catalog: **32 SKUs in six tabs**, priced from the playbook's ladder and checked against a free-play value curve.

**Companion file:** [ARSENAL.md](ARSENAL.md) defines every gun, melee weapon and armor piece sold here.

**Precedence:**
- [DECISIONS.md](DECISIONS.md) and [LDOE_PARITY.md](LDOE_PARITY.md) win over this file.
- This file replaces the SKU tables in [MVP_LAUNCH.md](MVP_LAUNCH.md) "Monetization v0.1" (reconciled SKU by SKU in §8) and the §8.6 pack sketches in [ECONOMY.md](ECONOMY.md).
- **Money decisions stay with the developer's veto** (full-creative-control rule). §8 flags the one price change to an existing SKU.

**Sources:**
- [Monetization playbook](research/ldoe-monetization-playbook.md): the price ladder (§4), levers, triggers (§3) and value rule (§7.2 item 5).
- `Data/Products.luau`, `Tuning.prices` and `Tuning.embers` on `main`.
- [ECONOMY.md](ECONOMY.md) chains and the §9 pacing model.
- The recordings: `rec8_shop_073s`, `rec8_sheet3` and `rec8_sheet4`, LDoE's Best, Equipment and Building tabs ([NOTES](reference/ldoe-recordings/NOTES.md)).
- LDoE wiki pack pages (§7).

## 0. Orchestrator rulings (2026-11-08; these override any row below)

1. **Reinforced Room Kit at 4,499, a whole 3×3 room: approved.** It matches LDoE, whose Metal Room 3×3 sells at $99.99, and the flow review's F-12 ("size it to a full room"). The kit also includes the **Reinforcement Plans** (`item.bp_reinforced`), so a buyer can place what they paid for. This is the one exception to "a pack never teaches a recipe". The developer keeps the veto; if they use it, the fallback in §8 applies.
2. **Renames approved:**
   - Pack of Weapon Parts → **Gun Parts Pack**
   - Heavy Equipment → **Heavy Loadout**
   Both drop LDoE's exact titles. **Raider Arms is repriced to 1,199** (the ladder).
3. **Heavy Loadout:** the Combat Shotgun is M2 (ARSENAL §0), so its slot becomes `item.tactical_smg` 1. Recompute its value against the rung.
4. **Owner:** S1b, the home and shop session, builds this catalog. There is no "S3".
5. **Unlock-gated cards** (flow review F-12, F-27). A card whose contents the player can't use yet shows greyed, with its lock line: for example, "+1 Smelter" until the plot is at its Smelter limit. Guns and armor are always usable (no ammo; P2W accepted), so weapon and armor packs are never greyed.

---

## Contents
1. [Summary](#1-summary)
2. [Shop rules](#2-shop-rules)
3. [The catalog by tab](#3-the-catalog-by-tab)
4. [Coverage check](#4-coverage-check)
5. [Price-to-value sanity](#5-price-to-value-sanity)
6. [Moment-of-need offers](#6-moment-of-need-offers)
7. [Sales, timers and the Roblox rules](#7-sales-timers-and-the-roblox-rules)
8. [Reconciliation with MVP_LAUNCH](#8-reconciliation-with-mvp_launch)
9. [Implementation notes](#9-implementation-notes)
10. [Deferred SKUs](#10-deferred-skus)

---

## 1. Summary

| Tab | SKUs | Robux range | What it sells |
|---|---|---|---|
| **Best** | 1 (+ a free daily crate + up to 3 featured cards) | 99 | The first-purchase offer; featured cards are SKUs from other tabs, picked by the player's state (§2.6) |
| **Equipment** | 14 | 79–2,499 | Weapon packs per class, armor per set, mixed loadouts, gun parts, iron tools |
| **Building** | 6 | 79–4,499 | Room kits for all three tiers, the Scrap-tier crate, "+1 can be placed" capacity |
| **Supplies** | 5 | 79–149 | Death refill, raw materials, meds, food and water, Energy; Trail Rations priced in Embers |
| **Embers** | 4 | 149–1,699 | The premium currency in four sizes |
| **Passes** | 2 | 199–399 | Pack Expansion, VIP Lounge |
| **Total** | **32** | **79–4,499** | |

**Prices on the ladder:**
- Every price is a rung of the playbook's ladder: 79 / 99 / 149 / 199 / 249 / 399 / 799 / 1,199 / 1,699 / 2,499 / 4,499.
- Each fits one Robux pack or a pair, so nothing is stranded (playbook §4).

**Value rises with size:**
- Small packs give about 1.55 free-play hours per 100 Robux; the 4,499 room kit gives 2.59.
- In Robux per hour, that is about 65 R$/h down to 39 R$/h (§5).

---

## 2. Shop rules

### 2.1 Repurchasable and the "never sell" list

**Repurchasable** (DECISIONS 2026-11-08, "Every pack is repurchasable"):
- Every developer product here can be bought again, because everything in it is used up or wears out. Guns count shots, melee counts hits, armor counts hits taken, and tools count gathers; meds, food and materials are consumed.
- **Only these are once-only or permanent:**
  - the Firestarter Kit (once, for never-payers)
  - the two capacity packs (permanent, one each)
  - the two game passes
- Bought items arrive at **full durability, with no repair path** (LDOE_PARITY #21), so the next purchase is the refill.

**Never sold** (DECISIONS; playbook §5.4):
- shields
- raid or PvP immunity
- locked-stash capacity
- random boxes (so no odds disclosure is needed: every SKU has fixed, listed contents)

**Sold capacity stays raidable:**
- The capacity packs add **station placements**, not storage.
- The Pack Expansion adds **carried** backpack slots, which drop on death like the rest of the bag.

**Delivery** (DECISIONS: purchases are raid-proof; playbook rule 2):
- Everything goes to the raid-proof inbox (DECISIONS: Item inbox).
- Building and crafting draw from it directly.
- Items are raid-proof in the inbox and **lootable once carried into a run**.
- `ProcessReceipt` is idempotent (playbook rule 9).

### 2.2 Tags

Each card carries one ribbon: Limited, then Hot, then Popular, then New, in that priority.

| Tag | Rule |
|---|---|
| **Limited** | Only with a real purchase limit **and** an accurate timer: the Firestarter Kit, and live sale windows (§7). Never decorative |
| **Hot** | The top-converting card in its slot: Scout's Kit, Gunrunner Pack, Raider Arms, Anti-Materiel Crate, Reinforced Room Kit (as LDoE tags Genesis Weapon Pack and Scout's Equipment, rec8_sheet4) |
| **Popular** | The steady sellers: Padded and Hidebound armor, Builder's Crate, Gun Parts Pack, Medic's Satchel, Heavy Loadout, Ember Chest, VIP Lounge |
| **New** | Any SKU in its first 14 days live. At launch that is every card without a higher tag |

### 2.3 Purchase limits and timers

| Kind | Limit | Timer |
|---|---|---|
| Firestarter Kit | 1 | 48 h from the first win; accurate; never restarts |
| Capacity packs | 1 each | none |
| Game passes | 1 each | none |
| Everything else | unlimited | none, except a sale window's own accurate countdown (§7) |

### 2.4 VIP points

- Every card shows the **VIP points** it earns (rec8 badge; LDOE_PARITY #53): 1 point per 10 Robux.
- The ladder itself is M3. In v0.1, any purchase opens the VIP Lounge for 7 days (`Tuning.embers.vipTrialDays`).

### 2.5 Shop UX

- LDoE card style (rec8): a banner carousel, scrolling cards, the bottom tab icons with badges, INBOX and VIP at the bottom-left, balances at the bottom-right (LDOE_PARITY #53).
- Calls to action are neutral: "View offer", "See price", "Open shop" (playbook §3, Roblox guidance for minors).

### 2.6 The Best tab

**The Best tab shows:**
1. **The Firestarter Kit,** while the player is eligible (never paid, inside the 48 h window).
2. **The Daily Supply Crate:** a FREE claim once a UTC day, like LDoE's free box (rec8). Fixed contents: 1 Field Dressing, 2 Boiled Water and 10 Timber. It isn't a product and isn't counted in the 32.
3. **Up to 3 featured cards,** each an existing SKU, chosen by state:
   - 72 h after **the Scrap tier unlocks:** Builder's Crate and Scrap Room Kit.
   - 72 h after **first entering Dense fog:** Gunrunner Pack.
   - 72 h after **first entering Black fog:** Raider Arms.
   - 72 h after **reading the Reinforcement Plans:** Reinforced Room Kit.
   - Otherwise: the Ember Chest, then the best-converting Equipment card of the last 7 days.

**Featured cards carry no countdown.** A feature is a placement, not a sale (playbook §3: "Best tab for 72 h (no countdown)").

---

## 3. The catalog by tab

**How to read the tables:**
- Contents are item IDs × counts.
- "Value" is free-play hours under §5.
- "VIP pts" is price ÷ 10.
- "Rebuy" is whether the SKU is repurchasable.

### 3.1 Best (1 SKU)

| SKU (ID) | Contents | R$ | Tag | Limit / timer | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Firestarter Kit** (`product.starter_offer`, existing) | `item.scrapblade` 1, `item.padded_hood` 1, `item.padded_vest` 1, `item.field_dressing` 10, `item.hearth_stew` 5, `item.ember_tonic` 3, `item.pack_frame` 1, `item.rations` 5, **a Scrap 3×3 room** = `Kits.room(BuildPieces, 2)` (`item.timber` 189, `item.rope` 14, `item.plank` 154, `item.stone_block` 84, `item.scrap_plate` 54, `item.rivets` 4), and 100 Embers. **Unchanged** | 99 | Limited | 1; never-payers only; 48 h after the first win (`Tuning.embers.firstPurchaseHours`) | No | 10 |

### 3.2 Equipment (14 SKUs)

**Weapon packs, one per class:**

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Gunrunner Pack**, sidearms (`product.gunrunner`) | `item.duty_pistol` 1, `item.field_dressing` 3 | 249 | Hot | — | Yes | 25 |
| **Shotgun Pack** (`product.shotgun_pack`) | `item.pump_shotgun` 1, `item.field_dressing` 4 | 399 | New | — | Yes | 40 |
| **SMG Pack** (`product.smg_pack`) | `item.machine_pistol` 1, `item.tactical_smg` 1, `item.field_dressing` 6 | 799 | New | — | Yes | 80 |
| **Rifle Pack** (`product.rifle_pack`) | `item.hunting_rifle` 1, `item.patrol_carbine` 1, `item.field_dressing` 2 | 799 | New | — | Yes | 80 |
| **Marksman Pack** (`product.marksman_pack`) | `item.marksman_rifle` 1, `item.hunting_rifle` 1, `item.hidebound_cap` 1, `item.hidebound_coat` 1, `item.hidebound_leggings` 1, `item.field_dressing` 5 | 1,199 | New | — | Yes | 120 |
| **Anti-Materiel Crate**, the Black-tier jackpot (`product.anti_materiel_crate`) | `item.anti_materiel_rifle` 1, `item.compact_rifle` 1, `item.riveted_helm` 1, `item.trigger_group` 4, `item.coil_spring` 4, `item.field_dressing` 10 | 1,699 | Hot | — | Yes | 170 |

**Armor packs, one per set.** Reedweave is sold in the Scout's Kit, below.

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Padded Armor Pack** (`product.padded_armor`) | `item.padded_hood`, `item.padded_vest`, `item.padded_leggings`, `item.padded_boots` (1 each), `item.field_dressing` 5 | 199 | Popular | — | Yes | 20 |
| **Hidebound Armor Pack** (`product.hidebound_armor`) | `item.hidebound_cap`, `item.hidebound_coat`, `item.hidebound_leggings`, `item.hidebound_boots` (1 each) | 399 | Popular | — | Yes | 40 |
| **Riveted Armor Pack** (`product.riveted_armor`) | `item.riveted_helm`, `item.riveted_cuirass`, `item.riveted_legguards`, `item.riveted_boots` (1 each), `item.field_dressing` 6 | 1,199 | New | — | Yes | 120 |

**Mixed loadouts:**

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Scout's Kit**: light loadout and the Reedweave set (`product.scout_kit`) | `item.reedweave_cap`, `item.reedweave_shirt`, `item.reedweave_trousers`, `item.reedweave_wraps` (1 each), `item.tire_iron` 1, `item.field_dressing` 1, `item.boiled_water` 1 | 79 | Hot | — | Yes | 8 |
| **Raider Arms**: Special Forces-style (`product.raider_arms`) | Hidebound set (4 pieces), `item.hand_cannon` 1, `item.patrol_carbine` 1, `item.field_dressing` 6 | 1,199 | Hot | — | Yes | 120 |
| **Heavy Loadout** (`product.heavy_loadout`) | Riveted set (4 pieces), `item.assault_rifle` 1, `item.tactical_smg` 1 (§0; was the Combat Shotgun), `item.rail_mallet` 1, `item.field_dressing` 20, `item.hearth_stew` 10, `item.trigger_group` 3, `item.coil_spring` 4 | 2,499 | Popular | — | Yes | 250 |

**Parts and tools:**

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Gun Parts Pack** (`product.gun_parts`) | `item.trigger_group` 2, `item.steel_pipe` 2, `item.coil_spring` 3, `item.pitch_glue` 2, `item.copper_wire` 1 | 149 | Popular | — | Yes | 15 |
| **Iron Tools Pack** (`product.iron_tools`) | `item.forged_hatchet` 1, `item.forged_pick` 1, `item.pitch_glue` 4 | 149 | New | — | Yes | 15 |

**LDoE parallels** (rec8_sheet4; §7 wiki pages):
- Scout's Equipment $0.99 (Hot) ↔ Scout's Kit.
- Genesis Weapon Pack $2.99 (Hot) and Weapons $0.99 ↔ our weapon packs.
- Special Forces Pack $2.99 ↔ Raider Arms.
- Pack of Weapon Parts $1.99 ↔ Gun Parts Pack.
- Heavy Equipment $24.99 ↔ Heavy Loadout.

### 3.3 Building (6 SKUs)

**Room kits:**
- They are computed from build data (`Domain/Kits`), so they stay exact when building costs retune.
- A 3×3 room is 9 foundations, 11 walls, a doorway and a door (`Kits.ROOM_3X3`).

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Timber Room Kit 3×3** (`product.room_kit_timber`) | `Kits.room(BuildPieces, 1)` plus two Timber Crates' materials = `item.timber` 205, `item.rope` 22 | 79 | New | — | Yes | 8 |
| **Builder's Crate** (`product.builders_crate`, existing; the Scrap-tier unlock offer) | `item.rivets` 16, `item.scrap_plate` 5, `item.plank` 30, `item.stone_block` 12. **Unchanged** | 399 | Popular | — | Yes | 40 |
| **Scrap Room Kit 3×3** (`product.room_kit_scrap`) | `Kits.room(BuildPieces, 2)` = `item.timber` 189, `item.rope` 14, `item.plank` 154, `item.stone_block` 84, `item.scrap_plate` 54, `item.rivets` 4 | 1,699 | New | — | Yes | 170 |
| **Reinforced Room Kit 3×3** (`product.room_kit_reinforced`, existing ID) | **The whole Scrap → Reinforced step for a 3×3,** `Kits.roomStep(BuildPieces, 2, 3)` = `item.stone_block` 250, `item.scrap_plate` 126, `item.rivets` 90, `item.ironbark_plank` 91, `item.copper_wire` 28, `item.coil_spring` 1 | **4,499** (was 1,699; §8) | Hot | — | Yes | 450 |
| **+1 Smelter can be placed** (`product.cap_smelter`) | Smelter placement max 2 → 3, permanent | 399 | — | 1 | No (permanent) | 40 |
| **+1 Recycler can be placed** (`product.cap_recycler`) | Recycler placement max 1 → 2, permanent | 399 | — | 1 | No (permanent) | 40 |

**LDoE parallels** (rec8_sheet4):
- Stone Room 3×3 $9.99 and Metal Room 3×3 $99.99, both whole-room kits ([Brick Room 3X3](https://last-day-on-earth-survival.fandom.com/wiki/Brick_Room_3X3)).
- "+1 max furnace can be placed" and "+1 max recycler can be placed", $4.99 each.

### 3.4 Supplies (5 SKUs)

| SKU (ID) | Contents | R$ | Tag | Limit | Rebuy | VIP pts |
|---|---|---|---|---|---|---|
| **Scavenger's Kit** (`product.scavenger_kit`, existing; the death refill) | `item.spiked_club` 1, `item.padded_hood` 1, `item.field_dressing` 2, `item.hearth_stew` 2, `item.boiled_water` 2 | 79 | New | — | Yes | 8 |
| **Supply Bundle** (`product.resource_pack`, existing) | `item.timber` 60, `item.stone` 60, `item.ironstone` 30, `item.plank` 10, `item.scrap_plate` **1** (was 2) | 99 | New | — | Yes | 10 |
| **Field Provisions**: food and water (`product.field_provisions`) | `item.cooked_meat` 15, `item.boiled_water` 15, `item.hearth_stew` 5, `item.sealed_tin` 2 (about two-thirds of a day's hunger and thirst, ECONOMY §8.4) | 99 | New | — | Yes | 10 |
| **Medic's Satchel** (`product.medic_satchel`) | `item.field_dressing` 10 | 149 | Popular | — | Yes | 15 |
| **Energy Refill** (`product.energy_refill`, existing) | +100 Energy, overfilling to the 400 hard cap. **Unchanged** | 99 | — | — | Yes | 10 |

**Trail Rations** (`item.rations`, +60 Energy, or pays AUTO and TAKE ALL):
- They sit in this tab as an **Ember-priced** card, not a Robux SKU: **20 Embers each, 5 for 90** (`Tuning.embers.ration` and `rationsFive`).
- This is LDoE's model: Rations replaced coins for Energy refills ([Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations)).

### 3.5 Embers (4 SKUs)

| SKU (ID) | Embers | R$ | Embers per R$ | Bonus vs the Pouch | Tag | Rebuy | VIP pts |
|---|---|---|---|---|---|---|---|
| **Ember Pouch** (`product.embers_50`, existing) | 50 | 149 | 0.336 | — | New | Yes | 15 |
| **Ember Satchel** (`product.embers_140`) | 140 | 399 | 0.351 | +5% | New | Yes | 40 |
| **Ember Chest** (`product.embers_300`, existing) | 300 | 799 | 0.375 | +12% | Popular | Yes | 80 |
| **Ember Crate** (`product.embers_680`) | 680 | 1,699 | 0.400 | +19% | New | Yes | 170 |

These are the playbook's §7.2 bonus ladder, which names the currency "Gold"; ours is Embers. The Strongbox (4,499 R$, 1,900 Embers) waits for M2 (§10).

### 3.6 Passes (2 SKUs)

| SKU (ID) | Grants | R$ | Tag | Limit | VIP pts |
|---|---|---|---|---|---|
| **Pack Expansion** (`product.pack_expansion`, game pass, existing) | +5 backpack slots, permanent (carried, so lootable) | 199 | — | 1 | 20 |
| **VIP Lounge** (`product.vip_lounge`, game pass, existing) | Haven VIP Lounge for good, a flame aura, +40 Energy cap, a daily fixed VIP crate (1 stew, 1 water, 1 dressing; a Trail Ration every 7th day in a row) | 399 | Popular | 1 | 40 |

---

## 4. Coverage check

| Required | SKU(s) |
|---|---|
| Weapon pack: sidearms | Gunrunner Pack (249) |
| Weapon pack: shotguns | Shotgun Pack (399) |
| Weapon pack: rifles | Rifle Pack (799) |
| Weapon pack: SMGs | SMG Pack (799) |
| Weapon pack: marksman | Marksman Pack (1,199) |
| Weapon pack: Black-tier jackpot | Anti-Materiel Crate (1,699) |
| Armor pack per set | Reedweave → Scout's Kit (79); Padded Armor Pack (199); Hidebound Armor Pack (399); Riveted Armor Pack (1,199) |
| Mixed loadouts | Scout's Kit (79), Raider Arms as the Special Forces-style pack (1,199), Heavy Loadout (2,499) |
| Weapon parts | Gun Parts Pack (149); parts are also in the Anti-Materiel Crate and the Heavy Loadout |
| Tools (iron) | Iron Tools Pack (149) |
| Medic | Medic's Satchel (149) |
| Food and water | Field Provisions (99) |
| Room kits, 3 tiers | Timber (79), Scrap (1,699), Reinforced (4,499); plus the Builder's Crate (399) |
| Station and capacity | +1 Smelter (399), +1 Recycler (399) |
| Embers bundles (4–5 sizes) | Pouch 149, Satchel 399, Chest 799, Crate 1,699 |
| Energy and Rations | Energy Refill (99); Trail Rations in Embers (20, or 5 for 90) |
| Game passes | VIP Lounge (399), Pack Expansion (199) |
| Starter offer | Firestarter Kit (99) |
| Moment-of-need offers | §6 |

---

## 5. Price-to-value sanity

### 5.1 Unit values

**"Free-play minutes per unit"** is what a free player spends to have one, with station time counted because the station is the throttle (ECONOMY §9.2). The values come from three places:
- the `Data/Products.luau` header and `Tuning.embers.fillUp` (40 Embers = 1 grind-hour, so 1 Ember = 1.5 minutes)
- the ECONOMY §2 chains
- **one new assumption, for the rare parts**

| Unit | Minutes | Basis |
|---|---|---|
| Timber, stone, scrap; sticks and fiber; ironstone | 0.3; 0.2; 0.4 | Raw, gathered in bulk: ECONOMY §9.3's day 1 gathers about 650 raw units in 150 minutes, alongside building, cooking and hunting |
| Cord (`item.rope`); Reedcloth | 0.6; 3 | 2 fiber by hand; 2 fiber at the Workbench, 2 m (fill-up 2 Embers) |
| Hewn Plank; Stone Block; Iron Ingot; Pitch Glue | 3; 4; 4.5; 4.5 | Products header; fill-up 2 / 3 / 3 / 3 Embers |
| Rivets | 12 | Products header (fill-up 8) |
| Scrap Plate; Ironbark Plank; Copper Wire | 20 each | Products header: the Workbench and Saw Bench L2 throttles (fill-up 13) |
| Tanned Leather | 6 | Hide from deer or wolves, plus tanning (Inference) |
| **Coil Spring; Steel Pipe; Brass Gear; Trigger Group** | **7; 16; 25; 35** | **Assumption (ARSENAL §6.5).** Half of an 18-minute Deepcut Pit run, divided by that run's yield of the part (§7.5: 1.25 / 0.55 / 0.36 / 0.26). Half the run is charged because ore and other parts come with it |
| Field Dressing; Hearth Stew; Boiled Water; Fire-Roasted Venison; Sealed Tin | 15; 6; 2; 2; 3 | 5 Reedcloth; ECONOMY §8.4 cooking chains |
| Trail Ration; Ember | 30; 1.5 | 20 Embers (`Tuning.embers.ration`); the fill-up rate |
| Anti-Materiel Rifle (loot only) | 970 (16 h) | Valued at 1.6 Marksman Rifles (ARSENAL §3.3) |

Every gun, melee weapon and armor piece is valued at its recipe (ARSENAL §3.3, §4 and §5). For example:
- Duty Pistol 3.6 h, Patrol Carbine 9.1 h, Marksman Rifle 10.1 h.
- Armor sets: Padded 2.1 h, Hidebound 7.7 h, Riveted 21.5 h.

### 5.2 Every SKU against the curve

**The target curve** extends the playbook's value rule (§7.2 item 5: small about 1.5, medium about 1.6, large about 1.8–1.9 grind-hours per 100 R$) across the whole ladder:

| R$ | 79 | 99 | 149 | 199 | 249 | 399 | 799 | 1,199 | 1,699 | 2,499 | 4,499 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Target hours per 100 R$ | 1.50 | 1.55 | 1.60 | 1.65 | 1.70 | 1.75 | 1.85 | 1.90 | 2.00 | 2.10 | 2.30 |

**Bigger packs get a better rate:** the median hours per 100 R$ at each price rung rises the whole way up.

| SKU | R$ | Value (free-play h) | h per 100 R$ | R$ per hour | vs target |
|---|---|---|---|---|---|
| Scout's Kit | 79 | 1.15 | 1.46 | 69 | −3% |
| Scavenger's Kit | 79 | 1.22 | 1.55 | 65 | +3% |
| Timber Room Kit 3×3 | 79 | 1.25 | 1.58 | 64 | +5% |
| Supply Bundle | 99 | 1.63 | 1.65 | 61 | +6% |
| Field Provisions | 99 | 1.60 | 1.62 | 62 | +4% |
| Gun Parts Pack | 149 | 2.53 | 1.70 | 59 | +6% |
| Iron Tools Pack | 149 | 2.45 | 1.64 | 61 | +3% |
| Medic's Satchel | 149 | 2.50 | 1.68 | 60 | +5% |
| Padded Armor Pack | 199 | 3.36 | 1.69 | 59 | +2% |
| Gunrunner Pack | 249 | 4.38 | 1.76 | 57 | +3% |
| Shotgun Pack | 399 | 7.13 | 1.79 | 56 | +2% |
| Builder's Crate | 399 | 7.17 | 1.80 | 56 | +3% |
| Hidebound Armor Pack | 399 | 7.71 | 1.93 | 52 | +10% |
| Rifle Pack | 799 | 15.00 | 1.88 | 53 | +1% |
| SMG Pack | 799 | 15.15 | 1.90 | 53 | +2% |
| Raider Arms | 1,199 | 23.03 | 1.92 | 52 | +1% |
| Riveted Armor Pack | 1,199 | 23.03 | 1.92 | 52 | +1% |
| Marksman Pack | 1,199 | 23.27 | 1.94 | 52 | +2% |
| Scrap Room Kit 3×3 | 1,699 | 33.18 | 1.95 | 51 | −2% |
| Anti-Materiel Crate | 1,699 | 33.19 | 1.95 | 51 | −2% |
| Heavy Loadout | 2,499 | 51.43 | 2.06 | 49 | −2% |
| Reinforced Room Kit 3×3 | 4,499 | 116.45 | 2.59 | 39 | **+13%**: the store's value anchor, as LDoE's room kits are |
| Firestarter Kit | 99 | 45.98 | 46.45 | 2 | about 30×, by design (below) |

**Rung medians (hours per 100 R$):** 79: 1.55 → 99: 1.63 → 149: 1.68 → 199: 1.69 → 249: 1.76 → 399: 1.80 → 799: 1.89 → 1,199: 1.92 → 1,699: 1.95 → 2,499: 2.06 → 4,499: 2.59.

**Rulings:**
- **Every material SKU is within ±10% of its rung's target,** except the Reinforced Room Kit (+13%). That one is deliberate: it is the biggest card, it should be the best rate in the store, and it is the "room kit" story LDoE players tell ([playbook §2.5](research/ldoe-monetization-playbook.md)).
- **The Firestarter Kit is about 30× the curve.** The playbook targets 10–20× for the non-payer offer; LDoE's Legendary pack was about 100×.
  - It is once-only and never-payers-only, and its contents are already built and decided (`Products.luau`, playbook §6.1), so it is left unchanged.
  - The Scrap room is about 33 of its 46 hours. If conversion data says it cannibalizes the Scrap Room Kit, the lever is to swap that room for a Timber room plus a Duty Pistol (about 5 h, 5×).

### 5.3 Exempt SKUs: currency, time and permanents

These are priced against each other, not against the materials curve:

| SKU | Basis | Check |
|---|---|---|
| Embers (4 sizes) | 40 Embers = 1 grind-hour. Pouch 1.25 h (0.84 h per 100 R$), Satchel 3.5 h (0.88), Chest 7.5 h (0.94), Crate 17 h (1.00) | **By design below the bundle curve**, so bundles always look like the better deal and Fill Up wins on immediacy (playbook §7.2 item 5). The rate still improves with size |
| Energy Refill (+100) | 100 Energy = 1.67 Trail Rations = 33 Embers, about 0.84 Ember-hours, about 0.84 h per 100 R$ | On the Ember ladder (0.34 Embers per R$, equal to the Pouch) |
| Trail Rations | 20 Embers, 5 for 90 | −10% for five |
| +1 Smelter, +1 Recycler | Permanent throughput: +50% Smelter and +100% Recycler capacity on a full plot, for good | LDoE $4.99 parity (rec8_sheet4) |
| Pack Expansion, VIP Lounge | Permanent conveniences (playbook §6.1) | Unchanged |

---

## 6. Moment-of-need offers

**Frequency and surface** (playbook §3, binding):
- At most one modal a session, at login, chosen by the player's state; never in the first session before the first win.
- Contextual chips have no session cap, but each trigger shows at most once per 24 h.
- Never during combat or a run. Offers appear at home, on the map, on the death screen, on the loading screen (one card, LDOE_PARITY #43) and in the inbox.

| Trigger | Condition | Surface | SKU |
|---|---|---|---|
| First win | First night survived or first extraction; never purchased | Full-screen card, then the Best tab for 48 h | **Firestarter Kit** (99) |
| Out of Energy | Run pressed with Energy below its cost | Run/Walk panel, Refill button | **Energy Refill** (99), or 2 Trail Rations in Embers |
| Missing materials | Any craft, build or upgrade with a shortfall | The have/need row: Fill Up in Embers | Fill Up; if Embers are short, **Ember Pouch** (149) for a shortfall up to 50, **Ember Chest** (799) above that |
| Waiting on a timer | A station job with 2+ min left | Station row | Speed-up in Embers (`Tuning.embers.speedUp*`) |
| Death in Light fog | Death screen | One chip | **Scavenger's Kit** (79) |
| Death in Dense fog | Death screen | One chip | **Gunrunner Pack** (249) |
| Death in Black fog | Death screen | One chip | **Raider Arms** (1,199) |
| Melee weapon broke | The break toast during a run; offered after extraction or on the map | Toast chip | **Scavenger's Kit** (79) |
| Gun broke | Same | Toast chip | That gun's class pack: pistol → **Gunrunner**; shotgun → **Shotgun Pack**; rifle → **Rifle Pack**; SMG → **SMG Pack**; Marksman → **Marksman Pack** |
| Gun re-craft short of a Trigger Group, Steel Pipe or Spring | Craft panel | Fill-up row chip | **Gun Parts Pack** (149) |
| Armor piece broke | Break toast | Toast chip | The set's pack: Reedweave → **Scout's Kit**; Padded → **Padded Armor Pack**; Hidebound → **Hidebound Armor Pack**; Riveted → **Riveted Armor Pack** |
| Tool broke with no spare | Break toast | Toast chip | **Iron Tools Pack** (149) |
| Low HP and the meds button empty | Meds button (LDOE_PARITY #1) | Chip on the button | **Medic's Satchel** (149) |
| Hunger or thirst at 20 or below with none in the bag | The pulsing HUD icon (LDOE_PARITY #2) becomes tappable | Offer card | **Field Provisions** (99) |
| Inventory full | A pickup is refused | "Inventory full" toast | **Pack Expansion** (199), once a session until owned |
| Placement cap hit | Build tray shows "Installed 2/2" (Smelter) or "1/1" (Recycler) | Build tray | **+1 Smelter** / **+1 Recycler** (399) |
| Storage full | A deposit is refused | Storage header | Crate upgrade in Embers (BUY on the arrow, LDOE_PARITY #16) |
| Under-geared for the location | Recommended gear score above yours | Loading-screen card | Light → **Scout's Kit**; Dense → **Gunrunner Pack**; Black → **Heavy Loadout** |
| Tier unlocked | Scrap tier; Plans read; first Dense or Black entry | Unlock card, then a Best feature for 72 h (no countdown) | **Builder's Crate** and **Scrap Room Kit**; **Reinforced Room Kit**; **Gunrunner**; **Raider Arms** |
| Inbox opened | — | Banner at the top of the inbox | The current Best feature |

**Logging:** every impression and conversion is logged by trigger. Triggers converting under 0.5% after 14 days are retired; Price Optimization tests the top four SKUs (playbook §3).

---

## 7. Sales, timers and the Roblox rules

**The Roblox rules, which bind on top of LDoE practice** ([Creator Hub, Monetization](https://create.roblox.com/docs/production/monetization); playbook §1.4):
- **Discounts must be genuine.** The struck-through price must have been charged on the SKU for at least 14 of the last 30 days.
- **Sale windows last at least 72 h,** with an accurate countdown that **never restarts for the same SKU**.
- **Products launched in the 14 days before Black Friday get bonus contents, not a discount badge** (MVP_LAUNCH).
- **No false scarcity:** "Limited" only with a real limit or timer.
- **Neutral calls to action** for minors.

**The v0.1 sales calendar:**

| Window | Dates | What runs | Why |
|---|---|---|---|
| **Black Friday** | Fri 27 Nov 2026 00:00 UTC to Mon 30 Nov 23:59 UTC (96 h) | **Bonus contents, no discount badges:** every item count ×1.25 on Equipment and Building packs; the Ember packs +50% Embers (the playbook's "+50% Gold") | If v0.1 launches after 13 Nov, it is inside the 14-day pre-Black-Friday window, so no SKU has a genuine full-price history yet. If it launches earlier, SKUs live 14+ days may show a real discount instead, under the same rules |
| **First real sale** | Fri 18 Dec to Mon 21 Dec 2026 (96 h) | −30% on weapon packs and room kits that have been at full price for 14+ of the last 30 days. **Bonus contents instead** for any SKU that hasn't | LDoE's December sale; big tickets drive the spikes (playbook §2.5) |
| **New Year** | 31 Dec to 3 Jan (≥ 72 h) | Bonus-contents event on Supplies and Embers. **No discount on any SKU discounted in the December window** | One sale per SKU per 30 days, so no countdown ever "restarts" |

**Timers:**
- The only standing timer is the Firestarter Kit's 48 h, which never restarts and is never shown again once it ends or any purchase happens.
- Sale timers end exactly when the window ends.
- Featured cards (§2.6) never carry timers.

---

## 8. Reconciliation with MVP_LAUNCH

MVP_LAUNCH lists 16 SKUs in two tables (the 10 v0.1 SKUs and the 6 Equipment packs), plus the 2 capacity packs in the Building tab line. All 18 are accounted for here:

| MVP_LAUNCH SKU | MVP price | Status | Now | Why |
|---|---|---|---|---|
| Firestarter Kit | 99 | **Keep** | Unchanged (Best) | Built and decided |
| Scavenger's Kit | 79 | **Keep, contents trimmed** | Spiked Club, Padded Hood, 2 dressings, 2 stew, 2 water (Supplies) | Its current Scrapblade, Padded Vest and 15 consumables are about 5.0 h, or 6.3 h per 100 R$: 4× the curve, which would break "bigger packs get a better rate" for every larger SKU. The death chip now scales by fog tier (§6), so Dense and Black deaths get the bigger refill |
| Supply Bundle | 99 | **Keep, 2 plates → 1** | Supplies | 1.97 h → 1.63 h, into its rung |
| Builder's Crate | 399 | **Keep; tab Best → Building** | Unchanged contents | On the curve (+3%) |
| Reinforced Room Kit | 1,699 | **Replace contents and price (same ID)** | The whole Scrap → Reinforced step for a 3×3, **4,499** | The 1,699 version held about 32 h of a 116-hour room: "a long start", not a room kit. LDoE's room kits are whole rooms (Stone Room $9.99, Metal Room $99.99), and at 1,699 a whole Reinforced room would be 6.9 h per 100 R$ (3.4× the curve). The 1,699 rung is now held by the Scrap Room Kit and the Anti-Materiel Crate. **This changes a DECISIONS price point (2026-11-08 playbook row), so it is the developer's money call.** If vetoed, keep 1,699 with the old contents, renamed "Reinforced Supply Crate", and drop the Reinforced room kit to M2 |
| Energy Refill | 99 | **Keep** | Supplies | — |
| Ember Pouch | 149 | **Keep** | Embers | — |
| Ember Chest | 799 | **Keep** | Embers | — |
| Pack Expansion | 199 | **Keep** | Passes | — |
| VIP Lounge | 399 | **Keep** | Passes | — |
| Scout's Kit | 79 | **Keep** | Reedweave set, Tire Iron, 1 dressing, 1 water (Equipment) | MVP said "meds, dressings and a light melee weapon". It now also carries the Reedweave armor set |
| Gunrunner Pack | 249 | **Keep name and price, replace contents** | Duty Pistol and 3 dressings (the sidearm pack) | The old contents (Worn Pistol, Scrap Shotgun, Trigger Group) are about 6.9 h, or 2.8 h per 100 R$: 1.6× its rung. And the shop no longer sells the improvised tier (ARSENAL §3.5) |
| Pack of Weapon Parts | 149 | **Rename → Gun Parts Pack** | 2 Trigger Groups, 2 Steel Pipes, 3 Coil Springs, 2 Pitch Glue, 1 Copper Wire | "Pack of weapon parts" is LDoE's exact pack title ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Pack_of_weapon_parts)). ECONOMY §1.5 renames exact LDoE names (Woodworking Bench → Saw Bench) |
| Padded Armor Pack | 199 | **Keep** | The full Padded set plus 5 dressings | — |
| Raider Arms | 499 | **Reprice to 1,199, refit** | Hidebound set, Hand Cannon, Patrol Carbine, 6 dressings: the Special Forces-style loadout | 499 isn't a rung of the ladder (it's the subscription price), and "the best v0.1 guns" are now the advanced tier |
| Heavy Equipment | 2,499 | **Rename → Heavy Loadout,** keep the price | Riveted set, Assault Rifle, Combat Shotgun, Rail Mallet, 20 dressings, 10 stew, 3 Trigger Groups, 4 springs | "Heavy equipment" is LDoE's exact pack title ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Heavy_equipment)). The top set is now Riveted |
| +1 Smelter can be placed | 399 | **Keep** | Building | — |
| +1 Recycler can be placed | 399 | **Keep** | Building | — |

**New SKUs (14):** Shotgun Pack, SMG Pack, Rifle Pack, Marksman Pack, Anti-Materiel Crate, Hidebound Armor Pack, Riveted Armor Pack, Iron Tools Pack, Timber Room Kit, Scrap Room Kit, Field Provisions, Medic's Satchel, Ember Satchel, Ember Crate.

**Result:** 18 kept or reworked + 14 new = **32**.

**ECONOMY §8.6's pack sketches map as follows:**

| ECONOMY §8.6 sketch | Becomes |
|---|---|
| Blade Bundle | Scavenger's Kit and Scout's Kit |
| Gunsmith's Kit | Gun Parts Pack. The name is too close to LDoE's "Gunsmith's crate" |
| Ammo Box | Removed: no ammo |
| Armorer's Bundle | The per-set armor packs |
| Field Provisions | Kept |
| Medic's Satchel | Kept, at 10 dressings |

---

## 9. Implementation notes

**Owner:** S1b, the home and shop session (§0). Data first, then the dashboard products.

| File | Change |
|---|---|
| `Types.luau` | `ProductDef.tab` gains `"equipment" \| "building"`. `ProductGrant` gains `{ kind: "stationCap", stationId: StationId, amount: number }`. `ProductDef` gains `tag: ("hot" \| "popular" \| "new")?` and `valueAnchor: boolean?` (exempts the Reinforced Room Kit from the ±10% test) |
| `Data/Products.luau` | 32 entries per §3. Grants are built with the existing `items()` and `join()` helpers; armor sets via a `set("hidebound")` helper; room kits via `Kits` |
| `Domain/Kits.luau` | Add `Kits.roomStep(pieces, fromTier, toTier)`: the upgrade costs only, from `fromTier` to `toTier`, for `ROOM_3X3`. Add `Kits.pieces(pieces, { [id]: count })` for the Timber kit's two crates |
| `Data/Tuning.luau` | `prices.robux` for all 32 IDs. `embers.dailyFreeCrate = { field_dressing = 1, boiled_water = 2, timber = 10 }` |
| Station placement | Max per plot = `Stations[id].max` + owned `stationCap` grants. On a crew outpost, the owner's caps apply (DECISIONS: Crews) |
| `Domain/Offers.luau` | The §2.6 featured-card rules (72 h, no countdown); the §6 trigger table with the 24 h-per-trigger cap; sale windows with the 14-of-30-days reference-price check and the one-sale-per-30-days rule; the Black Friday bonus-contents mode (a contents multiplier, not a price change) |
| Shop UI | rec8 card style (LDOE_PARITY #53): tag ribbon, VIP points badge, limit badge, accurate timer only when real; Best, Equipment, Building, Supplies, Embers and Passes tabs; INBOX and VIP bottom-left |
| Creator Dashboard (Open Cloud) | Create 20 developer products (the 14 new SKUs plus the 6 MVP Equipment SKUs not yet in `Products.luau`) and 2 game passes (+1 Smelter, +1 Recycler). **The Reinforced Room Kit goes to 4,499 with the Plans included (§0, approved by the orchestrator; the developer can veto).** Update the descriptions of the Scavenger's Kit, Supply Bundle and Reinforced Room Kit |
| Tests (`Products.spec`) | Recompute each SKU's value from the §5.1 unit table and the recipe data. Assert: each non-exempt SKU within ±10% of its rung; rung medians rising; every price on the ladder; every grant item exists; no grant of a shield, stash capacity or random item; `limit` set exactly on the Firestarter Kit and the capacity SKUs |

---

## 10. Deferred SKUs

These are deliberately held back for M2, which keeps v0.1 at 32 SKUs:

| SKU | R$ | Why it waits |
|---|---|---|
| +1 Workbench can be placed | 399 | The strongest throughput lever (the Workbench is the Reinforced tier's 123-hour throttle, ECONOMY §5.4). It ships with M2 raids, so the faster walls have something to stop |
| +1 Saw Bench can be placed | 399 | The Ironbark slog (ECONOMY §9.2); pairs with the Workbench cap |
| Ember Strongbox | 4,499 (1,900 Embers) | Playbook §7.2; after the 1,699 Crate shows demand |
| Ember Week | 399 (100 now + 30 a day × 7) | LDoE's Week Pack ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Week_Pack)); needs a daily-drip grant kind and login tracking |
| Gun Parts Crate (bulk) | 799 | About 10 Trigger Groups. Waits until advanced-gun upkeep data shows demand above the 149 pack |
| Season Premium, +5 levels, Premium Bundle | 799 / 249 / 1,699 | Playbook M2 |
| Recover all, Ember Heart ×3 | 100 Embers / 79 | Death recovery is M2 (LDOE_PARITY #46) |
