# Look test v4: survivor character kit (2026-11-08)

> **Status: stopped by the orchestrator.** The developer's verdict was "the avatars and player models look terrible"; gear over blocky R15 avatars doesn't clear the bar. Nothing was in flight when it stopped. Total spend on this task was **46.00 credits** (balance 1,165.13). A different route is being decided: likely a custom survivor body rigged to R15, e.g. through avatar auto-setup. Everything below is kept as a record; the gear meshes may still be reusable on a custom body.

Shots, all 16:9 under LightingStyle Realistic:
- 00 gear concept sheet
- 01 A vs B at gameplay framing by day
- 02 A vs B at gameplay framing at night
- 03 close-up
- 04 LDoE comparison

**A** is the developer's own avatar, fetched with `GetHumanoidDescriptionFromUserId`, wearing the kit. **B** is the default survivor look: a HumanoidDescription with muted body colours plus the same kit.

## Spend
**46.00 credits** against a cap of 60: 1 concept sheet (3×2, 2k, medium) at 1 credit, plus 5 Tripo H3.1 conversions at 9 each. Balance is now 1,165.13.

The sheet referenced the v2 kit and props sheets, so the gear matches the outpost art.

## Gear (rigid R15 Accessories; textures are 3 × 2048² PBR, downsampled to 1024)

| Accessory | Tris | Body attachment | Roblox asset |
|---|---|---|---|
| EO_Backpack (with bedroll and tin cup) | 2,699 | BodyBackAttachment (UpperTorso) | 139517733529889 |
| EO_Hood (ragged cowl with short cape) | 2,612 | HatAttachment (Head) | 107923907253341 |
| EO_Scarf (rust wool wrap) | 2,666 | NeckAttachment (UpperTorso) | 126890847108428 |
| EO_Belt (pouches, knife, cord) | 2,597 | WaistCenterAttachment (LowerTorso) | 74880759714480 |
| EO_ShoulderPadL / R (one mesh, mirrored by a 180° turn) | 2,647 each | Left/RightShoulderAttachment | 97521788642046 |

The full kit is about **16k triangles per character**, with both pads.

**Where things are:**
- Templates: `ServerStorage.EO_Kit.Gear` (EO_* Accessories, the Raw_* source models, and `SurvivorDefaultDescription`).
- Showcase: `Workspace.LookTest.SurvivorKit`, placed beside the kit lineup (x≈256–264) so the v3 outpost stays untouched.

**Conform pass:**
- PackageLinks removed; no scripts found.
- Each handle is CanCollide, CanQuery and CanTouch off, Massless, with render fidelity Automatic.
- Fitted by hand on the standard R15 body; each handle's attachment is solved from the fitted pose (`handle:ToObjectSpace(bodyAttachment.WorldCFrame)`), so `Humanoid:AddAccessory()` puts it in the same place on any R15 rig.
- The hood was aligned by raycasting for its opening.
- Both characters also carry the player readability light from v3.

## Manual and engineering notes
1. **Runtime equip isn't built.** I left it to the M1 code workers to avoid conflicts. On CharacterAdded:
   - for B, `Humanoid:ApplyDescription(SurvivorDefaultDescription)`
   - for both, `Humanoid:AddAccessory()` for each EO_* template
   - for A, hide or remove hair accessories while the hood is equipped
2. **Edit-mode gotcha:** accessory welds don't move parts in edit mode, because no physics runs. In Studio, a handle must be snapped with `bodyAtt.WorldCFrame * handleAtt.CFrame:Inverse()`; in play, the weld does it.
3. **CollisionFidelity:** nothing to set; every accessory has collision off.
4. **No layered clothing or custom bodies,** per scope.

## A vs B

| Criterion | A: own avatar + gear | B: default survivor + gear |
|---|---|---|
| Reads as a gritty survivor from the gameplay camera | Partly. The gear reads, but saturated avatar colours show through (here: orange hair, blue jacket, pink trousers). | **Yes.** Muted olive/charcoal body plus the gear gives one coherent hooded-survivor silhouette. |
| Palette and art-bible fit | Breaks it: avatar colours are uncontrolled. | **Fits.** |
| Clipping | Hair pokes through the hood; large bodies and Rthro proportions will clip further. | Clean on the standard R15 body. |
| Player identity | **Strong:** players keep their own face and body (Roblox players value this). | Weak: everyone looks alike apart from gear. |
| Monetization | Gear cosmetics only. | **The outfit slot itself** becomes a cosmetic (survivor outfits, skins), the LDoE-style item and progression route. |
| Remaining weakness | Uncontrolled. | The blocky default R15 body is still visible under the gear. |

**Recommendation: B as the default, with A as an opt-in setting** ("Show my avatar under my gear"), which hides hair while the hood is on.

B gives the consistent, LDoE-like read the art direction needs and opens an outfit cosmetic slot. A respects player identity for those who care, without compromising the default look.

**Next step to close the gap:** replace B's blocky body colours with a proper survivor outfit, using classic shirt/pants templates from generated worn-fabric textures (cheap) or, later, a layered-clothing jacket and trousers (an M2 candidate).

## Against LDoE (the standard)
- **Silhouette from the top-down camera:** B is near par. A hooded, geared survivor reads instantly, as LDoE's armoured player does.
- **Body under the gear:** below. LDoE's player is a fully modelled survivor; ours is gear over a blocky body.
- **A:** below, because of palette clashes.
- **Gear materials:** at or above. The backpack, pads and belt match the outpost's weathered PBR quality.
