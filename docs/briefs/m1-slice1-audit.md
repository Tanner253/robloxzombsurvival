# M1 slice 1: checklist audit

Status against every S1 row of docs/PLAYER_EXPERIENCE_CHECKLIST.md on branch
`claude/m1-slice1-home-loop-b55c20`. ✅ done and seen in a playtest · ⚠️ partial (reason) · ❌ missing.
Captures: docs/milestones/m1-slice1/ (40-46 LDoE side-by-sides, 50-72 gate captures, 73-88 this pass).

Checks at the head of the branch: 186 Lune specs, selene 0/0, stylua clean, luau-lsp 0 on both
solvers, `rojo build` OK. Z-fighting scan (roblox/tools/zscan.luau, all of Workspace.World on the
test base plus an L, a diagonal and a scrap-tier deck): 102 parts, 1334 overlapping pairs, **0 hits**;
re-run on the 8-stud test base after the scale change: 54 parts, **0 hits**.

## Orchestrator review of b1ebba8: scale, walls, ground (this pass)

- **Scale:** the cell is 8 studs (Tuning.building.gridStuds); 2-stud sub-grid; wall-layer kit models
  fit one cell (Models.fitEdge); trim and posts scaled down; layouts from the 12-stud grid reset
  (LAYOUT_VERSION 3, Lune test); minimap reads the cell size; test base is a 4 x 3 room (77).
- **Walls:** the palisade is a Defense piece now (build.fence_wood "Palisade Fence", Defense tab).
  The Timber Wall points at WallTimber, a solid plank wall with a top cap: family sheet drawn, wall
  converted (16.5k tris, one piece, 0 floater flags), hidden by the quality gate until model uploads
  are approved and it passes the lineup. Doorway and window wait (budget). Wall height stays 8.6:
  checklist 6.8 needs walls above head height plus the 2.2 hop (8.3), which rules out the reviewer's
  1.3x-survivor walls.
- **Ground (three layers, no new models):** the flat Ground, Road and Pad parts sat exactly on the
  painted terrain and hid it; they are gone (79 before, 80 after). Five generated PBR variants
  (Studio material generator, best of four each) override the terrain materials: grass, leaf-litter
  forest floor, gravel earth, rutted mud and straw dry grass. Pebbles, leaves and ruts are in the
  textures. Layers: macro zones from noise; worn plot pads, footpaths and the gravel road with two
  wheel ruts; fine grain noise ragging every border. Ash under the Hearth is painted only with the
  Hearth's approved model. Captures 78-88.
- **Lived-in dressing:** no kit dressing model grades A yet (the look-test barrels, crates, sacks,
  lamp, tool rack, shelf, cot, planter and car are soft generated meshes), so nothing was added. It
  lands with the Camp family once uploads work.
- **Generation:** this pass 2.75 (timber sheet) + 12 (timber wall); the pool is about 375 of 500.


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

## Quality gate (checklist §0) — this pass

- **Nothing below A is visible.** `Art.approved` lists the kit models graded A: pine, fatwood stump, the
  outpost kit walls and scrap window, workbench, the four tools. Every lookup goes through it and the
  stand-in builders are deleted. Hidden until their replacements are graded A: boulder (lichen card),
  fallen branches (leaf mat), ember bush, reeds and loose stones (floaters found by the gate), spring
  (primitive), campfire (generated), crates, recycler (Generator stand-in), doorways/doors/wood and
  reinforced windows (procedural), all look-test dressing, the Hearth brazier, the ground sack. Capture 73.
- **Floater gate:** art/tools/glb_floaters.py (+ glb_layflat.py) on all 29 GLBs → 0 flags after fixes;
  roblox/tools/kit_detached.luau in Studio → 140 kit models, 0 detached parts.
- **World as code:** tools/syncback.luau put the kit masters, StarterCharacter, survivor rigs and material
  sets into roblox/place/kit/; `rojo build` reproduces the saved place's content.
- **Blocked on one click:** model uploads only work from approved folders; the worktree's art folder isn't
  one and the tool forbids copying around that. 17 converted models wait.

## Adversarial QA (fresh reviewer, LDoE frames as the bar, default C) — and what changed

