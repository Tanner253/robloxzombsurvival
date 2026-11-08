# MVP launch plan (v0.1): publish a playable multiplayer game

Written by the orchestrator on 2026-11-08, after the developer said: "please get the game to MVP and playable multiplayer and lootable areas etc, we need to get this published... this is by far the most time consuming and slow development process."

**This file sets the launch scope.** Anything not listed under IN waits for a post-launch update, however good an idea it is. Quality rules still apply (checklist §0: nothing visible below A, no emoji, zero UI overlaps, LDoE parity on everything that ships).

## IN for v0.1

**Home: the Neighbourhood, up to 8 players per server, in the cloud place "Ember"** (session S1b)
- Gathering with finite home nodes, at arm's reach, with free AUTO.
- The LDoE HUD (#1–#12), the two-pane inventory and storage (#13–#16), and the item inbox.
- Hand-crafting catalogue, plus stations as converters. The launch set is Campfire, Woodworking Bench and Workbench (parts). Stonecutter and Smelter ship only if their models grade A in time; otherwise their recipes stay at the Workbench for v0.1.
- Building: 3 tiers, seamless, one material per tier, furniture against walls, the build-mode UX (#25–#28).
- Survival at LDoE rates. Readable nights. The old pines restored, with the occlusion fade fixed.
- **Ember Trail chapter 1** (quest-gated blueprints, a tracker that completes quests). A simple first-session flow.

**Fog Runs: lootable areas, PvE, multiplayer lobbies of up to 12** (session S2B)
- The Fog map with **3 locations**: Light, Dense and Black. Run/Walk with Energy (#38). Location panels and the loading screen.
- Each location is a **handcrafted, dense map built from code** (world-as-code), with **lootable containers** (search bar, loot panel).
- **The Hollow:** shambler, runner and bloater, rigged and animated, dissolving to ash. Combat with melee, bow, Pipe Pistol, Scrap Shotgun and Flare Pistol, plus the Ammo Press, noise and the dodge roll.
- Death: the backpack drops, re-entry while the lobby is open, extraction, the lobby-wide Fog meter.
- **Architecture: one place, two server roles** (decided 2026-11-08). Lobbies are reserved servers of the **same** place. On start, a server reads its teleport data or private-server ID and builds either the Neighbourhood or a location map. No extra places to create, and one `rojo build` publishes everything.

**Platform**
- ProfileStore on live DataStores, with schema migrations.
- **Monetization v0.1:** Starter Pack, Resource Pack, Energy Refill and Backpack Upgrade as developer products, with a simple shop screen in the LDoE card style. Purchases go to the inbox. Plus the moment-of-need buttons for Energy and Fill up.
- Experience icon, 3 thumbnails and description: made by the orchestrator.
- A publish checklist for the developer (the physical and account steps only).

## OUT (post-launch updates, in order)
1. **M2:** PvP in Dense and Black, raids, AI raiders, sneak, standard firearms, death recovery for ads or premium, the shop's Daily Deals.
2. **M3:** crews, guilds, companions, live defense, the quest screen with its premium row, skills, achievements, VIP points.
3. **M4:** Vaults, the vehicle frame and parts checklist, airdrops, region gates, the Haven hub, fog exposure, the wildlife economy.

## How we go fast
- **Two sessions in two Studio windows at once:** S1b in the cloud place "Ember", and S2B in a second Studio window opened from `roblox/build/EmberRuns.rbxl`, synced by Rojo on port **34873**. Two separate Studio windows don't collide.
- One consolidated brief per session. No drip-fed messages.
- The orchestrator merges each session to main as soon as its checks are green, and grades captures against the LDoE frames.
- **Launch gate:**
  - a 30-minute scripted playtest by a fresh QA subagent: new player → gather → craft → build → Run → loot → fight → die or extract → home
  - the overlap gate at zero
  - no below-A visible
  - checks green

## Publish checklist (developer; the orchestrator gives exact steps when ready)
1. File → **Publish** the final build of "Ember".
2. Creator Dashboard → the experience → **Questionnaire** (Mild: fantasy violence, no blood).
3. Set the experience **Public**, with genre Survival.
4. Confirm the icon, thumbnails and description (uploaded via Open Cloud where permitted).
