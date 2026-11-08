# Roblox Genres and Monetization Teardown (2025–2026)

*Research date: 2026-11-07. This builds on [platform-economics.md](platform-economics.md), which covers payouts and Google Play vs Roblox, and on the LDoE files indexed in [README.md](README.md). It does not repeat them.*

> **How to read this file**
> - Statements with a link are sourced. Lines starting with **Inference:** are my analysis.
> - **Source quality.** Roblox's own docs, DevForum posts, newsroom posts and earnings are primary. GameAnalytics publishes benchmark data. RoWatcher, Rotrends and profitable.app are trackers whose revenue figures are *modelled estimates*. Pages from Robux-reward sites (earnaldo.com) are affiliate content and are flagged when used.
> - Player counts move week to week. Treat every concurrent-user (CCU) figure as a snapshot.
> - **Not found:** Naavik, Deconstructor of Fun or GameRefinery teardowns of these specific games, and any credible session-length data broken down by genre.

---

## 1. TL;DR

1. **The biggest 2025–2026 hits are light, social, asynchronous "number goes up" sims.** Grow a Garden peaked at 22.3M CCU and Steal a Brainrot at roughly 24–25.9M. The biggest survival hit is **co-op and kid-friendly-spooky**: 99 Nights in the Forest peaked at 14M CCU with a team of about five. Hardcore PvP and extraction survival (Project Delta, AR2, Fallen) is a niche of thousands to tens of thousands of players.
2. **Top earners sell power and randomness:** luck passes, exclusive eggs, crate keys for skins, and timer skips. That draws loud criticism, but players keep paying. A fairer model is possible: Dead Rails sells a few clear passes and keeps its strongest content earnable. It will probably earn less per player.
3. **The platform changed a lot in 2026:**
   - age-tiered accounts (Kids 5–8, Select 9–15, Roblox 16+)
   - age checks to use chat
   - an evaluation gate before a game can reach under-16s
   - Robux subscriptions
   - a 28-day retention signal in discovery
   - a 42% DevEx uplift for US 18+ spend in "novel", R15 games
4. **Zombie survival fits Roblox if it stays at the Mild content level** (stylized deaths, no realistic gore). Mild keeps every age tier open. Realistic death or blood pushes the game to Moderate, which locks out the 5–8 tier.
5. **Visual quality is not what made most brainrot or idle hits.** Kotaku said Grow a Garden looks more like a prototype. But Roblox now rewards distinct, higher-fidelity games with the 18+ DevEx uplift and a "Standout Games" home-page row, and session quality and 28-day retention now drive discovery.

---

## 2. Which games win on Roblox (2025–2026)

### 2.1 Headline titles

