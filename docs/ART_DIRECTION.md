# Art Direction Bible: "Ember Outpost"

Every asset, animation, effect and UI element must pass this document. If something doesn't fit, it doesn't ship. Workers check their work against it with screenshots before showing anything.

## 1. North star

**"Cozy dread": warm firelight against cold fog.**
- Stylized **toon-PBR**: simple, slightly chunky shapes; hand-tuned colors; physically based roughness and metalness so wood, rust, cloth and glass read clearly; strong lighting and atmosphere.
- Not hyper-real, not blocky classic Roblox, not anime. It should look like a polished stylized studio game.
- **Grounded stylized: survival grit, not cute.** Confirmed on 2026-11-07 because stylized is what the most popular Roblox games use.
  - Human proportions stay close to realistic (R15-friendly); props are a bit chunky.
  - Every surface is weathered: rust, grime, chipped paint, patched repairs.
  - Muted colors with cold blue nights, and warm firelight as the only real warmth.
  - The mood follows the developer's Last Day on Earth references, with our own designs.
- Mild rating: spooky, never gory.

**Quality benchmark:** LDoE's level of visual polish is the minimum: rich materials, readable top-down silhouettes, atmospheric night lighting, consistent props and UI. We match that polish with our own designs, never its assets or look.

**The game must be impressive** (the developer's directive). Every milestone has to land these "wow" moments, not just function:
1. **A cinematic first minute:** the crash intro with a camera move, fog rolling in and a music sting. **Lighting your first Hearth pushes the fog back visibly**, which is the signature moment.
2. **A living world:** fog that rolls, curls and retreats from light; wind, rain and dust particles; smooth day and night transitions.
3. **Game feel ("juice"):**
   - hit-stop and subtle screen shake on impacts
   - wood chips, sparks and dust when gathering
   - the Hollow **dissolve into ash and embers** when they die
   - loot pops with rarity glows
   - snap animation and a dust puff when placing a build piece
4. **Custom animation for everything.** No default Roblox animations anywhere.
5. **Destruction:** breached walls break into debris; fire and smoke on damaged structures.
6. **Audio:** layered ambience, adaptive night music as the Fog advances, Hollow you can hear by direction, and a satisfying sound on every interaction.
7. **UI polish:** tweened panels, rendered 3D item icons, reward celebrations.
8. **Performance:** smooth 60 fps on PC. Impressive and stuttering isn't impressive.

**Test for every milestone:** a 15-second clip plus a screenshot set that would make a strong Roblox thumbnail or trailer shot. If it wouldn't, it isn't done.

**LDoE side-by-side gate:** every UI screen and world shot is placed next to the matching frame in `docs/reference/ldoe-recordings/`. Each visible gap is listed and fixed before reporting: crispness, contrast, readability, density, iconography and juice. UI must render pixel-crisp:
- no content left inside CanvasGroups at rest
- no fractional scaling
- near-opaque panels over the 3D scene

## 2. Shape language

- **Friendly / safe** (survivors, outposts, the Hearth): rounded-square shapes, sturdy, slightly oversized props (chunky lanterns, fat bolts, thick planks).
- **Threat** (the Hollow, fog structures): tall, thin, hunched, uneven silhouettes. Elongated arms, slumped heads.
- **Loot and interactables:** compact silhouettes that read from 15 m on a phone, with a soft rim glow.
- **Proportions:** world props are about 10–15% chunkier than realistic. Bevel all hard edges, with no razor-thin geometry.

## 3. Color and value

| Role | Palette | Rule |
|---|---|---|
| **Light / safety** | Ember orange `#FF8A3D`, amber `#FFB547`, candle `#FFE3A3` | The only saturated warm colors in the world. Reserved for light, fire, the Hearth and legendary loot. |
| **Fog / threat** | Fog blue-gray `#6E8291`, deep night `#1E2A36`, wraith cyan `#9FE7FF` (Hollow eyes) | Cold and desaturated. Cyan glow means danger. |
| **World mid-tones** | Rust `#8A4B2A`, olive `#5E6B3A`, concrete `#8C8A84`, timber `#7A5A3A` | Muted earth tones, kept at about 60% saturation. |
| **UI and loot rarity** | Common `#D9D4C7`, uncommon `#7FBF5A`, rare `#4FA3E0`, epic `#A97BE0`, legendary = ember `#FF8A3D` | Never use these colors for world materials. |

- **Values:** players and loot are always lighter than their surroundings at night. The Hollow are mid-dark, with bright cyan eyes.
- **No pure black or pure white** anywhere in the world.

## 4. Materials

- Use one MaterialVariant library, shared by everything: wood planks, scrap sheet metal, rusted steel, concrete, cloth, glass, asphalt, dirt, moss.
- Keep **texel density** consistent across assets. Avoid photographic detail; use soft, hand-painted-looking surface detail, edge wear and grime.
- **Ground and terrain: never a single tiled material.** The developer flagged flat, repetitive ground on 2026-11-08. Every area needs all three layers of variation:
  1. **Macro:** Terrain with noise-blended material zones (mud, grass, leafy grass, rock, road), palette-locked MaterialVariants with color and value shifts, and gently rolling land outside the flat building plots.
  2. **Mid:** wear that tells a story. Paths worn between points of use, cracked roads with puddles, scorched ash near fires, dead grey grass toward the Fog.
  3. **Micro:** scatter (grass tufts, pebbles, leaves, roots, scrap, planks) plus decals (stains, cracks, tire tracks). Wind-animated grass via Terrain decoration.
  - **Gate:** at the gameplay camera, a viewer can't spot a repeating pattern by day or by night.
- **Building tiers must read instantly by silhouette and material:**
  - **Wood:** plank lattice and rope.
  - **Scrap metal:** patched corrugated sheets and bolts.
  - **Reinforced:** steel plate, concrete, rivets.

## 5. Lighting and atmosphere

- `Lighting.LightingStyle = Realistic` with `PrioritizeLightingQuality` on (this replaced `Technology = Future` in current Studio), plus Atmosphere and a custom sky. Exposure must stay stable: no jarring brightness shifts when the camera moves.
- **Day:** hazy overcast, low warm sun, light fog at the edges.
- **Night:** deep blue ambient, heavy fog. Pools of warm light are the only safety, and gameplay depends on this.
- **Post-processing:** ColorCorrection (slightly desaturated, cool shadows, warm highlights), subtle Bloom (light sources only), SunRays by day. Use depth of field only in menus.
- **Fog zones** get denser and cooler with risk tier. The density itself communicates the danger level.

## 6. Characters and animation

- **Players:** R15 avatars, which the payout uplift requires. Survival gear is added as accessories (backpack, scarf, lantern) styled to this bible.
- **The Hollow:** custom R15-compatible rigs.
  - Ash-gray skin with cold cyan eye glow and fog wisps.
  - **On death they dissolve into ash and ember sparks.** No blood or gore, which keeps the Mild rating.
  - Five archetypes, each with a distinct silhouette: shambler, runner, bloater, brute, fog wraith.
- **Survivors (NPCs):** a shared rig and costume kit, varied through color and accessories.
- **One shared animation set,** made in one style with clear anticipation, readable on a phone:
  - idle, walk, run
  - gather, chop, mine, search, carry
  - craft, build
  - melee swing, aim, shoot, reload, hit-react
  - downed, revive, emotes

  Never mix in default Roblox animations or free-model animations.
- **Gear is always visible:**
  - The selected tool or weapon is held in the hand.
  - Gathering swaps to the right tool, plays the chop, mine or pickup animation with hit VFX and sound, then swaps back.
  - Other carried weapons and tools are holstered on the back or belt.

## 7. VFX and audio

- **VFX:** one particle library. Embers, sparks, ash, fog wisps, dust, a rarity sparkle and an impact puff. Fire and embers always use the warm palette; fog and Hollow always use the cold palette.
- **Audio:**
  - one ambience bed per zone, plus crackling fire at outposts
  - distinct cues for night approaching, a Hollow nearby, and loot
  - every reward gets a satisfying sound

## 8. UI kit

- One kit used everywhere:
  - dark charcoal panels `#1C1F24` at 92% opacity
  - **8 px corner radius**
  - 2 px stroke in warm gray, with an ember accent for primary actions
  - a soft drop shadow
- **Font:** Builder Sans (ExtraBold for headers, Medium for body). Use no other fonts.
- **Icons:** painted, realistic-leaning item renders in one style, with no emoji, flat symbols or default glyphs.
  - Same 3/4 angle, light from the top-left, soft shading, a subtle dark outline and a transparent background.
  - Weathered materials that match the toon-PBR world.
  - Lock the style with 3 sample icons before generating a batch.
- **PC first, mobile supported:**
  - Design layouts for 16:9 desktop, with keybind hints on buttons and hover states.
  - Every screen also needs a touch layout: tap targets at least 44 pt, thumb zones respected, HUD in the corners, and no hover-only information.
- **Juice:** every reward pops (scale and settle), sparkles and plays a sound. Rarity colors appear only in UI and item glows.

## 9. Performance budgets (PC first, mobile must hold up)

- Streaming enabled. A target of 60 fps on PC, and never below 30 on mid-range phones.
- Prefer MeshParts with LODs. Keep instance counts low per plot and per zone. Cap dynamic lights per screen (exact numbers set in the look test).

## 10a. Consistency system (v2, 2026-11-08)

**Why it exists:** the developer said "the visual quality of things is extremely inconsistent."
- **What's fine:** the developer approved the realistic painted concept look of the slice-1 node concepts (`art/higgsfield/m1-slice1/crops/`: loose stones, fatwood stump, pine and boulder). That look is the target.
- **What's bad:** assets that **didn't come from that pipeline**, such as fallback models, `generate_mesh` results, primitive builds, and leftover look-test dressing. Examples: a round stone pit with red metal inside, and a mud-blotch object.
- **Other causes:** conversions with defects (floating fragments, blobby silhouettes), and drift when assets are generated one at a time.

**The system** (mandatory for every new or redone world asset):
1. **Style reference:** the approved concept crops listed above are the style anchor. Every new concept passes them **as image references** with the same prompt preamble: realistic painted game asset, weathered, muted palette, top-left light, neutral grey background, 3/4 view.
   - **One pipeline only:** everything in the world comes from concept → conversion → conform → lineup.
   - Fallbacks, `generate_mesh` results, primitive builds and old look-test dressing are removed from the world, not tolerated.
2. **Family sheets:** generate assets in families on one canvas, so a family shares lighting, palette and detail.
   - **Nature:** rocks, stones, stumps, dead trees, branches, bushes, reeds.
   - **Camp:** campfire, crates, Workbench, Recycler, spring, lantern post.
   - **Structure trim.**
   - Never generate a lone asset.
3. **Conversion** with fixed settings for every asset.
4. **Conform pass:**
   - **Automated floater gate** (a script in `tools/`, run on every GLB before upload and on every existing kit model): split the mesh into connected components and flag any island that's detached from the ground and from the rest of the model, or that is a flat card hovering over it. A model ships only with zero flags. Developer-found floaters so far: the fallen-branches leaf card and the boulder fragments.
   - Delete floating fragments and internal faces, and plant the base on the ground.
   - Normalize scale to the survivor.
   - **Normalize color and value:** tint each asset's SurfaceAppearance so rocks match rocks and wood matches wood across assets. Keep the baked realistic detail.
   - Set CollisionFidelity, strip scripts, and run the z-fighting check.
5. **Lineup gate in Studio:**
   - A fixed lineup scene holds each new asset next to the survivor and 3 approved exemplars (outpost kit pieces), under the same lighting.
   - It's captured at gameplay zoom and close up, by day and by night.
   - Assets are graded **A** (ships), **B** (fix) or **C** (redo). Only A ships.
   - The orchestrator approves the lineup capture before anything enters the world.
6. **Audit the whole world:** list every distinct model in `Workspace.World` with its source (pipeline or not) and grade. Anything not from the pipeline, or graded below A, gets replaced or removed.

## 10. Asset pipeline and consistency gate

1. **Look test in Studio:** a small in-engine scene from the game's fixed angled top-down camera (LDoE-style framing; see `docs/reference/ldoe-recordings/`). It covers the outpost by day and by night, a fog-zone corner, the Hollow and the HUD. Once approved, it becomes the visual reference everything is checked against.
2. **Production:** Roblox `generate_mesh` / `generate_material`, Higgsfield 3D, or curated Creator Store assets. **Strip every script from inserted models**, because free models can contain malicious code.
3. **Conform pass:** apply palette-locked MaterialVariants, fix scale and texel density, bevel edges, add LODs.
4. **Z-fighting check:**
   - No coplanar overlapping surfaces, inside a model or against its neighbours: tiles, terrain, trim and decals.
   - Detail layers sit at least 0.05 studs proud of the surface beneath.
   - Watch the asset at the closest and farthest camera zoom while the camera moves, because flicker only shows in motion.
5. **Gate:** screenshot the asset in context at day and at night, and at phone resolution. Compare it with the style frames. Reject it or fix it before showing the user.
