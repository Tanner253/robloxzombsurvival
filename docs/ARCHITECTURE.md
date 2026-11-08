# Architecture: "Ember Outpost" on Roblox

Goal: a codebase that holds Last Day on Earth-level system depth without turning into spaghetti. Every worker session follows this. Changes to it are recorded in [DECISIONS.md](DECISIONS.md).

## 1. Principles

1. **Data-driven content.** Items, recipes, loot tables, locations, dungeons, stations, enemies, build pieces, quests and shop products are **data**, not code. Adding a new item or location should mean editing data only.
2. **Server-authoritative.** The client asks; the server validates and decides. Nothing stealable or progression-relevant is ever trusted from the client.
3. **Pure domain logic.** Inventory math, crafting checks, loot rolls, grid placement, timers and raid loot are pure Luau modules with no Roblox objects or APIs, so they can be unit-tested in seconds.
4. **Small services with clear boundaries.** One service per feature. Services talk through their public APIs and signals and never reach into each other's internals.
5. **Time is a timestamp.** Every timer (crafting, stations, crops, location resets, shields, energy regen) stores absolute UTC timestamps. Offline progress is computed when a player loads. Nothing "ticks" per player.
6. **Stable IDs forever.** Every content entry has a permanent string ID (`item.plank_wood`, `loc.pine_grove`). Display names can change, but IDs never do. Save data references IDs only.
7. **Strict types everywhere.** Every file uses `--!strict`, and every data table has a type.

## 2. Toolchain

| Tool | Purpose |
|---|---|
| **Git** | Version control for all code, data and docs. |
| **Rojo** | Syncs the `roblox/src` files into Studio. Code lives in the repo, not only in the place file. |
| **Rokit** | Pins tool versions (Rojo, Wally, Lune, Selene, StyLua). |
| **Wally** | Third-party Luau packages. |
| **luau-lsp, Selene, StyLua** | Type checking, linting and formatting. All must pass before a merge. |
| **Lune** | Runs unit tests for pure domain modules and data validation outside Studio. |
| **Roblox Studio MCP** | World building, asset work, playtests, screenshots, and in-engine test runs (`execute_luau`). |

**Split of responsibility:** Rojo owns **code and data**. The Studio place file owns **world geometry, models, terrain and lighting**. We rely on Roblox's place version history and also export a backup of the place at each milestone.

## 3. Libraries (chosen once, not per feature)

| Need | Choice |
|---|---|
| Player save data | **ProfileStore**: session locking, versioned schema with migrations |
| Replicating player state to the client | **Replica** (MadStudio) or a thin custom replicator, decided in M0 |
| UI | **React-lua** (jsdotlua): components plus theme tokens taken from ART_DIRECTION.md |
| Signals | GoodSignal-style module |
| Networking | Our own `Net` module: one typed list of remotes, with a server-side validator and rate limit on every remote. It can move to Zap later if bandwidth requires. |
| Analytics | Roblox **AnalyticsService**: economy, progression and funnel events from day one |

## 4. Repository layout

```
roblox/
  default.project.json        Rojo mapping
  rokit.toml wally.toml selene.toml stylua.toml
  src/
    shared/                   -> ReplicatedStorage.Shared
      Data/                   content tables (pure data, typed)
        Items  Recipes  Stations  ResourceNodes  Crops
        LootTables  Locations  Dungeons  AccessKeys  Events
        Enemies  BuildPieces  Quests  Products  Tuning
      Domain/                 pure logic (unit-tested with Lune)
        Inventory  Crafting  Loot  Grid  Timers  Energy  Raid
      Types.luau              shared types
      Net/Remotes.luau        the one list of every remote
      Util/
    server/                   -> ServerScriptService.Server
      Services/
        PlayerData  Inventory  Gathering  Crafting  Stations
        Building  WorldMap  Locations  Enemies  Combat  Loot
        Survival  Death  Quests  Shop  Analytics
        (M2) RaidIndex  Raids  Shields   (M3) Guilds  Territory
      Boot.server.luau        init() all services, then start() all
    client/                   -> StarterPlayerScripts.Client
      Controllers/            Input  Camera  Building  Combat  Interaction
      UI/
        theme/                tokens: colors, radius, stroke, font
        components/           Button  Panel  ItemSlot  ProgressBar  Timer ...
        screens/              HUD  Inventory  Crafting  BuildMenu  Map  Shop ...
      Boot.client.luau
  tests/                      Lune specs: Domain logic + Data integrity
```

