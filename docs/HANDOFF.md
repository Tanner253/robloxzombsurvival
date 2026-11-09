# Handoff: work paused 2026-11-09

**Read this first next session.** All work stopped for usage limits. Every session and agent is stopped, and every piece of work is committed and pushed to `origin`. No local-only state is left, apart from the raw Zona extracts (regenerable; see Assets).

**Where we are:**
- About **55–60% of a shippable v0.1** LDoE-style game, against [MVP_LAUNCH.md](MVP_LAUNCH.md).
- About **15–20%** of everything LDoE has today.
- The fastest path to launch is to **merge what's built, fix the 5 flow blockers, switch Fog Runs on, wire the guns, then run one playtest**. Add no new scope before that.

## 1. Branches (all on origin)

| Branch | Head | State | Contents |
|---|---|---|---|
| `main` | (this commit) | Clean, checks green at 0e14fa4 | Everything merged so far, plus specs: [ARSENAL.md](ARSENAL.md), [SHOP_CATALOG.md](SHOP_CATALOG.md), [research/flow-mechanics-review.md](research/flow-mechanics-review.md), [research/zona-item-catalog.md](research/zona-item-catalog.md) |
| `claude/m1-launch-home-platform` | 0cd1ead | Finished commits, 12 ahead of main, **not merged** | Haven density, room-kit copy, the Reedweave and Padded sets, stake, lights, doormat, Shop Equipment and Building tabs (8 SKUs live on Roblox), Dev Armory, every pack repurchasable, chapter 3 "Hold the Line" (quests 14-25, level cap 30), **no trailing particles, Haven NPCs grounded** |
| `claude/m1-slice2b-fog-runs-9a5388` | 7360449 | 13 finished commits plus 1 **WIP** commit on top, **not merged** | The six Forest and Mine maps (L1-L3), diegetic exits (12.10), nav probe (12.9). The top WIP commit is Hollow movement and step height, unfinished |
| `worktree-agent-a0101ba2e6be467ea` | 953bd76 | On top of launch; 8 commits plus 1 WIP | Flow-review fixes in progress (F-07 home pines and others). Check each commit against its finding ID |
| `worktree-agent-a3808d71e6cf77897` | c8505e4 | WIP, based on main 7d1a427 | VIP Lounge dressing (Higgsfield props: bar, brazier, seating, stew pot), Gatekeeper card, well and soup kitchen (`Domain/Comforts`), VIP traders |
| `worktree-agent-a3c75eb84c6644ce1` | 8abdec0 | WIP, based on main 7d1a427 | Melee polish: per-class clips, poses, timing, UAL retarget tools |
| `worktree-agent-a52ab36a54b0f4f87` | 3eeccad | 1 commit plus 1 WIP | Minimap 8.11 (one smooth live radar) plus side-by-side captures |

**WIP commits are unreviewed and may not pass checks.** Review each and run the checks before merging.

**Suggested merge order:**
1. `launch-home-platform`
2. `slice2b` (resolve, then flip fogRuns per F-01 and F-02 together)
3. the flow-fix branch
4. minimap
5. Haven VIP
6. melee

Run `lune run tests`, selene, stylua, luau-lsp and `rojo build` after each merge.

## 2. What to do next, in order

1. **Merge** the branches above and get main green.
2. **Flow blockers** ([flow-mechanics-review.md](research/flow-mechanics-review.md)):
   - F-01: fogRuns ON.
   - F-02: quest 1 gather-only; the kill and loot steps move to quest 6; S2B emits `lootBody`.
   - F-03: run servers set the FogRun attribute.
   - F-04: the inbox is locked mid-run.
   - F-05: a home death drops the bag, and you respawn at 50 HP with hunger and thirst at 40.
3. **No ammo** (F-13), then the **guns** per ARSENAL: item defs, loot, the four animation classes, durability as shots (F-14 floors).
4. **Moment-of-need offers:** F-08 (death screen and Energy) and F-09 (stay on the death screen; Recover all).
5. **SHOP_CATALOG** (32 SKUs) and ARSENAL melee and armor.
6. **Launch QA:** one scripted playtest plus the UI overlap gate. Then publish (MVP_LAUNCH checklist).
7. **Only then:** item depth from the Zona catalog (armor levels, helmets, gas mask, bags, meds, grenades), as a short spec first.

The full routing of every finding to an owner is in my last briefs; the findings table in the review doc names an owner for each.

## 3. Assets

**Gun models:** asset IDs, the tier mapping and the **dead-ID list** are in [ARSENAL.md §0](ARSENAL.md).
- **Uploaded and graded A:** Duty Pistol, Hand Cannon, Pump Shotgun (tactical pump), Hunting Rifle, Machine Pistol, Patrol Carbine, Assault Rifle, Tactical SMG, Anti-Materiel Rifle (v3).
- **Not uploaded yet:** the Marksman Rifle (`sniper`) and the Compact Rifle (`9a91` without its silencer).

**Files in the repo (`art/zona/`):**
- `guns/`: the final GLBs that match the uploads (`*_v2`, `barrett_v3`, plus earlier ones).
- `melee/`: the machete.
- `renders/`: side and top review renders.
- `wip-v3/`: the **unfinished** batch, never uploaded or reviewed:
  - sniper and 9a91
  - melee: bat, knife, hatchet, pitchfork
  - an ar15 decimated toward 8k triangles
  - deagle, mp7, scorpion and m9 with brand-text paint-out in progress (`s_*` and `text*` renders)
  - Verify every file before upload.
- `tools/`: the conversion pipeline. Run `npm ci` in that folder.
  - `build_v2.mjs <gun> <out.glb>` poses FPS-rig guns on their skeletons, drops spare magazines and bakes colour maps. It is a port of Zona's `scripts/weapon-packs.mjs`.
  - `verify.mjs` checks for floating parts and missing colour maps.
  - `render.mjs` makes the side and top renders.
  - `extract.mjs` is the old strip-only extractor.

**Raw extracts** (about 1.2 GB) were not committed, to protect the LFS quota. They are regenerable from Zona with the tools.

**Uploading:** Open Cloud uploads only work from approved folders: `.claude\worktrees\...` and main's `art\higgsfield`. Copy a GLB into a worktree folder to upload it. **Never use Sketchfab Standard models** (m32, vssk, elcan): the licence bars models that can be extracted, and Roblox serves meshes to clients.

## 4. Open decisions for the developer

- **Reinforced Room Kit at 4,499** (a whole 3×3 room, Plans included): approved by me; the developer can veto it and go back to 1,699.
- **40mm grenade launcher:** Zona's `m32` is Sketchfab Standard and unusable. It needs a CC0 or CC-BY model, which the developer or the Zona agent would have to find and download.

## 5. Working rules learned this week (also in memory)

- **No Workflow tool, ever.** Work inline or with one subagent. Be token-frugal.
- **Deterministic playtests** (ARCHITECTURE §11): Studio-only DevTest mode with god mode and auto-dismissed menus; scripted checks; at most 1 retry; QA subagents capped.
- **Answer status questions with one direct number first.**
- **Merge before adding scope.** Never ship below grade A; review models from renders before upload.
- **Cross-session messages queue** until a session's turn ends. Stopping a session doesn't stop its background agents, so tell it to TaskStop them.
