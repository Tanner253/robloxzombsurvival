# Player experience checklist (binding definition of done)

**Why this exists:** on 2026-11-08 the developer had to point out gaps that a well-planned build should never ship with: no tool in the hand, a weird-looking timber pickup, flat ground, a blurry inventory, and losing jump. Their words: "we need to make sure as we build we close these gaps automatically so i dont have to prompt you for these things... build the game right."

This file lists **everything a player sees, hears and feels**, system by system. LDoE is the minimum bar, and the "Owner" column says which slice ships each item.

**How it's used:**
- **Workers** build every row their slice owns.
- **Before reporting,** a worker self-audits each row as ✅ done, ⚠️ partial (with the reason) or ❌ missing, and fixes ❌ before reporting.
- **The orchestrator** re-checks the rows at review, against captures and the LDoE frames, and sends back any row that fails.
- **Reports** include the audit table.
- **New gaps** found by anyone (developer, worker or orchestrator) are added here first, then fixed. This file only grows.

Owners: **S1** M1 slice 1 (home loop), **S2** M1 slice 2 (Fog map, locations, combat, death), **S3** M1 slice 3 (quests, shop, crews, intro, polish), **M2** raids and PvP, **M3** guilds, Vaults, live defense.

## 0. The feature-feel rule (applies to every feature, every slice)

Nothing player-facing is done until it has all ten:
1. **A visible model** in the world. No invisible logic, no primitive stand-ins.
2. **Animation** on the character and on the object. Custom, never Roblox defaults.
3. **VFX** for its key moments (hit, finish, place, break).
4. **SFX** for each action, using real sounds from the Roblox library. No placeholder or missing IDs.
5. **UI feedback:** a prompt, progress, a result pop, and an error or "can't" state with its reason.
6. **A keybind hint** on PC and a touch equivalent on mobile (at least 44 pt).
7. **Data that matches the look:** the item name, icon, world model and in-hand model all depict the same thing.
8. **Server authority and persistence:** it's validated, and it survives a rejoin.
9. **LDoE side-by-side:** each capture sits next to the matching reference frame, with the gaps fixed.
10. **Performance:** no frame drop at 60 fps on PC, and the instance budget is respected.

## 1. Character and movement

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 1.1 | The player spawns as the custom survivor (StarterCharacter), never a default avatar. No duplicate stand-in near spawn. | Fixed survivor | S1 |
| 1.2 | Custom idle, walk, run and sprint animations | Character-specific set | S1 (stopgap) → S3 (final) |
| 1.3 | The character faces the mouse aim on PC and the movement or aim stick on mobile | Faces target | S1 |
| 1.4 | Jump is a short hop with a cooldown. No climbing anywhere. Can't stand on trees or rocks, can't get over walls. | No jump in LDoE; ours is bounded | S1 |
| 1.5 | The selected tool or weapon is visible in the hand. Other carried weapons and tools are holstered on the back or belt. | Weapon in hand | S1 |
| 1.6 | Footstep sounds per surface (grass, dirt, wood floor, metal, road), plus a light dust puff when sprinting | Surface footsteps | S1 |
| 1.7 | Readable at night: a subtle rim or readability light | Readable silhouette (rec6) | S1 |
| 1.8 | Other players show name tags. Your own character shows none. | — | S1 |
| 1.9 | Hit-react, downed and death animations. Players collapse without gore. | Hit and death | S2 |
| 1.10 | Eat and drink animations with sounds | Consume animations | S1 |

## 2. Camera

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 2.1 | Fixed angled top-down camera (about 55°) with a smooth follow and slight movement lead | rec1 framing | S1 |
| 2.2 | Zoom range with the wheel or pinch, clamped so the outpost reads at max and the character at min | — | S1 |
| 2.3 | **Occlusion:** walls, roofs and tall props between the camera and the player fade or cut away, so you can always see yourself inside buildings | Interiors stay visible | S1 |
| 2.4 | Smooth transition into the build-mode camera and back | Build view (rec2) | S1 |
| 2.5 | Subtle camera shake on heavy hits and tree falls, with a setting to turn it off | — | S1 / S2 |

