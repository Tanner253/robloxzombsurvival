# Technical feasibility: a Unity online survival game with persistent bases and real-time raiding

*Research snapshot: 2026-11-07. Live services and Unity packages change fast, and several big changes landed in the last 8 months, so re-check anything marked "verify" before committing.*

**How to read this file:** Every sourced fact links to where it came from (see **Sources**). Lines marked **Inference:** are my own analysis, not something a source said. Vendor blogs (Gameye, Edgegap, Crux/Supercraft, AccelByte) sell competing products, so their claims about rivals are flagged.

---

## TL;DR

- **It's feasible in Unity, and there's proof.** Rust is a Unity game with persistent, raidable bases. Back in January 2015, after a physics-trigger fix, Facepunch reported a steady **60 fps with 200 players and 150,000+ entities** on one server ([Devblog 42](https://rust.facepunch.com/news/devblog-42)). The hard part isn't the engine. It's (a) how building pieces get replicated, (b) the entity budget, decay and wipes, and (c) persistence and anti-dupe discipline.
- **Unity's own netcode changed a lot in 2026.**
  - NGO 3.0 (2026-09-14) made Netcode for Entities a hard dependency.
  - On 2026-11-05 Unity released **GhostObjects**, which bring prediction to GameObjects. It needs Unity 6000.7+ and Netcode 7.2 + NGO 3.2.
  - Unity calls it a "full release" but also a "first iteration," so it's powerful and still in flux.
- **Two big hosting changes happened in 2026.**
  - **Unity Multiplay** ended as a Unity service on **2026-03-31**. Unity licensed it to Rocket Science Group, whose onboarding is sales-led with no published pricing.
  - **Hathora shut down on 2026-05-05** after its AI pivot.
  - **Lesson:** never couple the game server to one host's proprietary SDK.
- **Cheaper bandwidth changes the math.** AWS GameLift Servers stopped charging for bandwidth on gen-6+ instances (2026-06-15). Hetzner bare metal has unlimited traffic, and Gameye advertises zero egress. Egress charges used to be a big hidden cost in survival games.
- **Recommended MVP stack (opinionated):**
  - Unity 6.3 LTS with **Fish-Networking Pro**, server-authoritative dedicated Linux servers.
  - Custom **chunked building replication**, with Postgres as the source of truth.
  - **Nakama** (Apache-2.0) for accounts, economy and IAP.
  - Persistent shards on **Hetzner bare metal**, or **Edgegap Private Fleets** for global reach.
  - Re-evaluate Unity Netcode/GhostObjects at a mid-2027 gate. Details and alternatives are in the last sections.

---

## 1. What this game asks of the tech

**Inference:** These are the requirements that drive every choice below.

| Requirement | Why it's hard | Implication |
|---|---|---|
| Persistent world shards that run 24/7 | Bases have to exist and be raidable when the owner is offline (the Rust model the developer wants) | Long-running server processes. That rules out "match" hosting with session caps, such as Edgegap Edge Cloud's 24 h limit. |
| Thousands to tens of thousands of building pieces per shard | Replicating each piece as a ticking networked object wastes bandwidth and CPU | Event-driven or static replication of pieces, plus interest management |
| Fast PvP combat during raids | Hit registration on mobile networks with 80-200 ms RTT | Server-authoritative play with client prediction and **lag compensation** (server rewind) |
| Real-money economy, loot theft | Dupes and client hacks destroy trust | Every item move is a server-side transaction with unique item IDs. Never trust the client. |
| Mobile + PC cross-play | Different input, performance and attack surfaces | Server-defined visibility, input-aware balance, platform attestation |
| Small team | Limited ops capacity | Few moving parts, portable containers, no exotic vendor lock-in |

---

## 2. How comparable games are built

| Game | Engine / networking (public info) | Notes |
|---|---|---|
| **Rust** (Facepunch) | Unity, C#. Networking used **RakNet** through a custom C# wrapper, and client and server share one codebase via `SERVER`/`CLIENT` defines ([Garry Newman, 2016](https://garry.net/posts/rusts-networking)). A uMod forum post says Rust later moved off RakNet. That's **unverified**. | Servers degraded at around 50k entities until the 2015 physics-trigger fix ([Devblog 42](https://rust.facepunch.com/news/devblog-42)). Official hosting guidance asks for **12 GB RAM minimum** and says CPU needs to be faster as player counts rise ([Facepunch wiki](https://wiki.facepunch.com/rust/Creating-a-server)). Community admins treat entity count and decay as the main lever against lag over a wipe. One 2018 community post put ~175-200k entities as the point where things "go weird" ([Rustoria thread](https://steamcommunity.com/groups/rustoria/discussions/0/1620600279666568817)). That's anecdotal. |
| **Rust+ companion app** | iOS, Android and web | Smart Alarms push notifications to your phone, there's team chat, and you can see the map remotely ([Rust+](https://rust.facepunch.com/companion)). It's a proven way to pull defenders online during a raid. |
| **Last Island of Survival** (HK Hero Entertainment) | **Not publicly documented.** I found no engine, networking or backend disclosures, only store listings ([App Store](https://apps.apple.com/us/app/id1463021419)). | Gap: needs an APK/IPA inspection or developer interviews. |
| **Last Day on Earth** (Kefir!) | Not researched technically here. | **Inference (from gameplay, not verified):** raids target stored base snapshots asynchronously, so no live defender is present. That's cheap to host but explains why raiding feels hollow. |
| **Megacity Metro** (Unity sample) | Netcode for Entities, server-authoritative | A **100+ player** cross-platform demo running on **mobile**, Switch and desktop ([Unity](https://unity.com/demos/megacity-competitive-action-sample)). It's evidence that NFE scales on mobile clients. |

---

## 3. Networking stacks compared (status Nov 2026)

### 3.1 Unity's own netcode, which got a major 2026 shake-up

- **NGO 1.x is dead on new editors.** Unity 6000.3 LTS and later support only NGO 2.x. Unity announced this on 2025-08-06 ([Unity Discussions](https://discussions.unity.com/t/netcode-for-gameobjects-1-x-deprecation-in-6000-3-editor/1674997)).
- **Netcode for Entities moved around.**
  - NFE became a core editor package in Unity 6.5 ([NFE 6.6 docs](https://docs.unity3d.com/Packages/com.unity.netcode@6.6/manual/index.html)).
  - On 2026-09-11 Unity announced **Netcode 7.0.0 as an independent package again** for Unity 6000.7.0b1+.
  - Unity 6.5 and 6.6 are "approaching the end of support," so no major changes or backports are planned for them.
  - Unity 6.3 stays on NFE 1.x ([Unity Discussions](https://discussions.unity.com/t/netcode-for-entities-7-0-0-moving-back-to-an-independent-package-in-unity-6-7/1736319)).
- **NGO 3.x is built on Netcode for Entities.**
  - 3.0.0 (2026-09-14) makes `com.unity.netcode` a hard dependency, which pulls in Entities, Burst and Collections.
  - 3.2.0 (2026-11-03) supports hybrid sessions with Unity Netcode, per the GhostObjects announcement. The changelog itself only lists hybrid-mode changes and fixes under 3.2.0, not a separate "Added" entry ([NGO changelog](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/changelog/CHANGELOG.html)).
  - The upgrade guide requires **Unity 6000.7+** and calls 3.x the "foundations" of a unified GameObject layer ([upgrade guide](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/upgrade-guide.html)).
- **GhostObjects released 2026-11-05.** They give GameObjects prediction (`PredictionUpdate()`), GhostFields with rollback, quantization, delta compression, Burst serialization and physics prediction.
  - Not yet available: pooling, CharacterController/collider prediction, relevancy APIs, error smoothing.
  - For Unity 7, Unity will move both codebases into one package and says: "This is NOT a deprecation of any one feature set" ([Unity Discussions](https://discussions.unity.com/t/prediction-in-gameobject-netcode-ghostobjects-released/1741239)).
  - The dev log listed NFE features that would come to GameObjects: prediction, relevancy, delta compression, quantization and **server rewind** ([dev log 1](https://discussions.unity.com/t/prediction-with-gameobjects-coming-to-netcode-for-entities/1698666)). As of May 2026 the APIs were "not recommended for production" ([dev log 4](https://discussions.unity.com/t/prediction-in-gameobject-netcode-devlog-entry-4/1719927)).

**Inference:** Unity's long-term stack is now "Unity Netcode (entities-backed) + GameObject facade." It's the strongest first-party feature set for exactly our problem: relevancy, importance scaling, delta-compressed static ghosts, rewind. But the GameObject layer is days old, needs a non-LTS editor (verify whether 6.7 becomes an LTS), and Unity 7 will repackage it again. That's a lot of churn to absorb in the next 12 months.

### 3.2 Comparison table

| Stack | Authority model | Prediction / lag comp | Interest management | Scale evidence | Cost / license | Maturity (Nov 2026) | Fit for persistent raiding |
|---|---|---|---|---|---|---|---|
| **Unity Netcode 7.x + NGO 3.x (GhostObjects)** | Server-authoritative; NGO also offers Distributed Authority | Prediction yes (new); server rewind exists in NFE | Relevancy and importance scaling in NFE ([changelog](https://docs.unity3d.com/Packages/com.unity.netcode@6.6/changelog/CHANGELOG.html)) | Megacity Metro 100+ players, mobile | Free (Unity license) | Core is solid; GO layer is a first iteration | **High potential, high churn** |
| **NGO 2.x (Unity 6.3 LTS)** | Server-auth or Distributed Authority | "Client anticipation" only; no built-in rewind (per [docs TOC](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/TableOfContents.html)) | Object visibility (manual) | No large-world evidence found | Free | Stable, but superseded by 3.x | Medium-low |
| **Fish-Networking** | Server-auth, client-auth optional | **Free** client-side prediction; **lag compensation is Pro** ([features](https://fish-networking.gitbook.io/docs/overview/readme/features)) | Observer conditions (scene/distance/custom); Network LOD is Pro | Marketed for MMO, BR and mobile; FishNet's own 2023 bandwidth benchmarks | Free core. Pro: $10 + $2/mo updates, or $60 lifetime ([Pro](https://fish-networking.gitbook.io/docs/overview/readme/pro-projects-and-support)) | Active (2.1k stars, 2026 commits) ([GitHub](https://github.com/FirstGearGames/FishNet)) | **High, available today** |
| **Mirror** | Server-auth | Lag comp **beta**; prediction "researching" ([GitHub](https://github.com/MirrorNetworking/Mirror)) | Spatial hashing and distance (stable) | Many shipped titles: Zooba, SCP: SL, Population: ONE, Laurum Online; Empires Mobile ~5k CCU, Another Dungeon 5k peak CCU (self-reported) | MIT, free | Very mature, largest community | Medium-high (you'd build your own prediction) |
| **PurrNet** (newer) | Server-auth or "Everyone" via Network Rules | Prediction module "PurrDiction" (rollback prediction); a "ColliderRollback" component is listed, but lag comp behavior isn't documented there (unverified) | Not confirmed | Self-published benchmark: ~49% less transform bandwidth than FishNet and ~61% less than Mirror ([benchmarks](https://purrnet.dev/docs/readme/performance/network-transform-benchmarks)) | MIT, "no CCU tax and no revenue share"; optional paid memberships and studio plans (from $500/mo) ([GitHub](https://github.com/PurrNet/PurrNet)) | Young (707 stars), few named shipped games | Medium (promising, less proven) |
| **Photon Fusion 2** | Dedicated Server, Client Host, or Shared | Prediction and lag comp, but lag comp is **Server/Host only**. Shared-mode hit detection is "vulnerable to cheating" because each client decides what it hit ([lag comp docs](https://doc.photonengine.com/fusion/current/manual/advanced/lag-compensation)) | AOI regions, Global, Explicit; Send Priority in 2.1 ([docs](https://doc.photonengine.com/fusion/current/manual/interest-management)) | "Very high player counts" (no hard number on the intro page) | Per-CCU: free 100; $125/500, $250/1k, $500/2k per month; Premium $0.50/CCU, $1k minimum ([pricing](https://www.photonengine.com/fusion/pricing)). **Plus** your own server fleet in Server mode. | Mature, polished | Medium: excellent netcode, but CCU fees stack on top of hosting, and it's room-centric |
| **Photon Quantum 3** | Deterministic input-sync; every client simulates the full state | Rollback built in | Prediction culling | "Up to 128 players" ([intro](https://doc.photonengine.com/quantum/current/getting-started/quantum-intro)) | Same CCU model | Mature | **Poor**: every client holds all state, so hidden loot and large persistent worlds don't fit |
| **coherence 2.0** | Configurable authority, simulators | Not verified | Not verified | Not verified | Free under $200K annual revenue or funding; Pro $1k/mo; **3% revenue share** on client and self-hosting after $15K/quarter ([blog](https://coherence.io/blog/news/introducing-coherence-2-0)) | 2.0 since 2025-11-18 | Medium-low (the revenue share and scale are unproven for us) |
| **SpacetimeDB 2.x** (newcomer paradigm) | Server logic runs as a DB module; clients subscribe to tables | Not a physics/rewind netcode | Subscription queries | BitCraft's whole backend runs on it (vendor claim) ([GitHub](https://github.com/clockworklabs/SpacetimeDB)) | BSL 1.1 converting to AGPL with linking exception. Maincloud Free 2,500 TeV/mo, Pro $25/mo ([pricing](https://spacetimedb.com/blog/all-new-spacetimedb-pricing)) | Young but real | Interesting for persistence and economy; **not** for twitch raid combat |

**Inference: Distributed Authority / Shared mode.** In NGO Distributed Authority and Fusion Shared mode, clients own objects. That's fine for co-op. It's wrong for a game whose highlight is stealing other players' stuff: raiders and defenders must never be the authority over damage, loot or doors. Use dedicated, server-authoritative servers only.

---

## 4. Networking thousands of building pieces (the core technical risk)

**Inference (design pattern), backed by Rust's history and the AOI features above:**

1. **Don't give every wall a ticking NetworkObject.** Represent each base as one **BaseChunk** networked object that owns a compact array of pieces: type (u16), packed grid position, rotation (u8), tier (u8), HP (u16), at roughly 8 bytes per piece.
   - A 1,500-piece base is about 12 KB raw, less compressed, sent **once** when the base enters a player's area of interest.
   - After that, only **reliable delta events** go out: placed, upgraded, damaged (batched per tick), destroyed.
2. **Only interactive pieces are full networked entities:** doors, storage, turrets, workbenches, traps. Static-ghost or "send only on change" modes map directly onto this:
   - NFE static optimization and importance scaling
   - Fusion Send Priority
   - FishNet Network LOD
3. **Use two interest radii.** A large, low-frequency radius for structures (you can see a base from far away) and a small, high-frequency radius for players and projectiles. The server decides both, so PC players can't see further than mobile players.
4. **Server-side structural integrity is computed incrementally,** only around damaged pieces. Rust reworked its stability system for performance ([Devblog 42](https://rust.facepunch.com/news/devblog-42)).
5. **Client rendering:** combine or instance piece meshes per chunk. Mobile GPUs choke on thousands of separate renderers long before the network does.
6. **Set a hard entity budget** per base (piece cap) and per shard. Enforce it with upkeep and decay. Rust admins treat decay as the main way to keep servers healthy ([GameServerKings](https://www.gameserverkings.com/knowledge-base/rust/server-performance/), vendor).
   - **Inference:** for mobile-first shards, target ≤50k persistent entities per shard, well below Rust's PC numbers.

---

## 5. Dedicated server hosting: current status (verified Nov 2026)

| Option | Status | Persistent 24/7 servers? | Pricing (published) | Notes |
|---|---|---|---|---|
| **Unity Multiplay → "Multiplay by Rocket Science"** | Unity's direct support **ended 2026-03-31** after a Dec 2025 notice. Software licensed to Rocket Science Group. **Unity 6.3 LTS removes built-in Multiplay features** ([Unity thread](https://discussions.unity.com/t/end-of-services/1698428)). Gameye says Rocket Science relaunched it on 2026-07-14 (vendor; unverified, and the Gameye article is dated 2026-03-06, so that line was added or edited later). | Yes | **None published**, sales-led ([Rocket Science](https://www.rocketscience.gg/services/hosting)) | Matchmaker, Relay, Lobby and DA are unaffected. Unity said it was "working on" third-party hosting support for Matchmaker. **Unverified** whether that shipped. |
| **Hathora** | **Shut down 2026-05-05.** Announced 2026-03-04 as it pivoted to AI inference. Customers were pointed to Nitrado GameFabric ([press release](https://www.gamespress.com/Nitrado-and-Hathora-collaborate-on-customer-transition-to-GameFabric); [Edgegap](https://docs.edgegap.com/docs/tools-and-integrations/switch-from-hathora)). The press release gives no shutdown date; the 2026-05-05 date comes from Edgegap and Gameye, both rival vendors. | n/a | n/a | It also took Stormgate's online modes down with it ([TechSpot](https://www.techspot.com/news/111969-stormgate-servers-go-dark-following-ai-focused-hosting.html)) (unverified: the TechSpot page refused access during fact-check). |
| **Edgegap** | Active | **Private Fleets with persistence** (`max_duration: -1`). Edge Cloud deployments are capped at **24 h** ([docs](https://docs.edgegap.com/unity); [persistence](https://docs.edgegap.com/learn/orchestration/persistence)) | Edge Cloud ~$0.069/vCPU-h + $0.10/GB egress. Private Fleet $280-350/host/mo (16 vCPU, 14.7 usable, 6 TB egress included) ([pricing](https://edgegap.com/pricing)) | Documents Mirror, FishNet and Fusion 2. Says in-memory state is lost on stop, so back up to a backend. |
| **Amazon GameLift Servers** | Active. **Bandwidth free on gen-6+ instances from 2026-06-15** ([AWS blog](https://aws.amazon.com/blogs/gametech/free-network-bandwidth-amazon-gamelift-servers-is-here-yes-really/)) | Yes (managed EC2 or containers); "Anywhere" for your own hardware ([docs](https://docs.aws.amazon.com/gameliftservers/latest/developerguide/gamelift-intro-pricing.html)) | AWS example: 1,000 CCU on c6g.xlarge ≈ **$2,978/mo compute**, about $119 per instance (derived) (unverified: this example isn't on AWS's current GameLift Servers pricing page, whose examples use 10k-100k peak CCU on c6a/c6i instances) | 12-month free tier for new AWS accounts |
| **Gameye** | Active | Reserved capacity; persistence not stated | On-demand $0.07-0.10/vCPU-h; reserved $0.035-0.042; **zero egress** ([pricing](https://www.gameye.com/pricing/)) | Vendor blogs are biased against rivals |
| **Nitrado GameFabric** | Active (Hathora's chosen successor) | **Session and persistent** environments; bare metal, Google Cloud, or BYOC | Not published | Built on Agones (per Gameye). Includes SteelShield DDoS protection ([press release](https://www.gamespress.com/Nitrado-and-Hathora-collaborate-on-customer-transition-to-GameFabric)). |
| **Agones (self-run on Kubernetes)** | Donated to the **CNCF Sandbox** on 2026-03-23 ([CNCF](https://www.cncf.io/blog/2026/03/23/agones-moves-to-the-cncf-a-new-era-for-open-source-multiplayer-game-infrastructure/)) | Yes | Free (open source); you pay for the cluster | Too much ops work for an MVP |
| **Bare metal (e.g., Hetzner)** | Active | Yes (you run it) | AX42 (8-core, 64 GB) €79-99/mo + €49 setup; AX102 (16-core 7950X3D, 128 GB) from €159/mo + €129 setup; prices exclude VAT; **unlimited traffic** ([Hetzner](https://www.hetzner.com/dedicated-rootserver/matrix-ax/)) | Cheapest per slot. You handle DDoS, failover and orchestration. Check location coverage for Asia/Americas. |
| **PlayFab Multiplayer Servers** | Active; **VM prices rose ~6% on 2026-11-01** ([PlayFab pricing](https://developer.microsoft.com/en-us/games/products/playfab/pricing/)) | Yes | 750 Dasv4 VM hours/mo included; egress $0.05-0.16/GB | Tied to PlayFab |

**Inference:** In 2026 two well-known hosts vanished or changed hands within weeks. Build the server as a **plain Linux container** (Unity Dedicated Server build target) with a thin, swappable "allocator" interface, and keep all durable state outside the server process.

---

## 6. Backend: accounts, persistence, economy

| Backend | What you get | Cost (published) | Risks |
|---|---|---|---|
| **Unity Gaming Services** | Auth (free), Cloud Save, Cloud Code, Economy, Leaderboards, Vivox | Cloud Save: 5 GiB, 1M writes and 1M reads free per month, then $0.50/GiB. Cloud Code: 1M invocations free, then $1.50/M ([pricing](https://unity.com/products/gaming-services/pricing)) | Unity's track record in 2025-26: Multiplay handed off, and most UGS services (including Cloud Save, Cloud Code, Economy, Relay, Lobby, Matchmaker and Vivox) were stopped for orgs registered in mainland China, Hong Kong and Macau from 2026-06-30; Ads, IAP and Authentication stayed available ([17173](https://news.17173.com/content/06302026/140631964.shtml), translated report). The key-value models aren't built for transactional anti-dupe item moves. |
| **PlayFab** | Full live-ops suite | **Development Mode: 1,000 lifetime players per title.** Pay-as-you-go $0, Standard $99, Premium $1,999/mo. Foundation Mode is free **only for Xbox-published** titles ([pricing](https://developer.microsoft.com/en-us/games/products/playfab/pricing/)) | The free runway disappeared in March 2026 (unverified: the cited digest says nothing about Development Mode or free-tier limits, and the pricing page gives no date for the 1,000-player cap). Insights Management was retired effective 2026-03-31, which also disabled Event Export ([PlayFab digest](https://developer.microsoft.com/en-us/games/articles/2026/04/playfab-digest-march-feature-updates/)). |
| **Nakama** (Heroic Labs) | Accounts and social login, storage, wallets, IAP validation, chat, parties, leaderboards; Go/TS/Lua server runtime; Unity SDK | **Apache-2.0, self-host free** on Postgres/CockroachDB ([GitHub](https://github.com/heroiclabs/nakama)). Heroic Cloud is priced on request ([pricing](https://heroiclabs.com/pricing/)) | You operate it, or pay Heroic. Very mature. |
| **Supabase / Postgres** | Managed Postgres, auth, storage, edge functions | Free (500 MB, pauses after a week idle); Pro $25/mo + compute (e.g., Medium 4 GB $60/mo) ([pricing](https://supabase.com/pricing)) | No game features. You write the economy yourself, but it's real SQL transactions. |
| **SpacetimeDB** | Relational DB plus server logic in one; Unity C# SDK | Free 2,500 TeV/mo; Pro $25/mo; storage $1/GB/mo ([blog](https://spacetimedb.com/blog/all-new-spacetimedb-pricing)) | BSL license. A new paradigm that would replace your netcode for state rather than complement it. |

---

## 7. Persisting bases and handling offline players' bases

**Persistence architecture (Inference, aligned with Edgegap's guidance to back up in-memory state to a backend or object storage):**

- **The game server is authoritative in memory.** It snapshots each base to Postgres every N minutes and when a base unloads.
  - Use a row per base with a binary or JSONB piece array, a version number, and the owner/clan.
  - Use an **append-only transaction log** for high-value events (container transfers, raid loot, purchases) so a crash can't duplicate items.
- **Premium currency and purchases never live on the game server.** They go to the backend (Nakama wallet/ledger with receipt validation). A shard crash may roll the world back a minute or two, but it must never roll back paid items.
- **Unique item IDs** for valuables, with server-side ownership checks on every move. That's how you detect dupes.

**Offline-base models:**

| Model | How it works | Pros | Cons |
|---|---|---|---|
| **A. Always-live world (Rust)** | Bases exist in the shard 24/7, and anyone can raid at any time | The "real" raid fantasy | Offline griefing, ever-growing entity count, needs decay/upkeep and wipes |
| **B. Asynchronous snapshot raids (LDoE/Clash style, inferred)** | The base is loaded from the DB into an instance for the raider. Defenses are AI or traps, and the owner gets a report. | Cheap, mobile-friendly, no griefing at 3 a.m. | No live defender, so it's the "nobody comes" problem the developer hates |
| **C. Hybrid (recommended)** | Bases live on persistent shards (model A), plus: **raid alarms through push notifications** (proven by Rust+ Smart Alarms), **offline raid protection that scales with owner offline time**, or **server raid windows**; turrets and traps are simulated only while raiders are present; upkeep and decay prune abandoned bases; seasonal wipes on PvP shards | Real raids with real defenders much more often, bounded server cost | More systems to tune |

---

## 8. Anti-cheat (mobile and PC)

- **Server authority is 90% of the defense (Inference).** The server owns damage, inventory, building placement, door state and loot. It validates movement speed and teleports, line of sight for shots and explosives, and rate-limits actions.
- **Android: Play Integrity API.**
  - It gives verdicts on app binary integrity, device integrity (strong/device/basic tiers), licensing, and risky apps such as screen capture or overlays.
  - Verify verdicts **on your server** and don't cache them.
  - Use tiered enforcement, not a plain allow/deny.
  - Default quota is **10,000 requests/day**, which can be raised.
  - Google says to use it as one signal among several ([Android docs](https://developer.android.com/google/play/integrity/overview)).
- **iOS: App Attest** (DeviceCheck) for genuine-app and genuine-device attestation ([Apple](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)). I couldn't read the page body, so check the details there.
- **PC: Easy Anti-Cheat** has been free through Epic Online Services since 2021 ([PC Gamer](https://pcgamer.com/epic-has-made-easy-anti-cheat-free-for-game-developers)). The community Unity EOS plugin lists Anti-Cheat as a feature ([plugin README](https://github.com/EOS-Contrib/eos_plugin_for_unity/blob/stable/com.playeveryware.eos/README.md)).
  - **Gap:** I couldn't confirm whether EAC's anti-cheat interface runs on Android or iOS. Assume PC-only.
- **Mirror** lists Cheat Detection as a Beta feature. Its "Guard" anti-cheat is a separate product sold on the Asset Store with a Mirror integration, not part of the free package ([GitHub](https://github.com/MirrorNetworking/Mirror)). Treat it as minor.
- **Inference:**
  - Use IL2CPP plus code obfuscation on clients.
  - Encrypt the transport.
  - Log every raid (inputs, hits, loot) for replay review.
  - Run server-side anomaly detection on loot gain per hour.
  - Modded APKs are common in this genre, and the only lasting defense is that the client can't grant anything.

---

## 9. Mobile + PC cross-play

- **Store rules on currency:** Apple 3.1.3(b) lets an iOS app honor currency bought on Steam or the web, **only if** the same items are also sold as IAP in the iOS app. Separately, guideline 3.1.1 says credits or in-game currencies bought through IAP may not expire ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- **Visibility parity:** keep the AOI radius server-defined, the same for every platform, and don't let a graphics setting reveal more (foliage, fog). **Inference.**
- **Input parity:**
  - A top-down or isometric camera (like LDoE) shrinks the mouse-vs-touch aiming gap a lot compared with first person.
  - Consider aim assist for touch and controller, input-based matchmaking for ranked or arena modes, and opt-out cross-play on PvP shards. **Inference.**
- **Performance tiers:** the server must never depend on client frame rate. Fixed-tick simulation, with mobile clients interpolating. Megacity Metro shows Unity's server-authoritative netcode working across mobile, Switch and desktop together ([Unity](https://unity.com/demos/megacity-competitive-action-sample)).
- **Unity NGO 3.2** officially targets Windows, macOS, Linux, iOS, Android and consoles ([NGO 3.2 docs](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/index.html)).

---

## 10. Server cost per player: rough estimates

**Inference, with assumptions stated so you can redo the math:**

- One persistent shard = **60 concurrent player slots** and needs **2 fast vCPU + ~6 GB RAM**.
  - Unity servers are main-thread-bound, like Rust, which hosting guides describe as mostly single-threaded.
  - Benchmark your own build: Unity publishes no per-player figures.
- Bandwidth is **~8 KB/s per player** (an assumption, not an AWS figure: AWS's current GameLift pricing examples use 2-20 KB/s per player depending on genre). At 40% average occupancy that's about **0.5 TB per shard per month**.

| Host | Monthly cost per 60-slot shard | Per slot per month | Notes |
|---|---|---|---|
| Hetzner AX102 (7 shards/box) | ~€23 + amortized setup | **~€0.38** | Unlimited traffic; you own ops and DDoS |
| Hetzner AX42 (3 shards/box) | ~€26-33 | ~€0.45-0.55 | |
| Edgegap Private Fleet (7 shards/host) | ~$40-50 | **~$0.67-0.83** | 6 TB egress/host included; global locations; persistence supported |
| Gameye reserved (2 vCPU at 1:4 RAM) | ~$61 | ~$1.02 | Zero egress; minimum one 8-core machine per region |
| AWS GameLift c6g.xlarge (2 shards/instance) | ~$60 (unverified) | **~$1.00** (unverified) | Derived from the ~$119/instance example in section 5, which couldn't be found on AWS's current pricing page; re-price with the AWS calculator. Bandwidth now free on gen 6+; easiest to scale globally |
| Edgegap Edge Cloud on-demand | n/a | n/a | 24 h cap, so use it for **instanced raids or events**, not persistent shards |
| Photon Fusion (Server mode) **adds** | +$0.25/CCU at the 1k tier | | On top of any host above ([pricing](https://www.photonengine.com/fusion/pricing)) |

**What changes the math:**

- **Shards are sized by base population, not by peak CCU.** Players' bases are pinned to a shard, so you can't consolidate shards at night like match-based games do.
- **Inference:** a shard world probably holds 150-300 active bases for 60 concurrent slots. For scale reference, Photon sizes 500 CCU at ~200k MAU for session games ([pricing](https://www.photonengine.com/fusion/pricing)). Survival sessions are longer, so expect a higher CCU/MAU ratio.
- **Backend:** a Nakama VM plus managed Postgres is roughly $50-300/mo at indie scale (Inference, based on [Supabase](https://supabase.com/pricing) compute tiers).

---

## 11. Recommended stack, scale path, and risks

### MVP (small team, first 12-18 months)

| Layer | Pick | Why |
|---|---|---|
| Engine | **Unity 6.3 LTS** | Stable LTS. Avoids the 6.5/6.6 end-of-support churn and the non-LTS 6.7 requirement of NGO 3.x. |
| Netcode | **Fish-Networking + Pro** ($60 lifetime) | Server-authoritative, free CSP, lag compensation, observers and Network LOD, GameObject-native, mature, documented on Edgegap. **Alternatives:** Mirror if you want the biggest community and MIT with no paid tier (you'd build prediction and lag comp yourself). Unity Netcode/GhostObjects if you'll accept churn for the first-party roadmap. |
| Building replication | **Custom BaseChunk + delta events** (section 4) | Works the same on any netcode, so it de-risks a later migration |
| Server build | Unity **Dedicated Server** target, Linux container | Portable across every host |
| Hosting | **Hetzner AX bare metal** (EU/NA alpha), or **Edgegap Private Fleet** if you need many regions | Lowest cost per slot; Edgegap documents persistence |
| Backend | **Nakama OSS + Postgres** | Free, self-hostable, accounts, wallet and IAP validation; Postgres transactions for anti-dupe |
| World persistence | Postgres snapshots + transaction log; object storage for backups | Survives crashes and host changes |
| Anti-cheat | Server authority + Play Integrity + App Attest + EAC (PC) | Layered |
| Voice/chat (optional) | Nakama chat; Vivox free up to 5,000 PCU ([UGS pricing](https://unity.com/products/gaming-services/pricing)) | |

### Scale-up path

1. **Closed alpha:** 1-2 bare-metal boxes, 5-10 shards, one Nakama node. Load-test with bots to measure KB/s per player, entities per shard, and tick time at 60/100 players.
2. **Open beta:** add Edgegap Private Fleet or GameLift for other regions. Edgegap Edge Cloud for instanced events and raid arenas. Put a shard directory and allocator service in front.
3. **Launch and scale:** move hot paths (inventory, trading) into Nakama Go modules or a dedicated service. Read replicas for Postgres. Consider Heroic Cloud or Agones/GameFabric once ops headcount allows.
4. **Netcode gate (mid-2027, Inference):** if Unity Netcode/GhostObjects reaches an LTS with relevancy and pooling, prototype one raid scenario on it. Migrate only if it clearly wins on bandwidth or CPU.

### Key risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Entity growth makes shards lag over time | High / high | Piece caps, upkeep, decay, wipes, entity telemetry from day 1 |
| Item dupes from crash/rollback edge cases | Medium / very high | Transaction log, unique item IDs, paid goods only in the backend |
| Host or vendor disappears (Hathora, Multiplay precedent) | Medium / high | Container plus allocator abstraction, no proprietary SDK in the server core |
| Unity netcode churn (NGO 3, Netcode 7, Unity 7 merge) | High / medium | Stay on 6.3 LTS with FishNet; isolate netcode behind your own gameplay layer |
| FishNet bus factor (small core team; Inference) | Low-medium / medium | Source is available. BaseChunk design keeps migration feasible. |
| Mobile hit-reg feels unfair | Medium / high | Lag compensation, generous hitboxes, top-down camera, regional shards |
| Bandwidth or cost surprises | Low-medium | Pick hosts with included or zero egress; measure KB/s per player early |

---

## Design implications for our game

1. **Real raiding means always-on persistent shards, and that's the main cost driver.** Budget for it from day one. It's affordable: under ~$1 per player slot per month on bare metal or reserved hosts (Inference). Don't fall back to LDoE-style async snapshots for the main raid loop, or you rebuild the "nobody comes" problem.
2. **Make offline raids rare and online raids frequent:** push raid alarms (Rust+ proves players respond), offline protection that scales with time offline, and optional raid windows per server. That turns raids into fights instead of empty looting.
3. **Treat building pieces as data, not objects.** Use BaseChunks with delta events, cap pieces per base, and add upkeep and decay. This one choice decides whether shards still run well after week three.
4. **Separate "home" from "frontier."** Possibly an async-defended home base plus contested live bases on PvP shards. The safe home lets casual and mobile players keep progress, and the frontier base is where Rust-style stakes live. It also caps how much loot a 3 a.m. raid can take.
5. **Use a top-down or isometric camera** (LDoE-like) to neutralize the mouse-vs-touch gap in cross-play PvP. It also lowers mobile GPU load from thousands of base pieces.
6. **Never trust the client with anything stealable.** Every loot move is a server transaction with an item ID. Premium currency lives only in the backend. Apple's 3.1.3(b) rule means cross-platform currency must also be sold as iOS IAP.
7. **Seasonal wipes on PvP shards and permanent PvE shards.** Wipes are a technical necessity (entity growth) as well as a design feature (fresh races). Players who hate wipes get PvE shards.
8. **Lag compensation is not optional** for the raid highlight on mobile networks. Pick a netcode that has it (FishNet Pro, Fusion Server or Host mode, or Unity Netcode's server rewind).
9. **Stay vendor-portable.** Linux container, your own allocator interface, Postgres as the source of truth. 2026 showed hosts can vanish in 60-90 days.
10. **Build a bot load-test harness before content.** Measure KB/s per player, entities per shard, and server tick time at 60 and 100 players. Those three numbers set your shard size, piece caps and hosting budget.

---

## Gaps and things I couldn't verify

- **Last Island of Survival:** engine, netcode and backend aren't publicly documented in anything I found.
- **Rust's current transport:** whether Rust still uses RakNet (only a 2016 primary source).
- **EAC on mobile:** whether Easy Anti-Cheat's anti-cheat interface supports Android/iOS.
- **Unity Matchmaker:** whether it now supports third-party hosts (promised before 2026-03-31).
- **Rocket Science:** Multiplay pricing and the exact relaunch date (only the Gameye vendor blog gives 2026-07-14).
- **Unity 6.7:** whether it is or will be an LTS.
- **coherence:** persistence features and scale data.
- **PurrNet:** lag compensation.
- **Server sizing:** no independent per-player CPU/RAM benchmarks for Unity survival servers. The numbers in section 10 are assumptions to replace with your own load tests.
- **Video research:** none. My web search budget ran out partway through, so YouTube guides weren't researched for this file.

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. About 31 high-impact claims were re-checked by opening the cited pages. The web search budget was already used up, so corroboration came from fetching primary and secondary pages directly, not from fresh searches.*

**Confirmed against the cited source (no change needed):**

- Rust Devblog 42 (9 Jan 2015): ~50k entities used to drop servers to ~5 fps; after the physics-trigger fix, "a solid 60fps with 200 players and over 150,000 entities"; stability system reworked.
- Rust uses RakNet through a C# wrapper with `SERVER`/`CLIENT` defines (Garry Newman, 18 Feb 2016). The Facepunch wiki lists "12 GB free RAM" and gives no minimum CPU.
- NGO 1.x unsupported in 6000.3+ (announced 2025-08-06). NFE became a core package in 6.5; Netcode 7.0.0 is independent again from 6000.7.0b1 (announced 2026-09-11); 6.3 stays on NFE 1.x.
- NGO 3.0.0 (2026-09-14) makes `com.unity.netcode` 7.0.0 a hard dependency; 3.2.0 is dated 2026-11-03; the upgrade guide requires Unity 6.7+ and uses the "foundations" wording.
- GhostObjects announcement (2026-11-05): Unity 6000.7, Unity Netcode 7.2.0, NGO 3.2.0; both "full release" and "first iteration"; pooling, CharacterController/collider prediction, relevancy APIs and error smoothing are on the to-do list; the "NOT a deprecation" quote is accurate.
- Multiplay: Unity runs it through 2026-03-31, software licensed to Rocket Science Group, built-in features removed in 6.3 LTS, and Matchmaker/Relay/Lobby/DA unaffected. Rocket Science publishes no prices.
- Hathora: Nitrado press release dated 2026-03-04 with the AI-inference pivot; shutdown on 2026-05-05 per Edgegap docs and Gameye (both vendors).
- AWS GameLift Servers: outbound bandwidth free on gen-6+ instances from 2026-06-15 (all Regions except China); 12-month free tier for new customers.
- Agones donated to the CNCF at Sandbox level (2026-03-23).
- Fish-Networking: free CSP; lag compensation and Network LOD are Pro; Pro costs $10 once + $2/mo, or $60 lifetime; 2.1k stars; commits through Oct 2026.
- Photon Fusion prices (free 100 CCU; $125/500, $250/1k, $500/2k per month; Premium $0.50/CCU with a $1,000/mo minimum; 500 CCU ≈ 200k MAU); lag comp is Server/Host only; Quantum "up to 128 players."
- coherence 2.0 (2025-11-18) pricing and 3% revenue share above $15K/quarter for client and self-hosting.
- Edgegap: Edge Cloud $0.00115/vCPU-min (≈$0.069/h) + $0.10/GB; 24 h runtime cap; Private Fleet $280-350/host/mo, 16 vCPU (14.7 usable), 6 TB egress; persistence via `max_duration: -1`; in-memory state is lost on stop.
- Gameye prices, zero egress fees and the one-8-core-machine-per-region reserved minimum.
- PlayFab plan prices, the 1,000-lifetime-player Development Mode cap, the ~6% VM price rise on 2026-11-01, 750 Dasv4 hours and $0.05-0.16/GB egress.
- UGS free tiers and overage prices for Cloud Save, Cloud Code and Vivox (free up to 5,000 PCU).
- SpacetimeDB pricing (2025-12-16), BSL 1.1 converting to AGPL with a linking exception, and the BitCraft claim; Supabase prices; Heroic Cloud Nakama pricing not published.
- Play Integrity: 10,000 requests/day by default (raisable), no caching, tiered enforcement, use alongside other signals. Apple 3.1.3(b) wording.
- Mirror: lag comp Beta, prediction Researching, MIT license, spatial hashing, the named games and self-reported 5k CCU claims. PurrNet: 707 stars, MIT, benchmark of ~49% / ~61% less bandwidth than FishNet / Mirror.
- Megacity Metro: "100+ player," Netcode for Entities, server-authoritative, mobile/Switch/desktop. Last Island of Survival developer is HK Hero Entertainment Co., Limited.

**Corrections made:**

1. Netcode 7.0.0 post: the quote "nearing end of support" was changed to the actual wording, "approaching the end of support."
2. NGO 3.2.0 "adds hybrid sessions": the support comes from the GhostObjects post. The changelog lists only hybrid-mode changes and fixes under 3.2.0, so the attribution was adjusted.
3. Photon Fusion: the quote "easy to cheat" isn't on the page. It was changed to the actual "vulnerable to cheating."
4. PurrNet: the quote "100% free" isn't on the GitHub page. It was replaced with "no CCU tax and no revenue share," and the optional paid plans (from $500/mo) were noted. A "ColliderRollback" component is listed, so the lag-comp entry now says that.
5. coherence: the free tier is under $200K "annual revenue or funding," not just revenue.
6. Hetzner: added the AX42 €49 setup fee and noted that the AX102 is "from" €159 (up to €259) and that prices exclude VAT.
7. UGS China shutdown: it covers mainland China, Hong Kong **and Macau**. Ads, IAP and Authentication remain available.
8. Mirror "Guard": it is a separately sold Asset Store product, not something Mirror ships. Mirror's own Cheat Detection feature is Beta.
9. Apple: the rule that IAP credits may not expire is guideline 3.1.1, not 3.1.3(b).
10. Section 10 bandwidth: "~8 KB/s per player" isn't an AWS example figure. AWS's current examples use 2-20 KB/s, so it's now labeled as an assumption. The arithmetic (≈0.5 TB per shard per month at 40% occupancy) checks out.

**Marked (unverified):**

- AWS "1,000 CCU on c6g.xlarge ≈ $2,978/mo" example, and the section 10 GameLift row derived from it. It isn't on AWS's current pricing page.
- PlayFab "the free runway disappeared in March 2026." The cited digest doesn't mention Development Mode or free-tier changes.
- Stormgate online modes taken down by Hathora's shutdown. TechSpot returned 403.
- Rocket Science relaunch on 2026-07-14. This is a single vendor source, and the line appears in a Gameye post dated 2026-03-06.
- PurrNet lag compensation behavior.

**Not re-checked:** the Rustoria/GameServerKings entity anecdotes, Rust+ features, NFE relevancy/importance-scaling changelog details, the EOS plugin README, and Apple App Attest. The PC Gamer page loaded only its headline, which confirms EAC is free; the 2021 date wasn't re-confirmed from the page body.

**Overall reliability: high.** Nearly every number, price and date that drives a decision matched its source exactly. The errors were misquotes, one misattributed bandwidth figure, one unsupported PlayFab claim, one unlocatable AWS cost example, and an overstated Mirror anti-cheat claim. None of these changes the recommended stack. The AWS row of the section 10 cost table should be re-priced before you rely on it.

---

## Sources

- [Facepunch Devblog 42 (2015): entity count and server FPS](https://rust.facepunch.com/news/devblog-42)
- [Garry Newman: Rust's Networking (2016)](https://garry.net/posts/rusts-networking)
- [Facepunch wiki: Creating a Rust server](https://wiki.facepunch.com/rust/Creating-a-server)
- [Rust+ companion app](https://rust.facepunch.com/companion)
- [GameServerKings: Rust server performance (vendor)](https://www.gameserverkings.com/knowledge-base/rust/server-performance/)
- [Rustoria community thread on entity limits (2018)](https://steamcommunity.com/groups/rustoria/discussions/0/1620600279666568817)
- [Last Island of Survival, App Store](https://apps.apple.com/us/app/id1463021419)
- [Unity: Megacity Metro sample](https://unity.com/demos/megacity-competitive-action-sample)
- [Unity Discussions: NGO 1.x deprecation in 6000.3](https://discussions.unity.com/t/netcode-for-gameobjects-1-x-deprecation-in-6000-3-editor/1674997)
- [Unity Discussions: Prediction with GameObjects coming to NFE (Dec 2025)](https://discussions.unity.com/t/prediction-with-gameobjects-coming-to-netcode-for-entities/1698666)
- [Unity Discussions: Prediction in GameObject Netcode, DevLog 4 (May 2026)](https://discussions.unity.com/t/prediction-in-gameobject-netcode-devlog-entry-4/1719927)
- [Unity Discussions: GhostObjects Released (Nov 2026)](https://discussions.unity.com/t/prediction-in-gameobject-netcode-ghostobjects-released/1741239)
- [Unity Discussions: Netcode for Entities 7.0.0 independent package (Sep 2026)](https://discussions.unity.com/t/netcode-for-entities-7-0-0-moving-back-to-an-independent-package-in-unity-6-7/1736319)
- [Unity Discussions: Multiplayer Services 2.4.0](https://discussions.unity.com/t/multiplayer-services-package-2-4-0-is-now-available/1738947)
- [Unity Discussions: Multiplay end of services](https://discussions.unity.com/t/end-of-services/1698428)
- [NGO 3.2 changelog](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/changelog/CHANGELOG.html)
- [NGO 3.x upgrade guide](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/upgrade-guide.html)
- [NGO 3.2 manual](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/index.html)
- [NGO 3.2 table of contents](https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@3.2/manual/TableOfContents.html)
- [Netcode for Entities 6.6 manual](https://docs.unity3d.com/Packages/com.unity.netcode@6.6/manual/index.html)
- [Netcode for Entities changelog](https://docs.unity3d.com/Packages/com.unity.netcode@6.6/changelog/CHANGELOG.html)
- [Fish-Networking features](https://fish-networking.gitbook.io/docs/overview/readme/features)
- [Fish-Networking Pro](https://fish-networking.gitbook.io/docs/overview/readme/pro-projects-and-support)
- [FishNet GitHub](https://github.com/FirstGearGames/FishNet)
- [Mirror GitHub](https://github.com/MirrorNetworking/Mirror)
- [PurrNet docs](https://purrnet.dev/docs)
- [PurrNet network transform benchmarks](https://purrnet.dev/docs/readme/performance/network-transform-benchmarks)
- [PurrNet GitHub](https://github.com/PurrNet/PurrNet)
- [Photon Fusion pricing](https://www.photonengine.com/fusion/pricing)
- [Photon Quantum pricing](https://www.photonengine.com/quantum/pricing)
- [Photon Fusion intro](https://doc.photonengine.com/fusion/current/getting-started/fusion-introduction)
- [Photon Fusion interest management](https://doc.photonengine.com/fusion/current/manual/interest-management)
- [Photon Fusion lag compensation](https://doc.photonengine.com/fusion/current/manual/advanced/lag-compensation)
- [Photon Quantum 3 intro](https://doc.photonengine.com/quantum/current/getting-started/quantum-intro)
- [coherence 2.0 announcement](https://coherence.io/blog/news/introducing-coherence-2-0)
- [SpacetimeDB pricing blog (Dec 2025)](https://spacetimedb.com/blog/all-new-spacetimedb-pricing)
- [SpacetimeDB GitHub](https://github.com/clockworklabs/SpacetimeDB)
- [Rocket Science: Multiplay hosting](https://www.rocketscience.gg/services/hosting)
- [Gameye: Unity Multiplay migration (vendor)](https://gameye.com/unity-multiplay-migration/)
- [Gameye: 2026 game server shake-up (vendor)](https://gameye.com/blog/game-server-shake-up-2026)
- [Gameye pricing](https://www.gameye.com/pricing/)
- [Nitrado and Hathora press release (2026-03-04)](https://www.gamespress.com/Nitrado-and-Hathora-collaborate-on-customer-transition-to-GameFabric)
- [Edgegap: Switch from Hathora](https://docs.edgegap.com/docs/tools-and-integrations/switch-from-hathora)
- [TechSpot: Stormgate servers go dark](https://www.techspot.com/news/111969-stormgate-servers-go-dark-following-ai-focused-hosting.html)
- [Edgegap pricing](https://edgegap.com/pricing)
- [Edgegap Unity docs](https://docs.edgegap.com/unity)
- [Edgegap persistence docs](https://docs.edgegap.com/learn/orchestration/persistence)
- [AWS: Free network bandwidth for GameLift Servers (2026-06-16)](https://aws.amazon.com/blogs/gametech/free-network-bandwidth-amazon-gamelift-servers-is-here-yes-really/)
- [AWS GameLift Servers pricing docs](https://docs.aws.amazon.com/gameliftservers/latest/developerguide/gamelift-intro-pricing.html)
- [CNCF: Agones moves to the CNCF (2026-03-23)](https://www.cncf.io/blog/2026/03/23/agones-moves-to-the-cncf-a-new-era-for-open-source-multiplayer-game-infrastructure/)
- [Hetzner AX dedicated servers](https://www.hetzner.com/dedicated-rootserver/matrix-ax/)
- [Unity Gaming Services pricing](https://unity.com/products/gaming-services/pricing)
- [17173: Unity services stopped for China/HK orgs (2026-06-30)](https://news.17173.com/content/06302026/140631964.shtml)
- [PlayFab pricing (Microsoft)](https://developer.microsoft.com/en-us/games/products/playfab/pricing/)
- [PlayFab Digest: March 2026](https://developer.microsoft.com/en-us/games/articles/2026/04/playfab-digest-march-feature-updates/)
- [Heroic Labs pricing](https://heroiclabs.com/pricing/)
- [Nakama GitHub](https://github.com/heroiclabs/nakama)
- [Supabase pricing](https://supabase.com/pricing)
- [Android Play Integrity API overview](https://developer.android.com/google/play/integrity/overview)
- [Apple App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [PC Gamer: Epic makes Easy Anti-Cheat free (2021)](https://pcgamer.com/epic-has-made-easy-anti-cheat-free-for-game-developers)
- [EOS Plugin for Unity README](https://github.com/EOS-Contrib/eos_plugin_for_unity/blob/stable/com.playeveryware.eos/README.md)
- [Apple App Review Guidelines (3.1.1, 3.1.3(b))](https://developer.apple.com/app-store/review/guidelines/)
