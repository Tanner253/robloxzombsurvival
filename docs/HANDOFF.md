# Project handoff: Ember Outpost (for the next model)

**Written 2026-11-11** by the previous orchestrator (Claude Opus 5.5) for the model taking the project over.

**What this doc gives you:**
- everything you need to continue without the old conversation
- what the developer wants
- how they want you to work
- where everything is
- what is done
- what to do next
- the mistakes not to repeat

**Read this whole file first.** Then read the docs in §3, in that order.

---

## 1. The project in one paragraph

**Ember Outpost** is an original **Roblox** survival-crafting game.
- It deliberately and closely copies **Last Day on Earth: Survival (LDoE)**: its loops, HUD and screens, crafting grind, durability and survival stats, and its **pay-to-win item monetization**. Names and art are our own.
- **The loop:** gather, craft and build at a home plot (the Neighbourhood). Spend Energy to **Run or Walk** to **Fog Run** locations, which are lootable handcrafted maps with zombies (we call them **the Hollow**). Fight, loot, then extract or die and drop your bag.
- **Around the loop:** a public safe hub (**Haven Square**) with traders, quests and a VIP Lounge. A premium currency (**Embers**) and a shop of repurchasable packs.
- **Later milestones:** PvP, raids, guilds and a large cross-server hub.

**Who the developer is:**
- A solo developer, Tanner253, on GitHub as `Tanner253/robloxzombsurvival`. They own a browser game repo, "Zona" (§7).
- They are not a Roblox expert.
- Their guiding rule: *"When in doubt Last Day on Earth is the standard... make the most fun and engaging game... optimized for micro txns."*

**Status:**
- About **55–60% of a shippable v0.1**, against [MVP_LAUNCH.md](MVP_LAUNCH.md).
- About **15–20%** of everything LDoE has today.
- The hard systems are built. What's left is mostly **merging branches, fixing known blockers, switching Fog Runs on, wiring in guns, and adding the purchase offers**. See §5 and §6.

---

## 2. How the developer wants you to work (binding)

These come from a week of direct feedback. Breaking them has made the developer angry before.

1. **Never ask clarifying, design or tooling questions.**
   - Decide, using LDoE as the tiebreaker. Solve blockers yourself.
   - The only things you may put to the developer, in one line at the top of a reply:
     - physical actions in Studio or on an account that only they can do
     - money decisions (spending credits, price vetoes)
   - Don't let worker sessions or subagents ask them either.
2. **LDoE is the standard.**
   - Before designing or reviewing any screen, mechanic, shop offer or item system, **open the matching LDoE recording frames** in `docs/reference/ldoe-recordings/`. Use `NOTES.md` and the citation index `docs/research/ldoe-parity-audit-2026-11-08.md` to find them.
   - Past misses the frames would have caught: guns don't use ammo; the shop has gun and equipment packs; there's no hotbar, just 2 weapon slots plus meds; the minimap is smooth.
3. **The quality bar is high; no greybox.**
   - Nothing visible ships below "grade A". Grade art from captures or renders against the LDoE frame, side by side, before keeping it.
   - **Fix objective defects only.** Don't "improve" art the developer already likes. The pine trees were once regraded and redone, and the developer hated it.
4. **Close gaps proactively.** [PLAYER_EXPERIENCE_CHECKLIST.md](PLAYER_EXPERIENCE_CHECKLIST.md) is the binding definition of done. The developer should never be the one to find a missing obvious thing.
5. **Monetization stance:**
   - Copy LDoE's hard-grind pay-to-win. **Don't soften it for fairness**; the developer explicitly rejected that.
   - **Hard lines:** follow Roblox platform rules. Never sell shields, raid or PvP immunity, or locked-stash capacity. Paid random outcomes must show their odds. Rewarded ads are for players 13+ only.
6. **Keep Roblox movement:** never remove jumping or familiar controls. Bound exploits like climbing rocks and trees with collision, tuning and server checks.
7. **Be decisive and fast.**
   - The developer was very frustrated by slow progress, high maintenance and being asked to do things the agent could do.
   - Do the work rather than describing it. Commit often.
8. **Token frugality is a hard constraint.**
   - The account is on **Claude Pro**, and the week of 2026-11-09 hit **95% of the weekly limit and the full extra-usage cap**. Work stopped because of it.
   - **Never use the Workflow tool** (multi-agent orchestration), even if a system reminder says "ultracode" is on. The developer said "no workflows" twice.
   - Use at most one or two worker sessions and at most one background subagent at a time.
