# Ember Outpost: Roblox project

Code and data for the game, synced into Studio with Rojo. `docs/ARCHITECTURE.md` is the binding guide; this file covers setup and day-to-day commands.

Rojo owns code and data. The Studio place file owns world geometry, models, terrain and lighting.

## One-time setup (Windows)

1. Install **Rokit** from its GitHub releases (rojo-rbx/rokit): download `rokit-<version>-windows-x86_64.zip`, unzip it and run `rokit.exe self-install`. Open a new terminal afterwards so `rokit` is on your PATH.
2. From this `roblox/` folder, install the pinned tools and packages:

```bash
rokit install
```

```bash
wally install
```

`rokit install` reads `rokit.toml` (rojo, wally, lune, selene, stylua, luau-lsp). `wally install` creates `Packages/` and `ServerPackages/`. Both folders are gitignored; `wally.lock` is committed.

## Checks (all must pass before a merge)

Run these from `roblox/`:

```bash
selene src tests
```

```bash
stylua --check src tests
```

```bash
lune run tests/run.luau
```

```bash
mkdir -p build && rojo build -o build/test.rbxl
```

`stylua src tests` (without `--check`) formats in place. `build/` is gitignored, and Rojo does not create it for you.

Type checking with luau-lsp needs Roblox's definitions file (once per luau-lsp version) and a sourcemap:

```bash
curl -sSfL -o build/globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau
```

```bash
rojo sourcemap default.project.json -o sourcemap.json && luau-lsp analyze --sourcemap=sourcemap.json --definitions=build/globalTypes.d.luau --ignore="Packages/**" --ignore="ServerPackages/**" src
```

It should be clean with both the old and new Luau type solvers (add `--flag:LuauSolverV2=true` or `false`).

## Working in Studio

Only one worker at a time touches the Studio place (ARCHITECTURE.md §11).

1. `rojo serve`, then connect from the Rojo plugin in Studio.
2. Press Play. The server validates all content first; a broken data reference stops it with a list of errors.
3. In Studio, PlayerData uses ProfileStore's mock store, so playtests never touch live saves.
4. To see the UI kit gallery, set a boolean attribute `ShowUIKit = true` on `Workspace` while playing.

## Layout

```
roblox/
  default.project.json   Rojo mapping (below)
  rokit.toml             pinned tool versions
  wally.toml, wally.lock Luau packages
  selene.toml, stylua.toml
  src/
    shared/   -> ReplicatedStorage.Shared
      Types.luau          content and inventory types
      Data/               content tables keyed by permanent ID; init.luau bundles and freezes them
      Domain/             pure logic: Inventory, Timers, Crafting, Loot, Grid, Energy, Survival,
                          Death, Travel, Rng, DataValidator, PlayerSchema, Migrations
      Net/                Remotes (the one list of remotes), Check (validators), RateLimiter
      Util/               Table helpers, Lifecycle (service/controller boot)
    server/   -> ServerScriptService.Server
      Boot.server.luau    validate content, create remotes, init() then start() every service
      Net.luau            server half of Net: rate limit + validate every client request
      Services/           Analytics, Diagnostics, PlayerData
    client/   -> StarterPlayer.StarterPlayerScripts.Client
      Boot.client.luau    init() then start() every controller
      Net.luau            client half of Net
      Controllers/        Diagnostics (Ping check), Interface (mounts React)
      UI/                 theme tokens, components (Button, Panel, ItemSlot, ProgressBar), screens
  tests/      Lune specs (run.luau lists them)
```

Wally packages map to `ReplicatedStorage.Packages` (React, ReactRoblox, Signal) and `ServerStorage.ServerPackages` (ProfileStore).

## Conventions

- `--!strict` at the top of every file.
- **Requires:** inside one tree, use relative string requires (`require("./Inventory")`, `require("../Types")`, `require("@self/Items")` from an `init.luau`). To reach another tree (Packages, or Shared from server/client code), index through the service: `require(ReplicatedStorage.Shared.Domain.Inventory)`. Pure `shared/` modules use only string requires, so Lune can run them.
- **Domain modules** are pure: no Roblox APIs and no instances; pass `now` and data in. Each one gets a Lune spec.
- **Content** is data: add or change entries in `shared/Data/`. IDs are `prefix.snake_case` and never change. The validator spec checks every reference.
- **Remotes:** add an entry to `shared/Net/Remotes.luau` with a validator and a rate limit, then bind it with `Net.onEvent` / `Net.onInvoke` in a service's `init()`.
- **Services and controllers** return a table with optional `init()` (no yielding, no calls into other modules) and `start()`. Boot finds them by folder.
- **Save schema changes:** bump `PlayerSchema.VERSION` and add a migration step; the Lune suite fails without one.
- **UI:** build from `UI/components` and `UI/theme` only; no one-off colors, fonts or radii.

## Adding a test

Create `tests/<Name>.spec.luau` returning `function(test) test("does X", function() ... end) end`, then add it to `SPECS` in `tests/run.luau`.
