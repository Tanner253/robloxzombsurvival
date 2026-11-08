# Look test v2: Higgsfield kit (2026-11-08)

Shots, all 16:9 except 06:
- 00 kit concept contact sheet
- 01 day overview
- 02 night overview
- 03 build tiers side by side
- 04 fog zone with the 3 Hollow at night
- 05 gameplay framing with the PC HUD
- 06 phone framing (19.5:9) with the touch HUD

## Pipeline and spend
1. **Concepts:** one master wall-kit sheet (gpt_image_2_6, 2k). Five more sheets/images used it as the reference: foundations + window, props, Hearth, runner, brute. The 2×2 sheets were cropped per piece, then uploaded to Higgsfield.
2. **3D:** Tripo H3.1 image-to-3D, textured + PBR.
3. **Into Studio:** Open Cloud Assets API upload (private Models, all passed moderation), then `InsertService:LoadAsset` into `ServerStorage.EO_Kit`.

**Credits for this batch: 141.00** (6 images × 1, plus 15 × 3D at 9 each). The cap was 150. Balance is now 1,313.13.

The survivor's backpack and scarf were made with Roblox `generate_mesh` (free). Roblox-generated grass and pebble clutter was tried and rejected (see Weak spots).

## Assets
Every texture is 3 × 2048² (base, metal-rough, normal); Roblox downsamples to 1024.

| Asset | Tris | Placed size (studs) | Roblox asset |
|---|---|---|---|
| Wall Wood | 2,785 | 12 × 8.9 × 1.9 | 73034671868204 |
| Wall Scrap | 2,685 | 12 × 8.3 × 1.6 | 130743868386555 |
| Wall Reinforced | 2,605 | 12 × 8.2 × 2.2 | 92884322486473 |
| Doorway + door (Scrap) | 2,724 | 12 × 9.2 × 2.8 | 97163536280232 |
| Window wall (Scrap) | 2,705 | 12 × 9.1 × 1.7 | 74247229223955 |
| Foundation Wood | 2,464 | 12 × 2.4 × 12 | 110134811947060 |
| Foundation Scrap | 2,592 | 12 × 2.1 × 12 | 104026449528462 |
| Foundation Reinforced | 2,521 | 12 × 2.3 × 12 | 121836992140289 |
| Hearth (gritty reroll) | 4,882 | 7.8 × 7.9 × 8.5 | 76717605925035 |
| Workbench | 4,486 | about 3.3 × 4.3 × 5.2 | 124370572669311 |
| Storage crate | 4,691 | 2.9 × 3.1 × 5.0 | 83537801984630 |
| Lamp post | 4,775 | 4.0 × 12.5 × 7.6 | 128082318656190 |
| Wrecked car | 4,655 | 7.2 × 6.7 × 15.5 | 81302134928659 |
| Hollow runner | 9,339 | 7.7 × 7.4 × 7.2 | 120510407924815 |
| Hollow brute | 9,534 | 7.6 × 11.5 × 10.7 | 136099804803908 |
| (Hollow shambler, from the test) | 9,774 | about 8 × 9.1 × 6 | 97368779063194 |

## Conform pass (done by script)
- Removed PackageLinks and tags. No asset contained scripts; the final audit found 0 scripts in `Workspace.LookTest` and `EO_Kit`.
- **Pivots:**
  - Walls: length runs along X, scaled to the 12-stud edge, pivot at the bottom centre.
  - Foundations: scaled to 12 × 12, pivot at the top centre, so walls sit on them directly.
  - Props: pivot at the bottom centre.
- **Grid fit:** all 8 building pieces fit the 12-stud grid on the first try. Walls sit on foundation edges with their posts on the tile corners.
- **Palette:** tinted with `SurfaceAppearance.Color` (cooler concrete and scrap floors, a lighter scrap tier, slightly cooled Hollow).
- **Render fidelity:** set to Automatic (LOD).
- **Hollow:** facing is auto-detected (the shambler was flipped), and each has neon cyan eyes, a small cyan light and ash wisps.

