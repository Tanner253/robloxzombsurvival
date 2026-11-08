# Fair Monetization Playbook for a Raid-PvP Survival Game

> Research dimension: monetization models that players accept in survival / PvP / persistent-world games, the platform and legal rules as of November 2026, benchmark metrics, and a draft "fair monetization charter".
> Compiled: 2026-11-07. Live-service details change often. Every dated figure below carries its date and source. **Inference:** marks my own analysis, not a sourced fact.

**Method note and limits.** I ran web searches until the shared search budget ran out, then fetched primary pages directly: Apple and Google developer pages, PEGI, Facepunch, Steam, App Store listings, Wikipedia, Sensor Tower and trade press. Reddit (old.reddit.com) could not be fetched, so there are no first-hand Reddit threads here. I also could not watch YouTube videos, and I did not find a current breakdown of LDoE's store (season pass or subscription prices). See "Gaps" at the end.

---

## TL;DR

1. **In a raid game, selling power means selling the result of someone else's loss.** A raid moves wealth from one player to another. If money buys raid tools, defenses or time, payers effectively farm non-payers. Non-payers then quit, and the people worth raiding go with them. The clearest PvP-specific backlashes all involved selling an edge in a competitive mode: Star Wars Battlefront II (2017), Escape from Tarkov's $250 "Unheard Edition" (2024) and Diablo Immortal (2022).
2. **Pay-to-win still makes money, so be honest about the trade-off.** Diablo Immortal hit a 0.2/10 Metacritic user score and still earned more than $100M in eight weeks (Sensor Tower, via Wikipedia). LDoE earned roughly $182K-$263K a week in the US alone in Q4 2023 (Sensor Tower; no newer US figure was checked). Fair monetization is a strategic bet on retention, word of mouth and streamability. It is not a free lunch.
3. **Fair models with real commercial proof:** Rust (premium price plus cosmetics: 9M copies and $142M revenue by Dec 2019, then 20M+ on Steam by mid-2025), Fortnite (cosmetic-only: about $9B by end of 2020), DayZ (premium plus map DLC), Palworld (premium: 15M Steam copies in about a month), and Once Human (free-to-play; praised at launch for an almost hidden shop).
4. **Platform economics shifted in 2025-2026, in our favor.**
   - **US iOS:** Apple currently takes **0% commission on purchases made through external purchase links**. This has held since April 30, 2025, and the rate is being re-litigated, including at the Supreme Court, where Apple was granted review in June 2026.
   - **Google Play:** a new fee schedule started June 30, 2026 (US/UK/EEA): **10% on subscriptions**, 10% on a developer's first $1M a year, and 20% on standard one-off purchases for new installs, plus a 5% billing fee when Google Play Billing is used.
   - **EU iOS:** new unified terms from Oct 1, 2026.
5. **Loot boxes are now a regulatory liability almost everywhere.**
   - Brazil bans selling them to minors (from March 2026).
   - PEGI rates games with paid random items **16+ by default** (from June 2026) and, from October 2026, is re-rating existing digital-only games rated PEGI 3/7/12 that contain them.
   - Australia sets a minimum of M (since Sept 2024).
   - Belgium treats them as gambling.
   - The US FTC fined HoYoverse $20M (Jan 2025).
   - Jagex removed RuneScape's Treasure Hunter in Jan 2026 after 120,000+ players voted for removal.

   Recommendation: **no paid randomness at all.**
6. **Recommended model (Inference):** free-to-play with a cosmetic-only shop, a cosmetic season pass you can earn back, an optional "Supporter" subscription limited to cosmetics, convenience that gives no power, and private-server perks, plus paid **private / rented servers**. Use a web shop to raise margins where the law allows it (US, EU, Japan), and add Twitch-style viewer drops because raids make good stream content. Never sell anything that changes the outcome of a raid.

---

## 1. Why pay-to-win is especially toxic in raid-PvP games

### 1.1 The mechanism (Inference, grounded in the cases below)

| Property of raid-PvP | What happens if you sell power or time |
|---|---|
| Loss is real: a raid moves stored wealth from defender to attacker | Every purchase of raid tools, explosives, wall tiers or protection is a purchase *against another player's base*. In PvE the victim is a zombie; here the victim is a customer. |
| The other players are the content | When non-payers learn they can't win, they stop playing. Payers then run out of people worth raiding, and the "Rust-like highlight" disappears. |
| Outcomes are visible and shared (killfeeds, raid logs, streams) | Players attribute a loss to the attacker's wallet rather than their own skill or planning, which is the most corrosive kind of loss. |
| Persistence compounds advantage | A one-time boost in a match-based game lasts one match. In a persistent world it lasts for the whole wipe or the life of the account. |
| Free accounts are cheap to replace | Free-to-play plus power for sale lowers the cost of cheating and alt accounts in a game where cheaters steal real progress. |

**Inference:** LDoE gets away with selling time and power (energy, boxes, coins) partly because its PvP raiding is mostly asynchronous and rarely involves an active human defender. That is the very thing the developer dislikes. **The more we make raiding a real, Rust-like highlight, the less room there is to sell power.** The two goals are coupled.

### 1.2 Evidence that selling an edge in PvP backfires

