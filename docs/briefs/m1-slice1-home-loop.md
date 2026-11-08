# Worker brief: M1 slice 1, the playable home loop

The orchestrator wrote this on 2026-11-07. It's ready to hand to a fresh worker session in its own git worktree, on branch `m1-slice1-home-loop`.

**Goal:** wire the merged Data and Domain layers into real server services, client controllers and UI, so a player can **gather → craft at stations → build on their plot**, with saves that persist.

**Read first:**
- `docs/ARCHITECTURE.md` (binding)
- `docs/GAME_DESIGN.md`: Vision, Structure, Building and MVP
- `docs/ART_DIRECTION.md`: the "impressive" checklist, the UI kit and the quality benchmark
- `docs/CONTENT_MVP.md`
- `roblox/README.md`
- the `Domain/*` public APIs
- `docs/reference/ldoe-recordings/NOTES.md`, for interaction flow

**Binding:** every row owned by **S1** in `docs/PLAYER_EXPERIENCE_CHECKLIST.md` (added 2026-11-08), plus the feature-feel rule in its §0.

**Quality bar:** "the game should be impressive." No default-looking UI, and no placeholder parts where kit art exists. Tweened panels, reward pops, sounds (placeholder IDs marked), snap animations.

## Scope

- **Services:**
  - **Inventory:** pockets, backpack, equipment, storage crates and the locked stash; server-authoritative moves, split and take-all.
  - **Gathering:** nodes on the home plot area, tool checks, yield, respawn, XP.
  - **Crafting and stations:** Workbench, Campfire and Recycler, with queues, offline completion and fuel.
  - **Survival:** hunger and thirst in the world.
  - **Energy:** display and regen only.
  - **PlayerLevel/XP.**
  - **Building:** the grid on the player's plot, with place, upgrade and demolish through the Grid module; the layout persists.
  - **Plots:** 6–8 per server, claimed on join, saved and restored.
- **Client:**
  - Controllers: the camera (fixed angled top-down, zoom), PC-first input (WASD, mouse aim, LMB, E, Shift, 1–9, Tab, B) with a touch fallback, interaction prompts, and build mode with a ghost preview that uses the same Grid rules.
  - **React UI:** HUD (superseded on 2026-11-08: see docs/LDOE_PARITY.md; no hotbar), Inventory (pockets, backpack, equipment, a storage panel with Take all/Put all), station screens (recipes, queue, timers, collect), and the build menu (Foundations, Walls, Doors, Windows, Stations, Storage). All with keybind hints.
- **World:** `Workspace.World` holds the plots, ground and nodes. Reuse the art masters in `ServerStorage.EO_Kit` and the dressing assets by name. **Don't modify `Workspace.LookTest`.**

## Studio coordination

- **Phase 1** is code-only: write the code and Lune tests, and run selene/stylua/luau-lsp/`rojo build`. No Studio.
- **Phase 2:** message the orchestrator and wait for its go-ahead before any Studio MCP call or Rojo sync. Rojo plugin setup may need the developer to click. Playtest save/load, a crafting queue across a rejoin, and placement on the server versus the client.

## Rules and deliverables

- Follow ARCHITECTURE.md: one service per feature, every remote declared in `Net` with a validator, Tuning instead of magic numbers, server validation, `--!strict`.
- Commit often and push the branch. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push to `main`; the orchestrator reviews and merges.
- **Deliverables:**
  - a pushed branch with all checks green
  - playtest captures (a 15-second clip or 4–6 sequential shots, plus 16:9 shots of the HUD, inventory, a station and build mode) in `docs/milestones/m1-slice1/`, left uncommitted
  - a report of about 250 words
- Be token-frugal: no Workflow tool and no subagent fan-out.