## 5. Data layer

- **Content definitions**, each a typed table keyed by ID:
  - `ItemDef`: id, name, category, tier, stack size, durability, icon, flags
  - `RecipeDef`: inputs, outputs, station, craft time, unlock gate
  - `LootTable`: entries, weights, min and max counts, guaranteed drops
  - `LocationDef`: fog tier, level gate, energy cost, walk time, reset timer, loot tables, enemy spawns
  - `DungeonDef` and `FloorDef`, plus `AccessKeyDef` for keycard chains
  - `StationDef`: levels, queue slots, fuel
  - `BuildPieceDef`: kind, tier, HP, cost, breach cost
  - `QuestDef`, `ProductDef`
- The exact fields are finalised from the systems catalog in `docs/ldoe-systems/`.
- **A data validator** (a Lune test, also run at server boot in Studio) checks that every reference points at something that exists: recipe inputs, loot entries, location loot tables, keycard chains, quest rewards and product grants. **A broken reference fails the build.**
- **Tuning** lives in `Data/Tuning`: energy cap and regen, raid percentages, shield durations. There are no magic numbers in services.

## 6. Player data

- **ProfileStore schema with a version number,** and migration functions for every schema change. Sections:
  - inventory (pockets, backpack, equipment)
  - storage
  - locked stash
  - stations (queues as timestamps)
  - crops
  - player level and XP
  - energy (value plus last-update timestamp)
  - quest state
  - unlocked recipes and blueprints
  - purchase receipts (idempotency)
  - shield and raid log
- **The outpost layout** (grid pieces) is stored as compact, versioned data, saved **separately** from the profile so a big base can't hit the profile size limit.
  - **Outposts are their own entity,** keyed by `outpostId` and holding `ownerId`, `members[]` (crews of up to 4) and per-member roles.
  - Plots are assigned per outpost, not per player.
  - An outpost is **session-locked to one server** at a time. A crewmate who joins elsewhere is offered a teleport to the server holding it.
  - Each member's locked stash stays in their own profile.
- **Purchases:** `ProcessReceipt` grants each purchase exactly once. The receipt ID is recorded in the profile before the grant is confirmed. Purchased goods go into the **locked stash**.

## 7. World and places

- **World place (the Neighbourhood):**
  - 6–8 outpost plots (crews share one)
  - the Haven hub
  - the Trailhead
- **Location places (Fog Runs):** each location is its own place, played in **reserved-server lobbies of 8–12 players** from across servers.
  - A MemoryStore queue per location and power band forms the lobbies, and parties teleport together.
  - The player's ProfileStore session moves with them.
  - Travel uses the Fog map UI (Run or Walk), then teleports into the lobby. This replaces the earlier plan of streaming zones into the world server; see GAME_DESIGN "Fog Runs: shared lobbies and PvP".
- **Raid place (M2):** a reserved server that loads the target's outpost and storage snapshot. The target is locked while the raid runs, and loot is applied in one transaction afterwards.
- **Vault place (M3):** reserved servers for party dungeon runs.
- **MemoryStore (M2):**
  - a region and power-band index of outposts for the map and matchmaking
  - raid locks
  - shield expiry

## 8. Networking and security

