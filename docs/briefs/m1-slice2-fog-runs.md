# Worker brief: M1 slice 2, Fog Runs (travel, lobbies, combat, the Hollow)

Written by the orchestrator on 2026-11-08.

**Binding:**
- every row owned by **S2** in `docs/PLAYER_EXPERIENCE_CHECKLIST.md` (§11–13, plus §1.9, §7.4, §8.7, §8.8)
- the feature-feel rule and the "never visible below A" rule in its §0
- `docs/ARCHITECTURE.md`

**Read first:** GAME_DESIGN sections "Leaving home", "Fog Runs: shared lobbies and PvP", "Combat and the arsenal" and "Free-player pacing targets"; ART_DIRECTION §6 and §10a; `docs/reference/ldoe-recordings/NOTES.md` (rec3, rec6, rec7).

**Never ask the developer anything.** No AskUserQuestion. Questions go to the orchestrator.

## Phase A: code only, runs now in parallel with slice 1 (no Studio, no Rojo sync)

- **Branch:** `claude/m1-slice2-domain`, created from `origin/claude/m1-slice1-home-loop-b55c20` (not main; slice 1 hasn't merged yet).
- **Edits to shared files** (`Data/Items`, `Recipes`, `Stations`, `Tuning`, `Data/init`, `Net/Remotes`) must be **small and additive** so the later merge is trivial.
- **New features stay behind feature flags that are off by default** (`Tuning.features.fogRuns = false`). Nothing new may appear in the live place until Phase B art grades A.

### Domain modules
Pure Luau, `--!strict`, every one with Lune tests.

| Module | Responsibility |
|---|---|
| `Lobby` | Lifecycle: open, then joinable for 3 min, then running, a 60 s warning, then closed when the Fog meter maxes (about 15 min). Fog meter as a function of time, plus loot-tier and Hollow-strength multipliers by meter band. Capacity 12, and join checks (power band, joinable window). Death-drop records with **access by fog tier**: Light means owner and party; Dense means anyone takes the backpack; Black means anyone takes everything except the secure pouch. Bags persist until the lobby closes. Re-entry while open, at an Energy cost. |
| `Extraction` | Light: any edge. Dense and Black: 2–3 points, with one closed at random per lobby seed. An 8 s channel, interrupted by damage. Results. |
| `Matchmaking` | Gear score from the loadout (weapon, armor and backpack tiers; a companion hook for M3). Power band. A queue that keeps parties together, fills to 12, and widens the band the longer a player waits. A hook for AI-raider backfill, behind an M2 flag. |
| `Combat` | Damage (base, armor reduction, crit), melee light and heavy with stamina, firearm stats (fire interval, magazine, reload, spread cone, range, projectile speed), the bow (draw time, arrow recovery chance), dodge roll (i-frame window, stamina cost, cooldown), and hit-stop and knockback values as data. A TTK test: no player one-shot from full HP (an M2 PvP rule; the data is in place now). |
| `Noise` | Emission per action: each gun's radius, plus melee, bow, sprint footsteps and the bloater burst. Decay, and aggro selection for nearby Hollow. |
| `HollowAI` | A pure state machine: Idle, Wander, Alert, Chase, Attack, Flee (from light), Dead. Its inputs are distance, a line-of-sight flag, noise events, light exposure and HP. Its outputs are state, target and action. Archetype parameters for **shambler, runner and bloater**; the bloater bursts into a toxic cloud. |
| `Containers` | Search duration, interruptible, searched state. Per-player rolls in Light, shared rolls in Dense and Black. Loot scaled by fog tier and meter band (reuse `Loot`). |
| `TravelBonus` | An on-arrival "found on the way" roll. |
| `Flare` | Light radius, duration, burn damage per second, and the radius in which the Hollow flee. |
| Extend `Travel` and `Energy` | Run's Energy cost and Walk's real-time duration per location, and re-entry cost. |

### Data
All of it passes `DataValidator`.

- **Locations:** 3 (one each for Light, Dense and Black) plus 1 rotating event, with: fog tier, recommended gear score, loot tables, Hollow spawn sets, extraction config, and Run and Walk costs. Use **our own names**.
- **Enemies:** shambler, runner, bloater (HP, speed, damage, attack range and rate, perception, light fear, XP, drops).
- **Items:** Pipe Pistol, Scrap Shotgun, Flare Pistol, Light rounds, Shells, Flares, Blackpowder and its sources, with durability. Add a few melee weapons if the ladder needs them (Fire Axe, Machete).
- **Recipes:** Workbench crafts the three guns. The **Ammo Press** station (new) crafts the ammo and flares.
- **Loot tables** per location tier and meter band.
- **Tuning:** lobby timings, noise radii, combat constants, dodge, and feature flags.
- **Pacing:** follow GAME_DESIGN's free-player pacing targets. The first firearm should land on days 3–5 for a free player. Put a comment on each value saying which target it serves.

### Server services
Written and unit-testable now, but **not playtested until Phase B**. All behind flags.

- **`LobbyService`:** server lobby state over `Domain.Lobby`, behind a **teleport adapter interface**. Real `TeleportService` reserved servers run live; a same-server simulation runs in Studio, where teleports don't work.
- **`CombatService`:** server-authoritative hits with rate limits, range, a line-of-sight hook and ammo use. Every remote declared in `Net` with a validator.
- **`HollowService`:** spawner plus an AI tick, network-light (server AI, client interpolation).
- **`ContainerService`, `ExtractionService`**, and the Travel extensions.

### Done for Phase A
- `lune run tests/run`, `selene src`, `stylua --check src tests`, luau-lsp and `rojo build` are all green. Commit often and push the branch, never to main.
- A `docs/CONTENT_S2.md` table of every new item, recipe, enemy, location and loot table, with pacing notes.
- A report of about 200 words to the orchestrator.

## Phase B: Studio, after slice 1 merges, on the orchestrator's go-ahead

Art goes through ART_DIRECTION §10a (style anchor = the approved concept crops; family sheets; floater gate; lineup graded A).

- **Hollow:** 3 rigs, each with a custom animation set.
- **Weapons:** 3 guns plus ammo and flare models.
- **Locations:** 3 dense, handcrafted maps plus the event spot, built world-as-code.
- **The Fog map** illustration, plus the panels and loading screen.
- **Effects:** VFX (muzzle, tracer, ash dissolve, flare) and real SFX.
- **Verification:**
  - Playtests in Studio, using the simulated lobby.
  - Real cross-server teleports verified on a private test place: publish the `rojo build` output via `open_cloud_invoke` (the Place Publishing API) from the approved worktrees folder.
  - The adversarial QA subagent and a capture census before reporting.
