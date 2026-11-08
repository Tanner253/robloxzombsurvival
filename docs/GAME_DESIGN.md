# Game Design: "Ember Outpost" (working title)

A Roblox survival-crafting game that closely follows **Last Day on Earth's (LDoE) gameplay loops and monetization model**, with our own world, names, art and UI. Rated Mild.
This is the source of truth that worker sessions build against. Reference material:
- [research/README.md](research/README.md) and [research/ldoe-core-systems.md](research/ldoe-core-systems.md): how LDoE works
- [research/roblox-genres-monetization.md](research/roblox-genres-monetization.md): Roblox platform rules
- [reference/ldoe-recordings/](reference/ldoe-recordings/): the developer's LDoE screen captures

**[LDOE_PARITY.md](LDOE_PARITY.md) is binding and overrides anything in this file it conflicts with.** It holds the 2026-11-08 rulings from a frame-by-frame audit: HUD, inventory, stations, building, economy, quests, shop and onboarding.

**IP boundary:** copy mechanics, loops, pacing and UX patterns freely. Never copy LDoE's names (locations, items, characters), art, map, story or exact UI look.

**Guiding rule: when in doubt, LDoE is the standard** for depth, complexity, visual quality and mechanics. Match its depth and polish everywhere. **Where we differ, we're better.** The main difference is multiplayer: the social, co-op, raiding and guild mechanics Roblox players engage with most. Back any deviation from LDoE with a reason.

## Vision (creative director, full control since 2026-11-07)

**The goal:** the most fun and replayable survival-crafting game on Roblox, with purchases players want to make. LDoE's depth and grind are the backbone. Four signature mechanics make it ours, plus the Roblox-native social layer LDoE never had.

**Signature mechanics:**
1. **Light is territory.**
   - Your Hearth burns fuel, and its light radius is your safe zone and build area. Lamps and flare towers push it further.
   - At night the Fog advances, and Hollow waves hit whatever sits in the dark. Nights play like **light tower defense**: layout, lights, traps and walls decide whether you hold. Roblox players love tower defense.
   - Fuel is a satisfying everyday sink, constantly gathered.
2. **Fog Runs (push your luck).**
   - Expeditions take 8–15 minutes in **shared lobbies** of 8–12 survivors drawn from across servers. Depending on the fog tier, you can team up, trade or fight. See "Fog Runs: shared lobbies and PvP".
   - A visible **Fog meter rises the longer you stay.** Loot gets better and the Hollow get stronger. **Extract before it closes in,** or drop your pack.
   - Location layouts and modifiers vary each run, with weekly modifiers on top. Every run plays differently.
3. **Survivors you rescue.**
   - Survivors are found on runs as escort events, never sold as a gacha. They move into your outpost and **staff stations, producing while you're offline.**
   - Each has traits and levels, and there's a collection log. This is the idle and collection layer that keeps people checking in.
4. **The Neighbourhood and Crews.**
   - Plots sit side by side, so players see, visit and help each other.
   - **Crews:** up to 4 friends share one outpost and build it together. See "Crews: build together".
   - A **server-wide Blood Moon** each week has everyone defending at once, with a leaderboard.
   - Then raids (M2) and guilds holding radio towers for server buffs (M3).

**The player character:** the game owns it. Players are a **custom survivor on Roblox's standard R15 rig**, not a default Roblox avatar. They choose a look, and **outfits, gear and flame colors are the cosmetic layer.**

**Retention by timescale:**
- **Hourly:** station timers, survivor output, fuel.
- **Daily:** contracts, login track, rotating locations.
- **Weekly:** Blood Moon, Vault resets, modifiers.
- **Season (6–8 weeks):** a new region and a pass.
- **Long term:** vehicles, Hearth levels, the survivor collection, guild territory.

**The first 10 minutes:**
1. A crash-site intro run.
2. Light your first Hearth.
3. Survive your first short night.
4. Rescue your first survivor.
5. The starter offer appears **only after that first win**.

**The money engine** (LDoE-proven levers at LDoE-level grind and prices; LDoE runs about 100k daily players on a hard-grind, pay-to-win model):

| Lever | What we sell |
|---|---|
| **Time** | Energy, speed-ups, auto-gather |
| **Capacity** | Backpack, storage, station queues, survivor bunks |
| **Progress** | Premium path, part packs, blueprint fill-up, starter and limited offers |
| **Identity** | Outfits, base themes, Hearth flames, weapon skins, emotes |
| **Recurring** | Survivor Club subscription, season pass, VIP servers |

