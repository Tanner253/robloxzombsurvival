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
> - **2.0, started 2026-11-11.** The developer asked for polish, performance, quality of life, UX and more content, with LDoE as the standard. They also asked that items sit and point right in the hand and have good animations. The batches, in order; the orchestrator reviews and merges each one:
>   1. **Hands, animations and feel** (Studio): every held item's grip and pose, plus the use, gather and fire animations. Guns start a run loaded, the loot panel closes on death, and a held body is hidden. Flow-review F-29.
>   2. **Flow-review quality of life and UX** (worktree, runs alongside batch 1): F-10, F-11, F-12, F-20, F-21, F-22, F-27, F-28, F-33, F-36 and F-38, and a recheck of F-06 and F-07.
>   3. **Performance:** the first lobby's map build (12–38 s), frame time at home and on a run, and network and memory.
>   4. **Content past the Scrap tier** (F-24, F-37): ARSENAL melee and armor (port the parked melee WIP), and Zona item depth (helmets, the gas mask as fog protection, bags, a meds ladder, grenades). Spec first.
>   5. **More guns** (the ARSENAL roster) and the full SHOP_CATALOG.
>   6. **M2:** raids, PvP and guilds.
> - **Update 2026-11-12, 2.0 batch 1 (hands, animations and feel): done on branch `feel-hands-animations`, pushed, reviewed and merged.**
>   - **Grips,** re-measured in Studio by casting rays across each handle. The Sharpened Stake's axis was about 80 degrees off, so it sat across the fist; it now holds on its cord wrap, point ahead. The Fire Axe, Stone Hatchet, Stone Pick, Spiked Club, Scrapblade and Tire Iron handles rode up to 0.5 studs off the palm (a head pulls the bounding box off the handle); `Art.held` now carries each handle's measured `offset` and corrected axis. The Forged Hatchet and Forged Pick were built greybox stand-ins in the hand and in the inventory; they now show their stone forms in hand and keep their painted icons (`Art.paintedIcon`). Their own models are art spend.
>   - **One animation set per class** (`Data/Holds`, `Domain/HoldRules`, `client/Clips`): fists, blade, axe, blunt, pick, heavy, stab, pistol, long and bow. Guns and the bow sit along the forearm (`Models` mount "gun"), so the aim stances have straight wrists. Long guns shoulder in both hands (stock in the shoulder, torso bladed 38 degrees) and pistols go out in both hands; while held, both carry at low ready (long guns in two hands) on every character, home and run. The bow carries upright and draws to the face. The stances were solved by IK against the rig's joints. New clips: chopSwing (axes, clubs), thrust and lunge (stake), punch (fists), drink and bandage. The slash, heavy and gather chop now strike with the head level or down into the target (set from the weapon's measured direction at each hit frame). Recoil is per class.
>   - **Feel:** a light melee blow lands on its swing's hit frame (the server waits `HoldRules.strikeDelay` less 0.05 s), and HollowView draws a hit when Combat's "hit" effect arrives instead of with the next 0.2 s snapshot: the number, a puff, a white flash (gold on a crit), the Hollow's hit-react and the thud together. The whoosh plays as the blade comes through. A Hollow's fall plays 0.85 s before it crumbles. A gather swing puts the tool in the hand at the wind-up (`GatherSwing` remote), not at the blow, and others see the swing from its start. Eating, drinking and dressing a wound play their own clips (`HoldRules.consumeAction`).
>   - **Quick fixes:** guns come up with a full magazine. The death screen and the results card close an open container's panel. A held body is invisible, untouchable, unshootable and untagged (the VIP tag too) until the player chooses. F-29: a tool in a weapon slot hits 9 at 1.22/s (10.98 a second, between fists at 10.8 and the Stake at 11).
>   - 526 Lune specs (517 + 9 in `tests/Holds.spec`: every holdable item has a class, an `Art.held` grip and a model; every class's clips exist; every clip the code plays by name is in `Data/Holds`; F-29). `Hands.spec` now expects loaded guns.
>   - **Verified in play** (the cloud place "Ember", Studio simulation, three sessions):
>     - Every melee weapon and tool in hand from the side, before and after (`docs/milestones/m1-launch/H10_grips_vs_rec6_04.jpg`).
>     - The Assault Rifle aimed, carried and run with; the Duty Pistol aimed and carried; the Shortbow carried and drawn (`H11_guns_bow_vs_rec6_05.jpg`).
>     - The Fire Axe wind-up, its hit frame on a Shambler at Pine Hollow, and running with it (`H12_melee_vs_rec3_07.jpg`).
>     - The first Assault Rifle pull on a run fired with no reload (30 → 29 rounds, 0.55 s for the whole check).
>     - The hit flash on a Shambler came 0.256 s after the click, against the swing's 0.24 s hit frame (it was about 0.48 s with the snapshot path).
>     - At a home pine, the Stone Hatchet was in hand 0.18 s into the wind-up (it used to arrive with the blow), and at the hit frame its head sat 0.29 studs inside the trunk.
>     - With a crate's panel open, death closed it; the respawned body was hidden (0 of 23 parts visible, not queryable, name tag off) and Continue put it back. With a crate's panel open, extracting closed it behind the results card.
>     - UI gate: 0 flags across 21,968 elements, after the last code change.
>   - **How to repeat it:** `EO_Dev` `("equip", itemId, slot)`, then the new `("hold", slot)` puts it in hand and `("approach", studs?)` stands you beside the nearest Hollow. On the Client, `require(Players.LocalPlayer.PlayerScripts.Client.Clips).play(character, name)` plays any clip; pause it with `AdjustSpeed(0)` to capture a key.
>   - **Not verified in play:** the Pipe Pistol, Flare Pistol, Scrap Shotgun, Pump Shotgun, Hunting Rifle and Anti-Materiel Rifle in the new stances (same class clips; their grip-to-butt lengths are within 0.2 studs of the Assault Rifle's); the thrust, lunge, punch, slash and heavy landing on a Hollow (their hit-frame wrists were measured, not watched); a second player's view of carries, stances and gather swings; the bandage and drink clips; touch.
>   - **Seen, not fixed:**
>     - In this Studio session the Rail Mallet renders flat white: its SurfaceAppearance ColorMap (rbxassetid://82838938570657) fails to fetch, beside the boot console's "Requester does not have permission" lines. The Tire Iron and Scrapblade looked untextured too. Check those image assets' permissions on the Creator Dashboard before launch.
>     - Pine canopies hide a survivor chopping from the gameplay camera.
>     - At 1.3x gun scale the support hand can't reach a long gun's handguard; it holds the magazine well. The survivor's hands are open meshes and can't close on a grip.
>     - Checklist 13.4's combos, weapon trails and per-material impacts are not built; the parked melee WIP (`worktree-agent-a3c75eb84c6644ce1`) uses the same class names as `Data/Holds` and is still batch 4's.
>     - The "Found on the way" travel-bonus card stays up into the first fight on arrival.
> - **Update 2026-11-11, 2.0 batch 2 (flow-review QoL and UX): done on branch `qol-flow-review`, pushed, reviewed and merged.** No Studio was used; every rule is a pure Domain module with Lune specs, and wiring is held by needles (`tests/QolFlow.spec.luau`, plus Shop, ItemSources, Grid, Death, Converter, Features and PlayerSchema specs). One line per finding:
>   - **F-06, F-07:** hold on main. Owned gear and placed pieces count when a quest opens (`Domain/Quests` holdings); 84 home timber, a last-tree toast and the Guide's Trailhead pointer.
>   - **F-10:** build mode's tray header shows "Fill up (coin) N" beside CLOSE for the card being placed when it's short; a placed piece's upgrade has it beside its costs. Both use the crafting pane's `offers.fillUp`. Fill Up in crafting and crate upgrades now buys only the shortfall (it charged for the whole recipe). `Offers.shortfall` and `fillUpFor`.
>   - **F-11:** the first win sends a one-time `firstOffer` (at home, once: `shop.cardShown`). It opens `screens/ldoe/OfferCard` (art, contents, the real countdown, the price button), and the HUD's offers strip, left of the clock, then shows the icon pulsing with its countdown until the window ends (`Offers.stripOffer`). The first extraction already counted as the first win.
>   - **F-12:** `ProductDef.unlock`. The Reinforced Room Kit needs the Plans read and Weapon Parts needs The Dense Fog. Locked cards stay greyed with the price and a red lock line (`Receipts.lockLine`); BEST skips them. The gun packs need no gate (no ammo since F-13). The Firestarter Kit isn't gated.
>   - **F-20:** the AUTO button reads "AUTO: 2 Rations + 22 Energy" from data (`AutoClear.price` and `label`). Refusals name the shortfall; airdrops read "loot airdrops in person".
>   - **F-21:** a `wildlife` flag (off) hides the Smoke Rack, its station, smoked venison and their quest steps; Full Stores asks for 10 Hearth Stews meanwhile. The Rain Barrel fills itself with a Boiled Water every 15 minutes, up to 5 (`StationDef.passive`, Converter), and its pane has no input slot. Run deaths count toward the milestone gifts (the 20th is the Ember Heart); home deaths don't. **Left:** selling the Ember Heart needs a new SKU. The doormat and leather were already fixed.
>   - **F-22:** `Domain/QuestText`: "Make a Hewn Plank at the Saw Bench and take it out", "Search containers in Pine Hollow", "Reach level 8: gather, fight and extract for XP". Tracker steps wrap to two lines. The Guide points a level step at the Trailhead. `InboxUse` reports `consume`.
>   - **F-26:** the Scout's Kit is the whole Reedweave set, a Tire Iron, 3 Trail Rations, 3 tins and 3 water (79).
>   - **F-27:** "+1 Smelter/Recycler" sell only at the plot's limit (`BuildRules.placedCaps`); before that they show "Placed 1/2: buy when your plot is full" (or the piece's quest).
>   - **F-28:** `MomentOffers.forBreak`: a weapon offers the kit, a tool Fill Up of its recipe, armor nothing.
>   - **F-30:** starter shelter pieces refund nothing; upgrades paid for on them still refund (`Grid.refundFor`). The old comment claimed this but the code refunded half.
>   - **F-32:** `Tuning.death.despawnSeconds` is gone. A run bag lasts until the lobby closes, a home bag `drops.lifetimeSeconds`.
>   - **F-33:** `features.dailyGift = true`; the false note is gone.
>   - **F-34:** `ItemSources.lockedMaker`: a build card whose cost no open station makes reads "Stonecutter: Ember Trail 4" (the card is wider to fit it).
>   - **F-35:** Trader sales and contract deliveries take from the home pool, and the pane counts the pool; the board only asks for items the player can gather or make now (`Contracts.eligible`, `ItemSources.obtainable`).
>   - **F-36:** a solo Walk is saved in `travel.walk` and resumes, or arrives, about 5 s after the next home load (`Travel.saveWalk` and `resumeWalk`). Party Walks aren't saved.
>   - **F-38:** already on main (Into the Fog pays 300 coins, 4 dressings and 2 Rations); a spec holds every chapter to a reward.
>   - **Player schema v12** (`shop.cardShown`, `deaths`, `travel.walk`), with a migration and a spec. **The parked Haven VIP branch also claims v12:** whichever merges second renumbers to v13.
>   - **Needs a play-check in Studio:** the OfferCard and the offers strip (`ShopTestFirstWin = true`); build mode's tray Fill Up and the upgrade row's Fill Up (the row widens to 440); the wider build card with the source line; the shop's greyed cards (Supplies, Equipment, Building); the two-line tracker (the UI overlap gate); the Rain Barrel pane; the AUTO label; a Walk surviving a rejoin; a contract delivered from a crate.
>   - **Seen, not fixed:** `Converter.lines` lists the Rain Barrel's passive line, so ALL RECIPES would show it if opened (the pane hides the button). Haven's board can change mid-day when an unlock adds an eligible item; delivered contracts stay delivered.
> - **Update 2026-11-12, 2.0 batch 3 (performance and asset loading): done on branch `perf-and-assets`, pushed, reviewed and merged.** Measured in the cloud place "Ember" (Studio simulation, one player). Calls are in the 2026-11-12 DECISIONS row.
>   - **Fog Run arrival (Pine Hollow, the first lobby, through the real `TravelStart` at the Trailhead):** seated **2.0 s after the 3 s Run timer** (5.0 s after TravelStart); before, about 19 s. Where the 19 s went: matchmaking waited 12 s before opening a lobby (`newLobbyAfterSeconds`), then the map built in 8.7 s (layout 3.5 s, of it 1.9 s InsertService loads; Hollow spawn checks 5.3 s, one path at a time). Now: the trip counts as the wait (`Matchmaking.waitSince`, 12 → 3 s), the Studio simulation builds during the trip (`RunWorld.prepare`), the layout takes 1.6 s with no loads, and the map is Ready before the spawn checks, which run in parallel in the background (4.3 s); the first Hollow spawn waits for them. Also fixed: a caller arriving during the spawn checks took the map for a failed build and built it again (two builds for one trip).
>   - **Assets:** the boot console's "Requester does not have permission" lines (`rbxassethash`, about 48 a boot, server and client) were the texture packs of SurfaceAppearances in models loaded through InsertService (`Art.uploaded`, Open Cloud GLB imports). Found by placing models one at a time with a log hook: a model with its SurfaceAppearance logged one, the same model without it none, the same with the SurfaceAppearance rebuilt in Studio none. Every asset id in the place and the source is the owner's (985 ids in the place, 191 in the source, 51 uploads; checked with GetProductInfo), except Roblox's own and `ServerStorage.Survivor_v3_standin` (unused; 16 meshes and a texture from users 278167270 and 3120406154 and group 308007392). Fix: `ServerStorage.EO_Uploaded` holds a Studio-built copy of all 51 uploads with rebuilt SurfaceAppearances (`roblox/tools/rebuild_uploaded.luau`), and `World/Models` uses it before InsertService. **Server-side failures at boot: 0** (were about 22). `tests/AssetAudit.spec` holds every asset id in the source to `tests/KnownAssets.luau`. **No Creator Dashboard action is needed.**
>     - `rbxassetid://203785492` is "Pop Close Sound" (audio, user 44821938), requested as another type 1-3 times a boot by something outside the game: it is not in the repo, Packages, the place, Studio plugins or Studio's ExtraContent, nor in any readable property of 15,185 client instances (CoreGui included). Probably a Roblox core script; no player effect.
>   - **Frame time and memory** (`EO_Dev` "perf" on the server; RenderStepped on the client; Studio, vsync 60):
>     - Home: client 60 fps, p99 19.3 ms, max 19.9 ms, no frame over 50 ms; server frames 16.7 ms average, max 20 ms; 0.2 KB/s to the client.
>     - Run, 8 Hollow active (band 2, walking near them): client 60 fps, p95 18.7 ms, p99 19.9 ms, max 21.6 ms, none over 50 ms. Server: the Hollow tick 0.4 ms average, 1.1 ms worst, 0.2% of the time; `Stats.HeartbeatTimeMs` 0.1-0.3 ms. Traffic about 2.8 KB/s a player (HollowSync 1.65, RunState 0.5, Sync 0.2-0.6).
>     - **Fixed: UI churn on a run, 1,370 GUI instances created in 9 s → 57 in 8 s.** Minimap blips were keyed by full name, and a map's many "Container_crate" siblings shared one key, so their icons were rebuilt 5 times a second and only one per name showed: every container now shows on the minimap. Idle HUD clocks tick slowly (the hurt edge, arrival title and progress card re-rendered at 20-33 Hz all run; the menu bar at 7 Hz).
>     - Lua heap 10 MB client, 9 MB server. Studio's memory and instance counts are per process (about 3 GB, 68k-80k instances), so they say nothing about a phone.
>   - **Rifle off hand:** it needed IK. The arm reaches 1.79 studs from the shoulder and the handguard was 1.9-2.2 away. Long guns now carry a "Support" attachment at the handguard (`HoldRules.supportAt`: 0.4 of the length from the grip, at most 1.25 studs; raised to just under the handguard). The client (`Controllers/Animations`) runs an IKControl on the left arm toward it on every character, plus a per-frame correction, because the IKControl settles 0.2-0.3 studs short on this AnimationConstraint rig wherever the target is. Both long-gun stances blade 20 degrees more, with the head and gun arm turned back by as much, so the gun and the gaze are unchanged. The IK lets go for a reload. Aimed, the palm sits 0.006 studs from the handguard point (0.98 without IK); carried at low ready, 0.24 short (out of reach). Capture: `docs/milestones/m1-launch/H13_rifle_off_hand_vs_rec6_05.jpg`.
>   - UI gate: 0 flags across 21,783 elements, after the last code change.
>   - 553 Lune specs (545 + the Matchmaking trip spec + `tests/AssetAudit.spec`: ids, known assets, the stored-copy order, Ready before the spawn checks, minimap keys, the support point).
>   - **How to repeat it:** `EO_Dev` `("perf", seconds)`, `("mapstats")` (BuildSeconds, LayoutSeconds, ModelLoadSeconds, SpawnCheckSeconds, parts, lights, emitters per built map) and `("assetfails")` (each failed content id since boot, with the models placed just before it). Arrival: stand the survivor at `workspace.World.Trailhead.Sign`, fire `Remotes.TravelStart("loc.pine_hollow", "run")` on the Client, poll `("runstate")`. Off hand: `("equip", "item.assault_rifle", 1)`, `("hold", 1)`, then a side camera through `BindToRenderStep` on the Client.
>   - **Not verified:** a live reserved server (its build at boot plus the teleport; it now builds in about 1.6 s with no loads); a phone (Studio's MCP can't emulate touch hardware; the touch HUD is the same tree, and its fast clocks are fixed); the off hand on the other four long guns (the same rule; only the Assault Rifle was measured and captured); a second player's view of the IK; the UI gate's touch profile beyond its layout flags.
>   - **Seen, not fixed:**
>     - The client still logs 0-16 `rbxassethash` permission lines per session, from content it draws in the HUD's and build menu's ViewportFrames (they came during the UI gate; the count changes with what is on screen). They don't map to any asset id; every id loads, and no model rendered white in any capture. If a live game shows white icons, re-upload those models' textures as plain images and rebuild the SurfaceAppearances.
>     - `EO_Uploaded` lives in the cloud place only (saved 2026-11-12 as place version 206). Rojo leaves it alone (an unknown ServerStorage child). To put it in the repo: save the place to `place/ember.rbxl`, run `lune run tools/syncback.luau place/ember.rbxl EO_Uploaded`, and add it to `default.project.json`. A place built by Rojo alone falls back to InsertService, as before.
>     - The biggest phone cost left is the scene: 500-650k triangles and 200-300 shadow draw calls on a run (54-69 scene draw calls; 36 emitters and 7 lights a map; 82 lights at home, 1 shadowed). Cutting it (LODs, no shadows on small clutter) changes the look, so it needs art and a side-by-side.
>     - Carried at low ready, the off hand stops 0.24 studs short of the handguard (beyond the arm's reach in that pose).
> - **Update 2026-11-11, 2.0 batch 4 (content past the Scrap tier): built, behind `Tuning.features.content2 = false`.** Branch `content-past-scrap`, reviewed and merged; switched on by batch 4b. Spec: [CONTENT_2_0.md](CONTENT_2_0.md). 534 Lune specs, all six checks green.
>   - **In:**
>     - 23 items: the four ARSENAL melee (Hand Axe, Hardwood Bat, Field Knife, Hay Fork), the Hidebound and Riveted sets (each piece consumes the one below), Steel Helmet, Combat Helmet, Plate Carrier, Gas Mask, Hide Rucksack (+8), Ranger Pack (+15), Trauma Pouch, First-Aid Kit, Ember Stim, Steel Plate, Antiseptic Tablets. 18 recipes, 32 loot rows.
>     - The **Fortified tier** (tier 4, five pieces upgrading from Reinforced) and two stations: the Blast Furnace (Steel Plate; needs a Reinforced floor) and the Apothecary (Antiseptic; needs a Fortified floor).
>     - Ember Trail **chapter 4, "Iron Lungs"** (quests 26-33), after Hold the Line.
>     - Rules: `Domain/Gear` (defense, bag slots capped at `maxBackpackSlots`, now 20), `Domain/Meds` (instant plus healing over time, 3 at once), `FogExposure.filterWear` (the mask's filter, 1 a second in Dense and Black fog), `Combat.backstab` and `Combat.meleeNoise` overrides. Wired in `Lobby` (Gear defense; filter wear applied 5 points at a time), `Survival` (heals tick with the meters, drop on death) and `Inventory` (bag slots; the meds button picks the biggest total).
>     - `Features.strip` now also drops tagged quests and loot rows, and the upgrade link into a dropped piece. `tests/Content2.spec`: flag off, nothing in the bundle names anything new; flag on, it validates and every item is earnable.
>     - The melee WIP (`worktree-agent-a3c75eb84c6644ce1`): its class taxonomy is ported as `melee.class`; its clips, poses and timing stay parked for batch 1.
>   - **Save schema: unchanged** (no new slots; heals are runtime only), so this batch takes no v13. If the Haven VIP or another branch bumps it, nothing here conflicts.
>   - **Pacing** (`tests/Pacing.spec`, content modelled on): every existing band green on the 21-day runs (2.5 h: Scrap 4.37, Black 6.81, Reinforced 11.79). New 30-day run: chapter 4 from day 17.8 to 27.8 with no gap over 4 days, Fortified on day 24.8; 3 h a day ends it on 23.8; 2 h a day gets 7 of 8 by day 30. Two sim changes: a loaded station gets fuel between demands, and a quest's crates can steer runs (`seek`).
>     - **The open melee-wear item above is closed:** melee now breaks in 52 of 233 runs (22%) at 2.5 h a day, so `Pacing.spec`'s floor is back at 10%.
>   - **Studio pass (orchestrator), in order:**
>     1. Upload the 14 GLBs in `art/content2/` and grade each side by side with rec9. The gear and meds are decoded for Roblox (no meshopt or WebP). The four melee are the **unreviewed** `art/zona/wip-v3` files: check them first. The pill box (Antiseptic Tablets) is a 12-triangle textured box: keep it only if the icon grades A.
>     2. Generate (free Studio MCP) and grade what Zona has no licensable model for: the 8 Hidebound and Riveted pieces, Steel Plate, the 5 Fortified pieces, the Blast Furnace and the Apothecary.
>     3. Held grips for the four melee (batch 1 owns grips; `melee.class` says axe, blunt, stab, stab).
>     4. Worn visuals: both helmets, the gas mask and the set caps on the head, the Hidebound and Riveted pieces, the Plate Carrier, both bags on the back.
>     5. Icons for all 23 (every `icon` is "" today), and `Art.items` entries.
>     6. **The Combat hook** (Services/Combat.luau, batch 1's file): at the melee hit, pass the weapon's melee stats: `CombatMath.backstab(fighter.sneaking, Hollow.isAware(run.hosted, target.id), tuning.sneak, weapon.melee)`. The knife's quiet swing needs `Hollow.noise` to take a radius: `CombatMath.meleeNoise(weapon.melee, tuning.noise.melee)`.
>     7. Flip `content2 = true` (and the "ships off" test in `Content2.spec`), then check in play: the mask's filter in Black fog, healing over time, a Fortified upgrade, the 20-slot backpack.
>   - **Seen, not fixed:**
>     - **For the economy batch:** with the mask, `fogExposure.maxResist` 0.8 binds for Hidebound and Riveted wearers, so Black fog stops hurting a geared player (20 min to fill against a 15 min run). Consider 0.75.
>     - The Hide Rucksack unlocks at quest 13, not F-37's quest 9: at 9 the model's Reinforced tier fell to day 9.8, under its band.
>     - The Hand Axe's `structureMultiplier` has no reader until M2 raids.
>     - The Credits panel lists the 14 new models while the flag is off.
>     - The Blast Furnace burns wood fuel like the Smelter; on Embercoal alone the model starved it.
> - **Update 2026-11-12, 2.0 economy batch (the flow review's balance findings): done on branch `economy-balance`, pushed, reviewed and merged.** No Studio was used. Every rule is in a pure Domain module or data with Lune specs; calls are in the 2026-11-12 DECISIONS row. Numbers are `Pacing.spec`'s 2.5 h-a-day player, before → after. One line per finding:
>   - **Melee wear (the open step-3 item):** the junk lever is turned in `Data/LootTables` and the spec's copy (Pine Hollow's band 2 and 3 ammo rows give `loot.junk`). Melee breaks in 52 of 233 → 41 of 231 runs with content2 on, and 52 of 233 → 43 of 227 with content2 off. The new content2-off check (`Features.strip`, no chapter 4 or Fortified goal) holds the bands and the 10% floor. The "about 5%" in step 3 predated batch 4's sim fixes.
>   - **F-16:** Energy cap 200 → 120 (regen and Run costs unchanged), location dailies 2 → 0 Rations a day, airdrops at 84/48/12. `PacingSim` now counts the moments the wanted Run was unaffordable: 5 → 33 (2 h a day 0 → 12, 3 h 24 → 45), none on day 1; walks 0 → 4 (3 h: 4 → 16).
>   - **F-15:** Black fog fills in 240 → 380 s unprotected; a full Padded set 7.3 → 11.5 min, so band 3 (11.8 min) costs about 34 HP instead of 500+. Into the Black warns of the fog and the gear drop.
>   - **Gas mask:** `maxResist` 0.8 → 0.56; Hidebound 0.55 → 0.48 and Riveted 0.67 → 0.51 fog resist. Any set plus the mask reaches the cap, 14.4 min (was 18.2 to 20), so the best kit still loses health before the 15 min close.
>   - **F-17:** the Trader's list drops Rivets and Planks: basics only.
>   - **F-18:** `Gathering.pickTool` takes the lowest tier that can harvest the node (a pine uses the Stone Hatchet with a Forged one in the bag).
>   - **F-19:** band 1 adds a Shambler per seated survivor past two and tops up for late joiners: Pine Hollow 6-9 → 16-19 at 12 players.
>   - **F-23:** player schema v12 → **v13** (`limits`: both ad caps, the airdrop day and pins, signal-tower parts and repairs), migration and spec; Travel and Lobby read the profile, not server memory. The parked Haven VIP branch's schema bump becomes v14 when it is ported.
>   - **F-25:** a speed-up is capped at the Fill Up value of what it makes (one Scrap Plate 18 → 13 Embers); tier-1 raw 1 → ⅓ Ember a unit (30 timber 30 → 10); Supply Bundle 196 → 65 Embers of contents, so the rate rises with price (0.66, 0.72, 0.75 Embers a Robux).
>   - **F-31:** Niter, Steel Pipe, Trigger Group, Signal Flare, Reanimator, both venisons and Leather stack to 20 (scrap 50).
>   - Bands: Scrap 4.37 → 4.36, Black 6.81 → 6.83, Reinforced 11.79 → 12.38, chapter 3 ends 17.82 → 19.34, chapter 4 27.81 → 28.82, Fortified 24.81 → 25.34; none moved. 580 Lune specs, all six checks green.
>   - **Needs a play-check:** the Fog map with a 120 cap (the regen countdown, "Need N more", the Refill slot, airdrop pins at 84/48/12); a profile loading as v13 and a Recover-all or AUTO ad cap surviving a hop (ads are off, so check the saved `limits` with `EO_Dev`); a tower part kept across a rejoin (`regionGates` is off); Black fog HP with a full Padded set, and with the mask once content2 is on; 10+ survivors at Pine Hollow (the crowd Shamblers, `maxActive` 60); the station pane's speed-up price on a short job; the Trader's shorter list; the Supply Bundle card; a pine chopped with both hatchets carried.
>   - **Seen, not fixed:** the pacing model is sensitive: a small Energy or loot change moves the broken-melee count between 1 run in 15 and 1 in 4, so re-run `PACING_VERBOSE=1` after any tuning. ECONOMY §9.2-9.3's tables and SHOP_CATALOG's Supply Bundle row still show the old numbers; LDOE_PARITY #38 and #43, ECONOMY §9.1 and ARSENAL §5's cap note are updated.

> - **Update 2026-11-12, 2.0 batch 4b (Content 2.0's Studio pass): done on branch `content2-studio-pass`, pushed, reviewed and merged. `Tuning.features.content2 = true`.** 570 Lune specs, all six checks green. Calls are in the 2026-11-12 DECISIONS row. The cloud place "Ember" was saved as **version 219**: 25 new `EO_Uploaded` copies, the survivor meshes restored, Rojo's duplicate containers removed and every SurfaceAppearance and MaterialVariant rebuilt.
>   - **In:**
>     - **Models (25, all owner assets):** 8 of batch 4's Zona GLBs (gas mask, both helmets, plate carrier, Ranger Pack, Trauma Pouch, First-Aid Kit, Ember Stim). The rest are Studio mesh generations: the four melee, both armor sets, the Hide Rucksack, Steel Plate, the Antiseptic bottle, the Blast Furnace and the Apothecary. The wip-v3 melee files are Git LFS pointers in the approved folder, so they couldn't be uploaded without filling or copying files there; the camping pack and the pill box weren't grade A. `CONTENT_2_0.md` §7 has the table, and the unused credits are dropped.
>     - **Fortified:** a generated riveted-plate MaterialVariant (`place/materials/EO_Deck_Fortified.model.json`) on the exact geometry, `Art.decks[4]`.
>     - **Worn look:** armor tints the clothes as Padded does (`Art.worn`, the Plate Carrier too). Headwear and bags are models on the body (`Art.wornModels`, `Models.worn`, `Inventory.wornModels`); a bag hides the survivor's own pack and pushes a back-slung weapon out.
>     - **Melee:** `Data/Holds` classes and `Art.held` grips, measured by casting rays across 12 slices of each handle.
>     - **Icons:** all 23 render their model, through `Art.items`.
>     - **Combat hook:** `weapon.melee` drives `CombatMath.backstab` and the swing's noise radius (a new `Hollow.noise` argument).
>     - **Chapter 4's Trail Keeper hand-in.**
>     - Studio-only `EO_Dev` `("hurt", hp)` and `("gearstate")`.
>   - **Client asset failures, 50 → 0 at a play start** (the first clean session). The kit files Rojo serves carried `TexturePackContent` assets the client can't read: the survivor rigs, the Hollow, `EO_Kit` and the generated materials. `tools/strip_texture_packs.luau` sets them to none in `place/kit/*.rbxm`, and the place's copies were rebuilt fresh. Plugins can't write that property, so Rojo can't clear it. Fresh generated textures drew grey in ViewportFrames, which don't fall back to the baseline image; `Controllers/ArtPreload` and `ModelView` now preload each icon's model and redraw it.
>   - **Verified in play** (Studio simulation; captures in `docs/milestones/m1-launch/`, side by side with LDoE where a frame exists):
>     - **Hidebound:** a coat crafted through `HandCraft` (the Padded Vest and 6 leather consumed) and worn through `InventoryMove`; the set reads as hide (C21).
>     - **Gas mask:** worn (C25); on a Rustwater run (Dense) the filter wore 895 → 885 in 10 s.
>     - **Meds:**
>       - Field Dressing: 30 → 70.
>       - Trauma Pouch: 20 → 45 at once, then 40 over 10 s.
>       - First-Aid Kit: 10 → 50, then to 100 over 12 s.
>       - Ember Stim: 10 → 70, then 100 by 3 s.
>       - The bandage clip plays (C23).
>     - **Bags:** the Ranger Pack through `InventoryMove` gives a 20-slot backpack (5 + 15, the cap), the Hide Rucksack 13; both on the back (C22).
>     - **Field Knife:** sneaking on an unaware Hollow (`DevUnseen`) dealt 40, its full health (11 x 4); the same swing unsneaked dealt 11 (C28).
>     - **Fortified:** a foundation and two walls upgraded wood → Fortified, the Apothecary on the Fortified floor and the Blast Furnace on a Reinforced one (C24).
>     - **Chapter 4:** `("quests", 25)` opens it. The card shows "Iron Lungs: Hotter Fires", the tracker shows both lines, and the Guide rings the build button (C27).
>     - **Icons:** all 23 draw textured on first open (C26).
>     - **UI gate:** 0 flags across 22,616 elements, after the last code change.
>     - Lineups: C29-C31.
>   - **Not verified in play:**
>     - Riveted pieces, the helmets and the Combat Helmet worn (seen only on Edit rigs, C31).
>     - The gas mask after its last size step (1.08, to cover a tuft of hair).
>     - Black fog filter wear.
>     - Fortified doorway, door and window.
>     - The Blast Furnace and Apothecary jobs.
>     - Hand Axe, Bat and Hay Fork swings on a Hollow.
>     - Chapter 4 past its opening.
>     - A second player's view, and touch.
>   - **Seen, not fixed:**
>     - **Client permission lines remain:**
>       - 0-12 at a play start, depending on what is near the camera; 8-21 on arriving at a run; 5 during the UI gate. All are hashes from the original 50.
>       - Placing each kit model in view one at a time traced them to batch 3's family conversions: barrel cluster, supply sacks, dead tree, bare branches, the pickup and van wrecks, fuel pump, loose stones, spring basin, hay bales, scrap heap, rock cluster, ember bush and reeds.
>       - Their SurfaceAppearances are rebuilt and every map is an owner image (checked with GetProductInfo), and they render textured. Next step: re-upload those maps as plain images and point the copies at them.
>     - About 14 "No asset content representation found while do_not_fallback_to_baseline" lines a boot, from fresh generated textures. Harmless now.
>     - **Rojo:** its connect and re-sync made twins of the rbxm-backed containers with empty meshes (plugins can't set `MeshContent`). `LT_Gen` and `Survivor_v3_standin` had them before this batch. Removed in the place; after pressing Connect, check `ServerStorage` and `StarterPlayer` for twins.
>     - Generated models use `TextureID`, so `Art.tints` can't warm them. The Blast Furnace's blue-grey stone is cooler than the Smelter.
>     - The Fortified plates' rivet holes read a little like bullet holes up close.
>     - ART_DIRECTION §10a still says `generate_mesh` results leave the world. This batch used them under the side-by-side bar; that line needs a revision.
>     - **Gas mask (left for the economy batch):** filter wear follows the location's fog tier, not the rising band. It wears in Rustwater at band "Thin" and not in Pine Hollow at band "Rising". Batch 4's 0.8 `maxResist` note stands.
> - **Update 2026-11-12, orchestrator: 2.0 batches 1–4b and the economy batch are all merged** (main ea73833, 580 Lune specs, six checks green). The merged build was checked in Studio:
>   - content2 is on, and Energy starts at the new 120 cap;
>   - the UI gate is at 0 flags across 22,544 elements;
>   - there are no script errors on the server or the client;
>   - the server has 0 asset-content failures;
>   - the client still warns about 18 permission and 14 "no content representation" assets, probably uploads still processing — re-check after a day;
>   - no twin containers in `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer` or `ServerStorage`.
>   - **Open:**
>     - The gas-mask filter wears by the location's fog tier, not by the rising band (above).
>     - The economy batch's play-check list.
>     - Batch 5: more guns and the full SHOP_CATALOG.
>     - M2: raids, PvP and guilds.
> - **Update 2026-11-12, batch 5 finished and arms out of the body: branch `guns-and-grenades`, pushed, reviewed and merged.** main (god mode) merged in; 592 Lune specs, six checks green. Calls are in the 2026-11-12 DECISIONS row.
>   - **How the clipping was measured:** a Studio script on the play client, deterministic, no eyeballing. Each arm part's mesh vertices (from the StarterCharacter's own meshes, read in Edit with EditableMesh) are tested against a 0.03-stud inside-depth grid of the UpperTorso, LowerTorso and Head meshes, plus the worn Hide Rucksack's hull (the widest bag). Upper-arm vertices within 0.5 studs of the shoulder pivot are left out against the upper torso (the joint's cap overlaps by rig design). Numbers are the deepest overlap in studs, sampled every frame through each pose. The data folder was a temporary `ReplicatedStorage.EO_MeasureData` and has been removed from the place.
>   - **Floor:** this rig overlaps itself with nothing in hand: idle 0.08 (upper arm on the flank), walk 0.11 (hand on the hip). Any free arm swinging with the walk sits at that floor.
>   - **Before → after, deepest overlap (studs):**
>     - Pistol (Duty Pistol, Hand Cannon): carry 0.36 → 0.08 (free left arm), aim 0.13 → 0.05, recoil 0.13 → 0.05, reload 0.12 → 0.08, walk 0.37 → 0.07, run 0.36 → 0.06.
>     - Long (nine measured: Machine Pistol, Tactical SMG, Compact Rifle, Patrol Carbine, Assault Rifle, Pump Shotgun, Hunting Rifle, Marksman Rifle, Anti-Materiel Rifle; the Scrap Shotgun plays the same clips, not measured): carry 0.47 → 0.06-0.08 (free left arm), aim 0.46 → 0.04, recoil 0.46 → 0.04, reload 0.12 → 0.08-0.16 (left hand into the hip on 7 of 9), walk 0.47 → 0.07-0.10, run 0.47 → 0.02-0.07.
>     - Bow: carry 0.40 → 0.08, draw 0.38 → 0.07, walk and run 0.40 → 0.06.
>     - Throw (Frag Grenade): swing 0.20 → 0.08.
>     - The long aim with the off-hand IK on (real mouse input, Assault Rifle): the old pole 0.08-0.13 (upper arm into the chest); a pole sweep put the new pole at 0.04. After the pole change the real-input recheck got no samples (the injected press did not register), so the shipped pole is measured only by that sweep.
>   - **What changed:** every gun, bow, throw and reload pose was re-solved against the meshes (Data/Holds); the long gun's off hand closes on the gun just ahead of the grip while aiming and lets go at the carry (`HoldRules.SUPPORT_MAX_STUDS` 1.25 → 0.12, `supportWeight(reloading, aiming)`); the IK pole moved out and ahead; the reload is hand-keyed. `HoldRules.armClear` is the pose limit, checked for every key in `tests/Holds.spec.luau` (it flags the batch-3 low ready).
>   - **Batch 5 play checks** (cloud place "Ember", Studio, Pine Hollow, god mode on throughout, health 100 at every read):
>     - Guns, one `("shoot", 10)` each: Hand Cannon 40 → 0 HP, durability 135 → 134; Machine Pistol 40 → 31, 720 → 719; Patrol Carbine 40 → 24, 570 → 569 (first try stopped by the Farmhouse roof panel); Compact Rifle 24 → 11, 600 → 599. Tactical SMG (720 → 719) and Marksman Rifle (78 → 77) were stopped by `Farmhouse.Roof.Panel` on both tries: their damage is not verified.
>     - Throws, `("throw", 10)`: Molotov landed on the aim and burned a Shambler 40 → dead inside 3.2 s, stack 3 → 2 (first try: the arc met the farmhouse 10.9 studs out). Frag Grenade landed short both tries (10.9 and 13.4 studs from the aim, the second after 0.35 s) and hurt nothing: **not verified**.
>     - The client throw (real mouse): the arc preview drew (18 dots and the blast ring) while held, the model flew, and one `CombatThrow` went per release. The first try instead spent all 3 grenades and left the Assault Rifle auto-firing about 54 rounds after the hand switched to it; the retry was clean. Likely the injected mouse input, not diagnosed.
>     - New in the controller: on touch, dragging the finger that pressed the weapon circle moves the aim from the auto target (up is farther). **Not verified** (no touch hardware).
>   - **Not done:** the G20 front and side captures. The capture script never saw the viewport (screen grab found no sentinel), and the session stopped at its tool-call budget. Take them from a fresh play: equip each class, `Clips.play` the aim, a `ZZ_PoseCam` render-step camera.
>   - **Seen, not fixed:** the shoulder stays bladed only 30 degrees and the off hand sits at the grip, not the handguard: at 1.3x gun scale this rig's arms (1.38 studs shoulder to wrist) can't reach a handguard without crossing the chest. The reload's left hand still brushes the hip (up to 0.16). Pine Hollow's Farmhouse roof panel stops rounds and throws from 8 to 13 studs out.

> - **Update 2026-11-12, moving combat and the throw bugs: branch `moving-combat`, pushed, reviewed and merged.** The developer: attacking or shooting while moving (behind, sideways) looked bad. 609 Lune specs, six checks green, UI gate 0 flags (22,551 elements). Calls are in the 2026-11-12 DECISIONS row.
>   - **The facing rules** (`Domain/Facing`, pure, `tests/Facing.spec`; applied by the new `Controllers/Stance`):
>     - Moving within 65 degrees of the target: the legs keep the movement (the rig's own run) and the waist turns the chest onto the target.
>     - Past that, the whole body turns toward the target, to the facing that leaves the movement exactly 45 off ahead, 45 off behind or straight behind. The legs then play a strafe (`legsAheadLeft/Right`), back-diagonal (`legsBackLeft/Right`) or backpedal (`legsBack`) cycle along it, and the waist turns the rest. Bands hold 6 degrees past their edges (no flicker); the waist's hard stop is 75 degrees.
>     - The cycles are solved by two-bone IK on the StarterCharacter's legs (thigh 1.04, knee to sole 1.6, hips lowered 0.4). The spec checks that the planted sole holds the ground, moves at the speed the play rate promises (within 2%), and never crosses the other foot. The play rate is ground speed over the cycle's foot speed.
>     - The root turns eased (`TURN_SECONDS` 0.05); the stance and the leg cross-fades blend over 0.15 s. The stance holds 0.6 s after the last attack. AutoRotate is off only while it holds.
>     - The waist turn is written on the Waist joint after the Animator, every survivor this client draws: others turn to the yaw of their last shot or swing. Shot tracers leave the muzzle along the shot, not the root.
>     - Swings, the throw and the hit flinch play through `Clips`' waist mask (`"upper"`: everything below the chest is left to the legs). The old swings were full-body and froze the legs at rest mid-run.
>   - **Measured in play** (cloud place "Ember", Studio, Pine Hollow, god mode on, health 100 at every read). The client drove `Humanoid:Move` in 8 directions at 16 studs/s against a fixed target 30 studs ahead (`EO_DevClient` `("aimAt", x, y, z)`, then `("stance")`). Columns: the move off the target, then gait, root, waist, ground and leg speed in studs/s.
>     - Assault Rifle held firing: 0° forward (rig run), waist 0; 45° forward, waist -60.5; 90° aheadLeft, waist -63.2, 16/16; 135° backLeft, -10.1, 16/16; **180° back (`legsBack`), root on the target, waist 0, 16/16**; 225° backRight, 9.9, 16/16; 270° aheadRight, 63.4, 16/16; 315° forward, 60.5. Movement against the root matched the cycle in every row (0, 45, 135, 180). The measured chest (upper torso against lower) was the written waist minus the aim's 30-degree blade every time.
>     - Hand Axe swinging (`chopSwing@upper`): in all 8 directions the right hip kept swinging 16 to 33 degrees over 0.24 s mid-swing (the legs never froze). The cycles and speeds were as above, and the waist peaked at 64.0.
>     - Leaving the stance: AutoRotate back on, waist 0, legs back to the rig's idle.
>   - **Captures** (Studio MCP `screen_capture`, a client `ZZ_PoseCam` side camera, day via `ClockOverride` 13.5 on the client): `docs/milestones/m1-launch/M01_fire_behind_on_the_run_vs_rec6_07.jpg`, `M01_strafe_swing_vs_rec6_04.jpg` (the swing track was held at its wind-up frame for the shot; the legs kept running), `M01_backpedal_rifle_vs_rec6_08.jpg`.
>   - **Throw fixes:**
>     - **Short landings:** batch 5's two short frags landed 10.9 studs from the aim, the same distance at which the Molotov's first try met the Farmhouse. The dev throw had stood the survivor under the roof. A 12-stud lob also peaked 9 studs over the ground, high enough to catch overhangs.
>       - `Throw.apexFor`: the rise grows with the throw's length up to the item's apex, so a 12-stud throw peaks 4.6 studs over the hand line. Throws of 25 studs or more are unchanged.
>       - `Util/ArcCast` is now the one cast the server and the preview both make. It passes through see-through volumes (`Throw.solid`: transparency 0.9 and up), and the client preview also leaves out its Hollow views.
>       - The dev throw stands on the first of eight bearings with a clear arc and reports `blocker`.
>       - In play: a frag from 12 studs landed 0 studs from the aim, no blocker, stack 3 → 2, and killed both Shamblers in the ring (40 → dead at 0 studs, 29 → dead at 9.5).
>     - **One press, one grenade** (`Domain/Trigger`, `tests/Trigger.spec`): a hold belongs to the weapon in hand at its press. A release completes only that weapon's action, once. A gun fires on a hold only if the hold began with the gun. The client also keeps the throw interval, so a press in the cool-down draws no throw. In play:
>       - One press threw one grenade (2 → 1, the preview drew while held).
>       - A press begun with a grenade, then switched to the Marksman Rifle mid-hold by the server, fired nothing for 2 s (durability 77 → 77). Its release threw nothing and cleared the preview.
>       - The real-mouse path wasn't repeated.
>   - **The two untested guns**, one `("shoot", 10)` each at Pine Hollow, clear of the Farmhouse:
>     - Tactical SMG: Shambler 40 → 29 HP, durability 720 → 719.
>     - Marksman Rifle: 40 → 0 HP, durability 78 → 77. The first try straight after the hand switch fired nothing (still in the swap or reload window); the retry hit.
>   - **Not verified:** touch input; another survivor's legs and waist as seen by a second client (one-player sessions only); the bow and the pistol stances on the move (the rifle and the axe were measured); real-mouse input for the trigger fix; how the cycles look at the 22 studs/s sprint (rates scale, not captured); night captures.
>   - **Seen, not fixed:** the frame-by-frame foot plant is held by the spec, not measured on the play client (the play check compares ground and leg-cycle speed). The `M01_` prefix is shared with the older minimap captures.
> - **Update 2026-11-12, roof fade (developer: "when im in a building the roof should dissapear"): done on branch `roof-fade`, pushed, reviewed and merged.** 590 Lune specs, six checks green. No Studio was used.
>   - **Why it looked broken before:** FogRun lifted the roof instantly to 1, then WorldFx's wall occlusion caught the same roof on its camera ray and held it at 0.6, so the roof never left. Haven had no roof handling at all.
>   - **What fades now** (`Controllers/RoofFade`, rules in `Domain/Interior`): in the building you're in, the roof, chimney, gable ends, porch awning and eave sign ease to 0.97 in 0.25 s. The walls and corner posts that face the camera ease to a 0.6 ghost. The far walls stay solid, as in LDoE (frames rec4 120 s and rec8 17 s: open-topped rooms, walls standing). A roof that hides you from outside ghosts to 0.6, found with one ray. The check runs 10 times a second, for buildings within 70 studs. Doorway hysteresis: you're in 0.3 studs past the inner wall line, and out only 1.5 studs beyond it.
>   - **Where the tags come from** (server, at build time, `World/Interiors`): `EO_Interior` with `InteriorFloor` and `InteriorSize` on the building, `EO_InteriorRoof` on roofs, and `EO_InteriorWall` with `Facing` on wall sides. Set in `Maps/Builder` (every enterable building, its porch awning and its corner posts), `ZoneDress.tower` (lookout decks), Rustwater's gas canopy, and Haven's two stalls and two sheds. `EO_Roof` and the `Interior` box stay for the Radar.
>   - **Player builds:** no roof piece exists yet (`Data/BuildPieces` has no roof kind). The doc header in `World/Interiors` says where to hook one in.
>   - **Ownership:** WorldFx's occlusion looks past anything tagged as roof, and past any wall RoofFade is holding, so two systems never write the same part. CastShadow is untouched.
>   - **Studio check (orchestrator, at merge):**
>     1. **Haven, Trail Keeper stall** (east of the square, facing west). Walk in from a side, between the front posts and the back crates. The roof panels and the "TRAIL KEEPER" board lift. The scrap wall behind (camera side) ghosts. Step out sideways: everything returns, with no flicker on the edge.
>     2. **Haven, Trading Post** (west of the square). The roof lifts and its back wall stays solid, because it's on the far side. Then the **hay barn** and the **stores** shed, south of the spawn.
>     3. **Pine Hollow** (`EO_Dev:Invoke("fogrun", "loc.pine_hollow")`). Walk through the door of any house: the roof and chimney lift, and the south and east walls ghost. Stand on the threshold and nudge back and forth: nothing flickers. Then stand just north-west of a house, behind it: its roof ghosts.
>     4. **Rustwater**, under the gas canopy: the deck and band lift and the pillars stay. **Bracken Edge's Hunter's Stand** or **Gloaming Deep's Fire Lookout**: on the deck, the plank roof lifts.
>     5. **Lighting:** inside a house at noon (ClockOverride 12), the floor should stay in the roof's shade. If it goes sunlit, LocalTransparencyModifier drops shadows in this lighting mode. Then decide whether a sunlit room is acceptable, since `ROOF_ALPHA` alone can't fix it.
>     6. **Cost:** RoofFade's Heartbeat should be under 0.1 ms in the MicroProfiler with a Fog Run map loaded.
>   - **Orchestrator Studio check 2026-11-12** (main after the merge, Pine Hollow, scripted):
>     - The Farmhouse's 12 roof parts read 0 outside, 0.97 inside and 0 again after leaving. The capture shows the room clear, the camera-side wall ghosted, and the floor shaded.
>     - That check found a bare 0.6-stud lamp cube floating in the room once the roof faded. `Builder.lamp`'s holder is now invisible; the glow stays.
>     - Haven, Rustwater, the towers and the doorway flicker were not checked in play.
> - **Update 2026-11-11, ship readiness (the launch gate on today's main): pass after 3 fixes.** Branch `ship-readiness` from main b547d44, pushed, not merged. 618 Lune specs, six checks green. Cloud place "Ember", Studio simulation, three play sessions (each a fresh mock profile), god mode on throughout except the one Black-fog check. No tester death outside the scripted one.
>   - **Launch gate (MVP_LAUNCH "How we go fast"):**
>     - **Scripted playtest: pass.** New player (Level 1, 0 Embers, Energy 120 of a 160 cap: the creator owns the VIP pass in Studio) → gather 10 sticks, 6 stone, 2 fiber in 18 swings through `Gather` → `HandCraft` rope, stake, hatchet and pick (all instant), stake equipped through `InventoryMove`: quests 1 and 2 done from real events → 20 pine swings, 10 timber → 2 foundations and 2 walls at real cost (40 → 4 timber, 2 rope): quest 3 done → `TravelStart` at the Trailhead, Energy 120 → 105, on Pine Hollow at once → a crate (`ContainerSearch`, 6.8 s, `ContainerTakeAll`: +9 timber, +1 pitch glue) → `("shoot", 10)` with the Assault Rifle, Shambler 40 → 23 HP, durability 480 → 479, then `("kill")` → `("extract")`: "YOU MADE IT OUT", 0:31, 1 Hollow, 1 searched, +40 XP, home → a run to Ashfall Depot and `("die")`: the death screen → Recover all (Embers 171 → 71, the bag to the inbox) → Continue, home. About 30 in-game minutes over the sessions.
>     - **UI overlap gate: pass,** 0 flags across 22,540 elements, after the last code change (a second run with every ScreenGui hidden for captures read 0 elements and doesn't count).
>     - **No below-A visible: pass with notes.** The store art is graded below; the pale rock cluster and scrap heap are under "seen, not fixed".
>     - **Checks: pass,** six green at every commit.
>   - **Play-checks cleared (from the 2.0 blocks):**
>     - **Fog map at cap 120** (VIP attribute off): "3/120", the regen countdown "+1 in 4:51", "Need 12 more", "No Energy", REFILL 99, RUN 15, WALK free, "AUTO: 1 Ration + 15 Energy"; the airdrop pin reads "Opens in 1:55:21" and "AUTO: loot airdrops in person".
>     - **The Trader:** buys Boiled Water, Fatwood, Field Dressing, Reed Cord, Reedcloth and Sealed Tin, no Rivets or Planks (F-17). Selling 5 timber took the coins 5 → 25; a Boiled Water cost 15 (25 → 10).
>     - **Supply Bundle contents:** two receipts through `ShopTestReceipt` put 90 timber, 90 stone, 60 ironstone, 12 planks and 2 Scrap Plates in the inbox: 45/45/30/6/1 each, as the card shows. Replaying the first receipt id granted nothing.
>     - **Speed-up price:** a Blast Furnace Steel Plate job (19 m 58 s left) showed SPEED UP 29; pressing it charged 29 (200 → 171) and gave 2 Steel Plates.
>     - **Build mode's tray Fill Up:** the Rain Barrel selected short of cloth shows "Fill up" 6. Fill Up on a Brass Gear (no Fill Up rate) is refused: "Those can't be filled up".
>     - **Greyed shop cards:** Reinforced Room Kit "Read the Reinforcement Plans", Pack of Weapon Parts "Complete the 'The Dense Fog' quest", +1 Smelter "Complete the 'Into the Fog' quest", +1 Recycler "Complete the 'Scavenger' quest"; the passes "limit" (owned).
>     - **The Firestarter Kit's one-time card:** not offered in Studio, correctly: `checkPasses` records the creator's two passes, so the tester is a payer (`Offers.hasPaid`). With the row forced on offer locally, the card draws (FIRESTARTER KIT, "You made it through. A survivor's kit, once:", contents, "Ends in 48h 00m", 99, Later, the strip's 47h 59m) and clears when the row goes off offer.
>     - **Chapter 4's first two steps:** `("quests", 25)` opens Hotter Fires and Hide and Rivet. A Blast Furnace on a Reinforced floor ticked step 1; the 2 sped-up plates read 2/6 on step 2 ("Make a Steel Plate at the Blast Furnace and take it out 2/6").
>     - **Black fog HP in Padded:** at Ashfall Depot with the full Padded set, god mode off for 10 s standing still: HP 100 → 100, no hits; exposure 0.031 after about 21 s on the map, which is the 11.5 min fill. God mode back on.
>     - **Death screen:** "YOU DIED", "Go back in: 17 Energy", Recover all 100, the Scavenger's Kit 79, Continue, "Your bag stays where you fell in Ashfall Depot until the lobby closes."
>   - **Fixed (3):**
>     - **A script error on every gather swing:** Interaction's local "swing" effect has no `userId`; CombatControl took it for another survivor's swing and called `GetPlayerByUserId(nil)` ("Argument 1 missing or nil", 7 in one session). It now ignores a swing without a survivor.
>     - **Recover all's inbox toast** listed the bag slot by slot ("Timber x20" ten times, about 60 entries). It merges by item and names at most six, then "N more".
>     - **Heavy Equipment's card said "every gun and the bow"** with 3 of the 14 guns inside. It now names the contents. Also: a product Roblox reports off sale is now "notListed" like a robloxId of 0: `ShopBuy` refuses it and the shop hides its card (BEST too), so a missing product can never open a broken prompt. A failed price read leaves it listed.
>   - **Shop products: 18 of 18 live, 0 missing** (`GetProductInfo` in Studio, universe 10775267789; every name and price matches `Data/Products` and `Tuning.prices`; all on sale):
>
>     | SKU | Robux | Roblox id | Kind |
>     |---|---|---|---|
>     | Firestarter Kit | 99 | 3729832319 | product |
>     | Scavenger's Kit | 79 | 3729872993 | product |
>     | Supply Bundle | 99 | 3729832298 | product |
>     | Builder's Crate | 399 | 3729873035 | product |
>     | Reinforced Room Kit | 1,699 | 3729873052 | product |
>     | Energy Refill | 99 | 3729832267 | product |
>     | Ember Pouch | 149 | 3729873068 | product |
>     | Ember Chest | 799 | 3729873080 | product |
>     | Scout's Kit | 79 | 3729896813 | product |
>     | Pack of Weapon Parts | 149 | 3729896823 | product |
>     | Padded Armor Pack | 199 | 3729896833 | product |
>     | Gunrunner Pack | 249 | 3729896836 | product |
>     | Raider Arms | 499 | 3729896845 | product |
>     | Heavy Equipment | 2,499 | 3729896851 | product |
>     | +1 Smelter | 399 | 3729896857 | product |
>     | +1 Recycler | 399 | 3729896863 | product |
>     | Pack Expansion | 199 | 2076082454 | game pass |
>     | VIP Lounge | 399 | 2075836390 | game pass |
>
>   - **Store art** (`docs/store/`, composed with PIL from MCP `screen_capture`s of this build; title in Impact, ART_DIRECTION's ember orange and cream; no Roblox marks, no claims beyond the game): `icon_512.png` (the survivor aiming at a Shambler, "EMBER OUTPOST"), `thumb1_fight_1920.png` (Pine Hollow at dusk, the Assault Rifle at point-blank, "SURVIVE THE FOG"), `thumb2_base_1920.png` (a Fortified room with the Workbench, Woodworking Bench and Smelter, "BUILD AND FORTIFY YOUR OUTPOST"), `thumb3_scavenge_1920.png` (the Pine Hollow Farmhouse with its roof faded and the survivor inside, "SCAVENGE WHAT THE FOG LEFT"), `description.txt` (about 770 characters). Graded beside LDoE's loading-screen key art (rec2 4.6 s): LDoE's is painted, ours are real captures, so ours are flatter in light but claim nothing the game doesn't do. The icon and the fight thumbnail are the strongest; in the base shot the Fortified rivet holes read as bullet holes, and in the house shot the ghosted near walls are busy. **2026-11-12 retake:** thumb2 is now a Reinforced base from outside at dusk (campfire, two torches, four stations). The thumb3 retake (the Fog map) showed Energy 380/160 from a dev setting and its title covered the RUN and WALK buttons, so it was dropped; launch ships two thumbnails.
>   - **What's left for the developer:** MVP_LAUNCH's "Publish checklist", 11 numbered steps (approve the merge, the twin check and save, optional Studio API access, Max Players 8, publish privately, a live private test with the first real teleport and a phone, the questionnaire, Basic Info and the description, the icon and thumbnails, Public, the soft launch).
>   - **Not verified:** a Walk resuming after a rejoin (the mock profile resets each play start; needs step 3's API access); a real reserved-server teleport; real purchases; touch; the Firestarter card through the server's one-time path for a never-payer (the creator owns both passes).
>   - **Seen, not fixed:**
>     - **Max Players vs lobby capacity:** one place serves both roles, so Roblox's Max Players caps run lobbies too. With 8 plots it must be 8, and `Tuning.lobby.capacity` 12 can never fill; a 9th seat would fail to teleport (Lobby refunds failed trips). Lower it to 8 after launch, or give runs their own place.
>     - Pine Hollow's rock cluster and scrap heap render pale, near white, at dusk (the batch 3 family conversions behind the client's permission lines). Re-upload those maps as plain images (batch 4b's next step).
>     - SHOP_CATALOG §0's renames ("Gun Parts Pack", "Heavy Loadout") and Raider Arms at 1,199 aren't applied; the live products carry the old names and 499. A rename needs the dashboard product renamed too.
>     - The Gunrunner Pack and Raider Arms say "Worn Pistol": that is the Pipe Pistol item's display name, so it's right, but the item id reads differently.
>     - 20 pine swings gave 10 timber (the hatchet's cooldown drops half of 0.6 s swings); not a defect, just slower than the step 5 rate.
>     - `Services/Energy`'s header still says the VIP cap is "200 to 240"; it's 120 to 160.
>     - AnalyticsService warns "Event field levelName is invalid" on some economy events.
>   - **How to repeat it:** step 5's recipe, plus `EO_DevClient` `("patch", { fogLocation = id })` for a Fog map card, `("action", "openShop", nil, tab)` for a shop tab, `("patch", { panel = "haven", havenId = "npc.trader", havenTab = "buy" })` for the Trader, and `("fixture", "shop", rows)` to force a row on offer. Read screens by collecting visible TextLabels under PlayerGui. Hide every ScreenGui and BillboardGui before a capture, and re-enable them before the UI gate.

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