- **Star Wars Battlefront II (2017).** Loot boxes gave paying players gameplay advantages in multiplayer.
  - EA's reply, "a sense of pride and accomplishment", became the most downvoted comment in Reddit history (more than -667K).
  - EA switched off microtransactions the day before launch, and its stock lost about $3B in value by the end of November 2017.
  - It sold 9M copies against a 10M target, and EA blamed the loot crate controversy.
  - Belgium opened a gambling investigation. In March 2018 the game moved to cosmetic-only purchases with linear progression. ([Wikipedia](https://en.wikipedia.org/wiki/Star_Wars_Battlefront_II_(2017_video_game)))
- **Escape from Tarkov "Unheard Edition" (April 2024).** A **$250** edition bundled a PvE mode with PvP bonuses.
  - Critics called it pay-to-win (the specific PvP perks were not itemized in the sources fetched during fact-check). Owners of the earlier top-tier edition revolted, and Battlestate locked down most of its Discord channels (unverified).
  - The studio apologized, gave earlier buyers PvE access, but kept selling the edition. ([PCGamesN](https://www.pcgamesn.com/escape-from-tarkov/apology), [GamesRadar](https://gamesradar.com/games/fps/this-cannot-be-tolerated-escape-from-tarkov-community-in-meltdown-over-dollar250-edition-with-exclusive-pve-mode-as-a-131-word-chant-consumes-the-official-discord), [TechSpot](https://www.techspot.com/news/102757-escape-tarkov-developer-offers-250-pay-win-dlc.html))
  - **Lesson:** in a looter-PvP game, even indirect advantages such as stash size or edition perks read as pay-to-win.
- **Diablo Immortal (2022).**
  - Maxing one character was estimated at about $100K by Bellular News, and later player estimates ran to $300K-$600K.
  - The PC Metacritic user score fell to 0.2, the lowest ever recorded.
  - It was not released in Belgium or the Netherlands, which have tighter loot box rules.
  - It still earned more than $100M in its first 8 weeks (Sensor Tower). ([Wikipedia](https://en.wikipedia.org/wiki/Diablo_Immortal))
  - **Lesson:** pay-to-win can work as a short-term business while destroying the brand's goodwill.
- **LDoE itself.**
  - In 2017 PocketGamer.biz described the store as optional and well integrated: $0.99 survival packs, coins, and energy refills for coins or an ad (15 energy per video). ([PocketGamer.biz, Oct 2017](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/))
  - Current App Store reviews say energy limits for map travel and ads can feel pay-to-win, though one reviewer says the game has become more free-to-play friendly. ([App Store US listing](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094), fetched 2026-11-07)
  - Third-party summaries widely describe the game as pay-to-win, and a TapTap review cites energy timers and blocked progression. These sources are aggregators, so low confidence.

---

## 2. Monetization models: how each works, the evidence, and the fit for us

### 2.1 Cosmetic-only: Rust skins, the item store and Twitch drops; Fortnite

- **Rust.**
  - The base game costs **$39.99** on Steam. Paid DLC packs (Instruments, Sunburn, Voice Props, Warhammer 40,000) cost $9.99-$12.99 each.
  - An in-game **item store** sells skins at $2.99-$12.99 (Steam page fetched Nov 2026).
  - Reviews: Very Positive, **86% of ~535K** reviews (English-language reviews; $39.99 is the regular price, the game was on sale when re-checked). ([Steam](https://store.steampowered.com/app/252490/Rust/))
  - Rust was the first Steam game to use Valve's Item Store (Nov 2015).
  - Facepunch reported **9M copies and $142M revenue by Dec 2019**, and about 12.5M copies by the end of 2021. ([Wikipedia](https://en.wikipedia.org/wiki/Rust_(video_game)), [80.lv](https://80.lv/articles/rust-sales-reached-over-12-4-million-units))
  - Facepunch's mid-2025 recap reported **20M+ copies on Steam alone**. ([KitGuru](https://www.kitguru.net/desktop-pc/mustafa-mahmoud/rust-has-sold-over-20-million-copies-on-steam-alone/))
  - Skin creators had been paid more than $1M by Nov 2017 (Garry Newman, reported by [PCGamesN](https://www.pcgamesn.com/rust/rust-skin-creators-paid-1m)). No newer skin revenue figure is public.
- **Rust Twitch drops.**
  - Introduced Nov 2020: watch any Rust stream for 1h, 3h or 6h to earn three skins. ([Rust blog](https://rust.facepunch.com/blog/rust-twitch-drop))
  - Drops are **account-bound and cannot be traded**, require owning Rust, and can't be earned once a campaign ends. Some drops come from watching specific streamers. ([Facepunch wiki](https://wiki.facepunch.com/rust/twitch-drops))
  - **Inference:** drops turn streamers into a marketing channel, and raids are the most streamable moment in the genre. They cost nothing in balance.
  - A Rust caveat: some DLC adds functional deployables, such as instruments and pool items. Whether that counts as "power" is debated. I could not fetch the Reddit debates to quantify it.
- **Fortnite.**
  - Revenue came from cosmetics, a seasonal battle pass, and since Dec 2020 the **Fortnite Crew** subscription (battle pass, a monthly V-Bucks allowance and exclusive cosmetics).
  - SuperData estimated $2.4B in 2018 and $1.8B in 2019. Total Fortnite revenue passed $9B by the end of 2020. ([Wikipedia](https://en.wikipedia.org/wiki/Fortnite_Battle_Royale))
- **Fit:** excellent for raid-PvP, provided cosmetics don't affect visibility (see the charter). The weak spot is that cosmetic revenue scales with audience size and art output, not with spending depth.

### 2.2 Battle passes and season passes in survival games

- Fortnite showed the format: a free track plus a paid track, with tiers you can skip by paying. ([Wikipedia](https://en.wikipedia.org/wiki/Fortnite_Battle_Royale))
- **Once Human** (Starry Studio / NetEase, July 2024): free-to-play with roughly six-week seasonal resets. Characters return to level 1, while blueprints, some currencies and materials carry over. ([Kotaku, Jul 2024](https://kotaku.com/once-human-steam-reviews-server-season-reset-cosmetic-1851592897))
  - At launch, players found the shop so unobtrusive they had to "hunt through [the menus] to find the shop" (Reddit, quoted by TheGamer). ([OpenCritic/TheGamer, Jul 2024](https://opencritic.com/news/2929/once-human-not-given-the-praise-its-due-for-monetization))
  - Then **two self-inflicted wounds**:
    - Paid cosmetics were bound to a single character instead of the whole account. A fix was promised for August. ([Kotaku](https://kotaku.com/once-human-steam-reviews-server-season-reset-cosmetic-1851592897))
    - The Aug 29, 2024 patch sold the summer cosmetic set **through loot boxes**, prompting boycott threats. ([Mein-MMO, Aug 2024](https://mein-mmo.de/once-human-loot-boxen-problem/))
- **Inference:**
  - Passes work in wipe-based survival because each wipe is a natural season.
  - The pass must hold cosmetics only. If it holds resources or boosts, it becomes pay-to-win on a timer.
  - PEGI's 2026 criteria put **"penalties for not returning" at a PEGI 12 minimum**, so avoid passes whose rewards are lost if you miss days. Use a pass that progresses at your own pace and doesn't expire, or one with generous catch-up mechanics. ([PEGI, Mar 2026](https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories))

### 2.3 Subscriptions with quality-of-life benefits

- **ARK: Ultimate Mobile Edition** (Dec 18, 2024): the base game is free. The **ARK Pass** costs **$4.99 a month or $49.99 a year** (EU €5.99 / €59.99) and unlocks all current and future expansion maps, monthly in-game "keys", bonus XP, single-player console commands and **subscriber-only servers**.
  - Expansions can also be bought one by one (€3.49-€11.99). "Keys" currency is sold from €1.09 for 100 up to €31.99 for 5,000. ([Wccftech](https://wccftech.com/ark-ultimate-mobile-edition-coming-to-ios-android-today-free-to-play), [ARK wiki](https://ark.wiki.gg/wiki/Ultimate_Mobile_Edition))
  - No revenue data found.
  - **Inference:** bonus XP inside a subscription would be pay-to-win in our game.
- **Albion Online** (full-loot PvP sandbox, free-to-play since April 2019): premium status can be bought with in-game currency, and the economy is fully player-crafted. It has 5M+ registered users. ([Wikipedia](https://en.wikipedia.org/wiki/Albion_Online))
  - **Inference:** letting non-payers earn premium status through play makes a subscription feel fair. The price is that payers can effectively convert cash into in-game currency, which matters in a full-loot game.
- **RuneScape:** membership since 2002. Since 2013, Bonds (bought with real money, tradable between players, redeemable for membership) have been Jagex's legal answer to real-money trading. ([Wikipedia](https://en.wikipedia.org/wiki/RuneScape))
- **Platform economics favor subscriptions:**
  - Google Play charges **10% on recurring purchases** under its new 2026 schedule (plus a 5% billing fee if Google Play Billing is used). ([Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/16954621))
  - Apple drops its commission on auto-renewing subscriptions after the first year: to 15% on standard in-app purchase (including EU Apple IAP under the Oct 2026 terms). In the EU, 10% applies only to alternative payment processing and link-outs. In Japan it is 10% commission, plus Apple's 5% payment-processing fee when Apple IAP is used. ([Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/), [Apple EU](https://developer.apple.com/support/dma-and-apps-in-the-eu/))
- **Fit:** good, as long as subscription perks are cosmetic, social or hosting-related. They must not be XP, gathering rates, storage or protection.

### 2.4 Premium (buy-to-play) plus cosmetics or DLC

- **Rust:** see 2.1. **Palworld:** early access in Jan 2024, 15M Steam copies and 10M Xbox players by Feb 22, 2024, and 32M+ players by Feb 2025. ([Wikipedia](https://en.wikipedia.org/wiki/Palworld))
- **DayZ:**
  - Livonia launched as a $30 DLC and was later folded into the base game, with the price rising from $40 to $49.99.
  - The **Frostline** map DLC (Sakhal, $26.99, Oct 2024) was review-bombed over its price. Bohemia's CEO replied that the studio earns under 10 cents per hour of online play across about 8M Steam users, and that nobody has to buy it. ([Wikipedia](https://en.wikipedia.org/wiki/DayZ_(video_game)))
  - **Inference:** paid maps split the player base, and in PvP they also split the pool of raid targets.
- **ARK: Survival Ascended:** charging for a remaster that had been described as a free upgrade caused backlash. It has still sold 4M copies (as of May 2, 2026). ([Wikipedia](https://en.wikipedia.org/wiki/Ark:_Survival_Ascended))
- **Inference, and important for raid games:** an upfront price works as an **anti-cheat and anti-alt-account deposit**. A banned cheater has to pay again. That is one reason premium PvP sandboxes (Rust, DayZ, Tarkov) can run hard full-loot PvP. Free-to-play raid games need stronger anti-cheat and probably account trust tiers.
- **Fit:** strong on PC and console. Weak on mobile, where our competitors (LDoE, Zombix) are free and paid mobile games sell far fewer copies. I did not find a current premium-mobile benchmark.

### 2.5 Server hosting, private servers and community servers

- Facepunch's **Community Server and Hosting Guidelines** (updated July 15, 2025, covering all Facepunch games) **allow** server owners to:
  - charge **one-time or subscription access fees**
  - accept donations
  - sell cosmetics, effects or "enhancements"
  - run their own currency
  - show ads and sponsorships

  Owners must label servers as unofficial and may not give away or bypass Facepunch's paid content. No explicit pay-to-win rule exists. ([Facepunch](https://facepunch.com/legal/servers))
- DayZ: most servers are community-run, from near-vanilla to heavily modded. ([Wikipedia](https://en.wikipedia.org/wiki/DayZ_(video_game)))
- ARK Mobile sells **subscriber-only servers** as a subscription perk. ([Wccftech](https://wccftech.com/ark-ultimate-mobile-edition-coming-to-ios-android-today-free-to-play))
- **Inference:**
  - Renting private servers (custom loot rates, PvE-only, friends-only, scheduled raid windows) is the **cleanest "power" anyone can sell**. Buyers pay for a different ruleset, not an edge over strangers.
  - It also pays for itself, because server costs scale with players.
  - **Risk:** rented servers with boosted rates must never feed progress back into official servers.

### 2.6 Rewarded ads

- LDoE has used rewarded video since at least 2017 (energy for an ad, free food from a "Healer" character in exchange for watching an ad). ([PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/))
- Midcore case study (Bytro Labs strategy games, via GameBiz Consulting): adding rewarded video and ad towers raised **ARPDAU by up to 32.9%** and **iOS D3 retention by 6.1%**, with eCPMs of **$23 (iOS) and $25 (Android)**. ([Gamesforum Midcore report, 2025, PDF](https://investgame.net/wp-content/uploads/2025/07/Gamesforum-Mobile-Midcore-Gaming-Report_AP-1_FINAL_FINAL.pdf))
- Apple explicitly allows encouraging users to watch an ad (guideline 3.2.2(x)). ([Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/))
- Zombix Online may monetize through IAP only: AppGoblin lists "Ads: No" and "IAP 100%", but its own SDK scan detects Google AdMob, so whether it shows ads is unverified (low confidence).
- **Inference:**
  - In a raid-PvP game, rewarded ads must never grant resources, energy, revives or timer skips. Those are pay-to-win paid in attention instead of cash.
  - The acceptable use is optional ads for **cosmetic currency only**. Even then, ads break immersion in a DayZ-style mood piece.
  - Treat ads as off by default and test them later, mobile only.

### 2.7 Comparison: selling power or time (LDoE style) versus fair models

| Model | Revenue depth | Player acceptance in raid-PvP | Regulatory risk 2026 | Fit |
|---|---|---|---|---|
| Power or time (energy, packs, boosts, revives) | Highest per payer. LDoE: about $182K-$263K/week in the US, Q4 2023 | Very low: payers farm non-payers | Medium (time-limited offers mean PEGI 12+) | **Reject** |
| Paid loot boxes / gacha | High | Low (Once Human, Battlefront II) | **High** (BR, BE, AU, PEGI 16, KR, FTC) | **Reject** |
| Cosmetic shop (direct purchase) | Medium; needs scale | High | Low (time-limited rotations mean PEGI 12) | **Core** |
| Cosmetic season pass | Medium | High if it doesn't expire | Low-medium (play-by-appointment) | **Core** |
| Cosmetic and QoL subscription | Medium, predictable | High if no power | Low; 10% Google fee | **Core** |
| Premium (B2P) | Upfront | High | Low | **PC/console option** |
| Private server rental | Low-medium; covers costs | Very high | Low | **Core** |
| Rewarded ads | Low-medium | Mixed | Low | **Optional, cosmetic only** |

---

## 3. Case studies at a glance

| Game (year) | What they sold | Outcome | Lesson |
|---|---|---|---|
| Battlefront II (2017) | PvP power in loot boxes | ~$3B stock value lost; missed 10M sales target; went cosmetic-only | Power in PvP is a brand-level risk |
| Tarkov Unheard (2024) | $250 edition with PvP perks and a mode | Discord lockdown, apology, partial reversal | Edition perks count as pay-to-win in looter PvP |
| Diablo Immortal (2022) | Paid random gems | 0.2 user score, yet >$100M in 8 weeks | Pay-to-win earns money but burns trust |
| DayZ Frostline (2024) | $26.99 paid map | Review bomb | Paid maps split the community |
| Once Human (2024) | Cosmetics, later in loot boxes; character-bound cosmetics | Praised at launch, then backlash | Keep cosmetics direct-purchase and account-wide |
| RuneScape (2014-2026) | Treasure Hunter keys (paid randomness affecting progression) | 120K+ votes for removal; removed Jan 19, 2026, alongside taking 225 Direct XP/skilling items off sale ([Wikipedia](https://en.wikipedia.org/wiki/RuneScape)) | Even a 12-year cash cow can become a liability |
| Rust (2013-) | B2P, skins, DLC, Twitch drops | 20M+ Steam copies; $142M by 2019 | Fair raid-PvP can be a long-term hit |
| Fortnite (2017-) | Cosmetics, pass, subscription | ~$9B by end of 2020 | Cosmetic-only can reach the very top |
| Undawn (Tencent, 2023) | Free-to-play zombie survival | Reuters (Mar 2024) called it a flop: ~$287K in a month (AppMagic) ([Wikipedia](https://en.wikipedia.org/wiki/Undawn)) | Big budgets don't guarantee a zombie survival hit |

**Note on "survival" revenue charts:** the top mobile "survival" earners, Last War: Survival ($475M in Q1 2025) and Whiteout Survival ($418M), are **4X strategy games** with deep spending, not crafting or raiding sandboxes. ([Gamesforum/AppMagic, 2025](https://investgame.net/wp-content/uploads/2025/07/Gamesforum-Mobile-Midcore-Gaming-Report_AP-1_FINAL_FINAL.pdf)) **Inference:** don't benchmark our revenue against them.

---

## 4. Platform and legal constraints (as of November 2026)

### 4.1 Apple App Store

- **Global baseline:** digital goods must use in-app purchase. Outside the US (and outside regional entitlements), apps may not include buttons or links to other payment methods. Paid random items **"must disclose the odds of receiving each type of item ... prior to purchase."** ([Guidelines 3.1.1/3.1.1(a)](https://developer.apple.com/app-store/review/guidelines/))
- **US storefront:** no entitlement is needed for buttons or links to external purchases (3.1.1, 3.1.3).
  - Judge Gonzalez Rogers found Apple in contempt on **April 30, 2025** and barred any commission on link-outs.
  - In **December 2025** the Ninth Circuit upheld the contempt finding but allowed a future cost-based "reasonable" fee, to be set by the district court. On Apr 28, 2026 it lifted the stay that had been pending the Supreme Court. ([MacRumors, Apr 2026](https://www.macrumors.com/2026/04/29/epic-games-wins-reversal-app-store-fee-battle/))
  - The **Supreme Court agreed in June 2026** to hear a narrow question about the contempt standard. Epic's brief is due Nov 13, 2026, and a ruling is unlikely before about June 2027. The rate proceeding is stalled over discovery.
  - **The link-out commission is currently zero.** ([TechTimes, Sep 15, 2026](https://www.techtimes.com/articles/327527/20260915/app-store-commission-limbo-enters-new-phase-apples-epic-merits-brief-opens-scotus-fight.htm))
- **Small Business Program:** 15% commission for developers under $1M a year. ([Apple](https://developer.apple.com/app-store/small-business-program/))
- **EU (unified terms effective Oct 1, 2026):** ([Apple DMA page](https://developer.apple.com/support/dma-and-apps-in-the-eu/))
  - Apple in-app purchase: **26%** (15% for Small Business participants and subscriptions after year one).
  - Alternative in-app payment: **20%/10%**.
  - Link-out offers: **15%/10%** on sales within 7 days of the tap.
  - Apps distributed outside the App Store: **5% Core Technology Commission**.
  - Users aged 13-17 need a parental gate for alternative payments and link-outs. Under-13s can't be offered link-outs at all.
- **Japan (smartphone competition law, MSCA; developers had to accept updated terms by Mar 17, 2026):** ([Apple Japan](https://developer.apple.com/support/app-distribution-in-japan/))
  - **21% commission plus a 5% Apple payment-processing fee** on in-app purchase.
  - 21% on alternative in-app payment.
  - **15%** on link-outs (7-day window).
  - 10% for Small Business participants.
- **Age ratings:** Apple now uses **4+/9+/13+/16+/18+** tiers. Loot boxes trigger 9+ globally, **16+ in Australia, and A18 in Brazil**. Frequent simulated gambling is 18+. LDoE is currently rated 16+. ([Apple age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/), [LDoE listing](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094))

### 4.2 Google Play

- **Epic v. Google timeline:** jury verdict Dec 11, 2023. Injunction Oct 2024. Ninth Circuit affirmed July 31, 2025. Supreme Court declined review Oct 6, 2025. Settlement announced Nov 5, 2025, with Judge Donato initially postponing approval. Completed deal announced Mar 4, 2026. Fortnite returned worldwide Mar 19, 2026. ([Wikipedia](https://en.wikipedia.org/wiki/Epic_Games_v._Google))
- **New fee schedule, official** ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/16954621)):

| New installs (after the regional rollout date) | One-off purchase (in-app or web link) | Recurring (subscription) |
|---|---|---|
| Standard | 20% (+5% billing fee if Play Billing) | 10% (+ billing fee) |
| Games Level Up / Apps Experience programs | 15% | 10% |
| First $1M annual earnings | 10% | 10% |

  - Existing installs pay more: 25% standard for in-app one-off purchases, 20% for web links.
  - **Rollout:** June 30, 2026 (US, UK, EEA). Sept 30, 2026 (AU, JP). Dec 31, 2026 (KR). **Sept 30, 2027 (rest of world).**
- **Unverified:** a vendor blog reports that the Nov 2025 settlement mentioned a **9% tier for items that don't materially affect gameplay (such as cosmetic skins)**, but that Google's published schedule leaves it out. Wikipedia confirms the Nov 2025 proposal would have cut Google's take to "between 9% and 20%", but the cosmetic-items criterion appears only in the vendor source. ([Neon, vendor](https://www.neonpay.com/blog/google-plays-new-u.s.-billing-linking-policies-what-game-developers-need-to-know)) If it ever applies, a cosmetic-only game would benefit directly. Watch for it.
- **Policy:** randomized items must disclose odds before and close to purchase. Linking to outside payment requires enrolling in Google's external-links or alternative-billing programs. ([Google Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738))

### 4.3 Loot box and paid-randomness rules by country

| Jurisdiction | Status (2026) | Source |
|---|---|---|
| **Belgium** | Paid loot boxes = gambling since Apr 2018; fines up to €800K. Enforcement is weak in practice | [Wikipedia](https://en.wikipedia.org/wiki/Loot_box), [Futura Jul 2026](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **Netherlands** | Sources conflict. A 2018 regulator opinion held boxes with **transferable** items illegal, but the highest administrative court overturned the FIFA decision in Mar 2022. Futura still describes it as strict | [Wikipedia](https://en.wikipedia.org/wiki/Loot_box), [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **UK** | Not gambling. Voluntary industry principles (parental consent, odds disclosure). The advertising regulator ruled against Hutch's F1 Clash over undisclosed odds (Nov 2025) | [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **Brazil** | Law 15.211/2025 ("ECA Digital") **bans paid loot boxes in products aimed at or likely accessed by minors**; in force March 2026 | [Pixelkin, Sep 2025](https://pixelkin.org/2025/09/29/brazil-becomes-latest-country-to-ban-loot-boxes-targeted-at-minors/) |
| **Australia** | Since Sept 22, 2024: paid chance-based items mean **M minimum**; simulated gambling means **R18+** | [Wikipedia](https://en.wikipedia.org/wiki/Loot_box), [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **China** | Odds disclosure since 2017; spending caps for minors since 2019 | [Wikipedia](https://en.wikipedia.org/wiki/Loot_box) |
| **Japan** | "Complete gacha" (prize only for completing a full set) banned since 2012; standard gacha allowed | [Wikipedia](https://en.wikipedia.org/wiki/Loot_box) |
| **South Korea** | Odds disclosure mandatory since Mar 2024; Nexon fined ~$8.9M over MapleStory odds | [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **US** | No loot box law. FTC v. HoYoverse (Genshin Impact, Jan 2025): $20M penalty, parental consent for under-16 loot box purchases, odds disclosure | [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **Germany** | Non-binding Bundesrat resolution (late 2025) urging gambling treatment and 18+ ratings | [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| **EU** | Proposed Digital Fairness Act (consumer-protection law) expected ~end 2026, applying no earlier than 2029; could ban loot boxes for minors | [Futura](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |

### 4.4 PEGI 2026 "interactive risk" criteria (Europe)

Announced Mar 12, 2026. Applies to games submitted from June 2026. Separately, from October 2026, existing digital-only games rated PEGI 3, 7 or 12 that contain paid random items are being re-rated to PEGI 16 (PEGI, Oct 6, 2026). ([PEGI](https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories), [PEGI re-rating](https://pegi.info/news/pegi-updates-age-ratings-existing-games-paid-random-items), [Wccftech](https://wccftech.com/games-with-loot-boxes-now-get-pegi-16-rating-starting-june-2026-ea-sports-fc/))

| Feature | Minimum rating |
|---|---|
| Paid random items | **PEGI 16** (18 in some cases) |
| Time-limited or quantity-limited offers | PEGI 12 |
| NFTs / blockchain | PEGI 18 |
| Rewards for returning (daily quests) | PEGI 7 |
| **Penalties for not returning** (lost content or progress) | PEGI 12 |
| Fully unrestricted chat with no block or report tools | **PEGI 18** |

**Inference:** a gritty zombie shooter will probably rate 16+ for violence anyway. Even so, the categories are now printed descriptors that parents and journalists read, and **wipes** could be read as "penalties for not returning." Keep cosmetics and account progress permanent across wipes, and ship block and report tools on day one.

---

## 5. Benchmark metrics (use as rough guides)

| Metric | Value | Source and date |
|---|---|---|
| Mobile D1 retention, all genres | Top 25% just over 30%; top 10% ~40%; top 1% 64-68% | GameAnalytics 2026 benchmarks (2025 data, 16,262 games), via [GameDev Reports, Jun 2026](https://gamedevreports.substack.com/p/gameanalytics-mobile-and-pc-game) |
| Mobile D7 | Median just under 4%; top 25% 6-7%; top 10% 11-12% | same |
| Mobile D30 | Median **0.69-0.79%**; top 25% 1.6-1.8%; top 1% 13-15% | same |
| PC D1 / D30 | D1 top 25% 15-16%; D30 top 10% ~2.5%, top 1% ~10% | same (3,582 PC games) |
| Midcore D1 (North America) | ~31.7%, highest of any category | [Gamesforum Midcore 2025](https://investgame.net/wp-content/uploads/2025/07/Gamesforum-Mobile-Midcore-Gaming-Report_AP-1_FINAL_FINAL.pdf) |
| Midcore D90 ARPU (iOS, hybrid monetization) | ~$9.69 | AppsFlyer, via Gamesforum 2025 |
| Midcore D7 ROAS | 4.3% (vs 7% casual) | Udonis, via Gamesforum 2025 |
| Midcore CPI | ~$2 average; iOS ~5x Android; hits up to $20-30 | Gamesforum 2025 |
| Sessions per day | Midcore highest, 6-7 | GameAnalytics 2025, via [GameDev Reports, Feb 2025](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks) |
| Payer conversion | **No authoritative published benchmark found.** Secondary blogs claim 1-3% typical and 3-5% for top free-to-play games; one says no benchmark is worth quoting | [Playio, Oct 2026](https://blog.playio.co/arppu-mobile-games), [Zorka](https://zorka.agency/blog/13-kpis-to-measure-your-mobile-game) (low confidence) |
| **LDoE, US (iOS+Android), Q4 2023** | Weekly revenue **$182K-$263K**; weekly active users 151K-196K; weekly downloads 11K-19K | [Sensor Tower](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| **LDoE, Europe iOS, Q3 2024** | Weekly revenue ~$94K-$97K; weekly active users 79K-83K | [Sensor Tower](https://sensortower.com/blog/2024-q3-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791) |

**Inference:**
- LDoE earns very roughly **$0.9-$1.7 per weekly active user per week** in those markets (US Q4 2023: $182K/196K ≈ $0.93 up to $263K/151K ≈ $1.74; Europe iOS Q3 2024: ≈ $1.2). That is my own division of Sensor Tower's auto-generated estimates, which are gross and approximate. It is the intensity of a power-selling model.
- Plan cosmetic-only revenue per user at a fraction of that. Make up the difference with a bigger audience, better retention, cheaper organic acquisition through streamers and raid clips, server rentals and subscriptions.
- Retention targets for a fair game should aim at the top 10%: D1 ≥40%, D7 ≥11%, D30 ≥4% (the D30 figure is unverified: the source gives no mobile top-10% D30 value, only top 25% at 1.6-1.8% and top 1% at 13-15%, so 4% is an interpolation). Fair monetization only pays off through longer player lifetimes.

---

## 6. Candidate "Fair Monetization Charter" (draft v0.1)

**One-line promise:** *"You can buy how you look, where you play, and how much you support us. You can never buy what you raid with, what protects your loot, or how fast you get either."*

### We WILL sell
1. **Cosmetics, by direct purchase at a visible price:** outfits, weapon skins, emotes, banners, base decor that has no function, vehicle paint, and cosmetic companion looks.
2. **A cosmetic season pass** with a free track. Paid progress never expires (or has generous catch-up), and you can earn back enough premium currency to buy the next pass.
3. **A "Supporter" subscription** with cosmetics, a cosmetic currency allowance, extra cosmetic loadout or outfit slots, name and clan-tag styling, early access to *test* servers, and discounts on server rental.
4. **Private and rented servers** with custom rules (PvE-only, friends-only, raid windows, boosted rates). Progress on these servers is **walled off** from official servers.
5. **Optional premium edition or PC price** if we ship buy-to-play on PC. It includes cosmetics only.
6. **Viewer drops** (Twitch, YouTube) and creator codes. Drop items are account-bound and cosmetic.
7. **Optional rewarded ads (mobile only, off at launch)** that grant cosmetic currency only.

### We will NEVER sell
1. Weapons, ammo, armor, meds, food, building materials, blueprints or crafting tiers.
2. **Raid tools or raid defense:** explosives, breaching items, turrets, traps, wall or door upgrades, shields, **offline raid protection**, base insurance.
3. **Time:** energy or stamina, travel cost, build or craft timers, XP, gathering-rate boosts, revives.
4. **Inventory or stash space** that exceeds what free players have. Tarkov shows that stash and edition perks read as pay-to-win.
5. **Paid random items of any kind:** loot boxes, gacha, keys, mystery crates.
6. Matchmaking or queue priority on official servers, and any advantage in information (maps, radar, raid alerts beyond what free players get).
7. NFTs or crypto, and player-to-player trading of paid items for real money.
8. Countdown-pressure offers aimed at minors. Rotating stores are fine; a pressure UI is not.

### Guardrails
- **Cosmetics must not change visibility.** No darker or camouflage variants beyond the base item's silhouette and readability, and hitboxes are unchanged. Base skins must still show **what material a wall really is**, so attackers can judge the raid.
- Cosmetics are **account-wide** and persist across wipes (the Once Human lesson).
- Currency packs line up with item prices. There are no deliberate leftover balances, and prices show in local money next to the currency amount.
- Spending limits and a parental gate for players under 18. Odds disclosure is moot because we sell no randomness.
- A public changelog for monetization changes and a promise that any change to this charter will be announced 30 days ahead.

---

## 7. Revenue-model options

| Option | Description | Pros | Cons |
|---|---|---|---|
| **A. F2P + cosmetics + pass** (Fortnite / Once Human-style) | Free on all platforms | Widest funnel; competes directly with LDoE/Zombix on price; streamer-friendly | Cosmetic revenue per user is low; needs a big art pipeline; free accounts make alts and cheaters cheap |
| **B. Premium on PC/console + F2P mobile** | Rust-style price on PC; free mobile with the charter | Price deters cheaters on PC; upfront cash funds development | Cross-play fairness and anti-cheat get complicated; two economies |
| **C. Premium everywhere (low mobile price)** | One-time price + cosmetics | Cleanest promise; no pay-to-win suspicion | Mobile premium audience is small (no benchmark found); hard against free competitors |
| **D. F2P + Supporter subscription + cosmetics + server rental** (recommended) | Option A plus recurring revenue | **10% Google fee on subscriptions**; predictable revenue; server rental pays its own costs; non-power perks are easy to defend | Subscriptions need a steady stream of cosmetic and social value; risk of "subscription fatigue" |
| **E. Web shop + link-outs** (add-on to A or D) | Sell currency and subscriptions on our site | US iOS link-out commission currently **0%**; EU 15%; JP 15%; Google web link 20% (10% under $1M) | Legal status may change (Supreme Court in 2027); conversion friction; we handle tax and refunds; parental-gate rules in the EU |
| **F. LDoE-style power/time sales** | Energy, packs, boosts | Highest short-term revenue per user | Kills raid-PvP; contradicts why the developer quit LDoE; PEGI/Brazil exposure if randomness creeps in |

**Inference, recommendation:** launch with **D on mobile, with E layered on where the law allows**. Treat **B** as a strong alternative if PC is the lead platform. Hire for anti-cheat before hiring for the shop.

---

## Design implications for our game

1. **Write the charter into the design doc before any economy work.** Every raid tool, defense and timer is designed assuming nobody can buy it. That makes balance honest and the marketing message simple: "LDoE's world, without the store."
2. **Make raids fair *and* monetizable without selling power.** Sell raid *expression* (breach animations, explosion effects with readability kept, victory emotes, a "raid replay" share card) and keep raid *outcomes* free.
3. **Give offline protection away as a design feature, never as a product.** The most tempting thing to sell in a Rust-like game is protecting a sleeping base. Use free systems instead: raid windows, decaying protection, or scheduled server raid hours.
4. **No paid randomness, ever.** It sidesteps Brazil, Belgium, Australia M, PEGI 16, Korea and the FTC in one decision.
5. **Wipes need permanence somewhere.** Keep cosmetics, account level and season-pass progress across wipes so that PEGI doesn't read wipes as "penalties for not returning" and players never feel their purchases were wiped.
6. **Private servers are a product, not a leak.** Build server rental and rulesets early. It funds hosting and gives PvE-minded LDoE refugees a home without softening official PvP.
7. **Design for streamers.** Raids are the genre's best clip moment. Ship viewer drops, creator codes and a spectator or replay mode, which are cheap ways to acquire players given midcore install costs of about $2+.
8. **Price is anti-cheat.** If we go free-to-play, budget for server-side authority, cheat detection and account trust levels (phone or Steam linking, playtime gates for ranked raid servers) from the start.
9. **Use the 2026 payment rules to protect margins.** Use subscriptions (10% on Google), a web shop with US/EU/JP link-outs, and the Small Business / first-$1M tiers while we're small. Re-check after the Supreme Court decision (~mid-2027) and Google's rest-of-world rollout (Sept 30, 2027).
10. **Measure fairness.** Track D30 retention for payers versus non-payers, and raid win rates by spend. If spend predicts raid success, something has leaked. Treat it as a P0 bug.

---

## Gaps and caveats

- **Search budget exhausted** partway through. Not researched: LDoE's current season pass and subscription prices, Zombix Online's store contents, Conan Exiles' Age of War battle pass backlash, Last Island of Survival, and Rust Mobile plans.
- **Reddit and YouTube:** old.reddit.com could not be fetched, and YouTube videos could not be watched. There are no first-hand player threads or video transcripts.
- **No credible survival-specific payer-conversion or ARPDAU benchmark** was found. Sensor Tower's LDoE numbers come from auto-generated blog estimates.
- **Fortnite totals** come from third-party estimates (SuperData) up to 2020.
- **Legal status is in flux:** the Apple US link-out fee (Supreme Court), Google's possible 9% cosmetic tier (unverified), the EU Digital Fairness Act and the Netherlands' position (sources conflict). This is not legal advice; get counsel before launch.

## Fact-check notes

Adversarial fact-check run on 2026-11-07. I re-opened the cited sources for 37 claim groups, focusing on numbers, prices, dates, fee rates and legal rules that drive design or business decisions. The shared WebSearch budget was already spent, so independent corroboration came from fetching extra primary or secondary pages directly: Wikipedia's Epic Games v. Apple and Loot box pages, PEGI's Oct 2026 re-rating notice, and the full text of the Gamesforum PDF. Nothing in the document looked fabricated.

**Changes made**
1. **TL;DR, LDoE revenue:** changed "$180K" to **$182K**, matching Sensor Tower's low and the table in section 5. Also removed "still earns", because the figure is from Q4 2023 and is nearly three years old.
2. **Section 5, LDoE revenue per weekly active user:** corrected "$1.2-$1.7" to **~$0.9-$1.7**. The US low end is $182K / 196K ≈ $0.93. Also replaced the garbled "net of nothing" with "gross".
3. **Section 2.3, Apple subscriptions after year one:** corrected the claim that the rate is "10% under the new EU terms". Under the Oct 1, 2026 EU terms, Apple IAP subscriptions after year one pay **15%**, and 10% applies only to alternative payments and link-outs. In Japan it is 10% plus a 5% payment-processing fee when Apple IAP is used. The 15% rate is Apple's standard after-year-one rate, not only "in its programs".
4. **Section 4.4 and TL;DR, PEGI re-rating:** added the specific source, PEGI's notice of Oct 6, 2026. Re-rating covers existing **digital-only games rated PEGI 3, 7 or 12** with paid random items, moving them to PEGI 16 from October 2026. The Mar 2026 announcement and Wccftech, as originally cited, do not mention re-rating.
5. **Section 3, RuneScape:** reworded "removed with 225 XP/skilling items". Per Wikipedia, 225 Direct XP and skilling items were *taken off sale* alongside the removal; they were not compensation.
6. **Section 2.6, Zombix Online:** qualified "no ads". AppGoblin lists "Ads: No / IAP 100%", but its SDK scan detects Google AdMob, so I marked ad use unverified.
7. **Section 1.2, Tarkov:** marked the Discord lockdown **(unverified)**. GamesRadar returned only a headline and TechSpot returned 403. PCGamesN confirms the $250 price, the apology, free PvE for Edge of Darkness owners and continued sales, but it does not itemize PvP perks.
8. **Section 5, D30 target:** marked "D30 ≥4%" for the top 10% as **unverified**. GameDev Reports gives no mobile top-10% D30 value.
9. **Section 4.2, Google's 9% tier:** left it marked unverified. Wikipedia confirms the Nov 2025 proposal cut Google's take to "between 9% and 20%", but the cosmetics criterion comes only from the vendor blog.
10. **Section 2.1, Rust Steam reviews:** noted that the ~535K count covers English-language reviews and that $39.99 is the regular, non-sale price.

**Confirmed against sources, no change needed**
- **Diablo Immortal:** 0.2 user score, more than $100M in 8 weeks, about $100K (Bellular), $300K-$600K, not released in Belgium or the Netherlands.
- **Battlefront II:** more than -667K downvotes, about $3B stock loss, 9M sold vs a 10M target, March 2018 overhaul.
- **Rust:** 9M copies and $142M (Dec 2019); almost 12.5M (end of 2021); 20M+ on Steam (KitGuru, Jul 7, 2025); first Item Store game; Twitch drops on Nov 12, 2020 with 1/3/6 hours and 3 items; drop rules; $1M paid to skin creators (Nov 2017).
- **Fortnite:** $2.4B / $1.8B / more than $9B; Crew launched Dec 2020.
- **Palworld:** 15M Steam copies and 10M Xbox players by Feb 22, 2024; 32M+ players by Feb 2025.
- **Sensor Tower LDoE:** US Q4 2023 and Europe iOS Q3 2024 figures.
- **PocketGamer.biz 2017 LDoE store details**, and the LDoE App Store 16+ rating and reviews.
- **Apple US link-outs:** 0% since the Apr 2025 contempt order; Ninth Circuit Dec 2025 ruling and Apr 28, 2026 stay reversal (MacRumors); Supreme Court review granted June 2026 on the contempt question only (TechTimes, corroborated by Wikipedia); Epic's brief due Nov 13; ruling unlikely before June 2027.
- **Apple EU (Oct 1, 2026):** 26%/15%, 20%/10%, 15%/10% with a 7-day window, 5% CTC, minors rules.
- **Apple Japan:** 21% + 5%, 15% link-out, 10% tiers, Mar 17, 2026 deadline.
- **Apple age ratings:** 9+ global, 16+ in Australia, A18 in Brazil for loot boxes.
- **Google Play schedule:** all rates and rollout dates.
- **Epic v. Google timeline.**
- **Loot box rules:** Brazil (March 2026); Belgium (Apr 2018, €800K); Netherlands (Mar 2022); Australia (Sept 2024, M / R18+); China; Japan; Korea (Nexon about $8.9M); FTC/HoYoverse ($20M, Jan 2025); Germany; EU DFA.
- **PEGI category minimums:** all six.
- **ARK Ultimate Mobile:** $4.99/$49.99, €5.99/€59.99, expansions €3.49-€11.99, keys €1.09-€31.99.
- **ARK: Survival Ascended:** 4M copies (May 2, 2026).
- **DayZ:** Livonia $30, then $40 to $49.99; Frostline $26.99 (Oct 2024); CEO's under 10 cents per hour across about 8M users. Wikipedia is the only source.
- **Undawn:** Reuters, Mar 21, 2024, about $287K.
- **Once Human:** Kotaku, TheGamer and Mein-MMO details.
- **Gamesforum PDF:** Last War $475M and Whiteout $418M in Q1 2025; Bytro +32.9%, +6.1%, $23/$25; 31.7%; $9.69; 4.3% vs 7%; CPI about $2, 5x, $20-30.
- **GameAnalytics benchmarks:** all quoted values.
- **Facepunch server guidelines:** dated Jul 15, 2025.
- **Albion Online.**

**Overall reliability: high.** The decision-driving numbers and platform-fee rules match their sources, and the corrections are small precision fixes. Residual risk: several 2026 legal facts rest on one or two secondary sources (TechTimes and Wikipedia for the Supreme Court grant), the DayZ figures rest on Wikipedia alone, and fee rules may change after this date.

## Sources

- [PocketGamer.biz: How does Last Day on Earth monetise (Oct 2017)](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/)
- [App Store: Last Day on Earth: Survival (US)](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)
- [Sensor Tower: Q4 2023 US top survival games revenue](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791)
- [Sensor Tower: Q3 2024 Europe iOS top survival games revenue](https://sensortower.com/blog/2024-q3-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791)
- [Steam: Rust](https://store.steampowered.com/app/252490/Rust/)
- [Wikipedia: Rust (video game)](https://en.wikipedia.org/wiki/Rust_(video_game))
- [80.lv: Rust sales over 12.4M (Jan 2022)](https://80.lv/articles/rust-sales-reached-over-12-4-million-units)
- [KitGuru: Rust over 20M copies on Steam](https://www.kitguru.net/desktop-pc/mustafa-mahmoud/rust-has-sold-over-20-million-copies-on-steam-alone/)
- [PCGamesN: Rust skin creators paid $1M](https://www.pcgamesn.com/rust/rust-skin-creators-paid-1m)
- [Rust blog: Twitch drops (Nov 2020)](https://rust.facepunch.com/blog/rust-twitch-drop)
- [Facepunch wiki: Twitch drops](https://wiki.facepunch.com/rust/twitch-drops)
- [Facepunch: Community Server and Hosting Guidelines](https://facepunch.com/legal/servers)
- [Wikipedia: Fortnite Battle Royale](https://en.wikipedia.org/wiki/Fortnite_Battle_Royale)
- [Wikipedia: Star Wars Battlefront II (2017)](https://en.wikipedia.org/wiki/Star_Wars_Battlefront_II_(2017_video_game))
- [Wikipedia: Diablo Immortal](https://en.wikipedia.org/wiki/Diablo_Immortal)
- [PCGamesN: Tarkov dev apologizes](https://www.pcgamesn.com/escape-from-tarkov/apology)
- [GamesRadar: Tarkov community meltdown over $250 edition](https://gamesradar.com/games/fps/this-cannot-be-tolerated-escape-from-tarkov-community-in-meltdown-over-dollar250-edition-with-exclusive-pve-mode-as-a-131-word-chant-consumes-the-official-discord)
- [TechSpot: Tarkov $250 pay-to-win DLC](https://www.techspot.com/news/102757-escape-tarkov-developer-offers-250-pay-win-dlc.html)
- [Wikipedia: DayZ](https://en.wikipedia.org/wiki/DayZ_(video_game))
- [Wikipedia: Ark: Survival Ascended](https://en.wikipedia.org/wiki/Ark:_Survival_Ascended)
- [Wccftech: ARK Ultimate Mobile Edition launch](https://wccftech.com/ark-ultimate-mobile-edition-coming-to-ios-android-today-free-to-play)
- [ARK wiki: Ultimate Mobile Edition](https://ark.wiki.gg/wiki/Ultimate_Mobile_Edition)
- [Wikipedia: Albion Online](https://en.wikipedia.org/wiki/Albion_Online)
- [Wikipedia: RuneScape](https://en.wikipedia.org/wiki/RuneScape)
- [Wikipedia: Palworld](https://en.wikipedia.org/wiki/Palworld)
- [Wikipedia: Undawn](https://en.wikipedia.org/wiki/Undawn)
- [OpenCritic/TheGamer: Once Human monetization (Jul 2024)](https://opencritic.com/news/2929/once-human-not-given-the-praise-its-due-for-monetization)
- [Kotaku: Once Human seasons and cosmetics (Jul 2024)](https://kotaku.com/once-human-steam-reviews-server-season-reset-cosmetic-1851592897)
- [Mein-MMO: Once Human loot box backlash (Aug 2024)](https://mein-mmo.de/once-human-loot-boxen-problem/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: DMA and apps in the EU](https://developer.apple.com/support/dma-and-apps-in-the-eu/)
- [Apple: App distribution in Japan](https://developer.apple.com/support/app-distribution-in-japan/)
- [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [Apple: Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [MacRumors: Epic wins reversal of stay (Apr 2026)](https://www.macrumors.com/2026/04/29/epic-games-wins-reversal-app-store-fee-battle/)
- [TechTimes: App Store commission limbo, SCOTUS brief (Sep 2026)](https://www.techtimes.com/articles/327527/20260915/app-store-commission-limbo-enters-new-phase-apples-epic-merits-brief-opens-scotus-fight.htm)
- [Neon: Apple alternative payment fees 2026 (vendor)](https://www.neonpay.com/blog/apple-app-store-alternative-payment-fees-what-developers-pay-in-2026)
- [Google Play Console Help: service fees](https://support.google.com/googleplay/android-developer/answer/16954621)
- [Google Play: Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Neon: Google Play U.S. billing and linking (vendor)](https://www.neonpay.com/blog/google-plays-new-u.s.-billing-linking-policies-what-game-developers-need-to-know)
- [Wikipedia: Epic Games v. Google](https://en.wikipedia.org/wiki/Epic_Games_v._Google)
- [Tech Insider: Epic v. Google Play changes 2026](https://tech-insider.org/epic-google-play-store-changes-2026/)
- [PEGI: Expanded age rating criteria (Mar 2026)](https://pegi.info/news/pegi-expands-age-rating-criteria-interactive-risk-categories)
- [PEGI: Updates age ratings of existing games with paid random items (Oct 2026)](https://pegi.info/news/pegi-updates-age-ratings-existing-games-paid-random-items)
- [Wikipedia: Epic Games v. Apple](https://en.wikipedia.org/wiki/Epic_Games_v._Apple)
- [Wccftech: PEGI 16 for loot boxes from June 2026](https://wccftech.com/games-with-loot-boxes-now-get-pegi-16-rating-starting-june-2026-ea-sports-fc/)
- [Wikipedia: Loot box](https://en.wikipedia.org/wiki/Loot_box)
- [Futura: Loot boxes in 2026, regulation map (Jul 2026)](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026)
- [Pixelkin: Brazil bans loot boxes for minors (Sep 2025)](https://pixelkin.org/2025/09/29/brazil-becomes-latest-country-to-ban-loot-boxes-targeted-at-minors/)
- [GameDev Reports: GameAnalytics 2026 benchmarks (Jun 2026)](https://gamedevreports.substack.com/p/gameanalytics-mobile-and-pc-game)
- [GameDev Reports: GameAnalytics 2025 benchmarks (Feb 2025)](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)
- [Gamesforum: Mobile Gaming by Genre: Midcore (2025, PDF)](https://investgame.net/wp-content/uploads/2025/07/Gamesforum-Mobile-Midcore-Gaming-Report_AP-1_FINAL_FINAL.pdf)
- [Playio: ARPPU and payer conversion (Oct 2026)](https://blog.playio.co/arppu-mobile-games)
- [Zorka: Mobile game KPIs 2026](https://zorka.agency/blog/13-kpis-to-measure-your-mobile-game)
- [AppGoblin: Zombix Online](https://appgoblin.info/apps/com.ZombixDev.ZombixOnline)