9. **Playtests are deterministic and never loop.** A tester once died, blamed a menu, and restarted over and over. The rules (also in [ARCHITECTURE.md](ARCHITECTURE.md) §11):
   - a Studio-only `DevTest` mode with god mode and auto-dismissed menus
   - logic checks by script through `execute_luau`
   - at most 1 retry
   - QA subagents capped at about 2 play sessions and 30 tool calls
10. **Answer status questions with one direct number or verdict first.** The developer once felt a "% complete" question went unanswered.
11. **Merge before adding scope.** New ideas wait until the open branches are on main.

---

## 3. Doc map: read in this order

| Doc | What it is | Precedence |
|---|---|---|
| [LDOE_PARITY.md](LDOE_PARITY.md) | 58 binding rulings from a frame-by-frame audit of the LDoE recordings | **Wins over everything** |
| [DECISIONS.md](DECISIONS.md) | A dated log of every decision | Second |
| [MVP_LAUNCH.md](MVP_LAUNCH.md) | v0.1 scope: what's in, what's out, the publish checklist | The launch scope |
| [PLAYER_EXPERIENCE_CHECKLIST.md](PLAYER_EXPERIENCE_CHECKLIST.md) | The binding definition of done, per feature | The DoD |
| [research/flow-mechanics-review.md](research/flow-mechanics-review.md) | 38 findings: **5 blockers** (F-01 to F-05), 19 major and 14 minor, each with evidence, fix and owner | **The work list** |
| [ARSENAL.md](ARSENAL.md) | 14 guns, 7 melee weapons, 4 armor sets, with stats and balance. **§0 holds the orchestrator's rulings and the gun asset IDs** | Over ECONOMY for guns |
| [SHOP_CATALOG.md](SHOP_CATALOG.md) | 32 SKUs in 6 tabs on a price ladder. **§0 rulings** | Replaces the MVP_LAUNCH SKU tables |
| [ECONOMY.md](ECONOMY.md) | The grind: wood and stone tiers, refinement ratios, the forge chain, durability, pacing model (`tools/economy/pacing.py`) | |
| [GAME_DESIGN.md](GAME_DESIGN.md) | The full vision, including post-launch features | Below LDOE_PARITY |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Tech stack, folder layout, DoD items, worker rules (§11) | |
| [ART_DIRECTION.md](ART_DIRECTION.md) | §10a consistency system, one art pipeline, one material per tier, no emoji, realistic weapons | |
| [research/zona-item-catalog.md](research/zona-item-catalog.md) | The Zona agent's report on armor levels, helmets, gas mask, bags, meds, grenades and attachments, with licences and triangle counts | For item depth (after launch blockers) |
| [research/ldoe-monetization-playbook.md](research/ldoe-monetization-playbook.md) | LDoE's monetization strategy and the price ladder | |
| `docs/feedback/` | The developer's screenshots of problems | |

---

## 4. Tech and tooling quick reference

**Stack:**
- Roblox Studio, **Rojo** (the repo is the source of truth: "world-as-code"), and **Luau `--!strict`**.
- **Lune** unit tests for the pure `Domain/` modules plus a **data validator**.
- Tools pinned by Rokit: Selene (lint), StyLua (format), luau-lsp (types; needs `build/globalTypes.d.luau`).
- React-lua UI; ProfileStore for saves, with schema migrations (player v8 economy, v9 Haven, v10 shop).
- Layout: `roblox/src/{client,server,shared}`. `shared/Data/*` is data-driven content; `shared/Domain/*` is pure logic. Tests are in `roblox/tests/` (runner `run.luau`).
- **All checks must pass before a merge:** Lune tests, Selene, StyLua, luau-lsp, `rojo build`.

**Places and servers:**
- One Roblox place, **"Ember"** (placeId 109182702421201), with **two server roles**:
  - the **Neighbourhood**: home plots plus Haven Square, up to 8 players
  - **Fog Run lobbies**: reserved servers of the same place, up to 12 players
- A server reads its teleport data at boot to decide which role to build.
- Features are behind flags in `Data/Tuning.luau` (`Tuning.features.*`). **`fogRuns` is currently `false`.**

**Studio work:**
- Through the **Roblox Studio MCP**: `execute_luau`, `screen_capture` (needs a `capture_id`), `start_stop_play`, `get_console_output`, `list_roblox_studios`, and `open_cloud_invoke` for Open Cloud asset uploads.
  - Studio IDs change between launches: call `list_roblox_studios`.
  - `execute_luau` needs `datamodel_type` (`Edit`, `Server` or `Client`).
- Two Studio windows were used in parallel:
  - the cloud place "Ember", Rojo on port **34872**
  - a local `roblox/build/EmberRuns.rbxl` for Fog Runs work, Rojo on port **34873**