## 3. Gathering

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 3.1 | Hovering a node or pressing E highlights the target with an outline and shows a prompt with the keybind and the required tool | Context action button (rec3) | S1 |
| 3.2 | Auto-swaps to the correct tool, plays the per-node animation (chop, mine or pickup), then swaps back | Hand/axe switch (rec3) | S1 |
| 3.3 | Per-hit VFX by material (wood chips, rock grit and sparks, leaves, dust) and per-hit SFX | — | S1 |
| 3.4 | The node reacts on each hit: a wobble or shake, and a node HP or progress indicator | — | S1 |
| 3.5 | Depletion is visible: the tree falls and leaves a stump, the rock crumbles to rubble, the bush is stripped. Respawn fades in after the timer. | Nodes deplete | S1 |
| 3.6 | Yield feedback: a "+2 Sticks" pop with the item icon flying to the inventory or hotbar, and a "+XP" pop | "+XP" popups (rec3) | S1 |
| 3.7 | Can't-gather states: "Need a hatchet", inventory full (overflow drops to the ground as a pickup, with a toast), node depleted | — | S1 |
| 3.8 | Tool durability goes down per hit, with a low-durability warning and a break event (sound, VFX, toast) | Durability | S1 |
| 3.9 | Auto-gather (Q) respects tools, shows its current target, walks the player between nodes, and stops on full inventory or danger | AUTO (rec3) | S1 |
| 3.10 | Item names, icons and world models agree (sticks look like sticks, timber like logs) | — | S1 |

## 4. Inventory, hotbar, storage

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 4.1 | **Pixel-crisp UI:** no CanvasGroup at rest, no fractional scaling, near-opaque panels, high-contrast text | Crisp panels (rec1, rec2) | S1 |
| 4.2 | Pockets plus backpack grid, and an equipment paper-doll (head, body, legs, feet, backpack, hand) | rec1, rec2 | S1 |
| 4.3 | Each slot shows the icon, the stack count at bottom-right, a durability bar, a rarity frame, and a NEW badge on new items | — | S1 |
| 4.4 | Drag and drop, split (Shift-drag or right-click → split), quick-move (Shift-click), drop to the ground (drag out) | — | S1 |
| 4.5 | Tooltip or detail panel: name, description, stats, durability, uses, and actions (Use, Eat, Equip, Drop) | — | S1 |
| 4.6 | Storage panel side by side with the inventory, with Take all and Put all | rec2 | S1 |
| 4.7 | A sort button. Full-inventory feedback (a red flash and a toast). | — | S1 |
| 4.8 | Premium currency balance with "+" on every inventory screen (opens the shop) | rec1 lever 10 | S1 (display) → S3 (shop) |
| 4.9 | Hotbar 1–9, the mouse wheel cycles, the selected slot is highlighted, durability and ammo counts show, quick-use consumables | Weapon swap (rec6) | S1 (ammo S2) |
| 4.10 | Open and close tweens, plus open, close, hover, click, error and pickup sounds. Esc closes. Tab toggles. | — | S1 |

## 5. Crafting and stations

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 5.1 | Station screen: recipe list, with locked recipes greyed and showing their unlock requirement, and a category filter | "All recipes" (rec4) | S1 |
| 5.2 | Each recipe shows the ingredients with have/need counts (red when short), the output, and the time | rec4 | S1 |
| 5.3 | Queue with timers, progress bars, collect (single and all), and the reward pop | — | S1 |
| 5.4 | **In-world state:** progress above the station, a "ready" icon when done, and an animated station (fire burns only while fuelled; the workbench has a working animation and SFX) | — | S1 |
| 5.5 | Fuel slots with burn time and a remaining-fuel bar. Jobs pause visibly when fuel runs out. | — | S1 |
| 5.6 | Offline completion is shown on return ("Ready while you were away") | — | S1 |
| 5.7 | A station upgrade arrow is always visible, with the upgrade cost | rec4 | S1 (UI) / S3 (levels) |
| 5.8 | Hand crafting (hatchet, pick, cord) from the inventory without a station | — | S1 |

