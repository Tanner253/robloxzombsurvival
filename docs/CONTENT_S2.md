# Slice 2 content: Fog Runs (M1)

The human-readable view of what slice 2 adds to `roblox/src/shared/Data/`. The data files are the source of truth; this page explains them and the pacing behind them. It follows [the brief](briefs/m1-slice2-fog-runs.md), [GAME_DESIGN.md](GAME_DESIGN.md) ("Leaving home", "Fog Runs", "Combat and the arsenal", "Free-player pacing targets") and the binding rulings in [LDOE_PARITY.md](LDOE_PARITY.md). [CONTENT_MVP.md](CONTENT_MVP.md) covers everything older.

**Everything here is off.** `Tuning.features.fogRuns = false`. With the flag off, `Shared/Features` leaves every recipe, station and build piece tagged `feature = "fogRuns"` out of the bundle, the Fog Run remotes are never created, and the six Fog Run services stay idle. Nothing new can appear in the live place until Phase B art grades A (checklist §0). Turning it on is a one-line change, and the Lune suite validates both bundles.

**Counts (new or changed):** 19 items, 12 recipes, 1 station, 1 build piece, 1 node, 3 new enemies (the brute leaves M1), 5 locations (4 updated, 1 new), 15 loot tables, 4 location quests, 33 remotes.

Units: seconds, studs, chances 0–1. Pacing assumes a free player at about 2–3 hours a day.

## Pacing targets this content serves

| Milestone (GAME_DESIGN) | Free player | How slice 2 gets there |
|---|---|---|
| Hatchet, Workbench, level 5 | first hour | unchanged (slice 1) |
| Dense fog | day 2 | level gate 8, plus the Quarry signal tower: 20 planks, 6 scrap plate, 10 cord, 1 coil spring |
| Scrap tier, **first firearm** | **days 3–5** | Pipe Pistol: level 11, Workbench level 2 (level 10), and a **Trigger Group** from Dense band-2+ loot (about 4–6 Dense runs). Lands on day 3. Flare Pistol day 4, Scrap Shotgun days 4–5 (two Trigger Groups, level 14). |
| Black fog | about day 5–6 | level gate 15, plus the Depot tower (brass gears, springs, steel pipe from Dense runs) |
| Reinforced tier | days 10–14 | unchanged; Black fog strongboxes still carry the plans |