- **DataStores:** use only `_Studio`-suffixed names in Studio.
- **Capture quirks:** client-side live edits don't show in captures. Use ClockOverride for lighting. Development GUIs (for example a `ZZ_ArtPreview` ScreenGui) can cover the viewport: set `StarterGui.ShowDevelopmentGui = false` while capturing.

**Asset uploads:**
- Use `open_cloud_invoke` POST `/assets/v1/assets` with assetType Model, creator userId **11569755804**, scopes `asset:read` and `asset:write`. Then poll `/assets/v1/operations/<id>` for the asset ID. Load with `InsertService:LoadAsset`.
- **The 20 MB limit per GLB.**
- **Only upload from approved folders:** `C:\Users\perci\source\repos\zombiesurvival\.claude\worktrees\...` and main's `art\higgsfield`.
  - **Never copy files into an approved folder to get around a permission guard.** That's a bypass, and a worker rightly refused it.
- **Images:** upload through a local `python -m http.server` with `upload_image`.

**Art pipeline (our own art):**
1. Higgsfield MCP (credits; spending is the developer's call)
2. Concept image
3. Tripo or P2 3D model
4. GLB
5. The floater gate (`art/tools/glb_*.py`)
6. Conform and grade A
7. Upload

The art credit pool is nearly spent: about 0–50 of 800 credits are left.

**Worker sessions:**
- Earlier work used Claude Code desktop "sessions" (S1b: home and shop; S2B: Fog Runs), each in its own git worktree under `.claude/worktrees/`.
- **Cross-session messages queue until the target's turn ends.** Stopping a session does **not** stop its background subagents, so tell it to stop them.
- Worktrees share one git stash stack: never use a bare `git stash`.

---

## 5. Current state: branches (all pushed to origin)

> **Update 2026-11-11: §6 step 1 is done.** `main` is at 1788203 with all checks green (489 Lune tests, Selene, StyLua, luau-lsp, `rojo build`).
> Later the same day `main` took the five blocker fixes, no-ammo and the first five guns (§6 update block): 509 Lune tests, all five checks green (`bash roblox/tools/check.sh`).
> - **Merged:** `claude/m1-launch-home-platform`, `claude/m1-slice2b-fog-runs-9a5388` (at a941de9, which finished the Hollow movement WIP), `worktree-agent-a0101ba2e6be467ea` (F-02, F-04, F-05, F-06, F-07 and the F-08 offer hooks), `worktree-agent-a52ab36a54b0f4f87` (minimap 8.11).
> - **Parked, not merged (post-launch, §6 step 7):**
>   - `worktree-agent-a3808d71e6cf77897` (Haven VIP): built on the Haven from before the density pass, so `World/Haven.luau` conflicts in 9 hunks; it re-adds the VIP particle aura the developer rejected; its four props were never graded; it bumps the save schema to v11. Port it onto main's Haven and grade it in Studio before merging. Keep main's side of the aura conflict.
>   - `worktree-agent-a3c75eb84c6644ce1` (melee polish): four new modules nothing requires, no specs, fails StyLua and luau-lsp (type errors in `MeleePoses`, `MeleeKeys`, `MeleeTiming`). Finish, wire and test it before merging.
> - The table below is the state before these merges, kept for the branch contents.

| Branch | Head | State | Contents |
|---|---|---|---|
| `main` | 0085468+ | Clean. Checks green at 0e14fa4; later commits are docs, assets and tools only | Everything merged so far, plus ARSENAL, SHOP_CATALOG, the flow review, the Zona catalog, the gun tools and GLBs |
| `claude/m1-launch-home-platform` | 0cd1ead | 12 finished commits ahead of main, **not merged** | Haven density; Reedweave and Padded armor; stake, lights, doormat; Shop Equipment and Building tabs (**8 SKUs live on Roblox**); Studio-only Dev Armory; every pack repurchasable; chapter 3 "Hold the Line" (quests 14–25, level cap 30); **the VIP aura particle removed; Haven NPCs grounded** |
| `claude/m1-slice2b-fog-runs-9a5388` | 7360449 | 13 finished commits plus 1 **WIP**, **not merged** | **The six Forest and Mine maps (L1–L3)**, plus the original four Fog maps; diegetic exits (12.10); nav probe (12.9); 0 type errors. The top WIP commit is Hollow movement and step height, unfinished |
| `worktree-agent-a0101ba2e6be467ea` | 953bd76 | On top of launch: 8 commits plus 1 WIP | Flow-review fixes in progress (for example F-07, home pines). Check each against its finding ID |
| `worktree-agent-a3808d71e6cf77897` | c8505e4 | WIP, based on main 7d1a427 | VIP Lounge dressing (Higgsfield props: bar, brazier, seating, stew pot), Gatekeeper card, well and soup kitchen (`Domain/Comforts`), VIP traders |
| `worktree-agent-a3c75eb84c6644ce1` | 8abdec0 | WIP, based on main 7d1a427 | Melee polish: per-class clips, poses, timing, UAL retarget tools |
| `worktree-agent-a52ab36a54b0f4f87` | 3eeccad | 1 commit plus 1 WIP | Minimap 8.11 (one smooth live radar) plus side-by-side captures |

**WIP commits are unreviewed and may fail the checks.** Review each before merging.

**Merge order:**
1. launch-home-platform
2. slice2b (switch fogRuns on only together with the F-02 fix)
3. the flow-fix branch
4. minimap
5. Haven VIP
6. melee

Run all checks after each merge.

**What's live on Roblox already:**
- 8 shop developer products (the Equipment and Building tabs) and the game passes.
- About 13 gun model assets.
- Many Higgsfield art assets.

**The game itself is not published publicly.**

---

## 6. What to do next, in order (the minimum to a soft-launchable build)

> **Update 2026-11-11: steps 1 and 2 are done in code; start at step 3.**
> - **Step 2 (the five blockers):** F-01 `fogRuns = true`, held by `roblox/tests/Launch.spec.luau` (no dormant quest; every objective kind has a server emitter). F-02 quest 1 is home-only, and a Hollow's drop now reports `lootBody` (`Containers.looted` source, `Domain/Quests.lootEvent`). F-03 and F-04 are enforced by `server/OnRun.luau` (the run server role), not a workspace attribute. F-05 home deaths drop the bag and wake at 50/40/40.
> - **Verified in play (2026-11-11, the cloud place "Ember", Studio simulation):** the server boots clean with Fog Runs on (33 modules, no script errors). A scripted run to Pine Hollow recorded quest 6's travel, kill and Hollow-drop objectives. How to repeat it: `ServerStorage.EO_Dev:Invoke("quests", 5)`, `("fogrun", "loc.pine_hollow")`, poll `("runstate")`, `("kill")`, then from the client fire `Remotes.ContainerSearch` and `Remotes.ContainerTakeAll` with the pile's `ContainerId`, then `("queststate", "quest.into_the_fog")`.
>   - That run found two bugs the specs had passed: the drop event was hooked on a search that piles never run (it now fires when loot is taken from a Hollow's pile), and a Shambler dropped nothing half the time (its table now always rolls once).
>   - **Not yet verified in play:** F-03, F-04 and F-05, and anything a real player sees (HUD, the Guide's pointer, the death screen).
>   - **Seen, not fixed:** the first lobby at a location builds its map on demand, 12 s one time and 38 s another, while the player waits at home with only the "matching" effect. Run servers build at boot, so check what a live player sees before launch.
> - **Step 3, first half, is done: no ammo (F-13, F-14).** Arrows, Light Rounds, Scrap Shells, Blackpowder, their recipes and the Ammo Press are gone; guns, the Flare Pistol and the bow fire on durability (Pistol 150, Shotgun 90, Flare Pistol 72). The Signal Flare stays as a hand-made consumable for the Black-fog flare extract. Player schema is v11 and outpost schema v5, both with migrations. Booted in Studio; no gun was fired in play. Details are in the 2026-11-11 DECISIONS row.
>   - **Open tuning item, do it after the guns are wired:** the removed ammo rows became scrap, and in the pacing model melee now breaks in about 5% of runs (it was 26%; `Pacing.spec` floor lowered from 10% to 5%) and the hook sits at 57 of 60 play-minutes. Levers: `loot.junk` instead of scrap in `loot.pine_band2` and `loot.pine_band3`, or melee durability. Restore the 10% floor if a lever allows it.
>   - The parked Haven VIP branch also claims player schema v11: renumber it to v12 when it is ported.
>   - ECONOMY.md, CONTENT_S2 and MVP_LAUNCH still mention ammo in places; DECISIONS and the checklist are current.
> - **Step 3, second half, is done: five guns** (2026-11-11, branch `guns-first-five`, merged). Duty Pistol, Pump Shotgun, Hunting Rifle, Assault Rifle and Anti-Materiel Rifle: items, recipes (chapter-3 quests; the Assault Rifle Schematic; the Anti-Materiel Rifle is loot only), ARSENAL §3.4 loot rows, graded models, credits, held and firing poses. Durability is ARSENAL's shots × 3. 509 Lune specs (`tests/Arsenal.spec.luau` is new). Calls are in the 2026-11-11 DECISIONS row.
>   - **Verified in play** (the cloud place "Ember", Studio simulation, a Fog Run to Pine Hollow): each of the five was put in hand, fired at a Shambler through the real fire path, and showed the hit, one durability a shot, and the break at zero with the hand-over to the other slot. Numbers: Duty Pistol 40 → 18 HP, 270 → 269; Pump Shotgun 40 → 0, 84 → 83; Hunting Rifle 40 → 0, 95 → 94; Assault Rifle 40 → 23, 480 → 479; Anti-Materiel Rifle 40 → 0, 45 → 44. With the mouse button held, the Assault Rifle put out 83 rounds across two self-reloads, and the pistol and long-gun stances were captured from the side (`docs/milestones/m1-launch/G01_guns_held_vs_rec6_05.jpg`).
>   - How to repeat it: `ServerStorage.EO_Dev:Invoke("equip", itemId, slot, durability?)`, `("shoot", studs?)` (fires once at the nearest Hollow and returns its health and the gun's durability before and after, and what blocked the shot), `("heal")`.
>   - **Not verified in play:** finding a gun in a container or crafting one (the loot rows and recipes are held by specs only); the Anti-Materiel Rifle's pierce (no two Hollow stood in line); how the shots sound; touch input.
>   - **Seen, not fixed:** the four black guns read dim in the weapon circle (a model-rendered icon on a near-black disc; they have no painted icon, and that is art spend). A shot is a level ray at chest height, so tree hulls and rising ground stop it: an apple tree blocked shots at a Shambler 6 studs away, and the 120 to 160 stud rifle ranges will rarely be clear. A gun starts a run empty, so the first pull is a reload.
>   - **Still open:** the melee-wear tuning item above. The pacing numbers did not move with the gun rows. The junk lever does nothing by itself because `Pacing.spec` rolls its own copy of the pine band tables: turn it in the fixture and in `Data/LootTables` together.
> - **Step 4 is done: the moment-of-need offers (F-08, F-09)** (2026-11-11, branch `offers-moment-of-need`, reviewed and merged). The rules are pure in `Domain/MomentOffers` (its own spec); `Launch.spec` holds the wiring with needles. Calls are in the 2026-11-11 DECISIONS row.
>   - Death screen: the Scavenger's Kit chip (79), **Recover all** for 100 Embers (short of Embers it prompts the Ember Pouch, 149), and short of Energy the Energy Refill (99) with the shortfall stands where "Go back in" was. No recover-by-ad option. `PriceButton` is now a shared component (the shop uses it too).
>   - The dead stay on the run side until they choose: the 4 s `DEATH_LINGER_SECONDS` is gone. The `DeathChoice` remote sends them home, or home and straight back in ("Go back in": `Lobby.wantsReentry` → Travel charges and starts the re-entry trip). A body that respawns meanwhile waits anchored. The lobby closing counts as Continue. `recoverAll` now checks the lobby is open before taking Embers.
>   - Fog map: short of Energy, the Run greys ("No Energy") and an amber REFILL slot with the Robux price and "Need N more" sits left of it; a neighbouring pin under the slot is left off. The server's `energyShort` (a refused Run, or a refused re-entry) shows it too.
>   - **Verified in play** (the cloud place "Ember", Studio simulation, fresh play after Rojo was reconnected, Fog Run to Pine Hollow, `EO_Dev` "die"): (a) still holding 14.3 s after death, body respawned and anchored; (b) kit chip shown, price 79, its button sent `ShopBuy product.scavenger_kit`; (c) at 3 Energy, "Go back in needs 5 more Energy" with the Refill at 99, its button sent `ShopBuy product.energy_refill`; (d) at 250 Embers, Recover all took exactly 100 (→ 150), the bag model went, the inbox went from 3 to 6 entries (stew, water, timber); (e) at 40 Embers, Recover all sent `ShopBuy product.embers_50`; (f) Continue released the hold and unanchored the body; at home with 3/240 Energy the Pine Hollow Run is grey with the Refill "Need 12 more", 99. UI gate: the new scenes `run.death.offers` and `fogmap.refill` have zero flags (the Run's "Not enough Energy" note clipped and is now "No Energy"). Captures: `docs/milestones/m1-launch/O01_run_refill_vs_rec1_06.jpg`, `O02_death_offers_vs_rec1_05.jpg` (the map capture predates the "No Energy" note).
>   - How to repeat it: `("quests", 5)`, `("energy", n)`, `("embers", n)`, `("fogrun", "loc.pine_hollow")`, poll `("runstate")`, `("give", ...)`, `("die")`, then `("deathstate")` (holding, Embers, inbox size, Energy, the body).
>   - **Not verified in play:** "Go back in" all the way back into the lobby (the `wantsReentry` path); the lobby closing while held; a live (reserved-server) teleport home after a choice, including the home server starting the re-entry once the profile loads; real purchases completing (Studio prompts only); touch input.
>   - **Seen, not fixed:** the UI gate is at 8 flags, all outside this step: the minimap's fog-meter Title and Time overlap in `run.hud` and `run.cards` at every profile (`components/Minimap`, last changed by Minimap 8.11). `Pacing.spec` is flaky: 2 of its tests failed once in three runs with no Pacing input changed. Studio's injected mouse clicks often miss the first press on a newly targeted button (a tool quirk; the second press lands). The Rojo server crashed during this step and the plugin had to be reconnected by hand; a stylua rewrite of open files may be the trigger. No LDoE recording shows a death screen.
> - **Orchestrator follow-ups, 2026-11-11 (merged and pushed):**
>   - **Shots and trees fixed** (branch `guns-followups`): a round ignores what doesn't collide (tree crowns), and each Hollow is checked along a line to its chest, so rising ground no longer swallows the shot. Verified in play at Pine Hollow with the Hunting Rifle: clear lines at 6 and 30 studs killed a Shambler (40 → 0 HP, durability −1 a shot). A trunk in the line still stops the round, as intended: 2 of 4 lines at 20, 40 and 80 studs met one in that dense wood.
>   - **UI gate is at zero** (21,938 elements, all four profiles): the fog meter's band name and time overlapped by 6 px; the label widths are now set from measured text ("FOG: CLOSING" 79 px, "59:59" 30 px).
>   - `Pacing.spec` passed 6 runs in a row on merged main; the flake was not reproduced. If it shows again, look for iteration order over table-keyed maps in `Domain/PacingSim`.
>   - **Seen, not fixed:** a held player's respawned body stands anchored on the run map until they choose; in a shared (Dense or Black fog) lobby, others can see it. Hollows ignore it (the player has left `hosted.players`). The console shows `rbxassetid://203785492` failing with "Asset type does not match" three times at boot: find which Data entry uses it.
> - **Update 2026-11-11, step 5 (the scripted launch playtest): pass after 3 fixes.** Branch `launch-playtest`, reviewed and merged. Run in the cloud place "Ember" (Studio simulation, Rojo connected) over two play sessions. Studio has no API access, so ProfileStore uses its mock: every play start is a fresh profile (Level 1, 0 Embers, 200 Energy).
>   - **Passed:**
>     - **Gather:** sticks, stones, reeds and pines through the real `Gather` remote; 40 pine swings gave 39 timber. Quests 1–3 tick from real events, and their rewards land in the inbox and count at home.
>     - **Craft and equip:** rope, stake, hatchet, pick and satchel through `HandCraft`; equipped through `InventoryMove`.
>     - **Build:** 2 foundations and 2 walls (36 timber and 2 rope) and the Saw Bench (10 timber and 6 stone) through `Building.place`, at real costs.
>     - **Run:** `TravelStart` at the Trailhead charged 15 Energy (221 → 206), and the player arrived about 19 s later (the map was built fresh). Quest 6's travel, kill and Hollow-drop objectives ticked, and the quest completed with a level-up.
>     - **F-03:** on the run, crafting a rope was refused ("Not enough materials") while the fiber was only in the inbox.
>     - **F-04:**
>       - `InboxTakeAll` on the run was refused with "Your inbox waits at home…".
>       - With the bag full, a crafted rope dropped 3 studs away with "Your bag is full. The rest dropped on the ground." `PickupDrop` took it back.
>     - **F-05:** a home death with 5 sticks and 7 timber carried dropped them in a bag 5 studs away. The player woke at 50 HP after 3.9 s, and Food and Water read 38 a few seconds later.
>     - **Death screen** (an idle survivor was killed by a Hollow): the bag list, "Go back in: 8 Energy", Recover all 100, Continue, and the Scavenger's Kit at 79 (`P04`).
>     - **"Go back in" all the way:** back in the same lobby within 2 s, Energy 226 → 218. `BagTakeAll` got the bag back.
>     - **The lobby closing while held:** the hold was released within 0.5 s of the close, and the player woke at home 0.5 s later. The dev command `meter` now ages the lobby a held player died in, which made this check possible.
>     - **Extract:** the results card reads "YOU MADE IT OUT", 0:37, 1 Hollow, 1 searched, +40 XP, with 3 items (`P05`).
>     - **UI gate:** 0 flags across 21,958 elements, run after the fixes.
>   - **Fixed (3):**
>     - **Quest 1 stranded a new player at "Craft a Sharpened Stake":** the stake needs a rope, a new player has none, and the Guide only points at listed objectives. First Light now lists "gather 2 Fiber" and "craft a Rope" before the stake. In the replay, the Guide outlined the reeds and all six objectives counted. The stake and equip objectives moved from indexes 3–4 to 5–6; there are no live saves yet.
>     - **The Fog map never marked the Guide's destination:** `guideLocation` was set but nothing read it, and it cleared when the map opened. `Actions.toggleFogMap` now opens the map on that pin. In the replay, it opened on Pine Hollow with RUN 15, WALK and the route (`P03`).
>     - **The quest-complete note read "Iron Ingot, Iron Ingot":** two recipes make the ingot. Each name is now listed once.
>   - **Not verified in play:**
>     - **A gun found in a container.** Pine Hollow's loot tables hold no guns by design. I made two tries at the Stranded Caravan at band 3:
>       - The first ended when the band-3 Hollows killed the player, and the lobby then closed and took the bag.
>       - In the second, my script took the loot before the 6 s trunk search ended. Wait 6.5 s per trunk next time.
>     - **The station timers:** quest 4's plank (4 min) and quest 5's boiled water (2 min) were skipped with `("quests", 5)`.
>     - **A live teleport home from a reserved server.** In Studio the death screen stays up after a release by the server; a live teleport resets it.
>     - **Real purchases and touch input.**
>   - **Seen, not fixed:**
>     - At boot the console shows 20+ "Requester does not have permission for Asset" errors (`rbxassethash://`) and `rbxassetid://203785492` three times. Check them before publishing.
>     - A searched container's panel stays open behind the death screen and the results card.
>   - **Captures:** `docs/milestones/m1-launch/P01`–`P05`.
>   - **How to repeat it:**
>     - Start play, then wait about 5 s before setting the UI gate attribute. If the first trigger is missed, set it again once.
>     - On the Client, fire `Gather`, `HandCraft`, `InventoryMove(ref, i, "equipment", 5 or 7)`, `TravelStart(loc, "run")`, `ContainerSearch` and `ContainerTakeAll`, and `DeathChoice`.
>     - On the Server, `EO_Dev` runs `place`, `kill`, `die`, `meter`, `extract` and `queststate`.
>     - Keep Studio un-minimized: a minimized window captures black, and an unfocused one runs at 15 fps.
> - **Next: step 6, the soft launch, is the developer's.** Before publishing, clear the boot console's asset errors (the "Requester does not have permission" lines and `rbxassetid://203785492`). Those need checking in the live game; Studio alone can't confirm them. 203785492 is in neither the repo nor the place's edit tree (6,000 instances scanned on 2026-11-11), so it is probably loaded at runtime by a Roblox core script.

1. **Merge** the branches in §5 and get main green.
2. **Fix the 5 flow blockers** ([flow-mechanics-review.md](research/flow-mechanics-review.md)):
   - **F-01:** `fogRuns = true`, plus a spec that every quest has a live objective and every objective kind has a server emitter.
   - **F-02:** quest 1 becomes gather-only plus "craft a Sharpened Stake"; the kill and loot steps move to quest 6; fire `lootBody` when a player picks up a Hollow's drop.
   - **F-03:** run servers set `workspace:SetAttribute("FogRun", true)`; hand-crafting on a run uses carried items only.
   - **F-04:** the inbox is refused on run servers, and crafting overflow drops on the ground.
   - **F-05:** a home death drops the bag; respawn at 50 HP with hunger and thirst at 40; Reset goes through the same death.
3. **No ammo** (F-13): remove `ammoItemId`, the Ammo Press and the ammo recipes. Then **wire in 4–5 guns** from ARSENAL §0 (items, loot, held pose, firing), using the F-14 durability floors. Leave the full 14-gun roster for later.
4. **Moment-of-need offers:**
   - **F-08:** the death-screen kit offer, the Energy Refill, and a Refill slot beside a greyed Run button.
   - **F-09:** stay on the death screen until the player chooses, with "Recover all" for 100 Embers.
5. **One scripted launch playtest:** new player, gather, craft, build, Run, loot, fight, die or extract, home. Plus the UI overlap gate at zero.
6. **Soft launch:** the developer publishes (MVP_LAUNCH publish checklist), puts a small Roblox ads budget behind it, and measures next-day retention and payer conversion before more investment.
7. **After launch, in order:**
   - the remaining flow-review majors and minors
   - the full SHOP_CATALOG (32 SKUs) and the ARSENAL melee and armor
   - item depth from the Zona catalog (armor levels, helmets, gas mask as fog protection, bags, a meds ladder, grenades); write a short spec first
   - M2: PvP, raids, guilds

**Budget guidance:**
- Steps 1–5 should fit one week of Pro usage, run lean: one worker session at a time, scripted checks, no fan-outs.
- Check usage with `mcp__ccd_session_mgmt__get_usage` and pace yourself.
- A fresh Fable worker session for the five guns cost 63% of the weekly Fable limit (94% used by 2026-11-11 evening). Run worker sessions and subagents on Opus; keep Fable for briefs and reviews.

---

## 7. Assets

**Zona:**
- The developer's browser game repo is at `C:\Users\perci\source\repos\Zona`.
- **Scope:** item models only (weapons, armor, gear, bags, meds, food, tools, attachments) plus animations. **Never** trees, environment props, buildings or zombies; the developer said those aren't up to standard.
- **Never use Sketchfab Standard models** (`m32`, `vssk`, `elcan`). That licence forbids making a model available in a way that invites extraction, and Roblox serves every mesh to clients. Use **CC0 or CC-BY only**, and credit every CC-BY asset in `CREDITS.md` and the in-game Credits panel (`Data/Credits.luau`).
- Zona's own item stats live in `Zona/src/sim/items/*.ts`.

**Guns:**
- Asset IDs, the tier mapping and the **dead-ID list** are in [ARSENAL.md §0](ARSENAL.md).
- **Uploaded and graded A:** Duty Pistol, Hand Cannon, Pump Shotgun (tactical pump), Hunting Rifle, Machine Pistol, Patrol Carbine, Assault Rifle, Tactical SMG, Anti-Materiel Rifle (v3).
- **Not yet uploaded:** the Marksman Rifle (`sniper`) and the Compact Rifle (`9a91` without its silencer).
- **The Combat Shotgun is cut to M2;** there's no second grade-A shotgun.
- **The 40mm grenade launcher is blocked:** there's no licensable model; `m32` is Sketchfab Standard.

**`art/zona/` in the repo:**
- `guns/`: the final GLBs matching the uploads (`*_v2`, `barrett_v3`, plus earlier ones).
- `melee/`: the machete.
- `renders/`: review renders.
- `wip-v3/`: an **unfinished, unreviewed** batch. Verify every file before upload.
  - the sniper and the 9a91
  - melee: bat, knife, hatchet, pitchfork
  - an ar15 decimated toward 8k triangles
  - brand-text paint-out for the deagle, mp7, scorpion and m9
- `tools/` (`npm ci` first):
  - `build_v2.mjs <gun> <out.glb>`: poses FPS-rig guns on their skeletons, drops spare magazines, bakes colour maps. It ports Zona's `scripts/weapon-packs.mjs`.
  - `verify.mjs`: checks for floating parts and missing colour maps.
  - `render.mjs`: makes side and top renders.

**Lessons:**
- Zona guns are first-person viewmodel rigs. Stripping the arms and animations leaves parts floating in bind space; **pose them on the skeleton** instead.
- Keep each gun at or under about 8k triangles and paint out brand text.
- About 1.2 GB of raw extracts was deliberately not committed (it would exceed the LFS quota). They're regenerable.

---

## 8. Open decisions for the developer

- **Reinforced Room Kit at 4,499 Robux** (a whole 3×3 room, Plans included): approved by the orchestrator; the developer can veto it and go back to 1,699.
- **The 40mm launcher:** needs a CC0 or CC-BY model, which the developer or the Zona agent would have to find and download.
- **Art credits:** the 800-credit pool is nearly spent; adding more is the developer's money decision.

---

## 9. Mistakes made this week (don't repeat them)

- **Token blowouts:**
  - two parallel worker sessions plus several background agents
  - long spec agents (about 500k tokens each)
  - looping playtests
  - a 9-agent Workflow launched despite the memory saying never
- **Asking the developer things they consider yours to solve:** menu steps, upload routing, "should I...".
- **Telling a worker to copy files into an approved folder to bypass an upload guard.** Never do that.
- **Widening an asset source's scope beyond the developer's words.** Zona trees and props were pulled in when only weapons were allowed.
- **Shipping visuals without a side-by-side check.** Examples: floating models, blurry UI, emoji buttons, UI overlaps, mismatched materials, the VIP flame aura that read as "constant farting".
- **Design calls the frames contradicted:** ammo for guns, a hotbar.
- **Answering a status question without a clear number.**

Everything is committed and pushed. No worktree has uncommitted changes. **Start at §6 step 1.**