## 6. Building

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 6.1 | B enters build mode: grid overlay and tabs (Foundations, Walls, Doors, Windows, Stations, Storage) | rec2 | S1 |
| 6.2 | Ghost preview, green or red, **with the reason** ("Needs a foundation", "Not enough timber 3/8"). Cost shown with have/need. | rec2 | S1 |
| 6.3 | R rotates. Place snaps with an animation, a dust puff and a sound. | — | S1 |
| 6.4 | Upgrading in place visibly swaps the tier material and model, with a sound. "Can be improved" hint. | rec2 | S1 |
| 6.5 | Demolish asks for confirmation and shows the refund rule. Hovering a piece shows its HP. | — | S1 |
| 6.6 | Doors open and close with an animation and sound, and lock to the owner (crew in S3) | — | S1 |
| 6.7 | Interiors stay readable: walls and roofs between the camera and the player fade (see 2.3) | — | S1 |
| 6.8 | Walls are taller than any reachable point (enforced by a test) | — | S1 |

## 7. Survival meters

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 7.1 | HP, hunger and thirst bars with smooth drain, and a pulse plus a warning sound when low | HUD (rec1) | S1 |
| 7.2 | Starvation and dehydration damage, and HP regen when fed and watered | — | S1 |
| 7.3 | Drink from the spring pool (animation and sound), boil water at the campfire | — | S1 |
| 7.4 | Death and respawn flow: a death screen with the cause, respawn at home, the backpack marker on the map | — | S2 |

## 8. HUD and notifications

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 8.1 | HUD: bars, level and XP, Energy with "+", premium currency with "+", hotbar, and the quest tracker on the left | rec1 | S1 (quests S3) |
| 8.2 | Toast stack for pickups, warnings and completions, which never covers the hotbar | — | S1 |
| 8.3 | Level-up celebration: a burst, a sound, and a list of what unlocked | — | S1 |
| 8.4 | NEW badges on menu buttons when something new is inside | rec5 | S1 |
| 8.5 | A day/night clock indicator and a "night is coming" cue | — | S1 |
| 8.6 | Settings: audio sliders, camera shake, UI scale, keybind list | — | S1 |
| 8.7 | Minimap with points of interest and, later, enemy dots | rec6 | S2 |
| 8.8 | Targeted enemy name and HP bar at top centre, damage numbers | rec6 | S2 |

## 9. World and atmosphere

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 9.1 | Ground variation in all three layers (ART_DIRECTION §4). No visible repetition. | — | S1 |
| 9.2 | Lived-in props around the outposts and the Neighbourhood (tarps, racks, crates, lanterns, fences, wreckage) | rec1 base dressing | S1 |
| 9.3 | The fog wall at the Neighbourhood edge, rolling. The Trailhead, lit and readable. | — | S1 |
| 9.4 | The Hearth's light radius is visible, and fog visibly retreats from light | Signature | S1 |
| 9.5 | Smooth day/night cycle with stable exposure (no jarring brightness shifts) | rec1 night | S1 |
| 9.6 | Wind (grass sway, drifting leaves and dust), occasional rain | — | S1 (wind) / S3 (rain) |
| 9.7 | Ambience: day birds and wind, night insects and an eerie bed, fire crackle near flames, all layered with distance | — | S1 |
| 9.8 | Music: calm day, tense night, a sting on level-up and quest completion | — | S1 (basic) / S3 |

## 10. Session, save, onboarding

| # | Requirement | LDoE reference | Owner |
|---|---|---|---|
| 10.1 | A loading screen with game art and gameplay tips, never a raw Roblox load into an empty world | rec2, rec7 | S1 |
| 10.2 | Autosave plus save on leave. Rejoin restores the base, inventory, queues and timers exactly. | — | S1 |
| 10.3 | The first 10 minutes as designed (arrival, first Hearth pushes back the fog, first craft, first build) with an objective beacon or arrow | — | S3 |
| 10.4 | Quest tracker with chapters and rewards, plus a premium row | rec5 | S3 |

## 11. Fog map, locations, combat (S2), and monetization, crews (S3)

S2 and S3 briefs expand these into full rows. The minimum:
- **Fog map:**
  - Location panels with main and possible loot, Run/Walk, and "items left here are lost".
  - A loading screen with the location name, time, temperature, stats and tips.
- **Locations:**
  - Container search with a progress bar (about 5 s).
  - Travel bonus loot.
  - Extraction points.
  - The shared lobby.
- **Combat:**
  - Targeting, attack animations per weapon class, hit-stop, damage numbers.
  - The Hollow dissolve to ash.
  - Loot drops.
  - Ammo counts, reload, noise.
  - Dodge roll.
- **Shop:** currency "+" opens it, products, receipt flow, and purchases going into the locked stash.
- **Crews:** invites, roles, a shared outpost.
