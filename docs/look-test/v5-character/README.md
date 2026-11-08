# Look test v5: custom survivor character (2026-11-08)

The game now owns the player character: one custom-modelled survivor, rigged to standard R15 with Studio's Avatar Auto Setup and installed as `StarterPlayer.StarterCharacter`. It is playtested with the default R15 idle, walk and run.

Shots, all 16:9 under LightingStyle Realistic, taken from a live playtest unless noted:
- 00 the two concept passes (gpt_image_2_6, A-pose front)
- 01 gameplay framing by day, with the PC HUD
- 02 gameplay framing at night, with the PC HUD
- 03 close-up, idle
- 04 movement check: idle, walk (12 studs/s), run (24 studs/s)
- 05 colour variant ("Dusk", left) beside the default (right)
- 06 LDoE comparison
- 07 before/after: the v4 blocky R15 with gear vs v5

## Spend
**11.00 credits** against a cap of 80:
- 2 concept images (2k, medium) at 1 credit each
- 1 Tripo H3.1 image-to-3D conversion (texture + PBR) at 9

The rig, backpack, arm fix and colour variant cost nothing. The Higgsfield balance is **1,154.13**. The M1 art pool has **289 of 300** left.

## Pipeline
1. **Concept:** one grounded-stylized survivor in A-pose: weathered field jacket with patched elbows, rust scarf, chest harness, belt pouches, cargo trousers, chunky boots and fingerless gloves.
2. **Mesh:** Tripo H3.1 → GLB, **14,474 tris**, 3 × 2048² PBR maps (Roblox downsamples to 1024). Uploaded with Open Cloud as asset **120283111201969** (passed moderation), loaded with `InsertService:LoadAsset`, scaled to 5.6 studs tall.
3. **Rigging route:** the `auto_setup_avatar` MCP tool (Studio Avatar Auto Setup), set to `Development` with `align_front_angle`.
   - **Output:** R15 Humanoid with 15 MeshParts + HumanoidRootPart, HipHeight 2.63, 30 rig attachments (including RightGripAttachment for tools) and 15 WrapTargets.
   - **Joints:** 15 `AnimationConstraint`s + 14 `BallSocketConstraint`s; **there are no Motor6Ds**.
   - **Animation:** its own `AnimateScript`, the default R15 set.
4. **Backpack:** the concept had a harness but no pack, so I reused the v4 `EO_Backpack` accessory on BodyBackAttachment. It fits flush against the jacket.

## Where things are
| Object | Location |
|---|---|
| Player character | `StarterPlayer.StarterCharacter`. The copied `StarterCharacterScripts.Animate` was removed, so the rig's own AnimateScript drives animation. |
| Library copies | `ServerStorage.EO_Kit.SurvivorRig` and `EO_Kit.SurvivorRig_Dusk` (the variant) |
| Untouched auto-setup output | `ServerStorage.EO_SurvivorRig_display` |
| Static source mesh, turned to face −Z | `ServerStorage.EO_SurvivorStatic` |
| Edit-mode stand-in | `Workspace.LookTest.SurvivorV5` at the old stand-in spot (10, 1.8, 15). It is anchored, has no scripts, its rest pose is baked, and it carries the readability light. |
| v3 blocky stand-in | `ServerStorage.Survivor_v3_standin` (moved out of the outpost; nothing else in the v3 outpost changed) |

## Problems hit, and fixes
1. **The character moonwalked (fixed).** The Tripo mesh imported facing −X, and Auto Setup guessed the front wrong: the face pointed backwards against the direction of travel.
   - **Fix:** turned the static mesh to face −Z, then re-ran Auto Setup with `align_front_angle = true`. Front attachments are now at −Z and the face leads the motion.
   - **Lesson:** always check the facing before auto-setup.
2. **The A-pose rest left the arms out (fixed).** Default R15 animations expect arms down; our rest pose has them 42° out, so the idle stood like a gunslinger.
   - **Fix:** rotated the arm-side shoulder rig attachments 33° down (attribute `EO_ArmDropDeg`). The animation swing axis stays correct, and the arms now hang naturally (03, 04).
3. **No skinning: rigid segments (open).** Auto Setup cut the mesh into 15 rigid parts with no bones or skin weights.
   - At gameplay zoom the seams don't show.
   - In close-up, elbows and knees bend as hard hinges, and the jacket, scarf and pack never deform or move secondarily.
   - There is slight texture stretch under the chin at the neck cut.
4. **Back detail (minor).** Tripo invents the back from a front image, so the jacket back is plainer. The backpack covers most of it.
5. **Hands (minor).** Fingers are modelled flat and splayed with no grip pose. Holding tools will need a hand-grip animation pose.
6. **Tool flakiness.** Auto Setup timed out once with no output; the second call succeeded in about 4 minutes.

## Engineering notes for the M1 code workers
- **StarterCharacter overrides player avatars.** `ApplyDescription` and the developer-avatar route from v4 no longer apply. `Humanoid:AddAccessory` still works, because all standard attachments exist.
- **The joints are AnimationConstraints, not Motor6D.** Anything that looks for Motor6Ds will find none: ragdoll, death effects, custom IK, first-person arms. Standard `Animator` playback and `Tool` grips work.
- **Animations:** replace the AnimateScript's default IDs with custom survivor animations later (idle, sprint, gather, chop, attack).
- **Stand-in in play:** `LookTest.SurvivorV5` also shows during play next to the spawn, as the v3 stand-in did. Delete it once real gameplay runs.
- **Variants** are a runtime-cheap outfit slot: set `SurfaceAppearance.Color` on the cloth parts, or clone `SurvivorRig_Dusk` as the character.

## Verdict against LDoE (the standard)

| Criterion | v4 (stopped) | v5 now | Notes |
|---|---|---|---|
| Reads as a gritty survivor from the gameplay camera | Gear over a blocky body | **At par** | A modelled human survivor with jacket, scarf, pack and boots; at night the readability light keeps it legible (02, 06). |
| Model and texture quality, close up | Below | **At or above** | Weathered PBR wear, patches and buckles, in the same material family as the outpost kit (03, 07). |
| Deformation | n/a | **Below** | Rigid segments, no skin weights, no cloth secondary motion. |
| Animation | Default R15 | **Below** | Default Roblox idle, walk and run. It's serviceable, but generic next to LDoE's character-specific set. |
| Identity and monetization | Avatar-based | **Outfit slot ready** | Tint variants cost nothing; new outfits cost about 9–11 credits each plus an auto-setup run. |

**Honest verdict:** auto-rigging reaches the bar **at the gameplay camera**, which is how players see the character almost all of the time. It does **not** reach LDoE's bar in close-up motion. The gap is skinning and animation, not the model or texture.

**Recommendation:**
- Ship M1 with this character.
- Before trailers or close-up marketing, hire an artist for a **skinned single-mesh version** of this same model (weights painted in Blender, R15-compatible, 1–2 days of rigging) plus a **custom animation set** (idle, run, gather, melee).
- That is a polish pass on an approved design, not a redo.
