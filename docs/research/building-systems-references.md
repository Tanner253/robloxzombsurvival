# Building Systems: Design References & Unity Implementation

*Research date: 2026-11-07. Scope: how leading survival games design construction (Part A) and how to build an equivalent system in Unity for an online, raid-focused zombie survival game (Part B).*

**How to read this file**
- Facts carry a source link. Lines starting with **Inference:** are my analysis, not sourced fact.
- Live games change often. Many exact numbers (HP, raid costs, upkeep %) come from community sites that **disagree with each other**. Where they conflict, I say so. Treat every number as "check in-game before copying".
- **Research limits (stated plainly):** the shared web-search budget ran out partway through, so some topics got fewer searches than planned. Fandom wikis (Valheim, Grim Soul, Westland Survival) returned HTTP 402 and could not be read. YouTube pages could not be read beyond title and channel (through oEmbed), so **I have no view counts, descriptions, or transcripts** for any video listed. Several news pages (PlayNews, Shockbyte, GamesBeat, Epic's 2018 Fortnite post) returned 403 errors; anything from them comes from search-result summaries and is flagged.

---

## TL;DR

1. **Rust is the reference design for raid-centric building.** Its parts: twig-first placement on sockets, a hammer to upgrade through tiers (each tier roughly doubles HP), weaker "soft sides", a Tool Cupboard (TC) that creates building privilege and charges upkeep, and decay timers measured in hours once upkeep runs out. Each of these exists to make raiding **possible, priced and worth it**.
2. **Rust's socket system was formalized in 2015** (Facepunch's `building_system_2` branch). It uses typed male/female sockets, "monogamous" (single-occupancy) sockets, separate *construction* and *stability* sockets, and per-socket stability factors. This is a ready-made blueprint for our data model.
3. **Stability models fall into three families.** Rust and Valheim propagate support from the ground and lose some at each hop (Valheim: wood 100 max / 10 min, losing 1/8 per vertical hop and 1/5 per horizontal hop). 7 Days to Die uses mass and max-load voxels. Simplest of all is plain grounded-connectivity. For an MVP, use **support propagation without weight**: it is predictable, cheap and easy to explain.
4. **Many games use time-boxed raid rules.** DayZ Expansion added a raid schedule. A V Rising mod adds raid windows plus an offline-protection grace period. Conan and ARK decay structures over days. Rust has none of this and relies on upkeep plus wipes.
5. **For Unity networking, do not make every wall a NetworkObject.** Replicate *buildings* (or spatial chunks) as compact arrays. Send a snapshot when a player comes into range, then deltas. Validate everything on a dedicated server. All major Unity netcode stacks provide interest management (Mirror spatial hashing, NGO `CheckObjectVisibility`, FishNet observers, Netcode for Entities relevancy, importance scaling and a "static" optimization mode).
6. **Touch UX is the biggest unsolved part.** No mobile game I could document has published how its building UX works. Rust Mobile, by Level Infinite under licence, kept building and raiding, and its producer is reported to describe "context-sensitive interactions" (unverified). Plan to prototype and playtest building on touch early and often.

---

# Part A: How leading games design construction

## A1. Rust (Facepunch): the gold standard for raid-centric building

