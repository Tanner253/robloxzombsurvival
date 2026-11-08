# Worker brief: M1 slice 1b, LDoE parity for the home experience

Written by the orchestrator on 2026-11-08. A fresh worker session in its own worktree, branched from `main` **after slice 1 merges**.

**Never ask the developer anything** (no AskUserQuestion). Questions go to the orchestrator.
- Start and stop playtests yourself (`start_stop_play`).
- Judge visuals yourself.
- The repo is the master copy of the place (world-as-code).
- Upload art only from the approved `.claude\worktrees` folder.

**Binding, in priority order:**
1. **`docs/LDOE_PARITY.md`** rulings owned by S1b. Open the frames listed in `docs/research/ldoe-parity-audit-2026-11-08.md` **before** building each screen, and match them.
2. `docs/PLAYER_EXPERIENCE_CHECKLIST.md`: §0 (the feature-feel rule, never visible below A, adversarial QA, a full capture census) and every S1b row.
3. `docs/ART_DIRECTION.md` §8 (UI kit, glyph set in `art/ui/glyphs/`, no emoji) and §10a (art consistency).
4. `docs/ARCHITECTURE.md` (definition of done).

## First: leftovers from slice 1 (do these before the parity work; the developer is waiting on them)

1. **Revert the pines** to exactly what they were before commit `3ebece2` ("Pines redone as conifers"): the developer liked the old ones. Keep the conifer GLBs unused, and don't touch trees again.
2. **Tree and wall occlusion fade:** fade only when the canopy or wall actually sits between the camera and the survivor (a raycast, not a proximity radius). Fade the canopy only, partially (about 0.5–0.6, tweened over about 0.2 s); the trunk is always solid. The tree you're targeting or chopping never fades.
3. **Night readability** (LDOE_PARITY #32): blue moonlight ambient, a survivor rim light and warm lantern pools, checked beside rec6_04.
4. **Finite home nodes** (#30): an LDoE-size set per plot, saved per outpost, **never respawning**. This supersedes slice 1's slow regrow.
5. **Q AUTO free everywhere** (#31).
6. **Gated models:** fix and grade the rock cluster (warm brown-grey, faceted, mossy, sunk into the ground), campfire, torch, spring basin and reed stubble, then ungate each one only when it grades A. Do the same for anything still gated after batch 2.
7. **Glyph swap:** if slice 1's handoff says it's incomplete, finish replacing every emoji and Unicode symbol with `art/ui/glyphs/`.
8. **Respect Roblox's own UI.** The developer's screenshot shows our top-left panel sitting under Roblox's menu, chat and emote buttons.
   - Every ScreenGui uses `ScreenInsets = CoreUISafeInsets` (or offsets by `GuiService:GetGuiInset()` and the top-bar height).
   - Nothing may overlap Roblox core buttons, chat, the leaderboard or the mobile thumbstick or jump zones.
   - Verify on PC and with the mobile emulator.
9. **The current action buttons** (Auto/Craft/Build/Bag/Use as big round emoji buttons) and the **level-ring vitals panel** are both replaced by the LDoE HUD in rulings #1–#12. Rebuild them; don't restyle them. Until the rebuild lands, they must at least use the glyphs and not overlap.
10. **Read slice 1's handoff note** (the orchestrator pastes it into your first message) for the Studio state, asset methods, `tools/` scripts and known bugs.

**Review rule (the developer, 2026-11-08):** don't redo an asset the developer hasn't flagged unless it has an objective defect (floaters, smeared texture, blobs, wrong scale or orientation, z-fighting, a stand-in, emoji). Restyling acceptable assets is over-engineering.

## Scope (LDOE_PARITY rulings)

- **HUD (#1–#12):**
  - The weapon-circle cluster, meds slot, context button and sprint.
  - The top-left reduced to name and HP, with warning icons for food and water; Energy moves to the map.
  - AUTO at bottom-left; Craft and Build under the minimap.
  - The menu bar with badges; the level bar with +xp.
  - The top-right strip, reserved.
  - Minimap icons; the top-centre target slot.
  - Floating pickup numbers.
  - Docked chat.
  - Full-screen panels that hide the HUD, with a CLOSE strip.
  - The zoom clamp hook for lobbies.
- **Inventory (#13–#17):**
  - The two-pane screen with the currency header and action bar, and the character pane.
  - Gear slots: Weapon 1, Weapon 2 and the Quick slot.
  - Stack size 20; bags +5/+10/+15.
  - The storage header with level, brush and upgrade modal; crate-lid icons.
- **Stations (#18–#23):**
  - The converter model (input → output, 20 per level, fuel slot, ALL RECIPES, upgrade arrow).
  - The station roster split (Woodworking Bench, Stonecutter, Smelter, Workbench, Campfire).
  - Gear crafted by hand only; no early repair.
  - Floor-tier gates; Installed x/y; teal ready badges.
  - Migrate saved queues.
- **Building (#25–#29):**
  - Build mode hides the HUD, with the hide-upper-walls toggle.
  - The icon tray; per-piece floating actions.
  - Ghost furniture; cost chips; plot size.
- **Survival UI and numbers (#33):** LDoE drain rates, no Energy from food, full reset on death.
- **Quests (#48–#50):**
  - Rename to **Ember Trail** everywhere.
  - Blueprints unlock through quests (only the hatchet, pick, satchel and small crate start unlocked).
  - The tracker completes quests and shows 3.
- **Onboarding (#56–#58):**
  - A damaged starter shelter on every new plot.
  - A wrecked vehicle frame with its parts-checklist screen (have/need, FILL UP slot, FINALIZE).
  - Quest 1 includes a Hollow kill and loot (behind the S2 flag until S2 lands; until then use a scripted stand-in Hollow at home, only if it grades A).
  - A crash-site quest hook.
  - Painted key art on the loading screen; the daily food and water gift until level 10.

## Done
- Every ruling above is built and verified in a playtest, with a capture placed **beside its LDoE frame**.
- The checklist audit table, the adversarial QA table, and the full object and screen grade list.
- All checks green.
- Pushed to branch `claude/m1-slice1b-ldoe-parity`, never main.
- Report to the orchestrator.
