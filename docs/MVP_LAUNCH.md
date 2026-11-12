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

**Haven Square: the public safe-zone hub, inside every Neighbourhood server** (session S1b, after the shop). The developer's ask on 2026-11-08: "a public outpost... to meet with quests and traders and NPCs or access VIP areas like Last Day on Earth has, to drive micro txns and also allow players to meet guild and stuff in a safe zone". It follows the LDoE Settlement (rec4).
- **Layout:** a central plaza in the middle of each Neighbourhood, with the 8 plots around it and the Trailhead just off the square. That makes it instantly multiplayer, with no new server role. It's a **safe zone**: no Hollow, and no PvP ever.
- **The Trader** (an NPC with a stall): buys and sells basics for coins. In v0.1 it's a small fixed stock; Daily Deals come in M2.
- **The Quest-giver** (an NPC): Ember Trail chapter hand-ins and a daily contract board (3 contracts a day).
- **The VIP Lounge:** a game-pass-gated fenced area with a warm fire, a cosmetic flame aura, a daily VIP crate in the inbox, and a VIP Energy cap bonus. People can see it from outside, which is the point (aspiration sells).
- **Social:** a notice board (server-wide Blood Moon later), a guild banner spot (guilds come in M3), emote space and a campfire circle.
- **NPC dialogue in the LDoE style** (rec4 speech bubble and talk button). NPCs are survivor-rig variants, so no new credits.

**Later (M3):** a large cross-server **Haven** hub as its own server role, with the guild hall, more traders, events and Haven-only quests.

