# Look test v3: dressed outpost (2026-11-08)

Shots, all 16:9 and rendered with **LightingStyle = Realistic**:
- 00 dressing concept contact sheet
- 01 day overview
- 02 night overview (re-lit)
- 03 gameplay framing with the PC HUD at night
- 04 interior close-up
- 05 LDoE comparison sheet

## Spend
**102.00 credits** against a cap of 110: 3 concept sheets (2k, medium) at 1 credit each, plus 11 Tripo H3.1 3D conversions at 9 each. Balance is now 1,211.13.

The 3 sheets used the v2 master wall sheet and props sheet as references, so the dressing matches the kit. 2×2 crops went to image-to-3D, then Open Cloud upload (all passed moderation), then `InsertService:LoadAsset` into `ServerStorage.EO_Kit`.

## Assets (all 3 × 2048² PBR maps; Roblox downsamples to 1024)

| Asset | Tris | Size (studs) | Roblox asset |
|---|---|---|---|
| Shelf rack | 4,088 | 2.5 × 6.6 × 6.2 | 93713888714205 |
| Barrel group | 3,634 | 5.2 × 4.3 × 4.8 | 114182559575945 |
| Sacks | 4,254 | 4.5 × 3.8 × 4.6 | 93218187470141 |
| Crate stack | 4,184 | 4.2 × 5.0 × 5.5 | 131977313330697 |
| Cot + bedroll | 4,319 | 6.6 × 3.0 × 3.0 | 81833592157379 |
| Tool rack | 4,242 | 2.1 × 6.2 × 6.9 | 83259609112893 |
| Generator | 4,146 | 4.4 × 3.1 × 3.9 | 103779375675605 |
| Water collector | 4,297 | 4.1 × 6.2 × 3.9 | 97579116215528 |
| Planter | 4,292 | 3.5 × 3.4 × 6.2 | 119800167515390 |
| Grass clump | 876 | 2.1 × 1.6 × 2.8 | 76164792770074 |
| Rock clump | 936 | 2.9 × 1.5 × 3.4 | 90898809779746 |

**Conform pass:** same as v2. PackageLinks and tags removed, no scripts (the final audit found 0 in the scene or the kit library), scaled to gameplay sizes, pivot at the bottom centre, render fidelity Automatic, palette tint on the shelf, sacks and grass. The tool rack was turned 180° so its tools face the room. Clumps have CanCollide and CanQuery off and don't cast shadows (the grass).

**Flatter interior floor:** I tried it two ways, a free Roblox-generated plank material and the built-in plank material on flat overlay tiles. Both clashed with the kit (one too orange and stripy, the other flat and cheap), so I removed them and kept the v2 foundation tiles. A matching flat tile needs one Higgsfield generation (9 credits) next time.

## Scene changes
- **Interior, by zone:**
  - NW workshop: workbench, tool rack, generator, sacks
  - north and NE storage: shelf, crate stack, crates, barrels
  - east wall: a second shelf and barrels
  - SW sleeping corner: cot, crate, sacks
  - SE water and food: water collector, planter
  - the Hearth court: a crate seat and a sack
- **Exterior:**
  - a two-planter garden on the east wall
  - a water collector by the west wall
  - a generator NE
  - barrels, a crate stack and sacks at the gate
  - 143 ground clumps (87 grass, 34 rock, plus path-verge clumps) hugging the walls, along the path and into the fog edge

## Lighting: unified system, re-tuned under Realistic
- **LightingStyle:** this Studio build has no `Lighting.Technology` any more. The script found it on **Soft** and set it to **Realistic** (with `PrioritizeLightingQuality = true`); `ReplicatedStorage.LookTestLighting.apply()` now enforces this on every preset switch.
- **Day:** the same neutral overcast sun. Lamps and fire are dimmed to 22% by day so the Hearth doesn't throw a warm cone at noon. Realistic adds crisp sun shadows and much better form.
- **Night re-light:**
  - a cool moon key (ColorShift_Top 120/160/235)
  - navy outdoor fill, so the exterior and unlit dressing stay readable
  - Hearth range cut from 28 to 16 and lamps from 22 to 14, so warm light reads as pools
  - more saturated orange for the fire and lantern colours, so the cool grade no longer turns them pink
- **Player readability light:** the survivor got a soft, cool fill light 4.5 studs above the head (no shadows), so the player stays lighter than their surroundings at night (art bible §3). The camera LocalScript adds the same light to the real player character at runtime.

## Manual steps for the developer
1. **None for lighting any more.** LightingStyle and PrioritizeLightingQuality are scriptable and set by the preset module.
2. **CollisionFidelity** isn't scriptable. Set it on the masters in `ServerStorage.EO_Kit` and on the placed copies under `Workspace.LookTest`:

   | Setting | Assets |
   |---|---|
   | Box | WallWood, WallScrap, WallReinforced, DoorScrap, WindowScrap, FoundWood, FoundScrap, FoundReinforced, Crate, Workbench, Shelf, CrateStack, Cot, ToolRack, Planter |
   | Hull | Hearth, Lamp, Car, Barrels, Generator, WaterCollector, Sacks |
   | None (CanCollide is already off) | GrassClump, RockClump |
   | Box, or CanCollide off | HollowRunner, HollowBrute, HollowShambler (static until M1) |

3. **Doorway:** an opening door needs a separate door-leaf mesh later.

## Verdict against LDoE (the standard), top-down camera

| Criterion | v2 | v3 now | Notes |
|---|---|---|---|
| Rich, weathered materials | At or above | **At or above** | Every dressing piece shares the kit's grain, rust and grime. Realistic lighting brings out form and texture detail. |
| Dense, believable set dressing | Well below | **Near par along the walls; below per area** | The walls carry LDoE-style clutter, and outside reads lived-in. LDoE still packs more per square metre: inner partition walls, small rooms, vehicles and big machinery. Ours is one large room with an open Hearth court. |
| Readable silhouettes from above | Shapes at par; value contrast below | **At par** | Cool moon fill separates walls and props, unlit dressing stays legible, and the player has a readability light. |
| Atmospheric night, warm pools | Below | **At par in mood; slightly darker than LDoE** | Navy night with discrete orange pools at the Hearth and lamps: the "warm light is safety" read. LDoE is brighter and bluer overall. Ours is moodier, and I'd keep it a touch darker for the cozy-dread theme. |
| Player character | Below | **Below** | A blocky R15 with gear; needs a survivor avatar kit (M1). |

**Overall:** by day and by night, the scene now reads at or near LDoE's level of finish. The remaining gaps are density per area (one big room, no partitions or vehicles) and the player character.

**Next, cheapest first:**
1. Inner partition walls or a second small room, built from the existing kit at no cost.
2. A flat interior floor tile (9 credits).
3. A survivor avatar kit (M1).