- Every remote is declared in `Net/Remotes` with an argument schema. The server validates types, ranges, ownership, distance and cooldowns. Requests from the client are only requests.
- **Combat:** hits are validated on the server, with tolerance for lag (distance and angle checks, attack cooldowns).
- **Loot pickup and gathering:** the server checks distance and that the node or container still exists. Every loot roll happens on the server.
- **Building:** placement uses the same pure `Grid` module on client (preview) and server (authority).
- Rate limits are set per remote, and violations are logged to analytics.

## 9. Client

- **Controllers** handle input (touch, mouse and keyboard, gamepad), the fixed angled top-down camera, build mode and interaction prompts.
- **UI:** every element is built from the shared components and theme tokens. No one-off styling. Screens read replicated state and send intents through `Net`.

## 10. Testing and definition of done

A feature is done only when all of these hold:
1. Its domain logic has Lune unit tests, and they pass.
2. The data validator passes.
3. Selene, StyLua and luau-lsp are clean.
4. It has been playtested in Studio through MCP, with screenshots at phone framing that meet ART_DIRECTION.md.
5. Analytics events for the feature are logged.
6. **Every row its slice owns in [PLAYER_EXPERIENCE_CHECKLIST.md](PLAYER_EXPERIENCE_CHECKLIST.md) is audited** (✅/⚠️/❌), and the feature-feel rule (§0 there) holds. The audit table goes in the report.
7. An **adversarial QA subagent** has graded every visible object and screen, and nothing below A is visible (checklist §0).
8. The orchestrator has reviewed the diff and a **complete capture census** (every distinct world object close up and at gameplay zoom, and every UI screen), and re-checked the checklist rows. The orchestrator grades too, defaulting to C, and blocks anything that wouldn't hold up next to LDoE, whether or not anyone flagged it.

## 11. Worker workflow

- One feature per ticket, specified from GAME_DESIGN.md and the systems catalog.
- **Code-only work** (Domain, Data, tests) can run in parallel, each in its own git worktree or branch.
- **Anything that touches the Studio place** (Rojo sync, world building, playtests) runs **one worker at a time**.
- **Zero developer maintenance** (the developer's rule, 2026-11-08):
  - Workers **never** ask the developer questions (no AskUserQuestion). They send anything they truly can't resolve to the orchestrator.
  - Workers start and stop playtests themselves (`start_stop_play`). If the developer's playtest is running, stop it, work, then restart it.
  - Workers judge visuals themselves from captures.
- **The repo is the master copy of the whole place (world-as-code):**
  - World layout, dressing placement and procedural Terrain are built by Rojo-synced builder code from repo data.
  - Kit models live in the repo as `.rbxmx` files synced into ServerStorage.
  - Nothing may exist only in an unsaved Studio window, so Ctrl+S is never needed. A fresh `rojo build` must reproduce the full game.
- **Repo:** https://github.com/Tanner253/robloxzombsurvival (`origin`). **Commit often**, in small logical commits, and push each one to the feature branch on origin.
- Merging into `main` happens after the orchestrator reviews and the developer approves.
- Workers sharing this folder never check out another branch. Parallel code work uses its own git worktree.

## 12. Build order

**M0, foundation:**
- repo and toolchain
- Rojo project
- Boot and the service skeleton
- `Net`
- ProfileStore with schema v1
- Data types and the validator
- Lune test harness
- the UI kit (theme plus core components)
- the analytics wrapper

**M1, MVP**, in this order:
1. Inventory and storage
2. Gathering (nodes, tools, respawn)
3. Crafting and stations (timers, offline progress)
4. Survival meters and Energy
5. Building (grid, tiers, upgrades)
6. Fog map and travel
7. Locations: streaming, containers, loot
8. Enemies and combat
9. Death drop
10. Quests and the starter questline
11. Shop and products
12. Polish pass

**M2, raids:** RaidIndex, the raid place, breach tools, raidable storage versus the locked stash, shields, raid log and revenge.

**M3:** guilds, live defense, territory, Vaults.