**Fog Runs: lootable areas, PvE, multiplayer lobbies of up to 12** (session S2B)
- The Fog map with **3 locations**: Light, Dense and Black. Run/Walk with Energy (#38). Location panels and the loading screen.
- Each location is a **handcrafted, dense map built from code** (world-as-code), with **lootable containers** (search bar, loot panel).
- **The Hollow:** shambler, runner and bloater, rigged and animated, dissolving to ash. Combat with melee, the bow and the full [ARSENAL.md](ARSENAL.md) roster: 14 realistic guns in 3 tiers, with no ammo (durability is shots), plus noise and the dodge roll.
- Death: the backpack drops, re-entry while the lobby is open, extraction, the lobby-wide Fog meter.
- **Architecture: one place, two server roles** (decided 2026-11-08). Lobbies are reserved servers of the **same** place. On start, a server reads its teleport data or private-server ID and builds either the Neighbourhood or a location map. No extra places to create, and one `rojo build` publishes everything.

**Assets from the developer's Zona repo** (`C:\Users\perci\source\repos\Zona`, browserdayz). The developer's scope: **weapons and animations ONLY**, owned by S2B. No Zona trees, props, buildings, rocks or zombies. Home keeps the original EO_PineTree, which the developer liked.
- Every CC-BY asset we use goes into our `CREDITS.md`, and the game ships an in-game **Credits** panel (Settings → Credits). Launch requirement.

**Platform**
- ProfileStore on live DataStores, with schema migrations.
- **Monetization v0.1**, from `docs/research/ldoe-monetization-playbook.md`.
  - **Premium currency: Embers.** Our name; it replaces the playbook's "Gold". It's needed because developer products have fixed prices, so Fill up, timer speed-ups, death recovery and Rations are priced in Embers: recover all 100, a Ration 20, speed-ups by time left.
  - **The 10 v0.1 SKUs** (in Robux):

    | SKU | Price | Notes |
    |---|---|---|
    | Firestarter Kit | 99 | Shown once, to never-payers only, in a 48 h window after their first win |
    | Scavenger's Kit | 79 | A repeatable gear refill, offered on the death screen |
    | Supply Bundle | 99 | |
    | Builder's Crate | 399 | |
    | Reinforced Room Kit | 1,699 | |
    | Energy Refill | 99 | |
    | Ember Pouch | 149 | 50 Embers |
    | Ember Chest | 799 | 300 Embers |
    | Pack Expansion | 199 | Game pass |
    | VIP Lounge | 399 | Game pass (Haven Square) |

  - **The full catalog (32 SKUs in six tabs) is [SHOP_CATALOG.md](SHOP_CATALOG.md) (2026-11-08), which replaces the tables below.** Changes: Gun Parts Pack (renamed), Heavy Loadout (renamed), Raider Arms at 1,199, and the Reinforced Room Kit as a whole room at 4,499 with the Plans included.
  - **Equipment tab (added 2026-11-08 from rec8_sheet4,** LDoE's Equipment tab: Weapons $0.99, Genesis Weapon Pack $2.99 Hot, Special Forces $2.99, Rad Protection $1.99, Pack of Weapon Parts $1.99, Scout's Equipment $0.99, Heavy Equipment $24.99). Fixed contents, P2W accepted:

    | SKU | Robux | Notes |
    |---|---|---|
    | Scout's Kit | 79 | Meds, dressings and a light melee weapon |
    | Gunrunner Pack | 249 | Hot: Worn Pistol and Scrap Shotgun at full durability, plus a Trigger Group |
    | Pack of Weapon Parts | 149 | The rare parts that gun and tool re-crafts need |
    | Padded Armor Pack | 199 | The full Padded set |
    | Raider Arms | 499 | The best v0.1 guns, Rail Mallet, Hidebound helmet and vest |
    | Heavy Equipment | 2,499 | Big ticket: full Hidebound set, every v0.1 gun, top melee, meds stack |

  - **Every pack is repurchasable,** because everything in it is used up or wears out. Weapons, tools and armor carry durability (guns count shots); food, meds and materials are consumed. Packs are repeatable developer products ("Buy as often as you like"). Only game passes (VIP, Pack Expansion), the capacity packs and the one-time Firestarter Kit are permanent or once-only. Pack items arrive at full durability with no repair path, so the next purchase is the natural refill.
  - **Building tab capacity packs:** "+1 Smelter can be placed" 399 and "+1 Recycler" 399, following LDoE's "+1 max furnace can be placed".
  - **No ammo (decided 2026-11-08, the developer: "we don't need ammo for guns, everything runs on durability").** As in LDoE, every gun's and bow's durability is its shot count. That removes ammo items, ammo recipes and the Ammo Press from v0.1. Gun durability and re-crafts are the sink, which also drives the gun packs.
  - **The price ladder for later SKUs:** 79 / 99 / 149 / 199 / 249 / 399 / 799 / 1,199 / 1,699 / 2,499 / 4,499 / 9,999 / 17,999.
  - **Shop UX:** Last Day on Earth card style (rec8). Purchases go to the inbox.
  - **Moment-of-need buttons:**
    - Energy on the travel panel
    - Fill up on craft and build
    - a gear offer on the death screen and on a broken weapon
    - a backpack offer when the inventory is full
  - **Roblox rules:** discounts must be genuine sale windows of at least 72 h, a countdown never restarts for the same item, and products launched in the 14 days before Black Friday (27 Nov 2026) get bonus contents rather than a discount badge.
  - **Raid rules:** never sell locked-stash capacity, since raid-proof storage would be raid immunity for goods. Death recovery never returns items another player has already looted.
  - **Next in M2:** the 21-day season pass (Premium 799, plus level skips), Survivor Club (499 a month), and the VIP points ladder (1 point per 10 Robux).
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

## Publish checklist (developer)

Exact steps, written 2026-11-11 on branch `ship-readiness` after the launch playtest. Each one is a physical or account action. **"After N"** means step N must be done first. All 18 shop products and passes already exist on Roblox, priced and on sale (checked with `GetProductInfo`; the table is in HANDOFF §6, "ship readiness"), so there is no product to create.

1. **Done (2026-11-12):** the orchestrator merged `ship-readiness` into main.
2. **Studio, the "Ember" place, Edit mode, Rojo plugin connected to main** (after 1). In the Explorer, look in `ServerStorage`, `StarterPlayer` and `ReplicatedStorage` for two folders with the same name (a Rojo "twin"). If you find one, delete the copy whose meshes are empty. Then **File → Save to Roblox**.
3. **Optional: Home → Game Settings → Security → "Enable Studio Access to API Services": on.** It is safe: Studio play saves only to `_Studio` DataStores, never to live saves. It lets Studio tests keep a profile across play sessions (the Walk-resume check needs it).
4. **Game Settings → Places → "Ember" → Max Players: 8** (after 2). The Neighbourhood has 8 plots, and a 9th player gets no plot. Run lobbies are servers of the same place, so they also hold 8 (`Tuning.lobby.capacity` is 8 to match).
5. **File → Publish to Roblox** (after 2 and 4). The experience stays **Private**.
6. **Live private test, about 15 minutes, on the website with your account** (after 5). This is the first time a real reserved-server teleport runs; Studio only simulates it.
   1. Join. Your plot and Haven Square load, and the HUD shows Energy 120 (160 if you own the VIP Lounge pass, as the creator does).
   2. Walk to the Trailhead sign, open the Fog map, pick Pine Hollow, press **RUN**. You should arrive within about 10 s.
   3. Search a crate, then walk out at the map's edge. The results card shows; press **Continue**. You should be teleported home with the loot.
   4. Run again and let a Hollow kill you (or reset). On the death screen press **Continue**: you should wake at home.
   5. Press **F9**. Under the Client tab, check for red script errors and for any model that rendered plain white. Send the orchestrator a screenshot if you see either.
   6. Repeat 6.1–6.3 once on a phone (touch has never been tested).
7. **Creator Dashboard → the experience → Audience → Maturity & Compliance questionnaire** (any time). Answer from what is in the game: violence yes (melee, a bow and realistic guns against undead "Hollow", who crumble to ash); blood or gore no; crude humor no; romance no; alcohol, drugs or tobacco no; gambling or paid random items no (every pack has fixed contents); strong language no. Accept the rating it gives.
8. **Creator Dashboard → the experience → Configure → Basic Info** (after 5). Name: Ember Outpost. Description: paste `docs/store/description.txt`. Genre: Survival. Devices: Computer, Phone and Tablet (Phone only if 6.6 passed).
9. **Creator Dashboard → the experience → Configure → Places → Ember → Icon and Thumbnails** (after 5). Icon: `docs/store/icon_512.png`. Thumbnails, in this order: `thumb1_fight_1920.png`, `thumb2_base_1920.png`, `thumb3_scavenge_1920.png`.
10. **Make it Public**: Creator Dashboard → the experience → the Private/Public switch (after 6, 7, 8 and 9).
11. **The soft launch** (after 10): put the small ads budget behind it (HANDOFF §6 step 6) and watch the first hour's Developer Console errors.