| Thing | QA grade | After this pass |
|---|---|---|
| Edge trees | C (1-stud, invisible) | Fixed: 3-row line of 26-36 stud pines before the fog (75) |
| Night look | C (near black) | Fixed: blue moonlight fill, 24-stud survivor light (76) |
| Hearth light | C (light over mud, no source) | Hidden until its fire model passes |
| Wind grass | C | Off until a grass that holds up exists |
| Ground at the edge | C (black mud blots) | Calmer mud, no blots, no ash pit |
| Wood deck | C (narrow noisy planks) | Wide calm planks, warm tint (75) |
| Deck trim / floating | C | Decks 0.45 above ground (FLOOR_HEIGHT 0.5) |
| Log posts | C | Lighter bark, rope bands, caps at the wall line, wider |
| Camera framing | C (too tight) | Default 30: room plus surroundings |
| Minimap | C | Round, N marker, trees and nodes; still plot-anchored |
| Inventory / Inbox overlap | C | Take all clear of Crafting; whole backpack rows |
| Build menu | C | Tray sized to cards, action bar uncovered, Demolish on Delete |
| HUD badges, Auto icon, clock | B | Badges above icons, Auto glyph, pinned hour shown |
| Crafting | B | Recipes for unbuildable stations hidden; NEW only until first close |
| Settings | B | C listed |
| Pine tree | C (clones, khaki leaf cards) | Taller, random yaw per node; **foliage needs a regenerated model** |
| Survivor | B (finger tips, armpit clip) | **Needs a character fix in the model** |
| Workbench | B (smeared saw) | Faces the room now; texture needs the model regenerated |
| Fatwood stump | B | Scaled to the trunk; resin colour needs the model |
| Fog banks | C | **Needs volumetric layers; open** |
| Inbox as its own screen | C | Kept as the inventory pane (spec allows); open |
| Quest claim / hotbar stacks / food numbers | B | S3 quests; stack sizes wait for the pacing rescale; open |

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
| 2.2 | ✅ | Default zoom 31 on the 8-stud grid: the survivor stands about 1/7 of the screen with a room around them (77, 86); Ctrl+wheel 18-70; build mode eases out. |
| 2.3 | ✅ | Walls, doors, windows and posts between camera and survivor fade; tree nodes and the edge pines fade when their canopy covers the survivor or stands in the sight line (87). |
| 2.4 | ✅ | Build mode eases the camera out and back. |
| 2.5 | ✅ | Shake on swings and falls; Settings toggle. |
| 3.1 | ✅ | Outline and prompt with key and tool. |
| 3.2 | ✅ | Auto-swap, clip, swap back. |
| 3.3 | ✅ | Chips and per-node hit sounds. |
| 3.4 | ✅ | Wobble and hit pips. |
| 3.5 | ⚠️ | Pines fall to fatwood stumps. Boulder, branches, bush and reeds are hidden by the quality gate until their A models upload (boulder rubble, stubble, bare branches converted). |
| 3.6 | ✅ | Merged "+N" cards, icon flies to the Bag, "+XP". |
| 3.7 | ✅ | Tool refusal; overflow goes to the inbox (no ground sack until a sack model is graded A) + toast; AUTO stops. |
| 3.8 | ✅ | Wear, warning, break burst. |
| 3.9 | ✅ | AUTO walks node to node and stops when full. |
| 3.10 | ⚠️ | Bare-branches model converted, laid flat, floater-free (glb_floaters 0 flags); waits on the upload click. The leaf-mat model is hidden, so Gather Sticks is unreachable meanwhile. |
| 4.1 | ✅ | Text F2EEE6 / B8B2A6; section headers 25 px and captions 19 px at 1080p; disabled buttons plain grey; locked text in red; crisp (no CanvasGroup). |
| 4.2 | ✅ | Pockets, backpack, gear paper-doll with silhouettes (63). |
| 4.3 | ✅ | Icon, count, durability, rarity, NEW badge at readable size. |
| 4.4 | ⚠️ | Drag and drop, split, quick-move; drag-out-to-drop and Drop are hidden until a ground-sack model is graded A (§0). |
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
| 5.4 | ⚠️ | Workbench progress, ready count, saw loop; the campfire is hidden (generated model below A) until the converted campfire passes the lineup; fire/embers/smoke/light only while fuelled are coded for it. |
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
| 6.6 | ⚠️ | Doorways, doors and wood/reinforced windows are hidden (stand-ins removed); the palisade doorway, door leaf and window are converted and wait on the upload. |
| 6.7 | ✅ | See 2.3. |
| 6.8 | ✅ | Wall height test. |
| 6.9 | ✅ | Seamless decks; trim frame outside the decks, beams abut end to end, one corner block per outside corner (64, 71-72). |
| 6.10 | ✅ | Quarter-cell furniture, flush to walls. |
| 6.11 | ✅ | Scan 0 hits (re-run on the 8-stud grid: 0); tiles abut with zero overlap; trim and posts offset ≥ 0.05; deck tops 0.95 above terrain; closest/farthest zoom captures from two angles (71-72). |
| 6.12 | ✅ | Kit pivots at the base centre, up +Y (Studio check); the workbench source model turned so its working side faces the pivot front (tools/conform_pivots.luau); against a wall it stands on its legs, worktop up, back to the wall, working side to the room (74). Other placeables are gated until their models land and go through the same lineup. |
| 7.1 | ✅ | Bars drain smoothly, pulse when low. |
| 7.2 | ✅ | Starvation/dehydration damage and regen. |
| 7.3 | ⚠️ | The primitive spring is hidden; the spring basin is converted and waits on the upload (water surface, wet stones, crouch-and-cup drink to follow with it). |
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
| 9.2 | ⚠️ | Dressing by rule, but every look-test prop is hidden by the gate; only edge pines remain until the Camp family models land. |
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
