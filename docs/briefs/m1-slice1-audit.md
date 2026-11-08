# M1 slice 1: checklist audit (working file)

Status against docs/PLAYER_EXPERIENCE_CHECKLIST.md rows owned by S1, on branch
`claude/m1-slice1-home-loop-b55c20`. ✅ done and seen in a playtest · ⚠️ partial (reason) · ❌ missing.
Updated as work lands; the final version goes into the slice report.

## Work queue (in order)
1. ~~Crisp UI root cause (4.1)~~ (code done; 200% comparison capture still to take)
2. ~~Held tools, holsters, auto-swap, chop/mine/pickup animations~~
3. ~~Sticks vs timber split~~ (sticks icon done; bare-branches model waits on a credit decision)
4. ~~Real sound IDs, ambience, footsteps, music~~
5. ~~Gathering feel: remnants, fly-to-bag, overflow drops, durability warning~~
6. ~~Building: seamless tiling + posts, furniture sub-grid, wall fade, explained refusals~~
7. ~~Inventory: drag and drop, drop, sort, NEW badges, full flash, wheel hotbar~~
8. ~~Stations: progress above the station, offline toast~~
9. HUD: ~~level-up unlocks, day/night + cue + clock, settings, hop~~; loading screen
10. World-as-code: WorldBuilder, KitLoader, Lighting from code, look-test leftovers, fresh-build test
11. LDoE side-by-sides, gate captures, report

## Audit table