Only the platform rules and raid rules under Monetization apply.

## Pitch

The world is lost to **the Fog**, and the **Hollow** walk inside it. Only firelight holds them back. You build and defend your **outpost** around your **Hearth**. You scavenge locations on a world map, craft your way up tier by tier, and work toward big goals: a working vehicle, a restored radio tower, the next region.

**Theme pillar: light holds back the fog.**

## Design pillars

1. **The grind is the game.** A slow, satisfying loot-and-progress ladder (LDoE's core). There is always the next tier, the next blueprint part, the next location.
2. **Your outpost is your pride, and it's at risk.** It visibly grows, it sits on a shared map, and other players can raid it.
3. **Raids actually happen.** Every real player's outpost appears on the Fog map with its level, defense and loot tier. You always have targets in your power band, and you will be raided too. This is the part LDoE got wrong and we get right.
4. **Guilds are war parties.** Guild districts on the map, defending each other, guild raids and territory.
5. **Always something cooking.** Craft timers, offline production, location timers, and 2–3 reasons a day to come back.
6. **Sell progress, power and convenience, the LDoE way.** A hard grind with strong reasons to pay is proven (the developer's call, 2026-11-08). Don't soften it. Tune it with data.
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
| Survival meters | Health, hunger and thirst, at LDoE rates (−1 every 10 s, warning at 20). Food does **not** restore Energy. |
| Pockets plus backpack inventory, storage boxes, recycler with a skill level | The same: limited pockets plus backpack slots that grow with better bags; storage crates at base; a **Recycler** with a skill that raises the chance of rare outputs. |
| Workbenches with craft timers; tier-gated recipes | Stations: Workbench, Smelter, Campfire/Kitchen, Recycler, Ammo Press, Garden, Water Collector. Each has timers and unlocks by Hearth or player level. |
| Durability on tools, weapons and armor | Kept. Worn gear is re-crafted; repair only comes from a late Repair Station or as a VIP perk. |
| Death drops your inventory at the location | Kept: your backpack drops where you fell and you can go back for it while the lobby is open. Equipped gear is kept, except in Black fog, which is full loot apart from the secure pouch. |
| Long build goals (chopper, ATV, motorcycle from parts) | A **vehicle chain** (scooter, truck, then something bigger), each built from rare parts found deep in the fog. The parts are also sold. |
| Companions (dog): food to train and breed, % chances for quality and traits | **Companions:** dogs you raise, train and breed for traits and roles (fighter, scavenger, guard and more). Better food means better odds. See "Companions: raise, train, breed". |
| Random "unknown box" chests | Loot crates **earned in play** (event and location rewards). If we ever sell them, the odds must be published (a Roblox rule). |
| Season pass, events (Halloween season) | 6–8 week seasons with a free and a premium track, plus themed events. |
| Clans | **Guilds:** guild districts on the map, a guild hall in Haven, defense calls, guild raids, co-op Vaults and territory control points. |
| Raids on other bases (underwhelming in LDoE: level 150 gate, quest-chain access, unbreakable top walls) | **Core feature:** real player outposts on the Fog map, with matchmaking by power band, raid tools, partial loot, shields and live defense. See "The Fog map" below. |

**Platform: PC first, mobile fully supported.** Design and polish for mouse and keyboard first, then make sure every feature works on touch.

**Camera:** a fixed angled top-down camera like LDoE's (about 55° pitch, zoomable with the mouse wheel or pinch).

**PC controls:**
- WASD to move, the mouse to aim, left click to attack or gather, E to interact, Shift to sprint
- Q to toggle AUTO (gather and attack): free everywhere, as in LDoE. The paid AUTO sits on the location panel and clears a location into the inbox without entering it.
- Space to **jump** (a short hop), C for a **dodge roll** (combat, slice 2)
- **Two weapon slots** (LDoE-style; no 1–9 hotbar): 1 and 2 select, and F or the on-screen swap button swaps. The active slot shows the weapon icon and ammo count. Tools never take a slot, because gathering auto-equips the right tool from your bag.
- **H, or the meds button,** uses your best healing item. It shows the count.
- The mouse wheel zooms the camera.
- Tab for inventory, B for build mode, M for the Fog map

**Jumping yes, climbing no.** The developer wants to keep jumping, which Roblox players expect. Walls still have to hold, so nobody gets over a wall, onto a rock or up a tree:
- **A short hop:** jump height is tuned well below the lowest wall, with a brief cooldown so nobody bunny-hops in fights.
- **No climbing:** the Humanoid's Climbing state is off, and the steepest walkable slope is limited, so rock faces and tree trunks can't be scaled.
- **Collision:** tree canopies don't collide, and rocks and props use simple shapes that can't be stood on.
- **Building rule:** every wall and gate is taller than the highest point a player can reach, standing on anything that can be placed outside a base. Raiders can't place objects, only raid tools.
- **Parkour where we want it:** Fog Run locations have hand-placed **vault ledges, rooftops and gaps** that you mantle with Space. They make shortcuts, hidden loot spots and escape routes. Bases never get them.
- **Server checks:** raids also validate on the server that nobody is inside an enclosed base without a breach, because exploiters can ignore client movement rules.

**Mobile controls:** a virtual joystick on the left, and action, attack, weapon swap, meds, jump, dodge, sprint and auto buttons on the right.

**Gamepad:** later.

## The Fog map: neighbours, raids, guilds

**Leaving home: walk off the edge into the Fog.** This is the LDoE feel, and the developer asked for it.
- The Neighbourhood (6–8 plots in one server) is ringed by a wall of Fog.
- Walking into that edge anywhere starts a short fog-in: the screen fogs, footsteps and ambience change, and after about 1.5 s the **Fog map** opens. Backing out during the fog-in cancels it.
- The **Trailhead** at the end of the Neighbourhood road is the main exit. It's a lit signpost and gate, and the natural place to group up for co-op runs.
- Closing the map leaves you standing at the edge, so a separate confirmation dialog isn't needed.
- M opens the map anywhere **to plan** (timers, loot previews, neighbours). Travel starts only from the edge or the Trailhead.
- Leaving a location depends on its tier. In Light fog, walk out of any edge. In Dense and Black fog, you leave only through **extraction points** (see "Fog Runs: shared lobbies and PvP").

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

**Raid ecosystem rules** (so new players stick around long enough to become targets and spenders):
- New players are protected until Hearth level 3 or for 3 days.
- After being raided you get a shield (about 8–12 hours). Raiding someone else ends your own shield.
- Every raid is logged. The attacker is always revealed, and you can take revenge on them or put a bounty on them.

**Roblox implementation note:**
- Outposts are saved to DataStores, and a MemoryStore index lists bases by region and power band to drive the map and matchmaking.
- A raid locks the target base in MemoryStore, runs in a reserved server, and applies loot changes in one transaction.
- That works whether the defender is online or offline, which solves the "nobody raids, nobody gets raided" problem.

## Crews: build together

Roblox is built around playing with friends, and the big Roblox building and survival games let friends build together. LDoE never had shared bases; we do. That's a "better than LDoE" multiplayer win, and friend invites are free growth.

**How it works:**
- A **Crew** is 2–4 players sharing **one outpost**: one Hearth, one plot, shared storage crates and stations. Anyone in the crew can queue station jobs and collect them.
- **Joining** is an invite from the outpost owner. Your own outpost is packed into storage crates that you take with you, so nothing is lost.
- **Each member keeps a personal locked stash.** Purchases still go there.
- Crews always play in the same Neighbourhood server. Joining sends you to the server where your crew's outpost is loaded.

**Roles (anti-grief):**
- The **owner** can invite, kick and promote.
- **Builders** can place and upgrade.
- **Demolish** is limited to the owner and whoever placed the piece.
- **Shared storage** keeps an access log.

**Leaving:**
- You keep your personal stash and start a fresh outpost with a starter kit.
- The outpost and its shared storage stay with the crew.

**Raids:**
- A crew outpost is matched by its combined power.
- Online crewmates all get the defense alert.
- The share of raidable loot is the same as for anyone else.

**Without a crew:** you can still team up while living in separate bases. Party up at the Trailhead for co-op Fog Runs, defend the Blood Moon together, trade, and visit or help neighbours. Guilds (M3) are the large-group layer, with 20–50 players and districts.

**Monetization:**
- **gifting** packs to crewmates and friends, a major Roblox lever
- crew cosmetics (banner, Hearth flame)
- crew-wide storage expansions that any member can buy

The platform rules under Monetization apply.

**Rollout:**
- **M1 slice 3:** crews.
- **Already in M1:** Neighbourhood visits, Trailhead parties and the co-op Blood Moon.

## Companions: raise, train, breed

The developer flagged this as one of LDoE's strongest money engines:
- Dogs need food to train and breed.
- A pup only has a **% chance** of the quality and traits you want, so players keep feeding and breeding to get the perfect dog with the skill they need (fetching loot, fighting zombies).
- There are no casino crates, but the chase never ends.

Pets are also among Roblox's biggest genres, so companions are a major pillar for us.

**Roles:** each dog has one active role, set by its best trait.

| Role | What it does |
|---|---|
| **Fighter** | Attacks the Hollow, draws aggro, and can pin runners |
| **Scavenger** | Picks up nearby drops and searches containers on Fog Runs; brings small finds home |
| **Tracker** | Marks hidden caches, Hollow and players (in PvP fog) on the minimap |
| **Guard** | Defends the outpost on nights and during offline raids (M2 synergy) |
| **Hauler** | Carries extra slots (a pack harness) |

**Quality and traits:**
- Each dog has a quality tier (Common → Uncommon → Rare → Epic → Legendary) and **2–4 trait slots**, more at higher quality.
- Traits come in tiers: Bite, Nose, Stamina, Courage, Loyalty, Pack.
- Dogs level up by **training**: timed sessions at the **Kennel** that cost food.

**Breeding:**
- Pair two dogs at the Kennel. It costs food and takes a timer.
- Each of the pup's trait slots inherits from either parent or **mutates** (a chance of a tier-up or a new trait). Its quality rolls from the parents' qualities.
- **Better food raises the odds,** and that's the chase:
  - **Common Kibble** is craftable from hunted meat, with low odds.
  - **Hunter's Feast** is craftable from rare ingredients, slowly.
  - **Prime Feast** gives the best odds and is mainly sold, with a trickle from events.
- **Odds are shown in the breeding panel** when paid food can feed a roll. Roblox requires it for paid random outcomes. Gate it with PolicyService in regions that restrict paid random items.

**Rules:**
- A downed dog limps home and rests on a timer, with no permadeath, because losing a pet makes Roblox players quit.
- A companion counts toward gear score in matchmaking.
- Trading dogs between players is later.

**Money levers:**
- food bundles, with Prime Feast as the star
- premium breeds (Legendary-quality bloodlines) in packs
- Kennel capacity (how many dogs you keep)
- breeding and training speed-ups
- cosmetic coats, collars and dog armor
- a starter pup in the starter offer

**Social:** dogs follow you around the Neighbourhood, have names, and show their traits. Showing off a Legendary Tracker is identity.

**Later species:** cats (base buffs), crows (scouting) and mules (hauling), each a new collection to chase.

## Fog Runs: shared lobbies and PvP

The developer asked for this: a run should feel like a Tarkov lobby. Strangers meet, and each can team up and loot in peace or turn on the other for their loot. It has to be "healthy and balanced, so it feels real and random." The **fog tier sets the rules**, so every player picks their own risk.

**Lobbies:**
- Each location run is its own server holding **8–12 players**, matched from across all servers by **power band** (player level plus the gear score of the loadout). Parties queue together.
- The **Fog meter is shared by the whole lobby** and acts as its clock. Loot gets better and the Hollow get stronger as it rises. When it closes in (about 15 min), anyone still inside is lost to the Fog.
- That pulls everyone toward the extraction points late in the run, which is where the drama happens.
- New players can join a lobby only during its first 3 minutes.
- The Hollow are in every lobby, and gunfire noise draws them. A loud fight gets **third-partied by the horde**, which makes ambushes a gamble rather than a sure thing.

**Rules by fog tier:**

| | **Light** | **Dense** | **Black** |
|---|---|---|---|
| Entry | Anyone | Player level 8+ | Player level 15+ |
| PvP | **Off** (co-op and trading only) | **On.** Attacking a non-hostile player marks you **Hostile** for 3 min (red outline, shown on everyone's minimap) | **On**, with no marks. Anything goes. |
| Loot | **Personal:** each player gets their own container rolls | **Shared and contested** | Shared, best tier: Vault keycard fragments, rare blueprints |
| On death | Your backpack drops. **Re-enter the same lobby** while it's open (costs Energy), or have a teammate carry it out. | Backpack drops and **anyone can loot it** | **Full loot:** everything you carry drops, equipped gear included, **except your secure pouch** |
| Leaving | Any edge | 2–3 extraction points; one is closed at random each run | 2 extraction points, plus a **flare extract**: fire a flare and survive 30 s while everyone sees it |

**Bodies stay until the lobby ends.**
- Whatever a player drops on death stays in the world as a lootable body or bag, **however they died**: another player, the Hollow, or the Fog.
- It lasts until the lobby closes, when the Fog closes in. The next lobby at that location is a fresh roll.
- Example: player 1 kills player 2, then dies to the Hollow. Players 3 and 4 can loot both bodies.
- Who can open a drop depends on the fog tier:
  - **Light:** only the owner and their party.
  - **Dense:** anyone can take the backpack.
  - **Black:** anyone can take everything except the secure pouch.
- A fresh death drops a faint lantern glow that's visible from a distance. Scavengers notice and come running, which creates more emergent fights over the spoils.

**Social tools:**
- **Party up** at the Trailhead before a run, or queue with friends.
- **Truce ("show your light"):**
  - Raise a lit flare to offer a truce, and the other player accepts by raising theirs. That forms a party for the rest of the run: no friendly fire, and shared credit for Hollow kills.
  - **Betrayal is possible but never instant.** Breaking a truce takes a 2 s hold that alerts your partner ("X lowered their light"), and damage switches on 3 s later. In Dense fog the betrayer also becomes Hostile and is tagged **Oathbreaker** for the run.
- **Downed state** (in PvP tiers): at zero HP you're downed and can crawl. A teammate can revive you, or an enemy can finish you.
- **Bounties:** killing non-hostile players while Hostile posts a bounty on you, and anyone who kills you in a Dense or Black run claims it. This is the same revenge and bounty system raids use.

**PvP is the fast lane** (the developer, 2026-11-08: kill someone, take their loot, snowball):
- The free grind is days per tier, but a good PvP player can shortcut it. Dense and Black fog have richer loot, and every kill hands you everything that player carried in. Winning snowballs, and that's intended, because it's the high-risk, high-reward path that makes PvP fog worth entering.
- **Snowball limits** stop it from becoming a stomp:
  - power-band matchmaking by gear score
  - the Hostile mark and bounties on serial killers
  - gunfire drawing the Hollow, so a fight gets third-partied
  - you can only take what someone carried in, never their base
- **It works at any player count:** when a lobby is short of real players, **AI raiders** fill it. They're hostile survivor bands with real loadouts that loot, extract and fight like players, so the PvP lane and the "feels real and random" vibe hold up even in quiet hours. As player counts grow, real players replace them.
- Every gear loss creates demand for gear, which drives the gear packs.
- **The pacing simulation models both lanes:** PvE grinding, and PvP at assumed win rates. A 50% PvP player should progress faster than a PvE-only player, but not skip tiers outright.

**Lobby rules** (these keep the healthy, balanced feel the developer asked for):
- **Light fog is always PvE.** PvP tiers are faster and richer.
- **You only risk what you carry in.** Your base, storage and locked stash are never at stake on a run. Before a Dense or Black run, the loadout screen shows what's at risk.
- **Secure pouch:** 2 slots to start. Bigger pouches come from progression and **from the shop**, which is a strong Tarkov-proven lever.
- **Spawn protection:** 10 s, and players spawn spread apart.
- **Power-band matchmaking:** a veteran can't drop into a lobby of newcomers.
- **Cross-platform fairness:** touch players get aim assist in PvP, tuned with telemetry so neither PC nor mobile dominates. Time-to-kill is longer than Tarkov's, with no one-shots from full HP, so a fight is a fight and not a coin flip.

**Monetization:**
- PvP losses create constant demand for gear, ammo, weapon and armor packs, and secure-pouch upgrades.
- **Never sold:** PvP immunity. Players in a lobby must be killable, or PvP fog dies.

**Roblox implementation:**
- Each location is its own place in the universe, and lobbies are reserved servers.
- A MemoryStore queue per location and power band forms lobbies, and parties teleport together.
- The player's ProfileStore session moves with them, so extracted loot saves directly in the run server.

**Rollout:**
1. **M1:** cross-server shared lobbies from day one (this is architecture, so it isn't bolted on later). PvE in every tier, with extraction points, Trailhead parties, the lobby-wide Fog meter and re-entry to recover a backpack.
2. **M2, the PvP milestone:** PvP in Dense and Black fog, Hostile marks, truces and betrayal, downed and finishing, bounties, the secure pouch and touch aim-assist tuning. It ships together with raids and the standard firearms, so PvP balance is tuned once against the real arsenal.

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
- **Pacing: long and gruelling for a free player** (the developer, 2026-11-08: "the grind for a legit player should be long and grueling and take days of grinding"). The first hour hooks with quick wins; after that, every tier is days of grinding. Paying compresses each tier to hours.

**Free-player pacing targets** (about 2–3 h of play a day; checked by the pacing simulation):

| Milestone | Free player | Paying player |
|---|---|---|
| Hatchet, first walls, Workbench, first queue, level 5 | **first 30–60 min** (the hook) | same |
| Timber tier: a small walled base with Campfire, Workbench and crates | end of **day 1** | first session |
| Scrap tier: scrap walls, Recycler running, the first firearm | **days 3–5** | day 1 |
| Reinforced tier: a fully reinforced base | **days 10–14** | days 2–3 |
| Standard firearms and armor set | **weeks 2–3** | days 3–5 |
| First vehicle | **weeks 4–6+** | about week 1 |

**Grind levers:**
- **Bottleneck materials:** low drop rates, found only in the higher fog tiers.
- **Station timers that scale by tier:** minutes, then hours, then many hours.
- **Energy caps:** they limit Runs a day. Walking is free but slow, in real time.
- **Backpack capacity:** it limits the haul from each run.
- **Durability:** tools and weapons wear out.
- **Upgrade costs:** about ×2.5 each tier.

**Testing:** a Studio-only **DevSpeed** multiplier compresses timers, yields and Energy so the developer and workers can playtest in minutes. It's hard-disabled on live servers.

## Combat and the arsenal

LDoE is the standard here: a long weapon ladder, from improvised melee to modded firearms, is the backbone of progression and of the shop. We match its breadth and add three things it lacks:
- **Noise.** Every gunshot has a noise radius that pulls the Hollow toward you. Guns are a push-your-luck choice, not a straight upgrade.
- **Light.** Flares and fire are weapons, because the Hollow fear light.
- **A dodge roll.**

**Weapon classes:**

| Class | Role | Ladder (our own names, no real-world brands) |
|---|---|---|
| **Melee** | Silent, costs no ammo, durability only | Club → Scrapblade → Fire Axe / Machete → Rebar Maul (heavy, staggers) → Reinforced variants |
| **Bows** | Silent ranged; cheap craftable arrows | Reed Shortbow → Recurve Bow → Crossbow |
| **Firearms: improvised** | First guns, loud and unreliable | Pipe Pistol (single shot), Scrap Shotgun (two barrels) |
| **Firearms: standard** | The mid-game workhorses | Service Revolver, Semi-auto Pistol, Pump Shotgun, Hunting Rifle, SMG |
| **Firearms: advanced** | Late game, from Vaults and blueprints | Carbine (assault rifle), Marksman Rifle, Drum Shotgun |
| **Light weapons** | Signature: burn and repel the Hollow, light the area for a while | Flare Pistol, Ember Thrower (burns Hearth fuel), incendiary rounds |
| **Throwables** | Crowd control and breaching | Molotov, flashbang, breach charge (raids) |

**Supporting systems:**
- **Ammo Press:** crafts 4 ammo types (Light rounds, Shells, Rifle rounds, Flares) from Rusted Scrap plus Blackpowder. Ammo is the steady resource sink.
- **Weapon parts and blueprints:** guns are crafted at Workbench tier 2–3 from parts found deep in the Fog and in Vaults. Firearms are also found in high-tier containers.
- **Durability and repair:** at the Workbench.
- **Mods** (M2–M3): suppressor (cuts noise, which matters a lot on Fog Runs), scope, extended magazine, stock. The rarest mod blueprints are Vault drops.
- **Rating:** guns are fine at Mild. The Hollow dissolve into ash with no blood, and downed players collapse without gore.

**Monetization:**
- weapon-part packs, ammo bundles and weapon skins
- **Weapon packs** (like LDoE's "Genesis" or "Special Forces" packs) sell strong guns directly. Pay-to-win is accepted. Power-band matchmaking counts gear score, so buyers face similarly geared players.

**Rollout:**
1. **M1 slice 2:** melee, bows, Pipe Pistol, Scrap Shotgun and Flare Pistol; the Ammo Press with Light rounds, Shells and Flares; noise; dodge roll.
2. **M2 (raids):** the standard firearms, the suppressor mod and breach charges.
3. **M3:** advanced firearms, the Ember Thrower, the full mod system and Vault-exclusive weapons.
4. **Seasons:** each one adds 1–2 weapons.

## Building

- Grid **foundations**; **walls, doorways, doors, gates and windows** snap to cell edges. Build menu tabs: Foundations, Walls, Doors, Windows, Stations, Storage, Defense, Decor.
- Structure (foundations, walls, doors) snaps to the cell grid and **meshes seamlessly**. Corner posts appear where walls meet.
- **Furniture** (stations, storage, decor) is placed freely on foundations on a ¼-cell sub-grid. It snaps flush against walls and rotates in 90° steps, so bases can be laid out like real rooms.
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

**Item desire is the engine** (the developer's point, 2026-11-08). LDoE has no casino crates. It makes the items themselves so desirable that people pay for the supplies, weapons, armor and backpacks to get them faster. We design for desire on purpose:
1. **Each tier has a bottleneck material.** For example Rivets for the Scrap tier, Steel Plate for Reinforced, and gun parts for firearms. It's slow but possible to farm, and it's the star of that tier's packs.
2. **Visible power:** gear, weapons and backpacks show on your character, and every tier is a clear jump in look and stats. People want what they can see.
3. **Capacity pressure everywhere:** pockets, backpack, storage, Kennel slots and placement limits, each with a capacity product.
4. **Long goals with visible checklists:** vehicles, Hearth levels and dog lineages, with part packs and "fill up".
5. **Time:** station, training and breeding timers, with speed-ups.
6. **Chance-based chases:** dog breeding with food, and later weapon mod rolls. Better paid inputs mean better odds.
7. **Social proof:** neighbours, crews and lobby-mates see your base, your dog and your gear.

LDoE-level grind and prices, tuned with live data. Don't pre-soften them.

**Shop structure** (from the developer's 2026-11-08 recordings, rec8):
- **Tabs:** Best, Season, Daily Deals, Outpost, Equipment, Building, Vehicles, Companions, Currency, plus a **Delivery inbox** and VIP.
- **Daily free claim:** one free item every day. It's the cheapest daily return trigger there is.
- **Daily Deals:** a rotating stock of 12 items bought with soft currency. One refresh a day is free, further refreshes come from a rewarded ad (13+), and one deal a day is free with an ad.
- **Room kits:** prefab material bundles ("Timber room 3×3", "Stone room 3×3") that let a player who pays build a whole room instantly. They land in the Delivery inbox.
- **Capacity packs:** "+1 Campfire can be placed", "+1 Recycler". Placement limits ("Placed 1/2") make the value of these obvious.
- **Cards:** contents, tag ribbons (Popular, Limited, Hot), discount badges, purchase limits and countdown timers, as in LDoE. "Possible reward" packs are allowed, with the odds shown (a Roblox rule).
- **Item inbox (from M1 slice 1):** everything bought, earned (level-ups, quests, events) or mailed, and anything that overflows, arrives here first.
  - Players take it out when they have room, but they rarely need to: **at home, building, crafting and station jobs draw from pockets, backpack, all home storage and the inbox.**
  - So a big pack (for example an "Outpost Pack" with every material for Timber → Stone → Reinforced) is usable the moment it's bought, even though it could never fit in an inventory.
  - It's raid-proof, which is our "purchases go to the locked stash" rule as a screen. Bought items never expire.
- **Outpost packs:** tiered base packs with the materials to take a base from bare foundations up a full tier ladder. They're the big-ticket bundle, like LDoE's $99.99 metal room.

**Conversion levers seen in LDoE that we adopt** (detail in [reference/ldoe-recordings/NOTES.md](reference/ldoe-recordings/NOTES.md)):
- Run vs Walk on Energy
- **auto-gather** (rewarded ad with a daily cap, or paid)
- **bonus travel loot** for a rewarded ad
- **"fill up" missing blueprint parts** with premium currency
- a **premium row on the questline** next to the free rewards
- storage and part packs
- timed offers, used sparingly
- the premium currency balance with "+" shown on inventory screens

Rewarded ads are only shown to players aged 13+ (a Roblox rule).

**Stance** (the developer, 2026-11-08): LDoE has about 100k daily players on a hard grind with pay-to-win. Copy that model. Don't soften the grind or the prices up front; tune them with live data.
- **Everything is reachable without paying.** A free player can progress through all content; it's slower and grindier. Paying is the natural shortcut, never a wall.
- **The game creates the want; the shop is always one tap away when it hits.** In the developer's words, LDoE's way is "elegant and extremely effective... it's easy to make purchases in that game."

**Buy at the moment of need** (frictionless purchasing, where most conversions happen):
- **Out of Energy** when choosing Run → a "Refill" button right in the travel panel.
- **Missing materials** for a craft, build or upgrade → "Fill up" the shortfall with premium currency, in the same panel (LDoE's FILL UP).
- **Inventory full** while gathering or looting → a backpack upgrade offer on the toast.
- **Storage or placement limit reached** → a capacity pack offer in the build or storage panel.
- **Waiting on a timer** → speed up with currency, priced by time left, on the station and queue rows.
- **Downed or lost gear on a run** → a gear pack offer on the death screen.
- **Tough location, weak gear** → an equipment pack suggestion on the location panel.
- **Shared mechanics:**
  - Premium currency, so prices feel small, with the balance and "+" on every screen.
  - Roblox's one-tap purchase prompt.
  - Purchases arrive in the inbox at once and count toward have/need straight away.
- **The first purchase gets a starter offer,** shown only after the first big win (see "The first 10 minutes").

**Platform rules** (Roblox requirements, not choices):
- Any paid random outcome (packs, or breeding with paid food) shows its odds, and is hidden where PolicyService restricts paid random items.
- Rewarded ads are for 13+ only.
- Prices are read from script so price testing and regional pricing work.

**Raid rules** (these protect revenue, not fairness):
- Purchased items go to the raid-proof inbox or locked stash, so payers never get robbed of what they bought and keep buying.
- **Never sell shields, raid immunity or PvP immunity.** If spenders can hide forever, nobody has targets, and raids and PvP fog die.

## Platform requirements

- Rated **Mild**: the Hollow dissolve into ash, with no blood.
- R15 avatars and a distinct look, which qualify for the 18+ payout uplift.
- Works without chat: pings, emotes, quick chat.
- PC first, but it must hold 30+ fps on mid-range phones: streaming, LODs, low instance counts.

## MVP (first playable)

**In scope:**
- Home plot with grid building in 3 tiers
- The Fog map with Run/Walk and Energy
- 3 locations (one per fog tier) plus 1 rotating event location, run as **cross-server shared lobbies** (PvE in M1) with extraction points and the lobby-wide Fog meter
- 5–6 resources
- About 15 craftables, plus the first weapons: melee, bows, Pipe Pistol, Scrap Shotgun and Flare Pistol (see "Combat and the arsenal")
- Workbench, Campfire, Recycler and Ammo Press with timers
- Pockets/backpack inventory and storage crates
- Hunger and thirst
- 3 Hollow types
- Death drop
- **Crews:** 2–4 friends share one outpost and build together
- Quest tracker with a starter questline
- DataStore saving
- A shop with 3–4 products (resource pack, Energy refill, backpack upgrade, starter offer)
- The full UI kit and HUD

**Milestone 2 (raids and PvP, straight after the MVP):**
- Fog Run PvP in Dense and Black fog: Hostile marks, truces and betrayal, downed and finishing, bounties, the secure pouch, and AI raiders filling low-population lobbies
- Neighbour markers on the Fog map (level, defense, loot tier, shield)
- Raid tools and breach costs
- The standard firearms and the suppressor mod
- Raids on offline bases, with raidable storage versus the locked stash
- Shields, new-player protection and a raid log with revenge

**Milestone 3:** guilds (districts, defense calls, control points), live defense, and **companions** (dogs, Kennel, training, breeding, the five roles).

**Milestone 4:** Vaults, advanced firearms and the full mod system.

**Later:** vehicles, more companion species, seasons.

**How we judge it:** D1, D7 and D28 retention, session length and payer conversion.
