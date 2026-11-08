# M1 slice 1: checklist audit

Status against every S1 row of docs/PLAYER_EXPERIENCE_CHECKLIST.md on branch
`claude/m1-slice1-home-loop-b55c20`. ✅ done and seen in a playtest · ⚠️ partial (reason) · ❌ missing.
Captures: docs/milestones/m1-slice1/ (40-46 LDoE side-by-sides, 50-72 gate captures).

Checks at the head of the branch: 186 Lune specs, selene 0/0, stylua clean, luau-lsp 0 on both
solvers, `rojo build` OK. Z-fighting scan (roblox/tools/zscan.luau, all of Workspace.World on the
test base plus an L, a diagonal and a scrap-tier deck): 102 parts, 1334 overlapping pairs, **0 hits**.

## Art consistency (ART_DIRECTION 10a v2)

- Family sheets from the approved slice-1 crops: Nature (dead pine, bare branches, rock cluster, reed
  stubble, grass clump, twig shrub), Camp (campfire, storage crate, recycler, spring basin, lantern
  post, standing torch, barrels, supply sacks, rain collector) and Structure (palisade doorway,
  palisade window, door leaf, signpost), drawn against the kit wall. art/higgsfield/m1-slice1/families/.
- 17 converted with one fixed Tripo setting (18k faces, PBR, detailed texture); conform pass done
  offline (textures to Roblox's 1024 cap, floaters stripped: reed stubble 98 triangles, barrels 68).
  Grass clump and twig shrub are not converted (thin blades become blobs).
- **Blocked:** the GLBs can't become Roblox models until the worktree's art folder is an approved
  upload directory (one click, asked). Then: import, lineup capture (with the survivor and 3 kit
  pieces, day and night, gameplay and close zoom), A/B/C grades to the orchestrator, and only A
  replaces the off-pipeline models.
- Off-pipeline models already removed from the world: the WaterCollector stone pit, the GrassClump
  "mud blob" scatter, the squashed reed remnant. Still standing until their A-graded replacements
  land: look-test Lamp, CrateStack, Barrels, Sacks, Generator, Car, RockClump, Gen_pebbles, Gen_tree,
  the Hearth brazier, the generated campfire, the procedural doorway/window/door and the primitive
  spring.
- Spend this pass 213.25 credits (4 sheets + 17 conversions); pool total about 360 of 500.

## Audit table

| # | Status | Notes |
|---|---|---|
| 1.1 | ✅ | Custom StarterCharacter. |
| 1.2 | ⚠️ | Custom chop, mine, pickup, eat clips; drink reuses eat; idle/walk/run are the Animator defaults until S3's set. |
| 1.3 | ✅ | Faces the mouse aim; touch faces movement. |
| 1.4 | ✅ | 2.2-stud hop, 1.2 s cooldown, climbing off; walls out of reach (Lune test). |
| 1.5 | ⚠️ | Selected tool in hand, others holstered; the shortbow has no 3D model yet. |
| 1.5b | ✅ | Per-item grips (Art.held). |
| 1.6 | ⚠️ | Per-surface steps and sprint dust; metal floors share the stone step. |
| 1.7 | ✅ | Readability light on your survivor, now by day too (smaller, dimmer). |
| 1.8 | ✅ | Name tags on others only. |
| 1.10 | ✅ | Eat/drink clip and sounds. |
| 2.1 | ✅ | Fixed 45° yaw, steep pitch, smooth follow. |
| 2.2 | ✅ | Default zoom 26: the survivor stands about 1/6 of the screen (69); Ctrl+wheel 18-70; build mode eases out. |
| 2.3 | ✅ | Walls, doors, windows and posts between camera and survivor fade. |
| 2.4 | ✅ | Build mode eases the camera out and back. |
| 2.5 | ✅ | Shake on swings and falls; Settings toggle. |
| 3.1 | ✅ | Outline and prompt with key and tool. |
| 3.2 | ✅ | Auto-swap, clip, swap back. |
| 3.3 | ✅ | Chips and per-node hit sounds. |
| 3.4 | ✅ | Wobble and hit pips. |
| 3.5 | ⚠️ | Trees fall to stumps, boulders to rubble; reeds and bushes leave nothing until the stubble and bare-branch models pass the lineup (the old squashed copy read as a mud blob). |
| 3.6 | ✅ | Merged "+N" cards, icon flies to the Bag, "+XP". |
| 3.7 | ✅ | Tool refusal; overflow drops a sack plus toast; AUTO stops. |
| 3.8 | ✅ | Wear, warning, break burst. |
| 3.9 | ✅ | AUTO walks node to node and stops when full. |
| 3.10 | ⚠️ | Bare-branches model converted (no leaf mats) and waiting on the upload click and lineup; the leafy model is still in the world. |
| 4.1 | ✅ | Text F2EEE6 / B8B2A6; section headers 25 px and captions 19 px at 1080p; disabled buttons plain grey; locked text in red; crisp (no CanvasGroup). |
| 4.2 | ✅ | Pockets, backpack, gear paper-doll with silhouettes (63). |
| 4.3 | ✅ | Icon, count, durability, rarity, NEW badge at readable size. |
| 4.4 | ✅ | Drag and drop, drag out to drop, split, quick-move. |
| 4.5 | ✅ | Details: name, stat chips, category/tier and description, action bar. |
| 4.6 | ✅ | Crate panel with Take all / Put all and Sort. |
| 4.7 | ✅ | Sort; full-bag flash and toast. |
| 4.8 | ⚠️ | No premium currency exists in data yet (S3 shop); the HUD has room for the chip. |
| 4.9 | ✅ | 1-9, wheel cycles, highlight, durability. |
| 4.10 | ⚠️ | Tweens and sounds; Esc is Roblox's own menu key. |
| 4.11 | ✅ | Right-aligned action bar: Use/Equip, Split, Drop, trash with a two-press confirm (InventoryDestroy); Sort; storage Take all / Sort / Put all. |
| 4.12 | ✅ | Crate header strip: slots now → next, cost have/need (home pool), Upgrade in place. |
| 4.13 | ✅ | Crates show the icon of what they hold most of (67). |
| 4.14 | ✅ | Stat icon + value chips in item details and the recipe card. |
| 4.15 | ✅ | Unlimited inbox in the profile (schema v4 migrates the old stash): level-up rewards, refunds and crafts that don't fit; TAKE, USE in place, Take all, category filter; Bag badge counts rows and opens it (65). Quests/purchases route there when S3 grants them. |
| 5.1 | ✅ | Locked recipes greyed under a padlock, red unlock condition, sorted last. |
| 5.2 | ✅ | Inputs have/need (home pool), output, time; where each input comes from. |
| 5.3 | ✅ | Queue, collect, reward pop. |
| 5.4 | ⚠️ | Progress above the station, ready count, fire only while fuelled, saw loop; the workbench model doesn't animate. |
| 5.5 | ✅ | Fuel slot and stalls. |
| 5.6 | ✅ | "Ready while you were away". |
| 5.7 | ✅ | Station upgrade with cost. |
| 5.8 | ✅ | Hand crafting, now in the catalogue. |
| 5.9 | ✅ | C opens the catalogue: tabs incl. Favourites ★, every recipe, NEW badges (profile marks), locked greyed with red condition (66). |
| 5.10 | ✅ | Blueprint card, stat chips, description, ingredients have/need (red when short), source on hover (Domain/ItemSources, Lune), quantity bar with Max, Craft. |
| 5.11 | ✅ | "Placed n/max" on build cards; limits enforced (BuildRules). |
| 5.12 | ✅ | Count badge over stations with ready output (ReadyCount). |
| 5.13 | ✅ | Pockets → backpack → crates → inbox, atomic (Domain/MaterialPool, Lune: order, partial, refusal); building, upgrades, station jobs and hand crafting; client counts include crates and inbox; Fog Runs carried only. Playtest: four foundations built from inbox timber with nothing carried. |
| 6.1 | ✅ | Grid overlay and tabs. |
| 6.2 | ✅ | Green/red ghost with the exact reason and have/need. |
| 6.3 | ✅ | R rotates; snap, dust, thud. |
| 6.4 | ⚠️ | Upgrade swaps the tier model; no "can be improved" marker. |
| 6.5 | ✅ | Demolish confirm and refund (overflow to the inbox); HP on hover. |
| 6.6 | ⚠️ | Doors swing locally; server lock is S3. |
| 6.7 | ✅ | See 2.3. |
| 6.8 | ✅ | Wall height test. |
| 6.9 | ✅ | Seamless decks; trim frame outside the decks, beams abut end to end, one corner block per outside corner (64, 71-72). |
| 6.10 | ✅ | Quarter-cell furniture, flush to walls. |
| 6.11 | ✅ | Scan 0 hits; tiles abut with zero overlap; trim and posts offset ≥ 0.05; deck tops 0.95 above terrain; closest/farthest zoom captures from two angles (71-72). |
| 6.12 | ⚠️ | Workbench stands on its legs facing the room, crates upright, campfire flat, doors hinge, R turns about vertical only; the lineup capture of every placeable vs rec8 comes with the art lineup. |
| 7.1 | ✅ | Bars drain smoothly, pulse when low. |
| 7.2 | ✅ | Starvation/dehydration damage and regen. |
| 7.3 | ⚠️ | Spring pool and boiling in data; the spring model is the primitive until the basin passes the lineup. |
| 8.1 | ⚠️ | Bars, level/XP, Energy (amber +N over the cap), hotbar, tracker; premium currency chip waits on 4.8. |
| 8.2 | ✅ | Toasts top centre, rewards right; inbox toast. |
| 8.3 | ✅ | Burst, sting, rewards ("rewards are in your inbox"), unlocks. |
| 8.4 | ✅ | NEW dot on Bag. |
| 8.5 | ✅ | Clock chip and cues. |
| 8.6 | ✅ | Settings. |
| 8.9 | ✅ | « folds the tracker to one line; level bar with level and XP along the bottom (70). |
| 8.10 | ⚠️ | Bottom bar Auto, Craft (NEW count), Build, Bag (inbox count), Use; Quests is the tracker; Shop and Social are S3. |
| 8.11 | ✅ | Home minimap: floors, walls, stations, storage and your arrow (70). |
| 9.1 | ✅ | Three layers in one terrain pass: noise zones, rolling land, dry grass to the fog; worn paths, plot wear, Hearth ash; wind grass (68). |
| 9.2 | ⚠️ | Rule-based dressing works; most props are look-test models waiting on the Camp family lineup. |
| 9.3 | ✅ | Fog banks, Trailhead. |
| 9.4 | ⚠️ | Hearth light and radius disc; fog doesn't yet retreat from light. |
| 9.5 | ✅ | 24-minute cycle, eased. |
| 9.6 | ⚠️ | Wind grass via Terrain decoration; no drifting leaves yet. |
| 9.7 | ✅ | Ambience by time and place. |
| 9.8 | ✅ | Sparse music and stings. |
| 9.9 | ⚠️ | Lantern post and standing torch converted; the placeable light pieces go in with them after the lineup (no primitive fallbacks). |
| 10.1 | ✅ | Loading screen. |
| 10.2 | ⚠️ | ProfileStore autosave/save-on-leave; real rejoin test skipped by decision. |

## Also done this pass

- DevSpeed: Tuning.devSpeed 10 scales timers, yields, regen and XP in Studio only (Data/init, before the
  freeze); live servers run at 1 (Lune). "DEV ×10" tag on the HUD.
- S3 shortfall slots (UI/offers): Fill up (crafting card, crate upgrade), Speed up (station queue),
  offers on toasts; nothing sold, hidden until the shop sets them.
- Dressing is rebuilt from code every run (the saved Dressing folder is gone from the place); the saved
  hand-built terrain is cleared, Scenery builds the ground.
- Pacing numbers live in Data/Tuning (grep for hard-coded timers in services found none).

Out of S1 scope but noticed: C was planned for the dodge roll (DECISIONS 2026-11-08); the checklist
puts the crafting catalogue on C, so the roll needs another key when it lands.