A paying player can compress the parts grind to day 1 with part packs (S3). Energy (LDOE_PARITY #38): cap 200, 1 point per 5 min, so a full bar plus a play session of regen is about 10 Dense Runs (22 each), or free Walks.

## Items

| ID | Name | Category | Stack | Durability | Stats / effect | Where it comes from |
|---|---|---|---|---|---|---|
| item.niter | Niter Crust | resource | 40 | — | half of Blackpowder | Niter Seams (Dense, Black), bloaters, Dense/Black band loot, Dense/Black road finds |
| item.blackpowder | Blackpowder | material | 50 | — | every round needs it | Ammo Press (2 niter + 1 fatwood → 2), Dense/Black band loot, airdrops |
| item.steel_pipe | Steel Pipe | part | 10 | — | barrels | Pine band 3 (rare), Dense/Black band loot, airdrops |
| item.trigger_group | Trigger Group | part (rare) | 5 | — | **the gun bottleneck** | Dense and Black band 2+ only (8–25% per roll), airdrops (rare) |
| item.light_rounds | Light Rounds | ammo | 60 | — | Pipe Pistol | Ammo Press (2 scrap + 1 powder → 6), band loot |
| item.shells | Scrap Shells | ammo | 30 | — | Scrap Shotgun | Ammo Press (3 scrap + 2 powder + 1 cloth → 4), band loot |
| item.flare | Signal Flare | ammo | 10 | — | light 24, 20 s, burn 6/s for 5 s, flee radius 18 | Ammo Press (2 powder + glue + cloth → 2), band loot; also the Black-fog flare extract |
| item.machete | Machete | weapon (melee) | 1 | 130 | 22 dmg, 1.6/s, range 6.5, crit 12% | Workbench (level 10), Dense band loot |
| item.fire_axe | Fire Axe | weapon (melee) | 1 | 150 | 36 dmg, 0.9/s, range 7, arc 80°, knockback 2.5, swap 0.6 s | Workbench L2 (level 12), Dense/Black band 3 |
| item.pipe_pistol | Pipe Pistol | weapon (gun) | 1 | 140 | 34 dmg, 1 round, reload 1.4 s, spread 4°, range 70, falloff from 45 to 0.7×, noise 90 | Workbench L2 (level 11), Black band 3 (rare, pity) |
| item.scrap_shotgun | Scrap Shotgun | weapon (gun) | 1 | 120 | 6 pellets × 9, 2 barrels at 0.35 s, reload 2.6 s, spread 18°, range 28, falloff from 10 to 0.35×, noise 120, swap 0.7 s | Workbench L2 (level 14), Black band 3 (rarest) |
| item.flare_pistol | Flare Pistol | weapon (gun) | 1 | 100 | 12 dmg + burn, reload 2 s, projectile 90 stud/s, noise 30 | Workbench L2 (level 12), Black band 3, caravan band 3 |
| item.rations | Trail Rations | consumable | 20 | — | +60 Energy (refused at the cap); pays for AUTO and TAKE ALL (#41) | location quests, airdrops, death milestone; shop in S3 |
| item.reanimator | Ember Heart | misc | 3 | — | carried, revives you at 50 HP instead of dying (#46) | 20-death milestone; shop in S3 |
| item.doormat | Reed Doormat | misc | 1 | — | sets the home respawn point (#46; slice 1b wires it) | hand recipe (level 3) |
| item.raw_meat | Raw Venison | consumable | 10 | — | hunger +6 | deer, wolves |
| item.cooked_meat | Fire-Roasted Venison | consumable | 10 | — | health +10, hunger +40 | Campfire (2 raw → 2) |
| item.hide | Raw Hide | resource | 20 | — | tans into leather | deer, wolves |
| item.leather | Tanned Leather | material | 30 | — | armor and bags later | Workbench (3 hide + glue → 2, level 4) |

Changed: the Reed Shortbow gains bow stats (draw 0.9 s, duds below 35% draw, 60% arrow recovery, arrow 140 stud/s at full draw). The Padded Hood and Vest gain `fogResist` 0.10 and 0.15 (#37).

**No one-shots.** A Lune test checks the biggest single hit of every weapon (heavy crit for melee, all pellets on a crit for guns) is under 100 HP. The largest are the Fire Axe heavy crit (97) and a point-blank shotgun crit (81). M2 PvP also caps any hit at 60% of a full-health survivor.

**Firearm cards:** a gun's `attacksPerSecond` is its sustained rate with reloads (`Combat.sustainedRate`), and the validator holds data to it.

## Recipes

All tagged `feature = "fogRuns"`.

| Recipe | Inputs | Output | Station | Time | Unlock |
|---|---|---|---|---|---|
| machete | 5 scrap plate, 3 rivets, 2 cloth | Machete | Workbench | 10 m | level 10 |
| fire_axe | 6 scrap plate, 3 plank, 4 rivets, 1 steel pipe | Fire Axe | Workbench L2 | 15 m | level 12 |
| pipe_pistol | 1 steel pipe, 1 trigger group, 2 plank, 4 rivets, 1 coil spring | Pipe Pistol | Workbench L2 | 20 m | level 11 |
| flare_pistol | 1 steel pipe, 1 trigger group, 3 scrap plate, 2 pitch glue | Flare Pistol | Workbench L2 | 20 m | level 12 |
| scrap_shotgun | 2 steel pipe, 2 trigger group, 4 plank, 4 scrap plate, 6 rivets | Scrap Shotgun | Workbench L2 | 45 m | level 14 |
| blackpowder | 2 niter, 1 fatwood | 2 Blackpowder | Ammo Press | 6 m | level 10 |
| light_rounds | 2 scrap, 1 blackpowder | 6 Light Rounds | Ammo Press | 4 m | level 11 |
| flare | 2 blackpowder, 1 pitch glue, 1 cloth | 2 Signal Flares | Ammo Press | 8 m | level 12 |
| shells | 3 scrap, 2 blackpowder, 1 cloth | 4 Scrap Shells | Ammo Press | 6 m | level 14 |
| cooked_meat | 2 raw venison | 2 roasted venison | Campfire | 3 m | default |
| leather | 3 hide, 1 pitch glue | 2 leather | Workbench | 8 m | level 4 |
| doormat | 8 fiber, 2 cord | Reed Doormat | hand | 10 s | level 3 |

A full three-job Ammo Press queue of Light Rounds (18 rounds) is about one Dense run's shooting, so ammo stays a steady sink.

## Station and build piece

| | Levels | Cost | Notes |
|---|---|---|---|
| station.ammo_press | L1: 3 slots. L2: 5 slots, ×1.25 speed (12 scrap plate, 8 rivets, 2 brass gears; level 15) | — | crafts ammo, flares and Blackpowder |
| build.ammo_press | — | 10 plank, 8 scrap plate, 6 rivets, 2 coil springs | tier 2, needs a tier-2 foundation, one per plot, level 10; also hidden until its model grades A |

## Resource node

| Node | Tool | Hits | Yield | Respawn | Placed at |
|---|---|---|---|---|---|
| node.niter_seam | pick 1 | 3 | 1 niter a hit | 10 m | Sunken Quarry (4), Ashfall Depot (6) |

## The Hollow and wildlife

Three Hollow archetypes for M1 (checklist 13.1). **The brute is removed from M1 data** (it was never shipped); it returns with the fog wraith and its own rig in M2. HP and damage below are the "Thin" band; the meter's bands scale them by 1, 1.2 and 1.45.

| Enemy | HP | Dmg | Attack | Range | Speed | Sight | Hearing | Light fear | XP | Special |
|---|---|---|---|---|---|---|---|---|---|---|
| Shambler | 40 | 5 | 1.6 s | 4 | 8 | 28 | 1.0 | 0.35 (flees a flare's glow) | 10 | — |
| Runner | 70 | 6 | 1.0 s | 4 | 18 | 42 | 1.25 | 0.70 (only a flare's core) | 25 | outruns a walk |
| Bloater | 60 | 4 | 2.0 s | 4 | 7 | 24 | 0.8 | 0.5 | 30 | fuse 0.8 s at 5 studs, then a toxic cloud (radius 9, 6/s for 6 s); also bursts when killed; drops niter |
| Fog Deer | 30 | 2 | 2.0 s | 3 | 20 | 30 | 1.5 | 0.9 | 15 | skittish: bolts from anyone within 18 studs, or any noise (#35) |
| Ash Wolf | 55 | 7 | 1.1 s | 4 | 19 | 36 | 1.2 | 0.6 | 30 | predator: hunts like a Hollow (#35) |

A sneaking player is seen from half as far and spooks deer from half as far (#44).

## Locations

| Location | Tier | Gate | Run | Walk | Gear score | Exits | Spawns (band) | Location quest |
|---|---|---|---|---|---|---|---|---|
| Pine Hollow | Light | level 1 | 15 | 12 m | 40 | any edge (1.5 s) | shamblers 6–9; runners 0–2 (band 2); deer 2–3; wolves 1–2 | The Hunter's Trail: 2 deer → 150 XP, 1 Rations |
| Sunken Quarry | Dense | level 8 + Quarry tower | 22 | 19 m | 90 | 2 of North Ramp, Conveyor Gate, Flooded Cut (8 s) | shamblers 8–10; runners 3–5; bloaters 1–2 (band 2) | Salt of the Stone: 6 niter → 300 XP, 1 Rations |
| Ashfall Depot | Black | level 15 + Depot tower | 33 | 29 m | 140 | 2 of Rail Yard, Loading Dock, Signal Tower (8 s), plus the flare extract (30 s) | shamblers 8–12; runners 5–7; bloaters 2–3; runners 2–3 more (band 3) | Signal in the Ash: 5 containers → 500 XP, 2 Rations |
| Stranded Caravan (rotating, 3 h in every 9 h) | Dense | level 8 + Quarry tower | 22 | 19 m | 110 | 2 of Lead Wagon Trail, Riverbank, Old Bridge | shamblers 6–8; runners 4–5; bloaters 1–2 (band 2) | What the Wagons Carried: 4 wagons → 400 XP, 1 Rations |
| Supply Drop (airdrop pin) | Light | level 1 | 10 | 8 m | 60 | any edge | shamblers 4–6, runners 1–2, a bloater | — |

Container kinds and search times: packs 3 s, crates, cabinets, lockers and trunks 5 s (Tuning.containers), strongboxes 8 s. Every location keeps its MVP container tables and adds band tables. Light fog rolls per player; Dense and Black share one contested roll.

**Death drops by tier:** Light, owner and party only; Dense, anyone takes the backpack; Black, anyone takes everything carried, equipped gear included, except the secure pouch (M2). Drops last until the lobby closes. Re-entry costs half the Run (rounded up: 8/11/17) and closes at the 60 s warning.

## Loot tables

| Table | Rolls | Highlights | Used by |
|---|---|---|---|
| enemy_bloater | 1 | niter 45, cloth 25, scrap 20, dressing 10 | bloater |
| animal_deer | 1 + 3 meat | hide 1–2 | deer |
| animal_wolf | 1 + 1 meat | hide 70, meat 30 | wolf |
| airdrop_crate | 3–4 + 1 Rations | tins, dressings, light rounds, powder, plate, tonic, pipe, trigger group 5 | Supply Drop |
| pine_band2 / pine_band3 | 0–1 / 1 | cloth, cord, arrows, a few light rounds / scrap, rivets, rounds, steel pipe 10 | Pine Hollow bands 2 and 3 |
| quarry_band2 / quarry_band3 | 1 / 1–2 | niter, powder, rounds, pipe, **trigger group 8 / 14**, machete / fire axe | Sunken Quarry |
| depot_band2 / depot_band3 | 1–2 / 1–2 | **trigger group 14 / 20**, powder, shells, flares / whole guns 3–6 each, pity: an epic gun every 10 opens | Ashfall Depot |
| caravan_band2 / caravan_band3 | 1 / 1–2 | powder, flares, pipe, trigger group 15 / 25, flare pistol | Stranded Caravan |
| road_light / road_dense / road_black | 1–2 | "found on the way": sticks, fiber, berries / scrap, fatwood, niter, junk / plate, niter, rivets, powder | each location's travel bonus |

Band loot is cumulative: a container searched in band 3 also rolls the band-2 table, and the base table opens 1.0×, 1.25× or 1.5× on average by band.

## Tuning added

| Section | Values |
|---|---|
| features | fogRuns false, aiRaiders false (M2) |
| energy (#38) | cap 200 (was 100), hardCap 400 |
| lobby | 12 seats, open timeout 90 s, seat hold 45 s, join window 3 m, run 15 m, warning 60 s, meter exponent 1.2, re-entry cutoff 60 s, band tolerance 1, bands Thin (0) / Rising (0.4) / Closing (0.75), ticket age 120 s |
| extraction | edge 1.5 s, point 8 s, flare 30 s, radius 10, XP 40/100/180 |
| matchmaking | power = level × 10 + gear score; band 60; widen every 4 s up to 2; new lobby after 12 s; gear weights weapon 40, armor 12, bag 10, companion 0 (M3 hook); party 4; AI backfill 8 (M2) |
| combat | crit 8% × 1.5; PvP cap 60%; lag tolerance 3; soft lock 12° |
| hands | 2 slots (no hotbar), swap 0.45 s default |
| melee | arc 100°, heavy ×1.8 after 0.45 s, stamina 6/18, hit-stop 60/90 ms, knockback 1.5/4; tools in a slot 8 dmg, 1.1/s, range 5 (#34) |
| stamina, dodge | 100, +20/s after 0.8 s; dodge 25 stamina, 0.3 s i-frames, 0.9 s cooldown, 9 studs |
| noise | decay 4 s; melee 10, bow 6, sprint 14, search 8, bloater 45, flare 30; guns carry their own |
| sneak (#44) | speed ×0.5, noise ×0.35, detection ×0.5, backstab ×3 |
| containers, travelBonus | search 5 s, reach 8; run 35%, walk 100% × 2 rolls; TAKE ALL 1 Rations; Hurry 2 Energy a minute |
| autoAttack, autoClear (#31) | AUTO radius 14; paid AUTO by ad (level 13+, 10 a day) or 1/2/3 Rations; half the nodes and Hollow |
| airdrops (#43) | below 140, 80, 20 Energy; pins last 2 h |
| regionGates (#43) | Quarry Signal Tower (Dense), Depot Signal Tower (Black) |
| fogExposure (#37) | full in 600 s (Dense) or 240 s (Black) unprotected; armor blocks up to 80%; 2 HP/s while full |
| deathRecovery (#46) | Recover all by ad once a day; Reanimator revives at 50 HP; gifts at 1, 5, 20 deaths |
| hollow | AI 5 Hz, sync 5 Hz, alert 6 s, memory 4 s, idle 2–6 s, wander 30, flee 3 s, 60 a lobby, spawn 40 from players, hit radius 1.6 |

## Code map

- **Domain (pure, Lune-tested):** Lobby, Extraction, Matchmaking, Combat, Hands, Noise, HollowAI, Containers, TravelBonus, Flare, Plane, RunTicket, AutoClear, FogMap, FogExposure, DeathRecovery, plus extensions to Travel (re-entry, rotating availability, refunds, region gates, airdrop pins, Hurry) and Energy (shortfall, refund).
- **Server services (flag-gated):** Lobby, Travel, Hollow, Containers, Combat, Extraction. Helpers live in `server/FogRuns`: Teleport (the live/simulated adapter), Map (the marker contract), Payments (the S3 hook).
- **Remotes:** `shared/Net/FogRunRemotes.luau`, merged into `Net/Remotes` only while the flag is on.

## Design calls made in Phase A

1. **Feature stripping at load** (`Shared/Features`) instead of UI filters, so slice 1's screens need no changes and the flag-off game has nothing to leak. Items stay in the bundle (only Fog Run loot drops them); items made only by tagged recipes carry the tag too, so the flag-off bundle still validates.
2. **The brute leaves M1** for the bloater (three archetypes, three rigs in Phase B).
3. **Level gates follow GAME_DESIGN:** Dense 8, Black 15 (were 4 and 10). Starter quest 10 now asks for level 8.
4. **Light fog's edge exit** uses a 1.5 s fog-out, matching home. **The flare extract** consumes a Signal Flare and ignores damage (only death or walking off break it).
5. **Seats:** a dead player's seat is held while re-entry is open, so a full lobby can't lock them out of their bag. Re-entry is Run-only, costs half a Run, and closes at the warning.
6. **Parties** are matched at their strongest member's power; the leader starts the trip and every member pays their own Energy.
7. **Magazines** live in server run state per weapon slot (no save-schema change); rounds go back to the bag when a run ends, unless the gun itself was lost in Black fog.
8. **Two weapon slots** read `equipment.weapon` and `equipment.weapon2`; slice 1 adds the second paper-doll slot (checklist 4.9).
9. **Melee hits one target** (the locked one if it's in the arc); heavy swings hit harder rather than cleave.
10. **Paid AUTO still costs the Run's Energy** and respects the level and tower gates. Airdrops can't be AUTO-cleared.
11. **Meds button:** the smallest heal that covers the wound, else the biggest; food never counts as meds.
12. **Fog exposure damage** ignores armor and never interrupts a search or an extraction, so full exposure can't trap you.
13. **Ads and premium** go through `FogRuns/Payments.verify`, which refuses until S3 wires it. In Phase A only Rations pay.

## Left for Phase B and after

- **Profile schema (after slice 1 merges):** Walk trips, airdrop pins and day records, tower repairs and contributions, AUTO ad counts, Recover-all counts, death counts for the milestone gifts, pity counters, and Rations shown on the map. All live in server memory for now.
- **Run-place roles:** in a published location place, slice 1's home services (Plots, Scenery, Building, home Gathering) must skip; `Teleport.role()` tells them.
- **Cross-server "Recover all":** the drop lives on the run server, but the player is home by then.
- **Hollow pathing** around handcrafted maps (Phase A moves in straight lines with ground snapping); client rendering and interpolation of `HollowSync`.
- **Maps** following `server/FogRuns/Map.luau` (spawn, hollow, container, extract and bounds markers); all art, VFX and SFX; the Fog map, panels and loading screen.
- **Slice 1/1b notes:** #33 survival rates and "food never restores Energy" live in slice 1 files (the MVP food items still restore a little Energy); the Doormat respawn and the meds and swap HUD buttons are UI work.
- **Real teleports** verified on a private test place.
