# Game Design: "Ember Outpost" (working title)

A Roblox survival-crafting game that closely follows **Last Day on Earth's (LDoE) gameplay loops and monetization model**, with our own world, names, art and UI. Rated Mild.
This is the source of truth that worker sessions build against. Reference material:
- [research/README.md](research/README.md) and [research/ldoe-core-systems.md](research/ldoe-core-systems.md): how LDoE works
- [research/roblox-genres-monetization.md](research/roblox-genres-monetization.md): Roblox platform rules
- [reference/ldoe-recordings/](reference/ldoe-recordings/): the developer's LDoE screen captures

**IP boundary:** copy mechanics, loops, pacing and UX patterns freely. Never copy LDoE's names (locations, items, characters), art, map, story or exact UI look.

## Pitch

The world is lost to **the Fog**, and the **Hollow** walk inside it. Only firelight holds them back. You build and defend your **outpost** around your **Hearth**. You scavenge locations on a world map, craft your way up tier by tier, and work toward big goals: a working vehicle, a restored radio tower, the next region.

**Theme pillar: light holds back the fog.**

## Design pillars

1. **The grind is the game.** A slow, satisfying loot-and-progress ladder (LDoE's core). There is always the next tier, the next blueprint part, the next location.
2. **Your outpost is your pride, and it's at risk.** It visibly grows, it sits on a shared map, and other players can raid it.
3. **Raids actually happen.** Every real player's outpost appears on the Fog map with its level, defense and loot tier. You always have targets in your power band, and you will be raided too. This is the part LDoE got wrong and we get right.
4. **Guilds are war parties.** Guild districts on the map, defending each other, guild raids and territory.
5. **Always something cooking.** Craft timers, offline production, location timers, and 2–3 reasons a day to come back.
6. **Sell progress and convenience, the LDoE way,** but more generously paced and fairly priced than LDoE (the developer's main complaint about it).
7. **Cohesive and polished.** One art bible, one animation set, one UI kit. See [ART_DIRECTION.md](ART_DIRECTION.md).

## Structure (mapped from LDoE)

| LDoE element (seen in recordings and research) | Our version |
|---|---|
| Private home base on a grid | **Home plot**: your outpost on a grid. On Roblox, plots sit side by side in a 6–8 player server, which adds a social layer that LDoE lacks. |
| World map with locations; **Run** (energy) or **Walk** (real time); each location's panel shows main and possible loot | **Fog map**: the same model. Run costs **Energy**, which regenerates and is restored by food and drink. Walk is free but takes real minutes. Location panels preview the loot. |
| Resource zones by danger tier (green, yellow, red) | Fog density tiers, Light, Dense and Black. Each location is its own area, teleported to or streamed in. |
| Timed and event locations (e.g. a fishing spot available for 11h 59m) | **Rotating locations** with countdowns: event spots, supply drops, crashed convoys. A daily return trigger. |
| Dungeons that refresh on a timer (bunker) | **Vaults:** multi-floor dungeons with keycards and a refresh timer. Co-op is allowed. |
| Settlement and multiplayer hub | **Haven:** a shared hub with traders, a contract board, the clan board and season activities. |
| Quest tracker (expedition, new home, watchtower) | A left-side **quest tracker** with chained storyline and side quests. |
| Survival meters | Health, hunger and thirst. Food and drink restore Energy as well. |
| Pockets plus backpack inventory, storage boxes, recycler with a skill level | The same: limited pockets plus backpack slots that grow with better bags; storage crates at base; a **Recycler** with a skill that raises the chance of rare outputs. |
| Workbenches with craft timers; tier-gated recipes | Stations: Workbench, Smelter, Campfire/Kitchen, Recycler, Ammo Press, Garden, Water Collector. Each has timers and unlocks by Hearth or player level. |
| Durability on tools, weapons and armor | Kept, with repair at the workbench. |
| Death drops your inventory at the location | Kept: your backpack drops where you fell and you can go back for it. Equipped gear is kept. |
| Long build goals (chopper, ATV, motorcycle from parts) | A **vehicle chain** (scooter, truck, then something bigger), each built from rare parts found deep in the fog. The parts are also sold. |
| Companions (dog) | A companion animal that helps in combat and finds loot. |
| Random "unknown box" chests | Loot crates **earned in play** (event and location rewards). If we ever sell them, the odds must be published (a Roblox rule). |
| Season pass, events (Halloween season) | 6–8 week seasons with a free and a premium track, plus themed events. |
| Clans | **Guilds:** guild districts on the map, a guild hall in Haven, defense calls, guild raids, co-op Vaults and territory control points. |
| Raids on other bases (underwhelming in LDoE: level 150 gate, quest-chain access, unbreakable top walls) | **Core feature:** real player outposts on the Fog map, with matchmaking by power band, raid tools, partial loot, shields and live defense. See "The Fog map" below. |

**Camera:** a fixed angled top-down camera like LDoE's (about 55° pitch, zoomable), with a virtual joystick on the left and action, attack, sprint and auto buttons on the right. Mouse and keyboard on PC.

## The Fog map: neighbours, raids, guilds

**What the map shows:**
- Your outpost, loot locations, rotating events and Vaults.
- **Other real players' outposts in your region**, each marker showing:
  - Hearth level and defense rating
  - **estimated loot tier** ("smoke from chimneys": high, medium or low stockpile)
  - online, offline or **shielded** status with a timer
  - guild tag
  - last raided
- **Guild districts:** guild members' outposts cluster together, with a banner. **Control points** (radio masts, fuel depots) pay a timed bonus to whichever guild holds them.

**How a raid works (v1):**
1. Pick a target in your **power band** (±2 Hearth levels or a similar defense rating). Travel there with Run or Walk, like any location.
2. Breach with raid tools: charges and cutters crafted from scarce fog-zone materials. Each piece shows its breach cost, and no tier is unbreakable.
3. Breaching makes **noise**, which draws the Hollow and gives the defender time to respond.
4. Loot comes from the target's **raidable storage**: up to about 40% per raid. The owner's **locked stash** can't be raided; its size grows with Hearth level.
5. **Every** raid is played live in a server that loads the target's outpost:
   - If the defender is offline, their turrets, traps and Hollow-proof walls defend.
   - If the defender is online, they get an alert and can **join and defend live**, and so can guildmates (a "defense call").

**Fairness rules:**
- New players are protected until Hearth level 3 or for 3 days.
- After being raided you get a shield (about 8–12 hours). Raiding someone else ends your own shield.
- Every raid is logged. The attacker is always revealed, and you can take revenge on them or put a bounty on them.

**Roblox implementation note:**
- Outposts are saved to DataStores, and a MemoryStore index lists bases by region and power band to drive the map and matchmaking.
- A raid locks the target base in MemoryStore, runs in a reserved server, and applies loot changes in one transaction.
- That works whether the defender is online or offline, which solves the "nobody raids, nobody gets raided" problem.

## Core loop

| Scale | Loop |
|---|---|
| **Minute** | Move, gather nodes, search containers, fight the Hollow, manage pockets and backpack. |
| **Session (about 20 min)** | Pick a location on the Fog map (Run or Walk), loot it, come home, store, craft, build or upgrade, queue station jobs. |
| **Daily** | Collect station output, check rotating locations, do daily quests, claim login rewards. |
| **Weekly** | Vault refresh, a weekly event, new rotating locations. |
| **Season (6–8 weeks)** | A new region or storyline, the season pass, themed content. |

## Progression

- **Player level** from XP: unlocks recipes and locations.
- **Hearth level:** plot size, build tiers, stations.
- **Blueprints and parts** from deep locations and Vaults: vehicles and advanced stations.
- **Material tiers** for weapons, armor and building pieces: Wood → Scrap Metal → Reinforced.
- **Pacing:** grindy by design, but each tier should land in hours to days, not weeks. Tune with retention data.

## Building

- Grid **foundations**; **walls, doorways, doors, gates and windows** snap to cell edges. Build menu tabs: Foundations, Walls, Doors, Windows, Stations, Storage, Defense, Decor.
- Upgrade pieces in place, and HP is shown. Wall tier cannot exceed floor tier. Placement is touch first: tap a cell, the piece snaps, confirm or cancel.
- Defenses: spikes, traps, turrets, and lights, which matter against the Fog at night.
- **Night assaults** on your outpost happen while you're online (escalating, with a weekly Blood Moon). Offline plots are never attacked.

## Monetization (LDoE-style: items and progression)

**What we sell:**
- Resource and material bundles
- Gear and equipment packs
- Vehicle part packs
- Storage packs
- Station and settlement building kits
- Energy refills
- Craft and timer speed-ups
- Inventory and backpack upgrades
- Season pass (premium track)
- Starter and limited-time offers
- A VIP subscription (daily rewards plus Energy cap)
- VIP servers
- Cosmetics as a side line

**Guardrails:**
- More generous pacing and fair prices compared with LDoE.
- No paid random boxes until we're ready to publish odds and handle regional restrictions.
- Sell items directly instead.
- Prices are read from script so Roblox's price testing works, and regional pricing is on.
- **Raid-economy rules:**
  - Purchased resources and items go into the **locked stash**, so nobody pays and then gets robbed.
  - **Never sell shields or raid immunity.** Otherwise heavy spenders hide forever and the raid ecosystem dies.
  - Matchmaking by power band keeps paid power from steamrolling weaker players.

## Platform requirements

- Rated **Mild**: the Hollow dissolve into ash, with no blood.
- R15 avatars and a distinct look, which qualify for the 18+ payout uplift.
- Works without chat: pings, emotes, quick chat.
- Mid-range phone first: streaming, LODs, low instance counts.

## MVP (first playable)

**In scope:**
- Home plot with grid building in 3 tiers
- The Fog map with Run/Walk and Energy
- 3 locations (one per fog tier) plus 1 rotating event location
- 5–6 resources
- About 15 craftables
- Workbench, Campfire and Recycler with timers
- Pockets/backpack inventory and storage crates
- Hunger and thirst
- 3 Hollow types
- Death drop
- Quest tracker with a starter questline
- DataStore saving
- A shop with 3–4 products (resource pack, Energy refill, backpack upgrade, starter offer)
- The full UI kit and HUD

**Milestone 2 (raids, straight after the MVP):**
- Neighbour markers on the Fog map (level, defense, loot tier, shield)
- Raid tools and breach costs
- Raids on offline bases, with raidable storage versus the locked stash
- Shields, new-player protection and a raid log with revenge

**Milestone 3:** guilds (districts, defense calls, control points), live defense, Vaults.

**Later:** vehicles, the companion, seasons.

**How we judge it:** D1, D7 and D28 retention, session length and payer conversion.
