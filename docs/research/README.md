# Research: summary and index

The research ran on 2026-11-07. There are 12 files, and an independent fact-checker reviewed each one. Each file ends with its own "Fact-check notes" section. Claims that could not be confirmed are marked *(unverified)*.

The workflow was stopped before it wrote the master synthesis, the game concepts and the recommendation. This page is a short summary written by hand instead.

**Limits of this research:**
- Reddit could not be fetched, and YouTube videos could not be watched (only titles were available).
- Several researchers ran out of web-search budget partway through.
- Revenue figures are third-party estimates.
- Hands-on play would still add the things a wiki can't capture: how combat and building *feel*, timer pain, and when the game pushes you to buy.

## Files

| File | What it covers |
|---|---|
| [ldoe-base-building.md](ldoe-base-building.md) | LDoE and Zombix base building: pieces, tiers, HP, costs, build UX, raid interaction |
| [building-systems-references.md](building-systems-references.md) | Rust, DayZ, Valheim, 7DTD and mobile building systems, plus the Unity implementation architecture |
| [ldoe-core-systems.md](ldoe-core-systems.md) | How LDoE works: core loop, crafting, map and energy, zones, combat, vehicles, updates |
| [ldoe-monetization.md](ldoe-monetization.md) | LDoE monetization teardown with prices and player sentiment |
| [ldoe-pvp-raiding-social.md](ldoe-pvp-raiding-social.md) | How LDoE raiding, PvP and clans work, and why raiding feels dead |
| [ldoe-retention-sentiment.md](ldoe-retention-sentiment.md) | Why LDoE is fun, its retention hooks, what players love and hate, and why they quit |
| [zombix-mechanics.md](zombix-mechanics.md) | How Zombix Online works: world, combat, flags and bases, clans, pets, trade |
| [zombix-business-sentiment.md](zombix-business-sentiment.md) | Zombix monetization, installs, reviews and community |
| [dayz-rust-raiding.md](dayz-rust-raiding.md) | Rust and DayZ raiding design, problems, fixes and mobile adaptations |
| [competitor-landscape.md](competitor-landscape.md) | 15-plus survival competitors, the market, and the white space |
| [fair-monetization.md](fair-monetization.md) | Monetization models players accept, 2026 store and legal rules, a fairness charter |
| [unity-online-tech.md](unity-online-tech.md) | Unity netcode, hosting and backend options (2026 status), and a recommended MVP stack |

## Headline findings

### Why LDoE raiding feels dead

The design itself stops raids from happening:
- Raiding is gated behind roughly level 150 and a quest chain.
- Targets come one at a time from tasks.
- The top wall tiers (L4/L5) cannot be breached, and special storage cannot be looted.
- Defenders never see a live attacker.
- The game also sells raid task skips, inventory recovery, resurrection with loot kept (Sept 2026) and event breach tools.

LDoE's best raid idea is worth keeping: the **noise meter**. Breaching draws escalating zombie waves.

### Zombix's strengths and failures

Zombix's strength is its persistent, shared, social world. Pieces worth copying:
- **Flag claims** with caps per claim (2 generators, 4 turrets).
- 1-hour immunity on new claims.
- Half the materials drop as salvage when a claim falls.
- Clan territory that pays out on a timer.
- Timed production that people guard for hours.

Its failures:
- The personal base cannot be raided, so stashes are never at risk.
- Mega-clans hold territory forever.
- Respawning is nearly free, so fights turn into "naked spam".
- Gacha sells power characters.
- Lag and outages.
- Weak onboarding.

It reached about 4.8M lifetime installs with a solo developer and almost no marketing, which is strong evidence of demand.

### What makes raiding work in Rust and DayZ

- Every piece has HP.
- Breach costs are visible and priced in one scarce explosive resource.
- Soft and hard sides.
- Building privilege, plus upkeep that grows with base size and group size.
- Wipes reset power gaps.

Their known problems are offline raiding, zergs and cheating. Rust's 2026 Softcore mode answers these with **raid windows**, partial loot loss and repairable debris.

### Building system recommendation

The research converges on these points:
- **Socket/lattice snapping** (Rust-style): floors first, then edge walls snapped to them.
- About 4 material tiers at about 2× HP each.
- No tier that can never be breached.
- A visible "cost to breach" on every piece.
- Claim radius with upkeep and decay.
- **Touch-first build UX** as our edge:
  - auto-snap
  - drag to paint walls
  - "upgrade whole building"
  - saved blueprints
  - generous undo
  - a top-down layout mode
- In code, treat pieces as **data in chunks**, not individual GameObjects, with delta replication, a server-authoritative design, and a cap on pieces per base.

### Monetization

LDoE sells energy, timers, gear, storage, VIP and revives, and that is the top reason players give low ratings and leave. Our pitch: **"Anything that can be raided can only be earned."** Allowed revenue:
- cosmetics, especially **base skins** (other players see your base when they raid it)
- one cosmetic pass at a fixed price
- private server rental
- a possible buy-to-play price on PC

Never sell energy, power, protection, storage, revives, or anything random.

### Technology

Real raiding requires **always-on, persistent, server-authoritative shards**. Async snapshots would bring back LDoE's "nobody comes" problem.
- **Networking:** FishNet Pro, Photon Fusion or Unity Netcode, each with lag compensation.
- **Hosting:** Linux containers that can move between providers, because 2026 showed hosting providers can disappear within months.
- **Data:** Postgres as the source of truth.
- **Testing:** build a bot load-test harness early.
- **Camera:** a top-down or isometric camera evens out touch versus mouse in cross-play and keeps GPU cost low.

## Recurring design levers (to discuss)

1. **Base split:** a home base plus raidable frontier bases or outposts, a small protected stash earned through play, and most of a player's wealth in a raidable base.
2. **Raid ruleset:** raid windows, offline damage reduction, or both (test them), plus push raid alarms and a minimum breach time so defenders can respond.
3. **Making raids happen:**
   - dense shards
   - large bases visible on the map
   - a raid board filtered by power band
   - 2–4 week seasons on PvP shards and permanent PvE shards
   - an instanced siege mode for short mobile sessions
4. **Zombies as the third party:** loud raids pull hordes, and horde nights test bases between PvP raids.
5. **No energy meter:** travel costs time, fuel, carrying capacity and risk.
6. **Death costs your carried loot,** but you can recover it by going back to your body, with a cheap "naked kit" to restart. No revive for sale.
