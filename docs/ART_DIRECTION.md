# Art Direction Bible: "Ember Outpost"

Every asset, animation, effect and UI element must pass this document. If something doesn't fit, it doesn't ship. Workers check their work against it with screenshots before showing anything.

## 1. North star

**"Cozy dread": warm firelight against cold fog.**
- Stylized **toon-PBR**: simple, slightly chunky shapes; hand-tuned colors; physically based roughness and metalness so wood, rust, cloth and glass read clearly; strong lighting and atmosphere.
- Not hyper-real, not blocky classic Roblox, not anime. It should look like a polished stylized studio game.
- Mild rating: spooky, never gory.

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
- **Building tiers must read instantly by silhouette and material:**
  - **Wood:** plank lattice and rope.
  - **Scrap metal:** patched corrugated sheets and bolts.
  - **Reinforced:** steel plate, concrete, rivets.

## 5. Lighting and atmosphere

- `Lighting.Technology = Future`, with Atmosphere and custom sky.
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
- **Icons:** one style, chunky with soft shading, a 2 px dark outline and a consistent light direction (top-left).
- **Mobile first:** tap targets at least 44 pt, thumb zones respected, HUD kept to the corners.
- **Juice:** every reward pops (scale and settle), sparkles and plays a sound. Rarity colors appear only in UI and item glows.

## 9. Performance budgets (mid-range phone first)

- Streaming enabled. A target of 60 fps on mid-range phones, never below 30.
- Prefer MeshParts with LODs. Keep instance counts low per plot and per zone. Cap dynamic lights per screen (exact numbers set in the look test).

## 10. Asset pipeline and consistency gate

1. **Look test in Studio:** a small in-engine scene from the game's fixed angled top-down camera (LDoE-style framing; see `docs/reference/ldoe-recordings/`). It covers the outpost by day and by night, a fog-zone corner, the Hollow and the HUD. Once approved, it becomes the visual reference everything is checked against.
2. **Production:** Roblox `generate_mesh` / `generate_material`, Higgsfield 3D, or curated Creator Store assets. **Strip every script from inserted models**, because free models can contain malicious code.
3. **Conform pass:** apply palette-locked MaterialVariants, fix scale and texel density, bevel edges, add LODs.
4. **Gate:** screenshot the asset in context at day and at night, and at phone resolution. Compare it with the style frames. Reject it or fix it before showing the user.
