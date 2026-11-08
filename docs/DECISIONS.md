# Decisions

| Date | Decision | Notes |
|---|---|---|
| 2026-11-07 | **Cross-platform (PC + mobile), built in Unity** | A move to Roblox is under discussion with the developer's partner. Keep the Unity work small until that's settled; the research and design docs carry over either way. |
| 2026-11-07 | **Camera: angled top-down 3D** (provisional) | Recommended and not objected to. Best for touch building and fair touch-vs-mouse PvP, and cheap on phones. Revisit after playing the lab. |
| 2026-11-07 | **Building: 3 m grid foundations, walls and doors snap to cell edges** | Wood → Stone → Metal, each tier about 2× HP, nothing unbreachable, breach cost shown on hover, simple stability (walls fall without a foundation). |

| 2026-11-07 | **Switched to Roblox** (Unity ZombieLab parked) | Free servers, cross-platform out of the box, built-in discovery. Unity greybox rejected as too low quality. |
| 2026-11-07 | **Concept: personal-plot outpost ("Ember Outpost", working title)** | Chosen for longevity, retention and purchase incentives. Co-op PvE first; raids become a Phase 2 opt-in theft mode. See [GAME_DESIGN.md](GAME_DESIGN.md). |
| 2026-11-07 | **Rated Mild, stylized toon-PBR, R15 avatars** | Keeps every age tier open and qualifies for the 18+ payout uplift. See [ART_DIRECTION.md](ART_DIRECTION.md). |
| 2026-11-07 | **Monetization charter** | Sell convenience, capacity and identity. Never luck, revives, energy, timer skips, stealable loot, storage, power or random boxes. |
| 2026-11-07 | **Camera: Roblox third-person, top-down in build mode** (provisional) | Replaces the Unity top-down decision. Confirm in the look test. |

| 2026-11-07 | **Model LDoE's loops "almost to a T"** | Same structure: home base, world map with Run/Walk and Energy, timed and rotating locations, stations with timers, slow loot ladder, vehicle parts. Our own names, art, map and UI (IP boundary). |
| 2026-11-07 | **Monetization changed to LDoE-style item and progression IAPs** | Replaces the cosmetics-first charter: bundles, Energy, speed-ups, storage and backpack, vehicle parts, season pass, VIP. Guardrails: fairer pacing and prices than LDoE; no paid random boxes until odds publishing is ready. |
| 2026-11-07 | **Camera: fixed angled top-down like LDoE** | Replaces the provisional Roblox third-person camera. |
| 2026-11-07 | **No Higgsfield concept art for now** | The look is defined by the art bible plus a Studio look test. LDoE recordings are used only for framing and UX reference. |

| 2026-11-07 | **Raids and guilds are core, not Phase 2** | The Fog map shows real neighbours' outposts with level, defense, loot tier, shield and guild tag. Matchmaking by power band, partial loot from raidable storage, locked stash, shields (never sold), defense from offline turrets and traps first, live defense and guilds next. Milestone 2 straight after the MVP. |

| 2026-11-07 | **Architecture: data-driven, server-authoritative, Rojo + Git** | See [ARCHITECTURE.md](ARCHITECTURE.md): typed content data with a reference validator; pure domain logic tested with Lune; one service per feature; timers stored as timestamps; ProfileStore; React-lua UI kit; M0 foundation before features. |

| 2026-11-07 | **PC first, mobile supported** | Design and polish for mouse and keyboard first (WASD, mouse aim, LDoE weapon circles and meds slot, keybind hints; the original "hotbar" was superseded on 2026-11-08). Every feature must also work on touch and hold 30+ fps on mid-range phones. |

| 2026-11-07 | **Art style: grounded stylized (toon-PBR with survival grit)** | The developer asked for whatever lands best with players. Top Roblox hits are stylized, and realistic survival games stay niche. The mood is tuned toward the LDoE references: weathered, muted, cold nights, warm fire. Our own designs, no copying LDoE's look. |

| 2026-11-07 | **When in doubt, LDoE is the standard** | It sets the bar for depth, complexity, visual quality and mechanics. Ours differs by being better, mainly through Roblox-native multiplayer (co-op, social, raids, guilds). Our own IP throughout. |