## Manual steps for the developer
1. **Lighting → Technology = Future.** The MCP can't read or write it, so the night balance was tuned blind and may need a 10-minute re-tune afterwards.
2. **CollisionFidelity** can't be set from script. Set it on the masters in `ServerStorage.EO_Kit` and on the placed copies in `Workspace.LookTest` (OutpostV2, Props, FogZone, KitLineup):

   | Setting | Assets |
   |---|---|
   | Box | WallWood, WallScrap, WallReinforced, DoorScrap, WindowScrap, FoundWood, FoundScrap, FoundReinforced, Crate, Workbench |
   | Hull | Hearth, Lamp, Car |
   | Box, or CanCollide off | HollowRunner, HollowBrute, HollowShambler (static stand-ins until they're rigged in M1) |

3. **Doorway:** the door is part of the doorway mesh. An opening door needs a separate door-leaf mesh later.

## Other changes in Studio
- **Lighting presets** (`ReplicatedStorage.LookTestLighting`):
  - Day: a higher, more neutral sun; less orange.
  - Night: dark navy rather than black, with stronger warm pools from the Hearth and lamps.
- **Camera:** default zoom raised from 38 to 46 (pitch 55°, field of view 45).
- **Ground:**
  - terrain grass patches hugging the walls and path verges
  - mud ruts along the path and toward the fog
  - v1 dead trees, debris and stakes re-materialed to dark weathered wood/stone
- **Survivor:** an R15 body with an olive jacket, a rust beanie, and a backpack with bedroll.
- **HUD:** unchanged (PC-first, with a touch toggle on F2).

## Verdict against the "polished stylized studio game" bar
- **Kit and props: yes, close up.**
  - One shared concept sheet kept every piece in one family: proportions, materials, a muted palette, rust toned down.
  - The walls tile.
  - The grounded-gritty direction reads clearly.
- **Whole scene: close, not there yet.** The weakest areas, in order:
  1. **The player character** is still a blocky default R15 with gear bolted on. It's the main tell that this is a Roblox template. It needs a survivor avatar kit (layered clothing or custom R15 meshes).
  2. **Ground clutter is thin.** Roblox-generated grass came out as yellow rings and was removed; the dressing is terrain only. A small Higgsfield dressing set (grass clumps, debris, planks, decal sheets; about 6–8 assets, roughly 60 credits) would fix it.
  3. **v1 holdovers:** the dead trees, rubble, stake barricades and broken fence still come from the earlier pass.
  4. **Floor grid at gameplay zoom:** the raised frame on each foundation reads as busy. A flatter "interior" floor variant would help.
  5. **Hollow are static** until rigging in M1.
## Against LDoE (the standard), from the top-down camera
Side by side: `07_vs_ldoe_reference.jpg`, which pairs our night shots with the developer's recordings `rec4_02` and `rec1_01`. Only the polish level is compared; we use none of their assets or designs.

| Criterion | Where we are | Why |
|---|---|---|
| Rich, weathered materials | **At or above LDoE** | Our PBR textures carry more surface detail at gameplay zoom: plank grain, rust bleed, rivets, patched sheets. LDoE's night grade flattens its materials into blue. |
| Readable silhouettes from above | **Shapes at par; value contrast below** | The wall and Hollow shapes read well: palisade tips, jagged scrap tops, hunched Hollow. But at night our floor, walls and props share one orange-brown value, so they merge. LDoE keeps cool rim light on wall tops and edges, and every object separates. Our survivor is a small blocky figure; LDoE's character reads instantly. |
| Atmospheric night with warm light pools | **Below LDoE** | LDoE's night is a strong cool-blue key over everything, with warm light only as small accents. Ours is a warm flood across the whole interior (Hearth range too large) and near-black outside, with no cold key on the walls. It reads as a lamp-lit room, not a warm pool in a cold night. |
| Dense, believable set dressing | **Well below LDoE (biggest gap)** | LDoE's base is packed: workstations, shelves, barrels, cabinets, a vehicle, planters and floor clutter in every room, with machinery and vegetation outside. Ours has a Hearth, a workbench, 3 crates and 3 lamps on large empty floors, and terrain-only dressing outside. |
| HUD | **At par** | Ours is cleaner and more consistent. LDoE's has more functional density (chat, icon bar, XP bar), which we'll add with the systems. |

**To reach LDoE's polish level:**
1. **Night re-light** (free, after Technology=Future):
   - a cold blue key and rim on the walls
   - Hearth range about 16 and lamps about 14, so the warm light becomes pools
   - a slightly lighter blue grade outside
2. **Dressing set** (about 10–12 Higgsfield assets, roughly 100 credits): shelves, a barrel group, sacks, a bedroll/cot, a tool rack, a generator, a water collector, a planter, crate stacks, grass and rock clumps, plus an interior layout pass. Without it the base reads as a demo, not a lived-in outpost.
3. **A survivor avatar kit** (M1).
4. **A flatter interior floor variant**, so the floor grid doesn't dominate the frame.

- **Modular kit: scales.**
  - Building pieces are about 2.5–2.8k tris each, so a 4×4 plot (16 floors + 16 walls) is about 85k tris.
  - With 8 plots plus props, that's fine on PC.
  - Mobile needs StreamingEnabled plus an on-device performance check.
  - Every unique piece adds 3 textures, so keep tier variants to wall/door/window/floor/doorway per tier (about 15 pieces in total).