| Game | Genre | Scale (source) | Notes |
|---|---|---|---|
| **Steal a Brainrot** | Collect-and-steal tycoon | Record of 25.87M CCU on Oct 11, 2025 ([The Spike via search](https://www.thespike.gg/roblox/beginner-guides/how-to-check-roblox-player-count)); "over 24M" in Sept 2025 ([Wikipedia GaG](https://en.wikipedia.org/wiki/Grow_a_Garden)) | #1 mobile earner on Roblox's own top-earning chart in Jan 2026 ([PCGamesN](https://www.pcgamesn.com/roblox/highest-revenue-jan-2026)) |
| **Grow a Garden** | Idle farming / collect | 22.3M CCU on Aug 23, 2025; 35.3B visits by May 2026; first version built in about 3 days ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)) | Peaks fade fast: the June 21, 2025 peak fell from 21.3M to 7.6M within an hour (same). "Grow a Garden 2" was at 171.8K CCU in Aug 2026, per a low-reliability list ([StudioKrew](https://studiokrew.com/blog/top-roblox-games-august-2026/)) |
| **99 Nights in the Forest** | Co-op survival horror | 14M peak CCU after its June 2025 launch; ~5-person team; 3-month build ([DevForum spotlight](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940)) | Weekly updates. 20th Century Studios bought the film rights ([TheWrap](https://www.thewrap.com/creative-content/movies/20th-century-studios-roblox-game-99-nights-in-the-forest/)) |
| **Dead Rails** | Co-op zombie train run | Over 600K CCU on one weekend ([GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)); down 38% over 30 days in 2026 ([RoWatcher](https://rowatcher.com/games/7018190066/dead-rails/dying)) | Roblox's official social accounts promoted it in Feb 2025, which put it on the front page (GameAnalytics) |
| **Brookhaven RP** | Roleplay | 400–665K CCU in Mar 2026 ([RoWatcher](https://rowatcher.com/news/top-10-roblox-games-by-players-march-2026-data-breakdown)) | Earns "five figures monthly" from rewarded video ([DevForum](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)) |
| **Adopt Me!** | Pet collect-and-trade | 380–531K CCU in Mar 2026 (RoWatcher) | About 40 staff and about $60M a year, per Wikipedia (unverified) ([Wikipedia](https://en.wikipedia.org/wiki/Adopt_Me!)) |
| **Blox Fruits** | Anime action RPG | 200–414K CCU in Mar 2026 (RoWatcher) | Long-running grind RPG |
| **RIVALS** | Arena FPS | About 400K CCU; #1 on the PC top-earning chart in Jan 2026 ([PCGamesN](https://www.pcgamesn.com/roblox/highest-revenue-jan-2026)) | Money comes from crate keys for weapon skins |
| **Escape Tsunami for Brainrots** | Brainrot obby/collect | #3 mobile earner in Jan 2026 (PCGamesN); up 210% year on year (RoWatcher) | The brainrot wave carried into 2026 |
| **Pet Simulator 99** | Incremental / collect / trade | 180K+ CCU in Mar 2026 (RoWatcher list) vs "roughly 46K" in another RoWatcher piece; the figures conflict ([RoWatcher](https://rowatcher.com/news/pet-simulator-99-inside-roblox-s-most-aggressive-monetization-machine)) | Updates every week or two; reached Update 72 by Dec 2025 |
| **Fish It!** / **Fisch** | Fishing "chill sim" | Fish It: 2.7M all-time peak and 90.5K CCU on Sep 19, 2026. Fisch: 64.1K in Jul 2026 ([profitable.app](https://profitable.app/roblox/games/fish-it), [RoWatcher](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026)) | Auto-fishing (AFK) is credited as the growth driver. "Hooked!" grew 9,019% in Q1 2026 (RoWatcher) |
| **Bubble Gum Simulator Infinity** | Egg-hatch incremental | 380.8K peak; about 11K average recently; 12–13 passes and about 450 developer products ([Rotrends](https://rotrends.com/game/6504986360)) | Shows how big a dev-product catalog in this genre gets |
| **Forsaken** | Asymmetric horror | 138K+ peak ([RoWatcher](https://rowatcher.com/news/forsaken-s-floral-update-drives-the-survival-horror-hit-past-86k-players)); named Best Survival Experience at the 2025 Roblox Innovation Awards, per a guide site ([earnaldo, affiliate](https://earnaldo.com/blog/die-of-death-vs-forsaken)) | Doors is the horror benchmark it is compared to. I found no 2026 data on Doors |
| **Bee Swarm Simulator** | Long-tail collect sim | No credible 2025–2026 data found | Inference: a 2018-era game still played, which shows how long collection sims can last |
| **(Break and) Steal an Egg**, **Huss Valley** | AI-built 2026 hits | Both reached the top 20 by CCU in Q3 2026 ([Roblox Q3 via WN Hub](https://wnhub.io/news/finance/item-52549)). A claimed 14.2M Q3 peak is unverified ([OtakuKart](https://otakukart.com/robloxs-steal-an-egg-reaches-6-billion-visits-and-14-2-million-peak-concurrent-players/)) | Steal-format clones keep charting |

### 2.2 Zombie and survival titles specifically

| Game | Format | Signal |
|---|---|---|
| 99 Nights in the Forest | Co-op PvE, survive N nights, campfire base | 14M peak. **The proof that survival-crafting works on Roblox.** |
| Dead Rails | Co-op PvE run: train, scavenge fuel, defend | Over 600K CCU at its 2025 peak, now declining. Its strongest content is reportedly earnable through free "Bonds" ([earnaldo, affiliate](https://earnaldo.com/blog/99-nights-in-the-forest-vs-dead-rails)) |
| Survive the Apocalypse (Rubicon South, 2026) | Wave defense, looting, base building | A fan wiki calls it "the 99 Nights zombie game" ([wiki](https://survive-the-apocalypse2026-wiki.pages.dev/)). Unverified scale |
| Apocalypse Rising 2 | Open-world PvPvE zombie survival (since 2017) | Long-lived niche. No reliable 2026 CCU found |
| Fallen Survival | Rust-like base raiding, servers of up to 100 | Niche, per an affiliate source ([earnaldo](https://earnaldo.com/blog/fallen-survival-vs-apocalypse-rising-2)) |
| Trident Survival | Movement-based PvPvE, build and defend a base | No data found |
| Project Delta | Hardcore extraction shooter | About 2K CCU now; 8K all-time peak in Oct 2026 ([RoWatcher](https://rowatcher.com/games/2862098693)). Sells "Delta Bux" skins |
| Those Who Remain | Wave-survival shooter | No 2026 data found |

**Inference:** On Roblox, survival scale comes from **co-op PvE with short, readable runs and a kid-safe scary tone.** Rust-style raiding and loot-loss extraction games stay at about 2K–tens of thousands of CCU. That matches the README's LDoE finding that harsh raid stakes shrink the active player base.

### 2.3 Platform context

- **Q3 2026:** bookings $1.7B (down 12% year on year), DAU down 9%, hours down 15%, monthly unique payers down 16% to 30.3M, bookings per DAU $12.29 ([WN Hub](https://wnhub.io/news/finance/item-52549)).
- **18+ players are the growth bet.** They are the fastest-growing group, and in the US they monetize more than 50% above younger players (same source).
- **AI tools are mainstream.** Over 80% of the top 100 games by hours used AI tools (same source).

**Inference:** The platform is shrinking while it pivots toward adults, so a game that can appeal to teens *and* adults is the best hedge.

---

## 3. Genre teardowns

Session length: I found no credible session data by genre. The descriptions below are **Inference** from how the games are built. GameAnalytics' cross-genre data is in §3.8.

### 3.1 Simulator / incremental (Pet Sim 99, BGSI, Bee Swarm)
- **Loop:** click or AFK to earn currency → hatch eggs → stronger pets → new zone → rebirth.
- **Retention:**
  - rebirth multipliers
  - updates every week or two
  - limited-time exclusive pets that become "permanently unobtainable" ([RoWatcher](https://rowatcher.com/news/pet-simulator-99-inside-roblox-s-most-aggressive-monetization-machine))
  - trading plazas and auction boards
- **Sold (PS99):**
  - Lucky pass, 275 R$
  - Ultra Lucky, 800 R$
  - Magic Eggs, 1,200 R$
  - Huge Hunter, 3,250 R$
  - about 8,075 R$ for all passes
  - exclusive eggs at about 400 R$
  - a "Forever Pack" whose price rises as you progress (same source)
- **Catalog size:** BGSI lists about 450 developer products ([Rotrends](https://rotrends.com/game/6504986360)).
- **Backlash:**
  - "more and more p2w" complaints
  - concern about gambling-like egg odds
  - power creep that cut some pets' value by about 40% overnight
  - NFT tie-in anger (same source)
- **What players accept:** the free path through every world. One BGSI review says the free path "remains genuine" despite heavy monetization ([earnaldo, affiliate](https://earnaldo.com/blog/bubble-gum-simulator-infinity-vs-pet-simulator-99)).

### 3.2 Tycoon / steal-tycoon (Steal a Brainrot, Steal an Egg)
- **Loop:** buy units from a conveyor → they earn passive income on your plot → steal other players' units in the same server → lock your base on a timer.
- **Retention:**
  - live in-server theft (social drama)
  - "admin abuse" events where the developer spawns luck boosts and lucky blocks on a schedule ([Chess.com review](https://www.chess.com/blog/robloxianmann/steal-a-brainrot-game-review))
  - cross-game "admin war" events, one of which drove the CCU records ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden))
- **Sold:** lucky blocks for Robux (Mythic, Brainrot God and Secret tiers), plus game passes ([allthings.how](https://allthings.how/steal-a-brainrot-lucky-blocks-explained-costs-odds-and-best-drops)).
- **Backlash:**
  - pay-to-win complaints
  - outrage at admin-abuse events
  - the Fortnite version's $40 loot boxes and gambling wheels drew press criticism ([Notebookcheck](https://www.notebookcheck.net/Fortnite-players-slam-Steal-the-Brainrot-microtransactions-as-gambling.1205005.0.html))
- **Inference:** In-server theft is a **raid loop for 8–13-year-olds**: short, live, low stakes, with lock timers. It is the closest proven Roblox analogue to LDoE raiding.

### 3.3 Collect-and-trade (Adopt Me!, Grow a Garden's pets)
- **Loop:** raise or hatch pets → trade up in rarity.
- **Retention:** trading value, limited-time pets, and FOMO (fear of missing out) from seasonal events.
- **Sold:** eggs, pets, potions and passes.
- **Risks:**
  - real-money trading on eBay and Discord breaks Roblox's rules ([Wikipedia GaG](https://en.wikipedia.org/wiki/Grow_a_Garden))
  - trading paid random items must be blocked in restricted regions (§4)
  - the 2026 age check for chat cuts chat use, and trading communities lean heavily on chat (§4)

### 3.4 Survival / horror co-op (99 Nights, Dead Rails, Doors, Forsaken)
- **Loop:** a run with friends or strangers → gather → craft → survive escalating nights or rooms → unlock classes and items for the next run.
- **Retention:**
  - weekly updates
  - themed events (99 Nights' Halloween event store with limited-time items)
  - a pre-release "Update Party" sandbox with players ([DevForum](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940))
  - co-play, which Roblox discovery explicitly rewards (§4)
- **Sold:**
  - Dead Rails: reportedly 4 passes and 13 products, with passes at about 148 R$ ([earnaldo, affiliate](https://earnaldo.com/blog/99-nights-in-the-forest-vs-dead-rails))
  - 99 Nights: classes and event items (exact list not verified)
- **Accepted:** clear one-off passes and a free path to the strongest gear.
- **Inference:** **Runs of about 15–25 minutes** fit GameAnalytics' best-retaining session band (§3.8).

### 3.5 Roleplay (Brookhaven)
- **Loop:** open-ended social play with houses, cars and jobs.
- **Sold:** vehicle and house passes and cosmetics. Roleplay also suits rewarded video best, as Brookhaven's ad earnings show.
- **Inference:** Weak monetization per player, offset by huge CCU. Not our lane, but houses and vehicles as **identity purchases** carry over.

### 3.6 Chill sims: fishing and gardening (Fish It!, Fisch, Grow a Garden)
- **Loop:** cast or plant → wait → collect rarities and mutations → sell → upgrade rod or plot.
- **Retention:**
  - offline growth
  - rotating seed stock with weekly exclusives you must be online to claim ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden))
  - **auto-fishing / AFK modes**, credited with Fish It! overtaking Fisch ([RoWatcher](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026))
- **Sold (Grow a Garden):** speed-ups, perks, and the ability to steal crops ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- **Backlash:**
  - Jacob Navok (ex-Square Enix) called it "somewhat evil" for paying to grow faster or to steal ([GamesRadar](https://www.gamesradar.com/games/simulation/former-square-enix-exec-says-viral-roblox-hit-grow-a-garden-is-somewhat-evil-do-you-wanna-pay-to-grow-this-faster-do-you-wanna-pay-to-steal-this-from-someones-garden))
  - a Jan 2026 piece says players felt it stopped "respecting their time" ([Roonby](https://roonby.com/2026/01/13/grow-a-garden-is-losing-players-is-it-finally-dead/))

### 3.7 Extraction / PvP survival (Project Delta, AR2, Fallen, Trident)
- **Loop:** deploy → loot → fight → extract or lose your gear; base raids in Fallen and Trident.
- **Sold:** cosmetic skins (Delta Bux).
- **Inference:** The adult-leaning audience these games attract is exactly who the 18+ uplift targets, but they stay small. Loot loss and griefing suit a minority of Roblox players.

### 3.8 Session length and retention benchmarks (GameAnalytics 2025 Roblox report)

GameAnalytics drew on thousands of games with over 1M MAU each, covering about 47% of Roblox engagement ([GameAnalytics](https://www.gameanalytics.com/reports/2025-roblox-report)):

| Avg session | D1 median / top 2% | D7 median / top 2% | ARPPU median / top 2% |
|---|---|---|---|
| 7–12 min | 7.9% / 15.8% | 0.9% / 3.6% | $0.77 / $4.48 |
| 13–18 min | 10.2% / 20.9% | 1.2% / 4.6% | $1.21 / $6.13 |
| **19–24 min** | **11.5% / 32.3%** | **1.6% / 8.5%** | **$1.71 / $31.09** |
| 25+ min | 10.8% / 25.4% | 1.8% / 7.0% | $2.12 / $15.87 |

- **Platform-wide (2025):**
  - median daily playtime 16.8 min; 95th percentile 93.8 min
  - median 2.0 sessions a day; 95th percentile 8
  - device mix: PC + mobile 48%, PC only 38%, console about 2%
- **Inference:** Design the core loop for **19–24 minute sessions with several returns a day** (timers that finish while you're away). That is LDoE's rhythm, cut shorter.

---

## 4. Platform rules and features in 2026

| Topic | Rule (source) | What it means for us |
|---|---|---|
| **DevEx** | $0.0038 per Robux ([Tubefilter](https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/)) | Developers keep about 26.6% of player spend in effect ([Q1 2026 letter](https://s27.q4cdn.com/984876518/files/doc_financials/2026/q1/Q1-2026-Earnings-Shareholder-Letter.pdf)) |
| **18+ uplift** | From Jun 8, 2026, spend by age-verified US 18+ players in **"novel" games** pays 37.8% instead of 26.6% (+42%). "Novel" means new genres, different mechanics, and a visual style distinct from classic Roblox. The game **must use R15 avatars** (15+ parts or joints). Eligibility is automatic and reviewed on an ongoing basis ([Roblox newsroom](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42), [Creator docs](https://create.roblox.com/docs/production/monetization/18-plus-devex-rate)). It covers passes, Robux subscriptions, select in-game items and private servers (Tubefilter). Novel games also get a **"Standout Games"** row on the Home page | **Use R15 and a distinct art style from day one.** It costs little and lifts both payout and discovery. |
| **Subscriptions** | Robux subscriptions since Apr 1, 2026. From 49 R$. Developer keeps 70%. Price can change every 60 days, with 30 days' notice for increases. Regional pricing is forced on ([DevForum](https://devforum.roblox.com/t/let-your-players-pay-for-subscriptions-within-experiences-in-robux/4552995)). Price optimization does not work on subscriptions ([docs](https://create.roblox.com/docs/production/monetization/price-optimization.md)) | A monthly "club" is viable. Keep its perks non-power. |
| **Rewarded video** | Creator must be 13+, ID-verified, with 2K+ monthly unique visitors. Viewers must be 13+. Roblox expects it to reach "up to 3%" of earnings early on. Native format required; third-party rewarded ads banned after the May 4 deadline ([DevForum](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678), [policy](https://devforum.roblox.com/t/new-advertising-policies-standards/4527365)) | A small extra: an opt-in "watch for 2× yield". |
| **Price optimization** | A/B tests prices for passes and developer products over about 2 weeks. Prices must be read from script, not hard-coded ([DevForum](https://devforum.roblox.com/t/introducing-price-optimization-find-the-best-prices-for-in-experience-items-and-passes/3186081), [docs](https://create.roblox.com/docs/production/monetization/price-optimization.md)) | Build the shop to read prices at runtime. |
| **Regional pricing** | Opt-in for passes since Apr 2025. VPN users see the highest price ([DevForum](https://devforum.roblox.com/t/introducing-regional-pricing-for-passes/3621382)) | Turn it on. Much of the audience is outside the US. |
| **Paid random items** | Show every outcome and its numeric odds before purchase, including indirect purchases (keys, spins). Luck boosts must state their effect and update the shown odds live. Where `ArePaidRandomItemsRestricted` is true, you must remove the item or offer an alternative (e.g., direct purchase at expected value). Where `IsPaidItemTradingAllowed` is false, paid items cannot be traded ([docs](https://create.roblox.com/docs/production/monetization/paid-random-items)) | Random rewards **earned** in play need no disclosure. Selling only non-random items avoids the whole compliance burden. |
| **Content maturity** | Minimal / Mild / Moderate / Restricted. **Mild** covers repeated mild violence, heavy *unrealistic* blood, and mild fear. **Moderate** covers realistic-looking non-graphic death and light realistic blood. **Restricted** (18+ verified) covers dismemberment and heavy realistic blood ([docs](https://create.roblox.com/docs/production/promotion/content-maturity)) | Stylized zombies whose bodies vanish or dissolve = **Mild**. |
| **Age-tiered accounts** | Kids (5–8): Minimal/Mild only. Select (9–15): up to Moderate. Roblox (16+): everything except Restricted ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select)). Globally available since Jun 2026 ([newsroom](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)) | Mild keeps all tiers open. Moderate loses the 5–8 tier. |
| **Under-16 publishing gate** | To reach Kids and Select, the creator needs ID or age verification, 2FA, and either a refundable fee or Plus/Premium held for 2 months. The game must pass an evaluation: 250 unique plays from highly engaged players in 60 days, plus a safety review. In effect since May 19 ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select), [DevForum](https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166)) | **A new game launches to 16+ only** until it qualifies. Plan a 16+ first impression. |
| **Chat age checks** | Players must pass a facial age estimate or ID check to chat (global since Jan 2026). Chat is limited to similar age bands. Roblox warns that chat use will drop ([DevForum](https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702), [PocketGamer.biz](https://www.pocketgamer.biz/roblox-rolls-out-mandatory-facial-age-checks-for-in-game-chat-worldwide)) | Build pings, emotes, quick-chat and trade UIs that work without chat. |
| **Discovery** | Recommendations now measure **28-day retention** (D1, D2–7, D8–28). qPTR (qualified play-through rate, the share of players who meaningfully engage) is split into separate play-through, session-quality and spend signals. Co-play is rewarded. Roblox warns against "exciting thumbnails" that don't deliver ([newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)) | **Helps** deep sims and co-op games. **Hurts** flash-in-the-pan fads. |

**Inference, policy net effect for sims:**
- **Helps:** 28-day retention signals, co-play signals, subscriptions, the 18+ uplift for distinct-looking games, and price optimization.
- **Hurts:**
  - chat age checks (trading and social coordination)
  - paid-random and trading restrictions by region (egg and trade economies)
  - the under-16 gate (slower launch reach)
  - a shrinking payer base (down 16%)

---

## 5. Visual and animation standards

**What the evidence shows:**
- **Mega-hits are not visually premium.**
  - Grow a Garden's first build took about 3 days. Kotaku said it looked more like a prototype than a finished game ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
  - Brainrot games use meme assets.
  - Their success came from loops, social virality and timing.
- **The best survival hit is cohesive rather than high-end.** 99 Nights:
  - aims for "spooky but kid-friendly", and the team debated how scary its deer mascot should be
  - bases its buildings on real-world references
  - keeps part, vertex and instance counts low so it runs on mobile
  - built it with one dedicated builder/modeller, one extra artist and one animator ([DevForum](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940))
- **Studios run style guides per game.** A studio's lead-artist job ad asks for a style guide per game that is "stylized or blocky, readable on a phone screen", plus thumbnail work measured on click-through and play-through ([job listing](https://vn.joboko.com/viec-lam-roblox-lead-artist-xvi6796545)).
- **Roblox is now paying for visual distinctiveness.** The 18+ uplift requires a visual style "distinct from classic Roblox" and R15 rigs. Roblox's "Reality" AI upscaler targets photoreal output, but early form is not expected until about 2027 and Roblox admits it is costly ([MMOHuts](https://mmohuts.com/news/roblox-says-its-new-ai-powered-reality-upscaler-could-arrive-in-early-form-by-2027), [PCGamesN](https://www.pcgamesn.com/roblox/reality-ai-multiplayer-upscaling)).
- **Thumbnails get you the click; the game has to keep the player.** Roblox's thumbnail personalization tests thumbnails automatically, but its later reported gains were small (+0.19% qPTR) ([DevForum](https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665)). Discovery penalizes games that don't hold players after the click.
- **Team and budget scale:**
  - 99 Nights: about 5 people
  - Uplift Games: about 40 (unverified)
  - KreekCraft reportedly spent over $100K on one Roblox game ([Tubefilter](https://www.tubefilter.com/2026/03/09/kreekcraft-has-spent-over-100000-making-a-roblox-game-whats-the-roi-for-developers/amp/))
  - the top 100 developers averaged about $7M a year and the median about $1,440, from Jun 2024 to Jul 2025 ([Game World Observer](https://gameworldobserver.com/2025/09/08/how-much-top-developers-earn-in-roblox-official-data))

**Inference, what "high quality" means on Roblox in 2026:**

| Pillar | Standard |
|---|---|
| **Style** | Stylized "toon-PBR" dominates quality titles: simple shapes, hand-tuned color, PBR roughness and metalness for material read, strong rim and atmosphere lighting (Future lighting). Realism is rare and risky on mobile. Blocky low-poly is for fads. |
| **Consistency** | One palette with value ranges for friend, foe and loot. Fixed texel density. Modular building kits (walls, props) made by one hand. Silhouette-first enemies. |
| **Animation** | One R15 animation set shared by every tool: idle, run, gather, chop, craft, swing, aim, hit-react, downed and revive. Custom animations on R15 rigs, not default Roblox ones. Readable anticipation frames on mobile. |
| **UI** | A single UI kit (buttons, panels, icons) with the same corner radius, stroke and icon style everywhere. Tap targets sized for phones. Juice on every reward: pop, sparkle, sound. |
| **Performance** | Low instance counts, streaming enabled, LODs. **Frame rate on a mid-range phone beats fidelity.** |

---

## 6. Mapping LDoE's loop onto Roblox

| LDoE pillar | Roblox analogue | Fit | Notes |
|---|---|---|---|
| **Gather → craft → build a base** | 99 Nights (campfire, crafting bench); tycoon plots | ✅ Strong | Keep crafting trees shallow: 3–4 tiers per item line. Show visible upgrades on the base, because base pride drives return visits. |
| **Timed production** (smelter, garden) | Grow a Garden's offline growth and rotating stock | ✅ Strong | The best "come back later" hook. Sell **extra queues or slots**, not skips. Paid skips drew the "somewhat evil" criticism. |
| **Risky runs into dangerous zones** | Dead Rails runs, 99 Nights' Cultist Stronghold, Doors | ✅ Strong if co-op and short | 10–20 minute expeditions. Losing a little carried loot is fine. Losing everything is not, for this audience. |
| **Vehicles and long goals** | Dead Rails train, "a dusty trip" car, Brookhaven vehicles | ✅ Good | A shared vehicle the group upgrades is a co-op long goal and an identity item to sell (skins). |
| **Raids** | Steal a Brainrot's in-server theft with lock timers; Fallen and Trident base raids | ⚠️ Partly | In-server, live, low-stakes theft is proven at huge scale. Persistent offline raids with total loss (Rust or LDoE style) are proven only for niche audiences. |
| **Energy meter, revives for sale, VIP power** | PS99 luck passes, GaG speed-ups | ❌ Avoid | Earns money, but it is what the developer quit LDoE over. Roblox's 28-day retention signal also rewards fairness over time. |
| **Long solo grind to level 150** | Blox Fruits | ⚠️ | Works for anime RPGs. For us, split long goals into weekly milestones. |

---

## 7. Original concepts

All prices are example Robux prices. At the base rate of about 26.6% effective share, 100 R$ of player spend nets the developer about $0.27. The **fairness rule** for every concept: *nothing that can be stolen or raided is sold; no paid randomness; no paid revives or energy.*

### Concept A: "Ember Outpost" (co-op night-defense base sim)
- **Core loop:**
  - 1–8 players share an outpost.
  - **Day:** 8–12 minute scavenging runs into fog zones.
  - **Night:** defend the outpost against a horde wave.
  - **Between nights:** craft, and upgrade the campfire, walls and turrets.
  - A personal **home workshop** produces on timers while you're offline.
  - **Long goal:** restore a radio tower to unlock new biomes.
- **Hooks:**
  - a night-streak counter
  - visible outpost growth
  - classes unlocked through events
  - rescued **survivor companions** who staff stations (collection without gacha)
  - weekly "blood-moon" event nights
- **IAPs:**

  | Item | Price | Type |
  |---|---|---|
  | Workshop 2nd and 3rd queue | 199 / 299 R$ | Pass |
  | Outpost theme packs (wall, fire, flag skins) | 149–399 R$ | Cosmetic, direct purchase |
  | Weapon and tool skins | 79–249 R$ | Cosmetic |
  | Starter kit (outfit plus a small material bundle, once) | 99 R$ | Product |
  | "Survivor Club" subscription (monthly cosmetic token, name tag, +1 queue) | 299 R$/mo | Subscription |
  | VIP private server | 100–200 R$/mo | Private server |
  | Rewarded video: 2× scavenge yield for 15 min (13+ only) | free | Ad |

- **Art:** warm firelight against cold blue fog. Stylized toon-PBR. Zombies with chunky silhouettes that dissolve into ash on death, which keeps the game **Mild**.
- **Scope:** **Inference:** 1 developer plus 1 contract artist plus a contract animator. MVP of one biome in about 10–14 weeks.
- **Risks:** too close to the 99 Nights format, so it needs a distinct hook (the workshop and companions). Balancing waves for groups of 1–8.

### Concept B: "Rust Bucket Caravan" (vehicle expedition plus home-yard tycoon)
- **Core loop:**
  - The crew drives an armored rig along a route of dangerous stops.
  - Loot scrap and fuel at each stop.
  - Back at your **home yard** (a tycoon plot), machines turn scrap into parts over time.
  - Parts upgrade the rig: armor, turrets, a sleeper cab.
  - **Long goal:** reach "the coast". Seasonal routes reset; yards do not.
- **Hooks:**
  - the rig is shared group pride
  - the yard runs offline
  - route-of-the-week modifiers
- **IAPs:**
  - rig paint and decal packs, 149–399 R$
  - horn and radio sound packs, 49–99 R$
  - an extra garage bay to keep a second rig build, 249 R$
  - yard theme packs, 199 R$
  - the subscription and VIP server as in Concept A
- **Art:** dusty desert-scrap look, sun-bleached palette, readable hazard colors.
- **Scope:** vehicle physics on Roblox is the hard part. **Inference:** about 14–18 weeks.
- **Risks:** the vehicle-run format is crowded (Dead Rails, a dusty trip), and players may file it as a clone.

### Concept C: "Blight Garden" (post-apocalyptic chill sim with light theft)
- **Core loop:**
  - Grow mutated crops in a walled greenhouse. They grow in real time, including offline.
  - Sell crops to fund new seed strains.
  - At dusk, comic "Blighters" raid crops. Defensive plants fight back.
  - Other players in the server can sneak in to snip one crop when your **shield timer** is down.
- **Hooks:**
  - mutations and weather
  - a weekly exclusive strain earned **in play**
  - collection logs
  - a light, funny theft loop
- **IAPs:**
  - greenhouse themes, 149–399 R$
  - sprinkler auto-water pass, 199 R$ (convenience; growth speed unchanged)
  - plot-expansion **cosmetic** rows (layout, not yield), 99 R$
  - shield cosmetics, 79 R$
  - the subscription
  - no paid seed packs
- **Art:** saturated toon, rusted metal and glass, glowing mutated plants. The **broadest audience** (Mild).
- **Scope:** the smallest. **Inference:** about 8–10 weeks to MVP.
- **Risks:** furthest from the LDoE fantasy. The garden genre is saturated, and Grow a Garden 2 is already live.

### Concept D: "Holdfast Rush" (session-based raid tycoon)
- **Core loop:**
  - Each server runs a 40–60 minute "claim rush".
  - Scavenge, build a fort quickly, and run timed production.
  - **Siren windows** open raids: your noise draws zombies, as LDoE's noise meter does.
  - Loot is kept as season points, not wealth that can be lost.
  - **Persistent layer:** blueprint unlocks and cosmetics.
- **Hooks:** live PvP drama, as in Steal a Brainrot, with no offline loss. Leaderboards. Weekly seasons.
- **IAPs:**
  - fort skins and raid emotes, 99–399 R$
  - extra blueprint save slots, 149 R$
  - VIP servers for clan scrims, 200 R$/mo
  - battle-pass-style **cosmetic** track, 399 R$ per season
- **Art:** chunky readable forts, team colors, strong VFX for breaches.
- **Scope:** networking and anti-exploit are hard. **Inference:** about 16–20 weeks.
- **Risks:** toxicity, frustration for young players, and the need for full servers.

---

## Recommendations for our game

1. **Build co-op PvE first; leave raiding as a later, opt-in mode.** 99 Nights' 14M peak against Project Delta's 8K peak is the clearest signal in this research.
2. **Lead with Concept A (Ember Outpost)**, then fold in Concept C's offline workshop and Concept D's siren raids later. It keeps LDoE's gather → craft → build → risk loop at Roblox session lengths.
3. **Target 19–24 minute sessions with timers that bring players back 2–3 times a day.** That is the best-retaining band in GameAnalytics' data.
4. **Stay at the Mild rating.** Use stylized zombies, deaths that dissolve or vanish, and no realistic blood. That keeps the Kids, Select and 16+ tiers open. Pass the under-16 evaluation early: ID, 2FA, then 250 engaged plays.
5. **Use R15 avatars and a distinct stylized toon-PBR look from day one.** This qualifies for the 42% higher payout on US 18+ spend and the "Standout Games" row. Write a one-page style guide, a shared animation set and a UI kit before mass-producing assets.
6. **Monetize with:**
   - production queues or slots
   - cosmetic base, vehicle and weapon skins (visible to others)
   - a 299 R$ monthly club
   - VIP servers
   - opt-in rewarded ads

   **Never sell** revives, energy, luck, raidable loot, or paid random boxes. That also removes the odds-disclosure and regional-restriction work.
7. **Read all prices from script** so Price optimization can A/B test them. Turn on regional pricing.
8. **Design for players who can't chat:** pings, emotes, quick-chat wheel, and party-finder.
9. **Ship weekly updates with event nights.** Hold an "Update Party"-style playtest with players before each one.
10. **Prototype in 4–8 weeks** (as recommended in platform-economics.md) and judge it on D1, D7 and D28 retention against Roblox's similar-game benchmarks, not CCU peaks.

---

## Sources

**Roblox (primary)**
- [Creator Hub: paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- [Creator Hub: content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- [Creator Hub: Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)
- [Creator Hub: U.S. 18+ exchange rate](https://create.roblox.com/docs/production/monetization/18-plus-devex-rate)
- [Creator Hub: price optimization](https://create.roblox.com/docs/production/monetization/price-optimization.md)
- [Creator Hub: subscriptions](https://create.roblox.com/docs/en-us/production/monetization/subscriptions)
- [Newsroom: 18+ DevEx uplift and high-fidelity games](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42)
- [Newsroom: Kids and Select accounts globally available](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)
- [Newsroom: optimizing discovery (2026)](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
- [Q1 2026 shareholder letter](https://s27.q4cdn.com/984876518/files/doc_financials/2026/q1/Q1-2026-Earnings-Shareholder-Letter.pdf)
- [DevForum: Robux subscriptions](https://devforum.roblox.com/t/let-your-players-pay-for-subscriptions-within-experiences-in-robux/4552995)
- [DevForum: rewarded video expansion](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)
- [DevForum: new advertising policies](https://devforum.roblox.com/t/new-advertising-policies-standards/4527365)
- [DevForum: price optimization](https://devforum.roblox.com/t/introducing-price-optimization-find-the-best-prices-for-in-experience-items-and-passes/3186081)
- [DevForum: regional pricing for passes](https://devforum.roblox.com/t/introducing-regional-pricing-for-passes/3621382)
- [DevForum: new publishing requirements](https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166)
- [DevForum: age checks for chat](https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702)
- [DevForum: recommendation algorithm and long-term retention](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)
- [DevForum: thumbnail personalization update](https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665)
- [DevForum: 99 Nights creator spotlight](https://devforum.roblox.com/t/creator-spotlight-the-story-behind-99-nights-in-the-forest/4036940)

**Data and analysis**
- [GameAnalytics: 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report)
- [GameAnalytics: Dead Rails and the hit makers' formula](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)
- [WN Hub: Roblox Q3 2026](https://wnhub.io/news/finance/item-52549)
- [Game World Observer: official developer earnings](https://gameworldobserver.com/2025/09/08/how-much-top-developers-earn-in-roblox-official-data)
- [Tubefilter: 18+ DevEx](https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/)
- [Tubefilter: KreekCraft's $100K game](https://www.tubefilter.com/2026/03/09/kreekcraft-has-spent-over-100000-making-a-roblox-game-whats-the-roi-for-developers/amp/)
- [PocketGamer.biz: chat age checks](https://www.pocketgamer.biz/roblox-rolls-out-mandatory-facial-age-checks-for-in-game-chat-worldwide)

**Games and press**
- [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden)
- [Wikipedia: Adopt Me!](https://en.wikipedia.org/wiki/Adopt_Me!)
- [PCGamesN: top-earning games, Jan 2026](https://www.pcgamesn.com/roblox/highest-revenue-jan-2026)
- [PCGamesN: Roblox Reality cost](https://www.pcgamesn.com/roblox/reality-ai-multiplayer-upscaling)
- [GamesRadar: "somewhat evil"](https://www.gamesradar.com/games/simulation/former-square-enix-exec-says-viral-roblox-hit-grow-a-garden-is-somewhat-evil-do-you-wanna-pay-to-grow-this-faster-do-you-wanna-pay-to-steal-this-from-someones-garden)
- [Roonby: Grow a Garden player loss](https://roonby.com/2026/01/13/grow-a-garden-is-losing-players-is-it-finally-dead/)
- [TheWrap: 99 Nights film](https://www.thewrap.com/creative-content/movies/20th-century-studios-roblox-game-99-nights-in-the-forest/)
- [Notebookcheck: Steal the Brainrot microtransactions](https://www.notebookcheck.net/Fortnite-players-slam-Steal-the-Brainrot-microtransactions-as-gambling.1205005.0.html)
- [Chess.com: Steal a Brainrot review](https://www.chess.com/blog/robloxianmann/steal-a-brainrot-game-review)
- [allthings.how: lucky blocks](https://allthings.how/steal-a-brainrot-lucky-blocks-explained-costs-odds-and-best-drops)
- [MMOHuts: Roblox Reality timing](https://mmohuts.com/news/roblox-says-its-new-ai-powered-reality-upscaler-could-arrive-in-early-form-by-2027)
- [Lead-artist job listing](https://vn.joboko.com/viec-lam-roblox-lead-artist-xvi6796545)

**Trackers (estimates, lower reliability)**
- RoWatcher:
  - [March 2026 top 10](https://rowatcher.com/news/top-10-roblox-games-by-players-march-2026-data-breakdown)
  - [Pet Simulator 99 monetization](https://rowatcher.com/news/pet-simulator-99-inside-roblox-s-most-aggressive-monetization-machine)
  - [Fish It!](https://rowatcher.com/news/fish-it-reels-in-270k-players-inside-roblox-s-most-addictive-casual-game-of-2026)
  - [Forsaken](https://rowatcher.com/news/forsaken-s-floral-update-drives-the-survival-horror-hit-past-86k-players)
  - [Dead Rails](https://rowatcher.com/games/7018190066/dead-rails/dying)
  - [Project Delta](https://rowatcher.com/games/2862098693)
- [Rotrends: BGSI](https://rotrends.com/game/6504986360)
- [profitable.app: Fish It!](https://profitable.app/roblox/games/fish-it)
- [StudioKrew: August 2026](https://studiokrew.com/blog/top-roblox-games-august-2026/)
- [OtakuKart: Steal an Egg](https://otakukart.com/robloxs-steal-an-egg-reaches-6-billion-visits-and-14-2-million-peak-concurrent-players/)
- [The Spike: player counts](https://www.thespike.gg/roblox/beginner-guides/how-to-check-roblox-player-count)
- earnaldo.com (affiliate):
  - [Dead Rails vs 99 Nights](https://earnaldo.com/blog/99-nights-in-the-forest-vs-dead-rails)
  - [BGSI vs PS99](https://earnaldo.com/blog/bubble-gum-simulator-infinity-vs-pet-simulator-99)
  - [Fallen vs AR2](https://earnaldo.com/blog/fallen-survival-vs-apocalypse-rising-2)
  - [Forsaken](https://earnaldo.com/blog/die-of-death-vs-forsaken)
- [Survive the Apocalypse fan wiki](https://survive-the-apocalypse2026-wiki.pages.dev/)