| # | Status | Notes |
|---|---|---|
| 1.1 | ✅ | Custom StarterCharacter. |
| 1.2 | ⚠️ | Stopgap: custom action clips (chop, mine, pickup, eat) are ours; idle/walk/run still the Animator defaults until S3's set. |
| 1.3 | ✅ | Faces the mouse aim (Interaction.aimAtMouse); touch faces movement. |
| 1.4 | ✅ | 2.2-stud hop with 1.2 s cooldown; climbing off; node colliders and 8.6-stud walls out of reach (6.8 test). |
| 1.5 | ⚠️ | Selected tool in hand, others holstered (belt/back). The shortbow has no 3D model yet, so it isn't shown. |
| 1.5b | ✅ | Per-item grip data (Art.held); hatchet 1.7, pick 2.2; captures front/side. |
| 1.6 | ⚠️ | Per-surface steps (grass, dirt, wood, stone/road) + sprint dust; metal floors share the stone step. |
| 1.7 | ✅ | Soft warm readability light on your own survivor at night. |
| 1.8 | ✅ | Roblox name tags on other players; none on your own. |
| 1.10 | ✅ | Eat/drink clip + crunch/gulp sounds. |
| 2.1 | ✅ | Fixed 45° yaw, steep pitch, smooth follow. |
| 2.2 | ✅ | Ctrl+wheel and pinch zoom, clamped 22-70 (plain wheel cycles the hotbar, 4.9). |
| 2.3 | ✅ | Walls, doors, windows and their corner posts between camera and survivor fade. |
| 2.4 | ✅ | Build mode eases the camera out (BUILD_EXTRA) and back. |
| 2.5 | ✅ | Shake on swings and tree falls; Settings toggle. |
| 3.1 | ✅ | Outline + prompt with key and needed tool. |
| 3.2 | ✅ | Auto-swap to the tool, chop/mine/pickup clip, swap back. |
| 3.3 | ✅ | Chips by material + per-node hit sounds (chop variants, rock, branch snap, grass). |
| 3.4 | ✅ | Wobble per hit + hit pips on the prompt. |
| 3.5 | ✅ | Tree falls to a stump, boulder to rubble, reeds to stubble, bush to twigs; regrow fades in. |
| 3.6 | ✅ | "+N" cards (merged), icon flies into the Bag button, "+XP" pop. |
| 3.7 | ✅ | Tool refusal, overflow drops as a sack beside the node + toast, AUTO stops. |
| 3.8 | ✅ | Wear per hit, one "about to break" warning, break snap sound + splinter burst + toast. |
| 3.9 | ✅ | AUTO respects tools, walks node to node, stops when the bag is full or nothing is left. |
| 3.10 | ⚠️ | Sticks icon painted; the Fallen Branches world model still has leafy mats (replacement needs ~6 credits over the cap; asked). |
| 4.1 | ⚠️ | Root cause fixed (no CanvasGroup at rest, 1/8 scale steps); the 200% comparison vs the Esc menu is still to capture. |
| 4.2 | ✅ | Pockets, backpack and gear paper-doll. |
| 4.3 | ✅ | Icon, count, durability bar, rarity frame, NEW badge. |
| 4.4 | ✅ | Drag and drop (Shift: half), drag out to drop, right-click split, Shift+click quick-move. |
| 4.5 | ✅ | Details strip: name, stats, durability; Eat/Drink/Equip/Hold, Split, Drop. |
| 4.6 | ✅ | Crate panel beside the inventory with Take all / Put all (F/G) and Sort. |
| 4.7 | ✅ | Sort (backpack, crate); full bag flashes the Bag button red + toast. |
| 4.8 | ⚠️ | No premium currency exists in the data yet. Naming and pricing it is a monetisation call for the developer; the HUD and inventory have room for the chip. |
| 4.9 | ✅ | 1-9, mouse wheel cycles tools, highlight, durability (ammo is S2). |
| 4.10 | ⚠️ | Tweens and all sounds done; Tab/O/X close. Esc is Roblox's own menu key and can't be taken. |
| 5.1 | ✅ | Recipe list, locked recipes show their unlock. |
| 5.2 | ✅ | Ingredients with have/need, output, time. |
| 5.3 | ✅ | Queue with timers, collect, reward pop. |
| 5.4 | ⚠️ | Progress bar + time above a working station, ready badge, fire burns only while fuelled, workbench saw loop. The workbench model itself doesn't animate. |
| 5.5 | ✅ | Fuel slot with burn time; jobs stall without fuel. |
| 5.6 | ✅ | "Ready while you were away: Workbench (2), Campfire" on rejoin. |
| 5.7 | ✅ | Upgrade arrow with cost on the station screen. |
| 5.8 | ✅ | Hand crafting from the inventory. |
| 6.1 | ✅ | B: grid overlay and tabs. |
| 6.2 | ✅ | Green/red ghost with the reason ("Not enough Timber 3/8", "Unlocks at level 7", "Needs the ... blueprint"); costs show have/need. |
| 6.3 | ✅ | R rotates; place snaps with dust and a thud. |
| 6.4 | ⚠️ | Upgrade swaps the tier model with a clank; no "can be improved" marker on upgradable pieces yet. |
| 6.5 | ✅ | Demolish confirms and shows the refund; hovering shows HP. |
| 6.6 | ⚠️ | Doors swing with a creak for the local player; the server doesn't yet lock other players out (S3 crews). |
| 6.7 | ✅ | See 2.3. |
| 6.8 | ✅ | Lune test: wall height > survivor + hop. |
| 6.9 | ✅ | Exact 12x12 deck slabs with tiling PBR variants (wood/scrap/concrete), trim only on outer edges, a post at every wall junction; all tiers in rows and an L, day and night. |
| 6.10 | ✅ | Quarter-cell sub-grid, footprints, flush-to-wall snap facing the room, R rotate, overlap refused, foundations required; layout v2 migration; tests. |
| 7.1 | ✅ | Bars drain smoothly, pulse when low, heartbeat loop. |
| 7.2 | ✅ | Starvation/dehydration damage and regen (Survival service). |
| 7.3 | ⚠️ | Spring pool and boiling exist in data; not re-verified in a capture this pass. |
| 8.1 | ⚠️ | Bars, level/XP, Energy, hotbar, quest tracker; premium currency chip waits on 4.8. |
| 8.2 | ✅ | Toasts top centre, rewards right; never over the hotbar. |
| 8.3 | ✅ | Burst, sting, rewards and "Unlocked: ..." list. |
| 8.4 | ✅ | NEW dot on the Bag button. |
| 8.5 | ✅ | Sun/moon clock chip; "Night is coming" / "Dawn breaks". |
| 8.6 | ✅ | Settings: five volumes, camera shake, interface size, key list; saved (PlayerSchema v3). |
| 9.1 | ⚠️ | Ground layers exist in the place from the look test; not yet rebuilt from code (world-as-code). |
| 9.2 | ⚠️ | Dressing exists in the place; not yet from code. |
| 9.3 | ❌ | Fog wall and Trailhead: world-as-code work. |
| 9.4 | ❌ | Hearth light radius: world-as-code work. |
| 9.5 | ✅ | 24-minute cycle; every lighting value eases; sun timed to the eased dusk; no jumps. |
| 9.6 | ❌ | Wind (grass sway, drifting leaves) not done. |
| 9.7 | ✅ | Day farmland/air beds, night crickets + low drone, fire crackle and saw loops near stations. |
| 9.8 | ✅ | Sparse calm day track / night drone; level-up sting (quest sting with S3 quests). |
| 10.1 | ❌ | Loading screen: next. |
| 10.2 | ⚠️ | ProfileStore autosave and save-on-leave; real rejoin test skipped by decision (unit tests + mock). |

Out of S1 scope but noticed: quest completion and claiming (the tracker shows objectives met but nothing completes) is S3 (10.4).