### Placement & sockets
- **You need a Building Plan to place pieces and a Hammer to upgrade, rotate or demolish them** (radial "pie" menu). In the 2014 devblog, new blocks start weak and regenerate health, and hitting a block with the hammer speeds that up ([Devblog 35, 21 Nov 2014](https://rust.facepunch.com/news/devblog-35)).
- **Every piece is placed as twig first and then upgraded.** You cannot place directly at a higher grade ([xgamingserver Rust guide](https://xgamingserver.com/blog/rust-base-building-guide/), search summary).
- **Socket-based snapping.** Foundations expose wall sockets on their four edges and a floor socket above. Walls cannot be placed in mid-air. A ghost preview turns green or red. Pressing R rotates a wall, which flips which face is the hard side ([rust-survival guide, updated 18 May 2026](https://rust-survival.pages.dev/01_Building)).
- **Socket architecture (primary source: Facepunch commit log, Oct–Nov 2015)** ([building_system_2 branch](https://commits.facepunch.com/r/rust_reboot/main/building_system_2)):
  - Entities link to each other through sockets, and placement on an occupied construction socket is rejected.
  - Sockets are typed male/female ("bi-gender") and can be "monogamous" (single occupant) or not.
  - **Construction sockets** (where pieces can go) are distinct from **stability sockets**, but per commit #11921 stability is carried by *both* construction and stability sockets. Stability follows only male links.
  - There is a "ramp" construction socket (used for roofs), a pillar stability socket and "dummy" sockets. The doorway/window commit only says those deployables became easier to rotate when placing; it does not describe a special socket type.
  - Per-socket **stability factors** were tuned so that existing saves stayed stable.
  - On the client, neighbour linking is load-balanced, meaning spread across frames.
- **Grace period:** for roughly 10 minutes after placing a foundation, and roughly 30 minutes for most other pieces, the owner can demolish or rotate it for free ([rust-survival](https://rust-survival.pages.dev/01_Building), community source) (unverified: the only other source checked, xgamingserver, says just "a short window" with no minutes).

### Stability
- The hammer tooltip shows stability as a percentage. In 2014 the system already allowed floors that support themselves, and it **"doesn't take weight into account"**. Facepunch said it would never be fully realistic ([Devblog 35](https://rust.facepunch.com/news/devblog-35)).
- Ground pieces sit at 100%, and stability falls the further a piece is from support. At 0% a piece collapses, either when placed or later when its support is destroyed. Raiders use this to drop floors by destroying what holds them up ([xgamingserver](https://xgamingserver.com/blog/rust-base-building-guide/)). Guides disagree on whether pillars still exist ([rust-survival](https://rust-survival.pages.dev/01_Building) vs xgamingserver).
- **Engineering lesson:** in 2016 Facepunch started **saving stability to disk**. Server restarts became much faster and runtime stability refreshes got cheaper, with a "negligible" change to the percentages ([Devblog 96, 4 Feb 2016](https://rust.facepunch.com/news/devblog-96)).

### Upgrade tiers (wall HP; community numbers, verify in-game)

| Grade | Wall HP | Upgrade material | Raid cost (per wall, community estimates) |
|---|---|---|---|
| Twig | ~10 | Wood | Melee |
| Wood | ~250 | Wood | ~1 C4 (Rustafied); calculator's cheapest is 4 satchels |
| Stone | ~500 | Stone | 2 C4 |
| Sheet Metal | ~1,000 | Metal fragments | 4 C4 |
| Armored | ~2,000 | High-quality metal | 8 C4 |

Sources: [Rustafied](https://rustafied.com/building-in-rust) (250/500/1000/2000 HP; C4 1/2/4/8), [rust-survival](https://rust-survival.pages.dev/01_Building), [xgamingserver raid calculator](https://xgamingserver.com/tools/rust/raid-calculator) (2/4/8 C4 for stone/sheet/armored, matching Rustafied). The C4 counts above are the hard-side figures on which both checked sources agree. **The secondary raid figures (satchels, rockets, soft-side counts) contradict each other and sometimes themselves**, and the xgamingserver calculator gives armored HP as 2,000 in its tables but 1,000 in its text and FAQ. The *structure* is stable across sources even though the exact numbers are not: **each tier roughly doubles HP and roughly doubles the explosives (sulfur) needed to breach it.**

- **Soft side vs hard side:** walls have a smooth hard face meant to point outward and a textured soft face meant to point inward. The soft side takes more damage, but sources disagree on how much: "2× damage from all explosives" ([rust-survival](https://rust-survival.pages.dev/01_Building)), "roughly 50% more from every explosive" in one place but "2× from explosives" in the FAQ of the same page ([xgamingserver calculator](https://xgamingserver.com/tools/rust/raid-calculator)), or "mainly melee, not explosives" ([xgamingserver guide](https://xgamingserver.com/blog/rust-base-building-guide/)). *Inference:* whatever the exact value, the purpose is the same: it **stops players from melee-farming walls from outside and punishes wrongly facing walls**.
- **Honeycombing** means wrapping the core in extra wall layers. One community estimate for a 2×2 stone base: a bare base costs raiders ~3–4k sulfur, one layer ~11–16k, two layers ~22–30k+ ([rust-survival](https://rust-survival.pages.dev/01_Building), unverified). *Inference:* this is the key Rust feeling. **Defenders turn farming time into raid cost for attackers, and both sides can read the trade.**
- **Airlocks** are two or more doors between the outside and the core, which stop "door campers" and chasers from getting in ([Rustafied](https://rustafied.com/building-in-rust)).

### Tool Cupboard (TC): privilege, upkeep, decay
- **Building privilege:** only players authorized on a TC can build, upgrade or demolish in its area. Others can still place twig floors and ladders, which deliberately leaves raiders a way in. The privilege radius **projects from the foundations connected to the TC**, not from the cupboard itself. The TC costs 1,000 wood ([Facepunch wiki: Tool Cupboard](https://wiki.facepunch.com/rust/the_tool_cupboard)). Third-party figures for the radius conflict: 16 m from each outer piece ([Rustafied](https://rustafied.com/building-in-rust)), ~17.5 m ([lone.design](https://lone.design/?p=156989), search summary) and 40 m ([rust-survival](https://rust-survival.pages.dev/01_Building)).
- **Upkeep:** the TC is paid from its own inventory every 24 hours. Walls, foundations, floors, roofs, doors and windows count; items placed inside do not. Each material only draws its own resource ([Facepunch wiki](https://wiki.facepunch.com/rust/the_tool_cupboard)). Upkeep scales with base size, from about **10% of build cost per day for small bases to 33% for very large ones**. Facepunch's own Power Trip post describes building blocks as "10% -> 33%" ([Rust news: Power Trip](https://rust.facepunch.com/news/power-trip)); [CorrosionHour](https://www.corrosionhour.com/rust-upkeep-building-guide/) rounds the top bracket to ~30%. The intermediate brackets were not confirmed in this pass.
- **2026 changes (confirmed against Facepunch's own update posts during fact-check):**
  - The "Power Trip" update (6 Aug 2026) says "High walls now have a static upkeep cost of 20%", which puts them mid-way in the 10%→33% building range ([Rust news: Power Trip](https://rust.facepunch.com/news/power-trip)). The post does not mention gates or state the previous value; the Facepunch wiki says high external walls do not add to TC upkeep ([Facepunch wiki](https://wiki.facepunch.com/rust/the_tool_cupboard)), which suggests they were previously free.
  - The "Breach and Clear" update (3 Sep 2026) added **"Upkeep Group Scaling"**. It counts players authed on the TC or on a code lock in the base (including guest code access), plus anyone de-authed from either in the last 24 hours. The first 4 players are free, players 5–10 add +2% each, later players add +4% each, and the surcharge is capped at 300% ([Rust news: Breach and Clear](https://rust.facepunch.com/news/breach-and-clear); [Shockbyte](https://shockbyte.com/blog/breach-and-clear-rust-update) was 403).
  - *Inference:* Facepunch is still using upkeep to **tax mega-clans and mega-compounds**, ten years in.
- **Decay once upkeep runs out:** twig 1 h, wood 3 h, stone 5 h, metal 8 h, armored 12 h. Decay starts at the outer layers and works inward. If a stocked TC is destroyed, it consumes up to 24 h of upkeep, which protects the base from instant decay as a griefing tactic ([Facepunch wiki](https://wiki.facepunch.com/rust/the_tool_cupboard)).
- *Inference:* the TC is also the **raid objective**. Destroy it and take authorization, and the base becomes the raider's. That one object ties building, upkeep and raiding together.

## A2. DayZ: kits, staged construction, part graphs

- **Player view:** you craft and place a Fence Kit or Watchtower Kit, then add materials in stages (planks, nails, logs; sheet metal can replace planks). A fence becomes a gate using metal wire and pliers, and gates take a 3- or 4-digit combination lock. A **flag pole** marks territory: items inside its radius do not despawn, and the flag lowers over time and must be raised again ([DayZ wiki: Base Building](https://dayz.wiki.gg/wiki/Base_Building), last edited 30 Mar 2026). Tents are insecure storage.
- **Technical model:** from the community modding wiki ([DayZ Modding Wiki: Construction System](https://stardz-team.github.io/DayZ-Modding-Wiki/es/06-engine-api/17-construction-system)):
  - **One entity holds many parts.** `BaseBuildingBase` (Fence/Watchtower) stores built parts as **three 31-bit bitmasks, up to 93 parts**. That is what gets synced and saved.
  - Each part has `required_parts[]`, `conflicted_parts[]` (for example wall vs gate), material lists and a **tool bitmask** that controls which tools can build or dismantle it.
  - Each part has its own **damage zone**. When a zone is ruined, the part and everything that depends on it are destroyed. *This is the raiding mechanic.*
  - Dismantling returns ~80% of materials, minus 20% per damage level. The "destroy part" action takes 25% of max health per cycle over four cycles. Repair costs 15% of the original materials.
- **Mods:** DayZ Expansion's BaseBuilding module has a **raid schedule**. Its 1.7.24 changelog (7 Dec 2022) reads "BaseBuilding: Added options to not use schedule for safe and container raiding" ([Steam Workshop changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/2828486817?p=6); note this Workshop item is DayZ-Expansion-Quests and is now removed from the Workshop). A 2022 pre-release article said codelocks would use 9V batteries and brute-force protection ([wobo.tools](https://wobo.tools/guides/dayz-rebuilding-and-codelocks-confirmed-for-badlands-2022/)) (unverified: page returned 403 on re-check). That was pre-release, so the final design may differ.
- *Inference:* DayZ's "part graph inside one networked entity" is a strong pattern for mobile bandwidth. A whole wall segment is one network object with a bitmask, not ten.

## A3. Valheim: structural integrity done legibly

Vanilla support values, as published by the Cornerstone mod, which mirrors the game's defaults ([Thunderstore: Cornerstone](https://thunderstore.io/c/valheim/p/VentureValheim/Cornerstone/v/1.0.0/)):

| Material | Max support | Min support | Vertical loss | Horizontal loss |
|---|---|---|---|---|
| Wood | 100 | 10 | 0.125 | 0.2 |
| Core wood | 140 | 10 | 0.1 | 0.167 |
| Stone | 1000 | 100 | 0.125 | 1.0 (no cantilever) |
| Iron | 1500 | 20 | 0.0769 | 0.0769 |

- Grounded pieces start at max support. Support weakens with every piece it passes through, and a piece falls when its support drops below the minimum. A horizontal loss of 1.0 means stone needs something directly beneath it ([Cornerstone](https://thunderstore.io/c/valheim/p/VentureValheim/Cornerstone/v/1.0.0/)). Iron Gate does not publish these numbers officially.
- *Inference (in-game, not re-verified here because Fandom was blocked):* Valheim colour-codes support on hover, from blue (grounded) through green and yellow to red. **Showing stability before you commit** is a big part of why its building feels fair.

## A4. 7 Days to Die: voxel blocks, mass/load, horde-night defense

- Each block has **mass**, **vertical support** and **horizontal support (max load)**. Anything connected down to bedrock is always stable. Overhangs fail when the total mass hanging off a face exceeds max load, and **the whole run falls together**. Example: a wood block has max load 40 and mass 5, so it holds 8 blocks and collapses at 9. A concrete block has max load 120 and mass 10. The placement preview is normal, yellow (strained) or red (will collapse) ([7DTD wiki: Structural Integrity](https://7daystodie.wiki.gg/wiki/Structural_Integrity), edited Sep 2026).
- **Upgrade chain:** frame → wood (8 wood) → cobblestone (10 rocks) → concrete (10 concrete mix) → steel (10 forged steel). A stone axe upgrades in 3 hits, a claw hammer in 2 and a nailgun in 1 ([7DTD wiki: Upgrading Blocks](https://7daystodie.wiki.gg/wiki/Upgrading_Blocks)). Community tables give HP of roughly 500 / 1,500 / 5,000 / 10,000 for wood, cobblestone, concrete and steel, but another blog disagrees ([xgamingserver 7DTD guide](https://xgamingserver.com/blog/7-days-to-die-base-building-guide/), search summary) (unverified: the wiki's Upgrading Blocks page lists no HP values).
- **Horde night:** the community consensus is to funnel the horde into a single trap-lined corridor by making one route clearly "cheaper" for the zombies ([7d2d.net AI pathing](https://wiki.7d2d.net/basics/base-defense-and-ai-pathing.html)). I found **no developer source** confirming how zombie pathfinding weighs block HP.
- *Inference:* this is the PvE answer to "nobody comes to raid you". Zombies that **actually attack the walls on a predictable schedule** give building a purpose even on quiet servers.

## A5. ARK and Conan Exiles: tier gating, decay in days, raid windows

- **ARK** has tiers Thatch → Wood → Adobe → Stone → Greenhouse → Metal → Tek. **Tool gating:** stone tools cannot damage wood, metal tools do almost nothing to stone, and **metal can only be damaged by explosives** (and some Tek weapons). Auto-decay on official servers: thatch 4 d, wood 8 d, adobe 8 d, stone 12 d, greenhouse 15 d, metal 16 d, Tek 20 d, with isolated (unconnected) foundations or pillars possibly decaying sooner. Snapping cycles through valid snap points with keys ([ARK wiki: Building](https://ark.wiki.gg/wiki/Building), edited Apr 2024; may be dated for ASA).
- **Conan Exiles** has per-tier decay settings: `StructureDecayLifetime_T1` (3 d), `T2` (10 d) and `T3` (20 d) as host defaults. A clan member walking near a piece refreshes its timer, and once a piece decays anyone can demolish it ([HostHavoc](https://hosthavoc.com/wiki/game-servers/conan-exiles/set-building-decay)). Official-server values were not confirmed. The cited Funcom forum thread (July 2018) only mentions a then-current flat 6-day decay and a player *suggestion* of 6/9/15 days by tier; it does not support a "7 d vs 10 d" figure ([Funcom forum](https://forums.funcom.com/t/decay-timer-based-on-tiers-as-well-as-size-numbers-of-structures/22887)).
- **Raid windows pattern:** V Rising has built-in raid-hour settings. The RaidForge mod adds daily raid windows and **offline protection that only starts after a grace period**, so players cannot log off to dodge an active raid ([RaidForge](https://thunderstore.io/c/v-rising/p/Darrean/RaidForge)).

## A6. Fortnite: the speed benchmark

- Player builds sit on a fixed lattice: 512 units wide and 384 units high ([UE forum post, Nov 2023](https://forums.unrealengine.com/t/builds-not-snapping-or-working-properly/1421423), community). UEFN docs treat one tile as a 512 grid snap ([Epic docs](https://dev.epicgames.com/documentation/fortnite/using-grid-snapping-in-unreal-editor-for-fortnite?lang=en-US)).
- **Turbo building** lets you hold the button to keep placing. A 2018 Epic post (403 to me; via search summary) gave 0.15 s for the first piece and 0.05 s for each piece after (unverified: the cited UE forum thread is a Dec 2024 bug report and gives no timings). Controller **edit-mode aim assist** pulls the crosshair toward the nearest edit tile (unverified: no source given or found).
- *Inference:* Fortnite proves that a **coarse fixed grid, hold-to-repeat, one-button piece selection and aim assist on snap targets** make building fast even on controllers. These are the right instincts for touch.

## A7. Mobile references

- **Rust Mobile:** Level Infinite (Tencent) is making it under licence from Facepunch. It was revealed on 1 Aug 2025 as free-to-play, keeping base building, raiding, crafting and permadeath. No monetisation details were given ([PCGamesN](https://www.pcgamesn.com/rust/mobile-revealed)). A closed beta was reported from 11 Dec 2025, and a broad launch is expected in 2026 but not confirmed ([NoPing](https://noping.com/blog/all-about-rust-mobile), unverified). The producer reportedly describes new controls built on a virtual joystick and **context-sensitive interactions** in place of keyboard and mouse ([GamesBeat](https://gamesbeat.com/?p=313066), 403 to me; search summary only) (unverified). Whether Rust Mobile has launched by Nov 2026 was not checked (unverified). **This is the competitor to watch on mobile building.**
- **Once Human:** a **Territory Core** anchors the base. Players can **move the whole territory** (PC: B for build mode, then Z to move), with a 10-minute cooldown reported in July 2024 guides (unverified: the cited VideoGamer page returned 404 on re-check, so the keys and cooldown could not be confirmed). You can **save the base, or a single building, as a blueprint/preset** and re-apply it. Players report failures such as "cannot apply territory blueprint due to potential building hovering and collision with the environment" (Steam thread, 28 Jul 2024) ([VideoGamer](https://www.videogamer.com/guides/once-human-how-to-move-territory) and [Steam discussions](https://steamcommunity.com/app/2139460/discussions/0/4514380244074171177), search summaries). I found nothing specific about its mobile build UI.
- **Last Island of Survival:** this is Rust-like. The store listing promises raiding enemy forts and says structures must be maintained against "rust" ([App Store](https://apps.apple.com/us/app/id1463021419)). I found **no** detailed write-up of its TC or building UX.
- **Grim Soul, Westland Survival:** Fandom wikis were blocked (HTTP 402), so **I could not research these**. LDoE's own building is covered in the other research files.

## A8. Grid vs socket vs free placement

| Model | Examples | Strengths | Weaknesses | Network / persistence cost | Touch fit |
|---|---|---|---|---|---|
| **Voxel / block grid** | 7DTD | Trivial validation; integer coordinates; easy stability (neighbour lookups); easy zombie pathing | Blocky look; huge piece counts; terrain becomes part of the problem | Very low per block, but huge counts | Good (tap a cell) |
| **Lattice + sockets** (grid of foundations; walls on edges; floors on tops) | Rust, Fortnite, LDoE-style | Readable bases; deterministic snaps; easy raid math; integer keys | Less creative freedom; needs triangle/half pieces for variety | Low: (building id, cell, slot, rotation) | **Best**: limited choices make auto-snap reliable |
| **Free sockets** (authored snap points on each prefab) | Valheim, ARK, Conan | Creative, organic builds | Floating-point drift; exploit surface (clipping, pixel gaps); costly overlap tests | Higher: full float transforms | Poor without heavy assist |
| **Free placement** (no snapping) | Decorations in most games | Expressive | Unraidable geometry exploits; impossible to balance | Highest | Poor |

**Inference:** for a raid-focused game, use a **lattice with sockets for structure** and **free placement only for interior deployables** (boxes, workbenches, beds), with a minimum clearance. Sockets keep bases raidable and stop raiders from being blocked by geometry exploits.

## A9. What makes building feel good, on mouse vs touch

*Mostly inference, drawn from the patterns above.*
- **Always show a ghost** in green, red or yellow (7DTD's "strained" state is worth copying), together with a **stability preview** and the **cost**, before the player commits.
- **Undo and forgiveness:** Rust's free demolish/rotate grace period removes the fear of misclicks. This matters even more on touch.
- **Bulk actions:** upgrade a whole building or wall run in one action. Once Human-style saved blueprints and relocatable bases let mobile players rebuild after a wipe or raid without hundreds of taps.
- **Mouse/keyboard:** build where you look, scroll to change piece, R to rotate, hold to repeat (Fortnite). Precision is cheap.
- **Touch:**
  - **Camera-driven placement with snapping to the nearest valid socket.** The joystick or camera aims; one large "Place" button confirms.
  - **Drag-to-paint** for wall and foundation runs.
  - An optional **top-down blueprint view** for laying out foundations.
  - A thumb-reachable radial menu, big hit targets, haptics on snap, and automatic hard-side-out orientation for walls (see the pitfalls section).
  - Never require pixel-precise taps.

---

# Part B: Implementation in Unity

*Context (well known, not re-verified in this pass): Rust, Valheim and 7 Days to Die are all Unity games, so the engine is not the limit. Architecture is.*

## B1. Data model

**Inference / recommended design.** Use a building-local lattice: each **Building** has an origin and yaw (taken from its first foundation), and every piece is stored by integer lattice coordinates rather than a world transform.

```csharp
// Static definition (ScriptableObject), shared by client and server
public enum PieceKind : byte { Foundation, Wall, Doorway, Window, Floor, Stairs, Roof, Door, Hatch }
public enum Slot : byte { Center, EdgeN, EdgeE, EdgeS, EdgeW, Top }   // lattice slot within a cell
public enum Tier : byte { Twig, Wood, Stone, Metal, Armored }

public sealed class PieceDef : ScriptableObject {
    public ushort id; public PieceKind kind; public Slot[] allowedSlots;
    public SocketRule[] requires;     // e.g., Wall requires Foundation|Floor below the edge
    public SocketRule[] provides;     // stability links it can give (male/female, Rust-style)
    public TierStats[] tiers;         // maxHp, upkeepCost, upgradeCost, damage multipliers
    public float supportLossVertical, supportLossHorizontal; // Valheim-style
}

// Runtime instance: compact, blittable, serializable
public struct PieceRec {
    public uint  pieceId;        // unique within building
    public ushort defId;
    public sbyte x, y, z;        // lattice cell relative to building origin
    public Slot  slot; public byte rot;   // rot also encodes hard-side facing
    public Tier  tier;
    public ushort hp;            // quantized
    public ushort support;       // cached stability (persisted, as in Rust Devblog 96)
    public uint  placedAtUnix;   // for grace-period demolish
    public byte  flags;          // locked, decaying, etc.
}

public sealed class Building {
    public uint id; public Vector3 origin; public float yaw;
    public uint ownerClanId; public uint tcPieceId;      // privilege + upkeep anchor
    public Dictionary<int, PieceRec> bySlotKey;          // key = pack(x,y,z,slot)
    public double upkeepPaidUntilUnix; public uint revision;
}
```

- The **slot key** is `pack(x, y, z, slot)`, which gives O(1) occupancy checks. Pieces with the same cell but a different slot are neighbours, so stability links follow mechanically from the lattice with no authored transforms. This mirrors Rust's typed and monogamous sockets ([Facepunch commits](https://commits.facepunch.com/r/rust_reboot/main/building_system_2)).
- **One Building = one connected component of foundations.** Upkeep, privilege and network replication all key off it. DayZ shows the value of one entity holding many parts ([DayZ modding wiki](https://stardz-team.github.io/DayZ-Modding-Wiki/es/06-engine-api/17-construction-system)).

## B2. Snapping & validation

**Client, every frame while building:**
1. Raycast from the camera or aim point. If it hits a building, convert the hit to building-local lattice space, collect the 4–8 nearest free slots that are valid for the selected piece, and pick the closest to the aim ray. Otherwise, for a foundation, free-place on terrain and snap yaw to camera or terrain.
2. Show the ghost with green/red/yellow, the predicted support value and the cost.

**Server, authoritative, on a `PlaceRequest{buildingId, cell, slot, rot, defId}`:**
1. Rate-limit the request, then check distance and line of sight from the player's eye to the slot. This stops building through walls.
2. Check privilege: the player is authorized on the TC, or the piece is on a "raider allowed" list such as ladders (Rust allows twig floors and ladders: [Facepunch wiki](https://wiki.facepunch.com/rust/the_tool_cupboard)).
3. Check that the slot is free and that the `requires` sockets are present.
4. Run a geometry overlap test with a slightly shrunk box against players, deployables, terrain and other buildings. Use `Physics.OverlapBox`, and `Physics.ComputePenetration` if you need depth. ComputePenetration works at arbitrary poses and does not need physics to step ([Unity docs](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physics/computepenetration)).
5. Compute stability for the new piece and reject it if support is below the minimum. Rust rejects 0% placements ([rust-survival](https://rust-survival.pages.dev/01_Building)).
6. Deduct resources, apply the change, increment `revision`, and broadcast a delta.

*Pitfall:* **share the snapping code between client and server** and make it pure C# with no MonoBehaviour dependency, so the ghost never lies.

## B3. Stability / support calculation

| Approach | Used by | Cost | Feel |
|---|---|---|---|
| Grounded connectivity only (flood fill) | Many small games | Cheapest | Binary; allows absurd overhangs |
| **Support propagation with loss per hop** | Rust, Valheim | Cheap if incremental | Predictable; good raid gameplay (knock out supports) |
| Mass / max-load per face | 7DTD | Moderate; whole runs fail | Realistic-ish; harder to explain |
| Physics or FEM | Not used by survival games for persistent bases | Expensive, nondeterministic | Avoid |

**Recommended algorithm (Inference):**
- `support(p) = grounded(p) ? max(p) : max over supporters s of (support(s) − loss(s→p))`, capped at `max(p)`, with collapse when `support < min(p)`.
- This is a **widest-path problem**, so solve it with Dijkstra using a max-heap seeded from grounded pieces.
- Store each piece's **best supporter** (a parent pointer).
- **Incremental update on removal:**
  1. Invalidate the subtree whose parent chain passes through the removed piece.
  2. Re-seed from that subtree's still-valid neighbours.
  3. Run the max-heap pass only over the invalidated set.
  4. Collapse anything that ends below its minimum. This can cascade, so process it in batches.
- **Incremental update on add:** relax outward from the new piece.
- **Budget:** process the queue with a per-tick cap, for example N pieces per tick. Collapses can play one or two ticks late, and players will not notice. Burst-compile the pass with `NativeArray` data if profiling shows hotspots.
- **Persist cached support**, as Rust did, so a server restart does not recompute every base ([Devblog 96](https://rust.facepunch.com/news/devblog-96)).
- **Ignore weight** for the MVP, as Rust did in 2014 ([Devblog 35](https://rust.facepunch.com/news/devblog-35)).

## B4. Networking & replication of thousands of pieces

- **Use a dedicated, server-authoritative architecture.** Clients only send *intents* (place, upgrade, rotate, demolish, damage via weapon fire). See the classic references: [GDC: *I Shot You First: Networking the Gameplay of Halo: Reach*](https://www.youtube.com/watch?v=h47zZrqjgLc) and [GDC: *Overwatch Gameplay Architecture and Netcode*](https://www.youtube.com/watch?v=W3aieHjyNvw). I could only confirm their titles and channels; I could not watch them.
- **Do not spawn a NetworkObject per wall.** In NGO, a hidden object is fully despawned on that client, and a visible one is spawned and sent traffic. Visibility checks run per object per client ([NGO object visibility](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.4/manual/basics/object-visibility.html)). *Inference:* at 20k pieces, per-object spawn and visibility overhead will dominate, so this does not scale.
- **Replicate per Building, or per spatial chunk, using custom messages** (NGO named or unnamed messages with `FastBufferWriter` ([docs](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.4/manual/advanced-topics/message-system/custom-messages.html))):
  - **Enter interest:** send a full snapshot (all `PieceRec`s, compressed) plus `revision`.
  - **Steady state:** send ordered deltas: `Add`, `Remove`, `TierChange`, `HpChange` and `CollapseBatch`, each tagged with `revision`. If the client sees a gap, it asks for a resync.
  - **HP traffic:** quantize HP and only send changes past a threshold, or to players within combat range. Use the ack-baseline and changed-bit ideas from [Gaffer On Games: Snapshot Compression](https://gafferongames.com/post/snapshot_compression/).
- **Interest management:** use a server-side spatial grid of buildings. The built-in options are Mirror's (Hex) Spatial Hashing ([Mirror docs](https://mirror-networking.gitbook.io/docs/manual/interest-management)), FishNet's ObserverManager with timed conditions and distance-based LOD send rates in Pro ([FishNet docs](https://fish-networking.gitbook.io/docs/manual/components/managers/observermanager)), and Netcode for Entities relevancy, **importance scaling by spatial chunk** and a **"Static" optimization mode that sends nothing while unchanged** ([N4E optimizations](https://docs.unity3d.com/Packages/com.unity.netcode@1.3/manual/optimizations.html)). Buildings are the ideal "static ghost".
- **Rough bandwidth (Inference):** a `PieceRec` packs to about 10–14 bytes. A 2,000-piece clan base is therefore roughly 20–28 KB before compression on first sight, and near zero afterwards unless it is being raided.
- **Client rendering (Inference):**
  - Build one combined mesh, or one instanced draw list, per building chunk, and rebuild it on delta.
  - Use simple LODs at range.
  - Keep **individual colliders only near the player**. The server keeps full colliders for validation and hit tests.
  - Look at GPU instancing and Unity 6's GPU Resident Drawer for mobile, but I could not fetch Unity's doc page in this pass, so verify device support yourself.

## B5. Persistence

**Recommended design (Inference):**
- **Store each building as a versioned binary blob** (header: schema version, building id, origin, owner, revision; body: a packed `PieceRec[]` plus cached support). Compress with LZ4 or zstd. Keep it in Postgres or another database, with indexed metadata columns (owner, region cell, TC location, `upkeepPaidUntil`) so queries such as "bases in this map cell" or "decaying bases" stay cheap.
- **Write-behind:** mark buildings dirty and flush every 30–60 s, plus immediately on high-value events: TC destroyed, raid breach, ownership change.
- **Keep an append-only event log** (place, upgrade, damage source, destroy, loot taken) for rollbacks, dupe investigations and raid replays or notifications.
- DayZ's approach of saving the bitmask and rebuilding visuals on load ([modding wiki](https://stardz-team.github.io/DayZ-Modding-Wiki/es/06-engine-api/17-construction-system)) and Rust's approach of saving stability ([Devblog 96](https://rust.facepunch.com/news/devblog-96)) both point the same way. **Persist the compact state and derived caches, never GameObjects.**

## B6. Raid damage model

- **Damage matrix:** `damage = base[weapon] × tierMult[weapon.damageType][tier] × sideMult(hitFace) × (1 − splashFalloff)`.
  - Damage types: Melee, Bullet, Fire, Explosive, Zombie.
  - **Tool gating:** set multipliers to zero where a weapon should not work, for example metal immune to melee and bullets, as in ARK where metal only takes explosive damage ([ARK wiki](https://ark.wiki.gg/wiki/Building)).
  - The **soft-side multiplier** should apply mainly to melee and fire, so walls cannot be chipped down from outside (see Rust's conflicting sources above).
- **Server-side hit resolution:** explosives use an overlap sphere, sort hits by distance, and apply line-of-sight occlusion so that one charge cannot damage everything through three walls. *Inference:* that occlusion rule is what makes honeycombing meaningful.
- **Doors and locks:** these are separate entities with their own HP. Locks are an authorization layer, and DayZ's code-or-break model works ([DayZ wiki](https://dayz.wiki.gg/wiki/Base_Building)).
- **Design knob:** publish a **"raid cost" for every tier**, like Rust's sulfur economy, and tune explosive crafting cost against it.

## B7. Decay & upkeep ticks

**Recommended design (Inference):**
- **Never tick individual pieces.** Per building, store `upkeepPaidUntilUnix`.
- **Upkeep:** a slow server job, for example every 5–10 minutes per building, draws `dailyCost × elapsed/24h` from the TC inventory, using Rust-style size brackets from 10% to 33% ([Rust news: Power Trip](https://rust.facepunch.com/news/power-trip); [CorrosionHour](https://www.corrosionhour.com/rust-upkeep-building-guide/) says ~30% at the top) and optionally a clan-size factor (Breach and Clear: first 4 free, +2% for players 5–10, +4% after, 300% cap).
- **Decay:** if unpaid, apply decay in batches from the outside in, at per-tier rates (Rust: twig 1 h through armored 12 h after upkeep runs out ([Facepunch wiki](https://wiki.facepunch.com/rust/the_tool_cupboard))).
- **Catch-up on load:** compute offline elapsed time on load (`now − lastProcessed`) so a server restart does not pause decay.
- **Grief protection:** if a stocked TC is destroyed, consume up to 24 h of upkeep, as Rust does.

## B8. Libraries, assets, tutorials, talks

| Resource | What it is | Notes |
|---|---|---|
| [Easy Build System (Asset Store)](https://assetstore.unity.com/packages/templates/systems/easy-build-system-v5-2-5-45394) | Commercial modular building system | v7.1.7, $29.99, 194 reviews, latest release 2 Nov 2026 (confirmed on the store page). Socket snapping; docs list Mirror, Fish-Net and PUN 2 integrations ([docs](https://polarinteractive.gitbook.io/easy-build-system)) (unverified: the docs redirect to a GitBook app page that could not be read, and the store page names no specific networking integration). Good for prototyping; *Inference:* a per-piece networking model likely needs replacing for raid-scale bases. |
| [ModularPro (Asset Store)](https://assetstore.unity.com/packages/slug/151460) | Socket snapping for **editor** level design | Not a runtime player system (search summary). |
| [Building Construction System (itch.io)](https://sometimesatnight.itch.io/building-construction-system) | Prefab sockets, radial menu, costs, refunds | Small indie pack (search summary). |
| [DanFilby/Unity_BuildingSystem](https://github.com/DanFilby/Unity_BuildingSystem) | Open-source modular building | 1 star, known snapping bugs. **Not recommended.** |
| [git-amend: *Survival Building System in Unity (Sockets + Snapping)*](https://www.youtube.com/watch?v=5x39UXN1WMw) | Video tutorial, V Rising-inspired (unverified: only title and channel confirmed) | View count not accessible. |
| [Code Monkey: *Awesome Grid Building System*](https://www.unitycodemonkey.com/video.php?v=dulosHPl82A) | Grid building tutorial (page shows "06/02/2021", which may be 2 Jun or 6 Feb 2021) | Grid model; no networking. |
| [Tamara Makes Games: *3D Grid Building System*](https://www.youtube.com/watch?v=rKp9fWvmIww) | Video tutorial | View count not accessible. |
| [NoScopeTutorials: *Snap to Grid Building Placement For Mobile Devices*](https://www.youtube.com/watch?v=GaZ8paevZdo) | Touch placement tutorial | View count not accessible. |
| Rust design videos: [CerealOverdrive: *Explaining Stability Bunkers IN DETAIL*](https://www.youtube.com/watch?v=Wojo-_BIPhc), [X3: *All Bunkers Explained*](https://www.youtube.com/watch?v=PdXgJI9wsWk), [Quick Tips: *How to Increase Stability in Rust*](https://www.youtube.com/watch?v=k7WSxaR1TSQ) | Player-side view of how stability gets exploited | Watch for exploit ideas to design against. |
| [Facepunch `building_system_2` commits](https://commits.facepunch.com/r/rust_reboot/main/building_system_2) | Primary source on Rust's socket and stability design | The most useful technical primary source found. |
| [DayZ Modding Wiki: Construction System](https://stardz-team.github.io/DayZ-Modding-Wiki/es/06-engine-api/17-construction-system) | Part-graph, damage-zone, sync and persistence internals | Directly reusable patterns. |

I found **no GDC talk specifically about survival base-building systems** in this pass.

---

## Recommended MVP building architecture

```
Client (Unity)                         Dedicated Server (Unity headless)
---------------                        ---------------------------------
BuildController (input, touch/mouse)   BuildService
  -> SnapSolver (shared pure C#) <---same code--->  SnapSolver + Validator
  -> Ghost + stability/cost preview      -> PrivilegeService (TC auth)
  -> sends PlaceRequest/Upgrade/...      -> StabilitySolver (incremental, budgeted)
                                         -> DamageService (matrix, LOS-occluded splash)
BuildingView (per Building/chunk)        -> UpkeepDecayJob (per building, lazy time math)
  <- Snapshot on interest-enter         BuildingStore (dirty flags, write-behind)
  <- Deltas (revisioned)                 -> DB: building blobs + metadata + event log
  -> combined mesh / instancing         InterestGrid (spatial cells -> observers)
```

**MVP scope (Inference):**
- **Pieces:** square foundation, wall, doorway, window, floor, stairs, roof, door, TC, storage. Leave triangles and half-walls for later.
- **Tiers:** Twig → Wood → Stone → Metal. Armored comes later.
- **Mechanics:** a free demolish grace window; a stability preview; bulk "upgrade whole building"; TC privilege, upkeep and decay; a raid damage matrix with soft and hard sides; zombie damage to walls.

**Build order:**
1. Single-player lattice and snapping.
2. Stability solver with unit tests.
3. Server authority and replication of one building.
4. Interest grid with 50+ buildings.
5. Persistence.
6. Upkeep and decay.
7. Raid damage.
8. Touch UX polish, which can start in parallel with step 1.

## Pitfalls to avoid

1. **Per-piece NetworkObjects and per-piece MonoBehaviours with Update().** These kill both server and mobile client performance.
2. **Client-trusted placement.** It lets players build through walls, inside rocks or in other bases. Validate on the server: line of sight, overlap and privilege.
3. **Float transforms as identity.** Use integer lattice keys. Floats drift, and drift creates gaps raiders can shoot or squeeze through.
4. **Recomputing stability globally**, or in the same frame as a 500-piece collapse. Make it incremental, budgeted and persisted.
5. **Geometry exploits.** Pieces clipping into terrain, rock bases and unreachable stashes. Restrict foundations to terrain-height bands and keep building away from map props.
6. **Indestructible or free-to-scale defences.** Upkeep must grow with base size and clan size, as Rust's 10–33% curve and group tax show, or mega-bases will dominate.
7. **Unclear raid economics.** If players cannot predict what a raid costs, raids feel random. Show tier HP and expected explosive counts in-game.
8. **Ignoring offline-raid policy.** Decide it deliberately: raid windows (DayZ Expansion, V Rising) vs always-on with alarms (Rust). It shapes who plays.
9. **Touch as an afterthought.** Pixel-precise sockets on a phone will fail. Design auto-snap and bulk actions from day one.

---

## Design implications for our game

1. **Use Rust's skeleton, not LDoE's.** Twig-first lattice/socket placement, hammer upgrades through 4 tiers with each tier about 2× HP, soft and hard sides, a TC as privilege, upkeep and raid objective, and decay that is measured in hours once upkeep runs out. This combination is what makes raiding a real, priced activity, and it directly fixes the "nobody raids, nobody gets raided" complaint.
2. **Bases must live in the shared persistent world, findable by other players.** Raiding cannot be a highlight if bases are instanced. Pair this with **raid alerts** (push notifications) so defenders can come online and fight. That is the Rust-like drama the developer wants.
3. **Choose an offline-raid policy early. My recommendation:** offline raiding is allowed but costs more. For example, defender walls take reduced damage after a grace period of more than 30 minutes offline, borrowing RaidForge's grace-period idea, rather than hard raid windows. (RaidForge itself gives full offline protection after a configurable logout grace period; its page does not state a length, so the 30 minutes and the "reduced damage" variant are our own proposal.) Hard windows feel artificial on mobile, where sessions are short and unpredictable. Test both models.
4. **Zombies must attack bases** (7DTD-style horde pressure) on a known cadence. This gives building a purpose between PvP raids and on low-population servers.
5. **Make raid cost a first-class, displayed economy.** Every tier shows its "explosives to breach". Craft costs for explosives are tuned against it. Honeycombing and airlocks emerge naturally from a line-of-sight-occluded explosive model.
6. **Tax size, not effort.** Upkeep grows with piece count (10%→33% per day of build cost) and with clan size. This keeps mega-clans from owning the map and is a design lever, not a monetisation lever. **Never sell upkeep skips, decay immunity or instant upgrades.** That kind of microtransaction is what drove the developer away from LDoE.
7. **Touch-first building UX is our differentiator against Rust Mobile:**
   - auto-snap to the best socket
   - drag-to-paint wall runs
   - one-tap "upgrade whole building"
   - saved blueprints and quick rebuild, as in Once Human
   - a top-down layout mode
   - a visible stability and cost preview
   - a generous free-undo window

   Prototype this before the netcode.
8. **Technically:**
   - integer lattice keys
   - shared C# snap/validate code
   - incremental support-propagation stability, persisted
   - per-building snapshot plus revisioned delta replication with spatial interest management
   - binary blobs with an event log in the database
   - lazy, timestamp-based upkeep

   Ship the MVP piece set first. Add triangles, armored tier and electricity/traps later.
9. **Avoid Valheim-style free sockets and 7DTD-style voxels for structural pieces.** Free sockets are exploit-prone and expensive on mobile. Voxels produce too many pieces and look too blocky for our art goals. Keep free placement for decorations and deployables only.

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. About 30 claims were re-checked by re-opening the cited pages, plus Facepunch's own news index and update posts. The shared web-search budget was already used up, so corroboration came from direct page fetches, not new searches.*

**Confirmed against the cited or primary source (no change needed):**
- Rust TC: costs 1,000 wood. Privilege is projected from connected foundations. Non-authorized players can place twig floors and wooden ladders. Upkeep is per 24 h. Decay after upkeep runs out is twig 1 h, wood 3 h, stone 5 h, metal 8 h, armored 12 h, from the outside in. A destroyed stocked TC eats up to 24 h of upkeep (Facepunch wiki).
- Devblog 35 is dated 21 Nov 2014 and says stability "doesn't take weight into account". Devblog 96 is dated 4 Feb 2016 and covers stability serialization, faster restarts and a "negligible" percentage change.
- `building_system_2` commits date from Oct–Nov 2015 and cover bi-gender sockets, monogamous sockets, male-only stability links, a ramp socket, a pillar socket, dummy sockets, stability factors balanced for existing saves, and load-balanced client neighbour linking.
- Rustafied gives wall HP of 250/500/1000/2000, C4 counts of 1/2/4/8 and a 16 m privilege zone. lone.design gives ~17.5 m and rust-survival gives 40 m, so the conflict is real.
- Valheim Cornerstone table, all four rows (the mod labels them vanilla defaults "as of the last update").
- 7DTD: the wood-block horizontal support of 40 (8 blocks hold, 9 collapse) and concrete's 120; the yellow/red preview; the upgrade costs 8 wood / 10 rocks / 10 concrete mix / 10 forged steel; stone axe 3 hits, claw hammer 2, nailgun 1.
- ARK tool gating, and Conan T1/T2/T3 host defaults of 3/10/20 days (HostHavoc).
- DayZ: three 31-bit sync ints for up to 93 parts; 80% dismantle return minus 20% per damage level; the 4×25% destroy action; 15% repair cost. On the DayZ wiki: gate conversion, 3- or 4-digit lock, flag-pole despawn protection, last edited 30 Mar 2026.
- Rust Mobile was revealed 1 Aug 2025 by Level Infinite, "fully licensed by Facepunch", free-to-play, keeping base building, raiding, crafting and permadeath, with no monetisation details (PCGamesN).
- Last Island of Survival listing: raiding forts and maintaining structures against "rust and decay".
- Fortnite build grid of 512 by 384 (UE forum, 26 Nov 2023), and the UEFN statement that a tile is a 512 grid snap.
- Unity/netcode: NGO visibility despawns hidden objects and is evaluated per object per client; N4E relevancy, per-chunk importance scaling and Static mode ("will not send it at all when not changing"); FishNet LOD is Pro-only; Mirror Hex Spatial Hashing; ComputePenetration works at arbitrary poses without a physics step.
- Easy Build System: v7.1.7, $29.99, 194 reviews, latest release 2 Nov 2026. DanFilby repo: 1 star, with a snapping bug noted in the README.

**Corrected:**
1. **Rust raid-cost table:** stone/sheet/armored C4 changed from "2–4 / 2–4 / 4–8" to **2 / 4 / 8**. Both checked sources (Rustafied and the xgamingserver calculator) agree on these hard-side counts; the earlier ranges overstated the disagreement.
2. **Rust soft side:** the quotes now match the sources. rust-survival says 2× from *all explosives* (it does not mention melee or fire), and the xgamingserver calculator contradicts itself (50% vs 2×).
3. **Upkeep 10%→33%:** this was sourced to CorrosionHour and PlayNews via search summary. Facepunch's Power Trip post confirms it ("10% -> 33%"). CorrosionHour actually says ~30%, not 33%.
4. **Power Trip (6 Aug 2026):** confirmed from Facepunch's post, so the "unverified" label was removed. "and gates" was removed because the post only says "High walls". "used to be free" is now marked as inferred from the Facepunch wiki rather than stated in the post.
5. **Breach and Clear (3 Sep 2026):** confirmed from Facepunch's post. The curve is not "+2% *or* +4%": it is +2% each for players 5–10 and +4% each after, with a 300% cap. "Recently removed" means de-authed in the last 24 h.
6. **Rust sockets:** stability is carried by both construction and stability sockets (commit #11921), not by stability sockets alone. The "doorway/window insert socket" claim was removed because the commit only covers easier rotation.
7. **Conan:** the "official maximums 7 d vs 10 d" claim is not supported by the cited Funcom thread, which mentions a 6-day flat timer (2018) and a player suggestion. It was replaced.
8. **ARK:** added adobe 8 d and greenhouse 15 d from the same wiki table, and softened "unconnected foundations decay sooner" to the wiki's "may have a shorter timer".
9. **DayZ Expansion:** the cited Workshop item is DayZ-Expansion-Quests (removed). The changelog line is dated 7 Dec 2022 and is quoted directly.
10. **Once Human:** the error-message wording was corrected to match the Steam thread ("hovering and collision with the environment").
11. **RaidForge (design implication 3):** clarified that RaidForge grants full protection after a configurable grace period. The 30-minute figure and the reduced-damage variant are our proposal.
12. **Code Monkey video date:** the page shows "06/02/2021", which is ambiguous, so it no longer says "2 Jun 2021".

**Marked (unverified):**
- The Rust 10/30-minute free demolish/rotate grace period (only one community source).
- 7DTD block HP values.
- Fortnite turbo-build timings and edit-mode aim assist.
- The Once Human B/Z keys and 10-minute move cooldown (VideoGamer page now 404).
- The Rust Mobile closed beta, producer quote and launch status.
- The wobo.tools codelock article (403).
- EBS networking integrations (docs unreadable).
- The git-amend video being "V Rising-inspired".

**Nothing found to be fabricated.** Every cited page that could be opened existed and broadly supported the claim attributed to it. The errors were overstatement, misquotation or weak sourcing.

**Overall reliability: medium-high.** The Rust TC/decay/upkeep core, the Valheim and 7DTD stability numbers, the DayZ part-graph internals and the Unity netcode claims are solid, and the primary sources back them. The weakest areas are mobile competitors (Rust Mobile, Once Human), Fortnite timing details, and any per-tier raid numbers beyond the hard-side C4 counts. Still verify every number in-game before copying it into tuning.

---

## Sources

**Rust**
- [Facepunch wiki: Tool Cupboard, decay and building privilege](https://wiki.facepunch.com/rust/the_tool_cupboard)
- [Rust Devblog 35 (21 Nov 2014): building, stability, hammer, TC](https://rust.facepunch.com/news/devblog-35)
- [Rust Devblog 96 (4 Feb 2016): stability serialization](https://rust.facepunch.com/news/devblog-96)
- [Facepunch commits: building_system_2 branch (2015)](https://commits.facepunch.com/r/rust_reboot/main/building_system_2)
- [Rustafied: Building, what you need to know](https://rustafied.com/building-in-rust)
- [xgamingserver: Rust Base Building Guide (Jun 2026)](https://xgamingserver.com/blog/rust-base-building-guide/)
- [xgamingserver: Rust Decay & Upkeep Guide (Jun 2026)](https://xgamingserver.com/blog/rust-decay-and-upkeep-guide/)
- [xgamingserver: Rust Raid Calculator](https://xgamingserver.com/tools/rust/raid-calculator)
- [rust-survival.pages.dev: Building (May 2026)](https://rust-survival.pages.dev/01_Building)
- [CorrosionHour: Rust Upkeep Building Guide](https://www.corrosionhour.com/rust-upkeep-building-guide/)
- [lone.design: Tool cupboard guide](https://lone.design/?p=156989)
- [Rust news: Power Trip (6 Aug 2026): high wall upkeep 20%, building blocks 10%→33%](https://rust.facepunch.com/news/power-trip)
- [Rust news: Breach and Clear (3 Sep 2026): Upkeep Group Scaling](https://rust.facepunch.com/news/breach-and-clear)
- [PlayNews: High external wall upkeep after Power Trip](https://www.playnews.gg/en/guides/rust-high-external-wall-upkeep-after-power-trip-20-per-day-what-your-compound-really-costs) (403 to me; search summary only)
- [Shockbyte: Breach and Clear Rust update](https://shockbyte.com/blog/breach-and-clear-rust-update) (403 to me; search summary only)
- [YouTube oEmbed-verified: CerealOverdrive, Stability Bunkers](https://www.youtube.com/watch?v=Wojo-_BIPhc) · [X3, All Bunkers Explained](https://www.youtube.com/watch?v=PdXgJI9wsWk) · [Quick Tips, Increase Stability](https://www.youtube.com/watch?v=k7WSxaR1TSQ)

**DayZ**
- [DayZ wiki: Base Building](https://dayz.wiki.gg/wiki/Base_Building)
- [DayZ Modding Wiki: Construction System](https://stardz-team.github.io/DayZ-Modding-Wiki/es/06-engine-api/17-construction-system)
- [DayZ Expansion Steam Workshop changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/2828486817?p=6) (search summary)
- [wobo.tools: DayZ codelocks preview (2022)](https://wobo.tools/guides/dayz-rebuilding-and-codelocks-confirmed-for-badlands-2022/)

**Valheim / 7 Days to Die / ARK / Conan / V Rising**
- [Thunderstore: Cornerstone (Valheim vanilla structural values)](https://thunderstore.io/c/valheim/p/VentureValheim/Cornerstone/v/1.0.0/)
- [7DTD wiki: Structural Integrity](https://7daystodie.wiki.gg/wiki/Structural_Integrity)
- [7DTD wiki: Upgrading Blocks](https://7daystodie.wiki.gg/wiki/Upgrading_Blocks)
- [xgamingserver: 7 Days to Die Base Building Guide](https://xgamingserver.com/blog/7-days-to-die-base-building-guide/)
- [7d2d.net: Base Defense & AI Pathing](https://wiki.7d2d.net/basics/base-defense-and-ai-pathing.html)
- [ARK wiki: Building](https://ark.wiki.gg/wiki/Building)
- [HostHavoc: Conan Exiles building decay](https://hosthavoc.com/wiki/game-servers/conan-exiles/set-building-decay)
- [Funcom forum: decay timer by tier/size](https://forums.funcom.com/t/decay-timer-based-on-tiers-as-well-as-size-numbers-of-structures/22887)
- [Thunderstore: RaidForge (V Rising raid windows / offline protection)](https://thunderstore.io/c/v-rising/p/Darrean/RaidForge)

**Fortnite / mobile**
- [Unreal Engine forum: Fortnite build grid 512/384 (Nov 2023)](https://forums.unrealengine.com/t/builds-not-snapping-or-working-properly/1421423)
- [Epic docs: Grid snapping in UEFN](https://dev.epicgames.com/documentation/fortnite/using-grid-snapping-in-unreal-editor-for-fortnite?lang=en-US)
- [Unreal Engine forum: Turbo building](https://forums.unrealengine.com/t/fortnite-br-building-turbo-building/2200242)
- [PCGamesN: Rust Mobile revealed (1 Aug 2025)](https://www.pcgamesn.com/rust/mobile-revealed)
- [NoPing: All about Rust Mobile](https://noping.com/blog/all-about-rust-mobile)
- [GamesBeat: Rust Mobile](https://gamesbeat.com/?p=313066) (403 to me; search summary only)
- [VideoGamer: Once Human, move territory](https://www.videogamer.com/guides/once-human-how-to-move-territory)
- [Steam: Once Human discussions](https://steamcommunity.com/app/2139460/discussions/0/4514380244074171177)
- [App Store: Last Island of Survival](https://apps.apple.com/us/app/id1463021419)

**Unity implementation**
- [Unity: NGO Object Visibility](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.4/manual/basics/object-visibility.html)
- [Unity: NGO Custom Messages](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@2.4/manual/advanced-topics/message-system/custom-messages.html)
- [Unity: Netcode for Entities optimizations (relevancy, importance scaling, static ghosts)](https://docs.unity3d.com/Packages/com.unity.netcode@1.3/manual/optimizations.html)
- [Unity: Physics.ComputePenetration](https://docs.unity.com/en-us/engine/current/script-reference/unityengine/physics/computepenetration)
- [Mirror: Interest Management](https://mirror-networking.gitbook.io/docs/manual/interest-management)
- [FishNet: ObserverManager](https://fish-networking.gitbook.io/docs/manual/components/managers/observermanager)
- [Gaffer On Games: Snapshot Compression](https://gafferongames.com/post/snapshot_compression/)
- [GDC: I Shot You First, Networking the Gameplay of Halo: Reach](https://www.youtube.com/watch?v=h47zZrqjgLc)
- [GDC: Overwatch Gameplay Architecture and Netcode](https://www.youtube.com/watch?v=W3aieHjyNvw)
- [Easy Build System (Asset Store)](https://assetstore.unity.com/packages/templates/systems/easy-build-system-v5-2-5-45394) · [EBS docs](https://polarinteractive.gitbook.io/easy-build-system)
- [ModularPro (Asset Store)](https://assetstore.unity.com/packages/slug/151460)
- [Building Construction System (itch.io)](https://sometimesatnight.itch.io/building-construction-system)
- [GitHub: DanFilby/Unity_BuildingSystem](https://github.com/DanFilby/Unity_BuildingSystem)
- [git-amend: Survival Building System in Unity (Sockets + Snapping)](https://www.youtube.com/watch?v=5x39UXN1WMw)
- [Code Monkey: Awesome Grid Building System](https://www.unitycodemonkey.com/video.php?v=dulosHPl82A)
- [Tamara Makes Games: 3D Grid Building System](https://www.youtube.com/watch?v=rKp9fWvmIww)
- [NoScopeTutorials: Snap to Grid Building Placement For Mobile Devices](https://www.youtube.com/watch?v=GaZ8paevZdo)
