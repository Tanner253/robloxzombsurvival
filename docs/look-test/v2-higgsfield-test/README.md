# Higgsfield 3-asset test (2026-11-08)

Pipeline: concept image (gpt_image_2_6, 0.25 cr) → Tripo H3.1 image-to-3D, textured + PBR (9 cr) → GLB →
Open Cloud Assets API upload (private Model) → `insert_asset` → conform in Studio.
The shots compare the v1 asset (left) with v2 (right) in a flat comparison area east of the outpost (`Workspace.LookTest.CompareBay`), at 16:9 with the HUD hidden.

| Asset | Tris | Textures (GLB) | Roblox asset |
|---|---|---|---|
| Hearth | 11,664 | 3 × 2048² (color, metal-rough, normal), downsampled to 1024 | 121383781734957 |
| Hollow shambler | 9,774 | 3 × 2048² | 97368779063194 |
| Scrap Metal wall | 7,204 | 3 × 2048² | 76478956585240 |

All three passed moderation on upload. None had scripts. Each arrived as a package, so the PackageLink was removed.

**Credits:** 32.75 total (27 for 3D, 5.75 for 23 concept images). Balance is now 1,454.13.

## Conform effort per asset (about 5–10 agent minutes each)
- **Orientation:** the wall needed a 90° yaw (its GLB length runs along Z), and the Hollow needed 180° (it faced away).
- **Scale and pivot:**
  - Scaled to match v1, or to the 12-stud grid edge for the wall.
  - Pivot moved to the bottom centre.
  - The wall snaps to the foundation edge, with its posts on the tile corners.
- **Palette:** `SurfaceAppearance.Color` can be set from script, so imported textures can be tinted to the palette. I used it to cool the Hearth's pale, yellow-mossed stones and to soften the wall's rust.
- **Hollow:** added neon cyan eye glow and a small cyan light under the hood.
- **Manual steps:** `CollisionFidelity` can't be set from script. Set it at import, or by hand (Box for walls, Hull for props). `Lighting.Technology` is also capability-locked to the MCP, so set it to Future by hand.

## Verdict
- **Asset quality:** a clear step up on all three. They have real sculpted forms, coherent hand-painted PBR and readable silhouettes. The Hollow and the wall are at the level of a stylized studio game.
- **Texture drift:** colours wander from the concept (moss turned yellow, stones went pale). Expect tint conform and some re-rolls.
- **Hearth:** came from an earlier, rounder concept and leans "cute". Re-roll it for the grounded-gritty direction.
- **Hollow:** the mesh is static. Gameplay needs rigging (Meshy rigging, or a custom R15-compatible rig).
- **Assets alone don't clear the bar.** The scene still needs:
  - a lighting pass (the day preset is too orange)
  - ground and set dressing
  - a styled character
  - v2 foundations: the part-built v1 deck now looks plasticky next to the v2 wall.
- **Modular wall kit: viable.**
  - Grid fit worked first time.
  - The back face is reconstructed plausibly, which matters because the game camera sees inner faces.
- **Risks to manage for a full kit:**
  - Proportions drift between separately generated pieces. Fix with one shared kit concept sheet plus scale normalisation.
  - 7.2k tris per segment is heavy for 16+ walls per plot across 6–8 plots. Generate walls at a 2–3k face limit and rely on automatic render fidelity (LOD).