| 2026-11-07 | **Full creative control given to the orchestrator** | The developer asked for "the most fun and engaging game possible optimized for micro txns and replayability". The orchestrator owns direction and merges reviewed, green code; the developer judges at milestones and keeps the veto and money decisions. |
| 2026-11-07 | **Signature mechanics and a game-owned survivor character** | Light is territory (night tower defense), push-your-luck Fog Runs, rescued survivors staffing stations, the Neighbourhood and Blood Moon. Players are custom R15 survivors with cosmetic outfits, not default avatars. See the GAME_DESIGN Vision section. |

| 2026-11-07 | **Standing 300-credit Higgsfield budget for M1 art** | Spent without per-batch approval and reported at milestones. The balance was 1,165 when approved. |

| 2026-11-07 | **A full arsenal, with guns** | The LDoE-scale ladder: melee, bows, improvised, standard and advanced firearms, light weapons (Flare Pistol, Ember Thrower) and throwables; the Ammo Press with 4 ammo types; parts and blueprints; mods. Noise makes guns a risk choice. Paid packs never go beyond the buyer's unlocked tier. First guns arrive in M1 slice 2. See GAME_DESIGN "Combat and the arsenal". |
| 2026-11-07 | **Leave home by walking off the edge into the Fog** | Requested by the developer, and it's how LDoE works. The Neighbourhood edge and the Trailhead start travel. M opens the map anywhere to plan. |
| 2026-11-07 | ~~No jumping or climbing; Space is a dodge roll~~ | Superseded on 2026-11-08 (the next row). |
| 2026-11-08 | **Crews: 2–4 friends share one outpost** | The developer asked about building together. Shared Hearth, plot, storage and stations; personal locked stashes; roles (only the owner or the piece's builder can demolish); the outpost is session-locked to one server and crewmates teleport to it. Gifting and crew cosmetics are the money levers. Ships in M1 slice 3. Outposts become their own entity, keyed by outpostId (ARCHITECTURE §6). |
| 2026-11-08 | **Fog Run locations are separate places with reserved-server lobbies** | Replaces the plan to stream zones into the world server (ARCHITECTURE §7). |
| 2026-11-08 | **Sticks split from Timber** | Developer playtest: ground pickups should be branches with a sticks icon, and logs are their own item. Sticks come by hand from fallen branches (hand tools, campfire, arrows). Timber logs need a hatchet (Workbench, planks, building). The ladder is hands → sticks + stone → hatchet → timber → planks. |
| 2026-11-08 | **LDoE side-by-side gate for every UI screen and world shot** | The developer felt we're "missing the LDoE mark", and the inventory looked blurry and washed out. Workers compare each capture with the matching LDoE reference frame and fix the gaps before reporting. The orchestrator repeats the check at review. |
| 2026-11-08 | **Companions: raise, train, breed** | The developer explained LDoE's dog loop: food to train and breed, and % chances for quality and traits, so players keep buying food. Ours has dogs with 5 roles, quality tiers and trait slots, plus a Kennel for training and breeding. Odds are shown before every breed, a Lineage meter gives bad-luck protection, every food is earnable, and there's no permadeath. Pets are a top Roblox genre. Ships in M3; Vaults and advanced firearms move to M4. |
| 2026-11-08 | **Item desire is the monetization engine** | No casino crates. Instead: bottleneck materials per tier, visible gear, capacity pressure, long checklists, timers, honest chance systems and social proof. Every paid shortcut has an earnable path. |
| 2026-11-08 | **Item inbox in M1 slice 1; home building and crafting draw from all storage and the inbox** | The developer asked for it from the LDoE recording. Big packs never need to fit in an inventory. The inbox is raid-proof. |
| 2026-11-08 | **Monetization: copy LDoE's hard grind and pay-to-win; drop the fairness softening** | The developer: LDoE has about 100k daily players with a hard grind and a P2W setup, so we don't need to worry about over-monetizing. Removed: generous pacing, fair prices, earnable-path guarantees, tier-capped weapon packs, breeding pity, the never-sold secure pouch, the exact-contents-only rule. Kept only Roblox platform rules (odds shown for paid random outcomes, PolicyService, ads 13+) and revenue-protecting raid rules (purchases are raid-proof; never sell shields or PvP immunity). This supersedes the earlier fairness clauses in the companion, inbox and item-desire rows. |
| 2026-11-08 | **The free grind is long and gruelling: days per tier** | The developer's call. A 30–60 min hook, then the Timber tier by day 1, Scrap by days 3–5, Reinforced by days 10–14, standard guns in weeks 2–3, the first vehicle in weeks 4–6+. Paying compresses each tier to hours. Enforced by a Lune pacing simulation of a free player's day, which asserts the time-to-tier bands, plus a data rescale. That pass runs after slice 1 merges, to avoid data conflicts. A Studio-only DevSpeed multiplier keeps playtests fast. |
| 2026-11-08 | **Art pool raised to 800 Higgsfield credits (+300)** | The developer approved it. About 497 was spent by then (balance 667.63). Allocation: about 50 for the S1b station models (Stonecutter, Smelter, parts Workbench) and the wrecked hauler, and about 200 for S2 (3 Hollow rigs, 3 guns, location dressing), with the rest as a buffer. |
| 2026-11-08 | **Art pool raised to 500 Higgsfield credits** | The developer: "you can use up to 500 art credits so dont worry about that". About 147 spent so far. Reserve about 120 for slice 2. |
| 2026-11-08 | **LDoE parity rulings adopted** | An independent audit of every LDoE frame and doc against our design. All 58 rulings are in [LDOE_PARITY.md](LDOE_PARITY.md) and are binding. The headline changes:<br>• the HUD layout, with no hotbar and no meds or food bars<br>• the two-pane inventory<br>• stations become converters, with gear crafted by hand<br>• finite home nodes<br>• free AUTO, with paid AUTO on the location panel<br>• LDoE Energy and survival numbers<br>• blueprints unlock through quests<br>• Survivor's Path renamed Ember Trail<br>• a starter shelter and a wrecked vehicle goal<br>• death recovery for an ad or premium<br>• the VIP points ladder<br>Kept deviations are listed there. |
| 2026-11-08 | **Zoom is kept (a deliberate deviation)** | LDoE has no free zoom, but the developer asked for it. Wide zoom at home and in build mode; clamped near LDoE framing in Fog Run lobbies, for PvP fairness. |
| 2026-11-08 | **Jumping restored; climbing is impossible** | The developer wants jumping. It's a short hop with a cooldown. The Climbing state is off and the walkable slope is limited, so rocks and trees can't be climbed. Canopies don't collide. Walls are taller than any reachable point. Hand-placed parkour ledges exist in Fog Run locations only. Dodge roll moves to C. |
| 2026-11-07 | **Fog Runs are cross-server shared lobbies; the fog tier sets the PvP rules** | Requested by the developer ("like a tarkov lobby"). Light is PvE with personal loot. Dense is PvP with Hostile marks and contested loot. Black is full loot except the secure pouch, with a flare extract. Truce and betrayal, downed state, bounties, power-band matchmaking. Light is always fully viable; protection is never sold. Lobbies are built in M1 (PvE), and PvP lands in M2 with raids and the standard firearms. |
| 2026-11-07 | **Painted, realistic-leaning item icons and modelled nodes** | Requested by the developer: no emoji or symbolic icons. Paid from the 300-credit pool, with a 3-sample style gate before batching. |

## ZombieLab (parked) (Unity 6000.3.27f2, built-in render pipeline)

`ZombieLab/` is a greybox prototype. Open it in Unity Hub and press **Play** in any scene: `World.cs` builds everything at runtime. It tests the core loop:

- **Gather:** trees give wood and rocks give stone. Metal piles appear only in the red danger zone to the east, which has more zombies.
- **Build:** press B, then:
  - 1 foundation, 2 wall, 3 door, 4 upgrade (T upgrades everything you can afford), 5 demolish
  - full refund within 30 s
- **Raid:**
  - craft charges with C (12 metal + 8 wood) and plant them with G
  - stone wall = 2 charges, metal door = 3; wood can also be broken by melee
  - explosions draw zombies (the "noise" mechanic)
  - the raider base has a wooden inner room around its stash
- **Death:** you drop a backpack at the spot, which stays for 5 min, and respawn.

Not in it yet:
- networking
- touch controls
- roofs or second floors
- zombies attacking bases
- real art
