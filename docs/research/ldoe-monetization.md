# Last Day on Earth: Survival — Monetization Teardown

*Researched 2026-11-07. Live-service game: prices, offers and systems change with every update, so each fact is tagged with its source date. Facts cite a URL; my own analysis is prefixed **Inference:**.*

**Access limits (read first):** The LDoE Fandom wiki returned HTTP 402 to automated fetches. Reddit (old/new) and YouTube video pages could not be fetched, and the Google Play page didn't render. The shared web-search budget for this workflow ran out partway through. The findings below therefore rest on Kefir's official help center, App Store listings across many storefronts (fetched 2026-11-07), App Store reviews, Sensor Tower blog snapshots, trade press (PocketGamer.biz, wnhub/App2Top, Baijing), and review aggregators (TapTap, Common Sense Media, GameBrain, MMOHuts). Reddit sentiment comes in only second-hand through aggregators.

---

## TL;DR

- **One hard currency (coins)**, earned only in small amounts in play and mainly bought. Coins pay for energy refills, speeding up crafts and trips, drone relaunches, store items and, since Sept 2026, **resurrecting with your loot intact**.
- **The money engine is "consumable power" plus full-loot death.** Paid weapons, armor and food are ordinary items, so they break, get used up, or are lost when you die. Kefir's help center says plainly that purchases can be lost on death.
- **Stacked passes:** a per-season **Season Premium**, priced at the $9.99 tier, with seasons lasting 21 days per Kefir's FAQ. On top of that sit a separate **Survivor's Path Premium / Premium+** and separate **event premiums** such as the Big Hunt. Each is bought separately.
- **VIP spending tiers** (VIP 1–10 plus "prestige") run on a timer that lapses unless you keep buying. One Dec 2021 reviewer reports that maxing out at VIP 10 costs about $300, plus a later level costing an extra $10 per day (single player claim).
- **The base itself is monetized**: fridges (storage) and their upgrade blueprints are sold in the store, including a limited-time high-capacity fridge.
- **Energy is the most-cited complaint** across 2017–2025 reviews (by this document's own tally; GameBrain's digest ranks monetization and grinding as the top negatives overall). **Losing paid items on death** and **"rigged" random boxes** come next.
- **Scale:** About $2–4M/month gross nine years after launch (Baijing, May 2026; Baijing does not name the source of this figure). US weekly revenue fell from about $323–410K (Q1 2021) to about $182–263K (Q4 2023) per Sensor Tower blog snapshots. 95% IAP / 5% ads (Kefir, 2019).

---

## 1. Scale: revenue and download estimates

| Metric | Value | Whose estimate / date | Source |
|---|---|---|---|
| Revenue target at launch | $2M/month (a goal, not a result) | Kefir producer, June 2017 | [wnhub 12740](https://wnhub.io/zh/news/other/item-12740) |
| US iOS grossing rank | #28 overall, July 2017 | wnhub, 2017 | [wnhub 13062](https://wnhub.io/news/stores-and-publishing/item-13062) |
| Downloads | ~130M in first two years, 80% Google Play | Kefir on Habr, Aug 2019 | [wnhub 15996](https://wnhub.io/news/marketing/item-15996) |
| Monthly revenue | ~$2.4M (July 2019, DataMagic estimate); peak "up to $7.2 million per month" (no source or platform stated; mentioned alongside the Android release) | wnhub, Aug 2019 | [wnhub 15996](https://wnhub.io/news/marketing/item-15996) |
| Revenue mix | 95% IAP, 5% video ads | Kefir, Aug 2019 | [wnhub 15996](https://wnhub.io/news/marketing/item-15996) |
| UA spend | ~$1M/month average | Kefir, Aug 2019 | [wnhub 15996](https://wnhub.io/news/marketing/item-15996) |
| US weekly revenue (iOS+Android) | ~$410K (late Dec 2020) → ~$323K (end Mar 2021); WAU 225–267K | Sensor Tower blog, Apr 2021 | [Sensor Tower Q1 2021 US](https://sensortower-china.com/blog/2021-q1-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| US weekly revenue (iOS+Android) | $182K (late Oct) → $263K (late Dec 2023); WAU peak 196K, 151K at year end | Sensor Tower blog, Jan 2024 | [Sensor Tower Q4 2023 US](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| Europe iOS weekly revenue | ~$94–97K, Q3 2024 (listed first of the five survival games; the post gives no explicit rank) | Sensor Tower blog, Oct 2024 | [Sensor Tower Q3 2024 EU iOS](https://sensortower.com/blog/2024-q3-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791) |
| Monthly revenue | ~$2–4M, "nine years after launch"; one of only two Kefir titles earning meaningfully (with Sunday City) | Baijing, 11 May 2026. Baijing names no source for the $2–4M figure; Sensor Tower is cited only for the iOS earners comparison | [Baijing](https://www.baijing.cn/article/55133) |
| Downloads | "over 100 million" | Aptoide case study, June 2024 | [Aptoide Connect](https://connect.aptoide.com/blog/last-day) |
| US App Store rating | 4.6★ from 104K ratings | Apple, fetched 2026-11-07 | [App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) |

**Caveats.** One Sensor Tower auto-generated blog post (labelled Q2 2024 Android, URL slug "ar") claims a $3.6M *weekly* peak and 7.9M weekly downloads alongside only 31K WAU. Those numbers contradict each other, so I discarded it ([link](https://sensortower.com/blog/2024-q2-android-top-5-survival%20games-revenue-ar-60144bdd241bc16eb8136791)). AppGoblin's estimate of "<$10K/month" for the iOS app is clearly far off the other sources ([AppGoblin](https://appgoblin.info/apps/1241932094)). I found no AppMagic or Sensor Tower *lifetime* total.

**Inference:** The US weekly figures put US gross at roughly $1.4–1.8M/month in early 2021 and $0.8–1.1M/month in late 2023, a decline of roughly 35–45%. The global $2–4M/month figure for 2026 fits a mature title that is slowly declining but still very profitable. December holiday spikes show up in every Sensor Tower snapshot, which suggests seasonal sales such as Black Friday and Winter events matter.

---

## 2. Currencies

| Currency | Earned how | Bought? | Spent on |
|---|---|---|---|
| **Coins** (hard currency) | Found in the world "infrequently" (2017); small event rewards. A 2021 reviewer noted 25 earned coins they could "never spend" and asked for login rewards. A daily login bonus was added in v1.39.6 (Sept 2025); whether it pays coins is (unverified) | Yes. 2017: $1.99 for 50 up to $29.99 for 750. 2026 US store: "Pile of coins" $1.99, "Tin with Coins" $9.99 (pack sizes not visible) | Energy refills, speeding up crafts and trips, store items (range diversified Oct 2025), drone relaunch, **resurrection with loot (Sept 2026)**, gasoline, bulk logs/stone, XP boosters (2017) |
| **Energy** (time-gate) | Regenerates over time (a 2021 reviewer cites ~4–5 min per point); cap raised from 100 to 200 by Feb 2021; energy drinks, Healer | Indirectly, via coins (2017: 70 energy for 25 coins ≈ $1) | Running on the global map |
| **Event currencies** (reputation, confetti, coupons, Infected Genome) | Event tasks | Some can be: Hunter's Instinct reputation "can be bought in the game shop" | Event rewards and blueprints |
| **Season / Path XP** | Tasks | Yes, via "+5 / +10 / +20 levels" bundles and Premium+ XP boosts | Pass tiers |

Sources: [PocketGamer.biz 2017](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/), [App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094), [App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews), [Kefir FAQ: lost resources](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/9-i-lost-my-resources/), [Kefir FAQ: Hunter's Instinct](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/914-hunter-s-instinct/), [Kefir FAQ: Genesis](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/956-what-is-genesis-how-can-i-get-genesis-collection-currency/), [Kefir FAQ: Pursuit of Luck](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/927-pursuit-of-luck/).

**Inference:** Having only one hard currency is simpler than most mobile games, but almost every coin sink converts directly into time or power. Free coin income is low enough that players notice it.

---

## 3. Sinks, mechanic by mechanic

### 3.1 Energy and global-map travel
- Running to a location costs energy and is near-instant. Walking is free but takes around 20 minutes (2017). Ads gave +15 energy (2017) ([PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/)).
- Kefir's 2022 reply to a review: energy is restored by ads or energy drinks ([App Store US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews)). The chopper travels without energy but needs fuel ([App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews)).
- Kefir's help center says the ad reward system is "in the testing phase" and rewards don't always appear ([FAQ 58](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/58-why-can-t-i-receive-energy-for-watching-ads/)). A user review quoted on GameBrain says that after one update, ads gave a 10% weapon bonus instead of energy (a player report, not a developer statement) ([GameBrain](https://gamebrain.co/game/last-day-on-earth-survival)). The date of that change is unverified.
- Common Sense Media: "Timer-based play means a lot of waiting or a lot of spending." ([CSM](https://www.commonsensemedia.org/app-reviews/last-day-on-earth-survival))

### 3.2 Timers and speed-ups
- Coins can be spent "boosting a craft or speeding up a trip" ([Kefir FAQ 9](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/9-i-lost-my-resources/)). A 2019 review complains of long crafting queues plus scarce materials ([App Store CA reviews](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews)).
- A 2022 review says crate drops needed for a raider challenge are so rare that players are pushed to "spend gold to skip it" ([App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews)).

### 3.3 Item packs, bundles and limited offers (sold power)
- 2017: Survivor's Pack ($0.99: 20 steaks, 20 beans, 20 water, crowbar); Zombie Warfare Pack ($9.99: nine weapons + 50 coins). PocketGamer noted that cheap bundles make sense because inventory is wiped on death ([PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/)).
- 2026 storefronts list Survivor's Pack, Silenced pack (x1/x5/x10), Special forces pack (x1/x5), Savings pack, Survival Guide, and many **generic "Product $X" SKUs** at $0.99, 1.99, 2.99, 3.99, 4.99, 5.99, 9.99, 14.99 and 19.99 (see §4).
- **Inference:** The generic SKUs mean the store can attach any server-defined bundle to a price tier. That allows rotating, limited-time and possibly personalized offers without App Store review of the contents. Black Friday 2025 sales appear in the 1.41.0/1.42.1 patch notes ([App Store US version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)).
- Kefir: purchased items behave like found items. They break, can be recycled by accident, and are lost with your inventory on death. Kefir advises keeping them in the inbox or at base ([FAQ 32](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/32-i-lost-my-purchases-after-death/)).

### 3.4 Passes: Season Premium, Survivor's Path Premium/Premium+, event premiums
- **Seasons** last **21 days**. The free track is open to everyone, and the paid track requires buying Premium **separately for each season**. Unclaimed rewards move to the Inbox ([FAQ 340](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/340-what-seasons-are-and-how-do-i-take-part-in-them/)).
- After the last unique paid reward, **only paid-pass owners** keep earning resource chests per level, with no cap other than season length ([FAQ 730](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/730-season-pass-bonus-rewards-and-how-to-get-them/)). Unopened season crates are auto-rolled at random at season end ([FAQ 1248](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1248-what-will-happen-to-season-rewards-if-i-don-t-open-the-crates-before-the-season-ends/)).
- **Price:** "Season Premium" is **USD 9.99** on the Uzbekistan storefront, which prices in USD. It sits at the same tier as the $9.99 SKU in Kazakhstan (5,990₸) and Pakistan (Rs 2,900). "Season + 5 lvl. (Sale)" is at the $2.99 tier (€2.99 Luxembourg; Rs 900 Pakistan) ([UZ](https://apps.apple.com/uz/app/id1241932094?l=en-gb), [KZ](https://apps.apple.com/kz/app/id1241932094?l=en-gb), [PK](https://apps.apple.com/pk/app/id1241932094?l=en-gb), [LU](https://apps.apple.com/lu/app/id1241932094?l=en-gb)). A search snippet of the Fandom "Season 21" page (an older season; I could not open the page) showed Premium at about $4.49 and Premium + 10 levels at about $9.99 "-60%" (unverified; the page still returns HTTP 402) ([Fandom Season 21](https://last-day-on-earth-survival.fandom.com/wiki/Season_21)).
- The paid track carries the season's unique outfit and weapon rewards (same Season 21 snippet; unverified).
- **Survivor's Path** (the onboarding/story quest line) has its **own** Premium and **Premium+**. Premium+ adds extra character XP, more season XP, **instant claiming of ad bonuses without watching**, and an outfit style. Both are time-limited, and the bonuses vanish when they expire. Path, season and event premiums (e.g., the Big Hunt) are **separate purchases** ([FAQ 841](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/841-survivor-s-path-and-its-premium-access/)).
- **Inference:** At $9.99 per 21-day season, buying every Season Premium costs up to about $170/year, before Path Premium+, event premiums or level skips. The model stacks passes rather than offering one pass.

### 3.5 VIP status (spend-tier loyalty)
- The VIP zone opened at the Gas Station "for store customers". Purchases earn VIP points across VIP levels up to VIP 10, after which "prestige" can be gained without limit. If you buy nothing "for quite a while", VIP status is suspended (progress kept, bonuses off) until you buy again. While prestige is active the timer doesn't run out. Purchases made before the system existed don't count ([FAQ 477](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/477-vip-zone-and-vip-status-why-can-t-i-get-into-the-vip-zone-anymore/), [FAQ 478](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/478-i-ve-made-purchases-before-why-don-t-i-have-a-vip-status-now/)).
- A Dec 2021 review by a self-described ~$2,500/year spender (Joey21875, 1 Dec 2021) claims that maxing out at VIP 10 costs about $300 in purchases, that a level beyond it costs "EXTRA 10USD PER DAY", and that VIP-zone loot was later nerfed, after which they stopped spending ([App Store CA reviews](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews)). This is one player's account and is unverified.

### 3.6 Random-reward elements
- **Unknown Box** (Gas Station, opened by watching ads): Kefir in 2019 said rare-item drop rates "isn't so high", but it can be opened 24 times per day ([App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews)). Players called the free boxes "rigged" (2020) and asked for better hourly box odds (2021).
- **Paid crates:** A 2021 reviewer who had "spent hundreds" asked how many crate purchases a specific dog takes and whether the odds are disclosed ([App Store US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews)). I found no published odds.
- **Season crates** are auto-randomized if unopened (above). **Mercenary contracts** (Settlement) unlock and upgrade mercenaries, and duplicates feed upgrades. The FAQ doesn't say whether they're random or for sale ([FAQ 775](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/775-didn-t-get-a-mercenary-contract-i-always-get-contracts-from-the-same-mercenaries/)).

### 3.7 Rewarded ads
Reported ad rewards over time:
- +15 energy (2017)
- Free food from the Healer (2017)
- Unknown Box opens, 24 per day (2019)
- A single revive (Aug 2025 review)
- Recovering loot lost on death at certain locations by watching a 30-second ad (Popcorn Rose, App Store GB review, 5 Nov 2025)
- Auto-farming specific locations by ads, limited to a 12-hour window (TapTap, June 2025)
- Clearing debris at the Abandoned Factory (v1.52.0, Sept 2026)

Ads were 5% of revenue in 2019. Ad availability depends on daily view limits and ad partners, and Kefir "cannot guarantee" it ([FAQ 901](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/901-bonuses-from-ads-are-not-available-in-the-game/)). Premium+ lets you claim ad bonuses without watching (§3.4). Sources: [PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/), [App Store US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews), [App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews), [TapTap](https://www.taptap.io/app/51131).

### 3.8 Monetizing the death penalty (new and important)
- **v1.52.0 (16 Sept 2026): "Resurrection for coins"**, pitched as a way to avoid losing valuable loot ([App Store CA](https://apps.apple.com/ca/app/id1241932094?l=en-ca), [App Store US version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)). This comes on top of the ad-based revive and loot restore noted in 2025 reviews.
- **Inference:** This sells the escape from the full-loot rule that was the game's defining tension. In a raid-centric game, a paid "keep your loot" button would directly cut the loot attackers win.

### 3.9 Base-building monetization
- **Fridges (food storage) are store items.** A Level 1 fridge (8 slots × 100) is sold in the store. A Level 4 fridge (10 slots × 300) is a **limited-time store offer**. Upgrade **blueprints are sold in the store** (four at the time of writing). Fridges bought before update 1.38 were converted to Level 4 ([FAQ 1218](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1218-fridges-what-s-changed-and-how-does-it-all-work-now/)).
- Workbench upgrades need a unique blueprint from the Genesis Collection. The FAQ doesn't say whether coins apply ([FAQ 958](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/958-how-do-i-upgrade-workbenches/)).
- **Inference:** Selling storage capacity and storage upgrades monetizes base convenience directly. Paired with the coin crafting speed-ups (§3.2), base progression in LDoE can be partly bought.

### 3.10 Vehicles, cosmetics, other
- Kefir's stock reply is that chopper and ATV parts are found in play. It points players to YouTube streams for locations and says the number of chopper-part locations was increased ([App Store CA](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews), [App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews)). Events also hand out ATV transmissions and a Flight Controller ([FAQ 1222](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1222-forlorn-fair/)).
- Cosmetics: outfit styles come through the season paid track and Premium+. The Oct 2026 Halloween update (v1.53.0) lists "New event-themed skins"; earlier updates also added skins (a luminescent-tattoo skin in v1.41.0, Oct 2025; skins in v1.51.1, Aug 2026) ([App Store CA](https://apps.apple.com/ca/app/id1241932094?l=en-ca)). Cosmetics are a minor part of the store compared with power items. **Inference**, based on the SKU names visible.
- The drone in Pursuit of Luck can be relaunched for coins at any time, even mid-timer ([FAQ 927](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/927-pursuit-of-luck/)).

### 3.11 PvP and raids: pay-to-win or pay-to-skip?
- Base raids are gated. You need level 150 and a CB Radio to deal with raiders. After a deal your base is attackable by other survivors for 24 hours, and the window grows if you attack or take revenge ([FAQ 104](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/104-how-do-i-summon-raiders/), [FAQ 106](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/106-when-can-my-base-be-attacked-by-other-survivors/), [FAQ 99](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/99-why-was-my-home-base-raided/)). No help-center article mentions paid raid protection.
- **Inference:** PvP is **pay-to-win in a consumable sense.** Bought weapons, armor and meds are ordinary items usable in any PvP zone or raid, so spending buys power. Full loot on death, durability and repairs mean that power has to be bought again. The opt-in, level-gated raid design keeps most players out of PvP (matching the developer's complaint that nobody raids). That limits how visible the pay-to-win is, but it also means PvP never became the show-off arena that drives cosmetic spending in Rust-style games.

---

## 4. Real-money price points (App Store, fetched 2026-11-07 unless noted)

Apple shows only about 10 "top" IAPs per storefront, so every list is partial.

| Storefront | Items and prices |
|---|---|
| **US** | Survivor's Pack $0.99 · Silenced pack $0.99 · Pile of coins $1.99 · Special forces pack $2.99 · Tin with Coins $9.99 · generic Products $0.99 / $1.99 / $2.99 / $4.99 / $9.99 ([US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)) |
| US (6 Apr 2026 snapshot) | adds Silenced pack x5 $3.99, Silenced pack x10 $6.99 ([AppPricingLab](https://apppricinglab.com/iap/apple/1241932094)) |
| Uzbekistan (USD) | **Season Premium USD 9.99** · Products 3.99 / 14.99 / 19.99 ([UZ](https://apps.apple.com/uz/app/id1241932094?l=en-gb)) |
| Oman (USD) | Product $19.99 ([OM](https://apps.apple.com/om/app/id1241932094?l=en-gb)) |
| Luxembourg (EUR) | **Season + 5 lvl. (Sale) €2.99** · Special forces pack x5 €12.99 · Tin with Coins €9.99 ([LU](https://apps.apple.com/lu/app/id1241932094?l=en-gb)) |
| Pakistan (PKR) | Season Premium Rs 2,900 (= $9.99 SKU) · Season + 5 lvl (Sale) Rs 900 (= $2.99 SKU) · Product 14,99$ Rs 3,900 ([PK](https://apps.apple.com/pk/app/id1241932094?l=en-gb)) |
| Russia (RUB) | Survival Guide 449 RUB · Savings pack 269 RUB (= $4.99 SKU) · Season + 5 lvl 149 RUB ([RU](https://apps.apple.com/ru/app/last-day-on-earth-survival/id1241932094?l=en-GB)). **Inference:** Survival Guide sits between the $4.99 and $9.99 tiers |
| Canada (CAD) | Tin with Coins $12.99 · Product 9,99$ $12.99 ([CA](https://apps.apple.com/ca/app/id1241932094?l=en-ca)) |
| 2017 (PocketGamer.biz) | Coins $1.99 for 50 up to $29.99 for 750 · 70 energy for 25 coins (≈$1) · Zombie Warfare Pack $9.99 |

**Inference:** The visible ceiling is $19.99 per transaction, so the business runs on frequent mid-size purchases (passes, $2.99–$9.99 offers) and VIP retention rather than $99 mega-packs.

---

## 5. Master table: mechanic → what it sells → price → sentiment

| Mechanic | Sells | Price (USD, date) | Player sentiment |
|---|---|---|---|
| Energy refills (coins) | **Time / access** to the map | 70 energy ≈ 25 coins ≈ $1 (2017); now unknown | **Most hated.** Every review aggregator lists it; called "a little p2w" (Oct 2025; unverified, not found on TapTap or the App Store pages checked) |
| Craft and trip speed-ups (coins) | **Time** | Unknown per use | Negative ("long crafting queues") |
| Coin packs | Currency | $1.99 pile / $9.99 tin (2026) | Neutral; free coin income seen as too low |
| Weapon, armor and food packs | **Power** (consumable) | $0.99–$12.99 (2026) | Tolerated as "cheap"; **anger when lost on death** |
| Rotating "Product $X" offers, Black Friday | Power / convenience | $0.99–$19.99 | Called "limited-time deals" and seen as P2W, though some call them fair (2021) |
| Season Premium (21-day) | Power + cosmetics + post-cap chests | $9.99; +5 lvl sale $2.99 | **Mixed:** "worth buying" (2021) vs "money grab" after buying late in a season (2019) |
| Survivor's Path Premium / Premium+ | XP / convenience / ad-skip / cosmetic | Not found | No direct sentiment found |
| Event premiums, purchasable reputation | Progress / access | Not found | "Events feel like nothing more than cash grabs designed to squeeze players" (Pheklom, TapTap, Sept 2025) |
| VIP status / VIP zone | **Access** + loot + bonuses, lapses without spending | Reportedly ~$300 to reach VIP 10, plus a claimed extra $10/day level (one 2021 review) | **Strongly negative** from whales (nerfs, "out of touch") |
| Unknown Box (ads), paid crates | **Random** power / pets | Ad-gated; paid crate prices not found | "Rigged"; odds not disclosed |
| Rewarded ads | Energy, revives, loot restore, boxes, auto-farm | Free (watch time) | **Tolerated / liked**; complaints mostly when ads break |
| Resurrection for coins (Sept 2026) | **Removes death penalty** | Coins (amount unknown) | Too new; no sentiment found |
| Fridges + store blueprints | **Base storage / convenience** | Not found | No direct sentiment found |
| Drone relaunch | Time | Coins | None found |
| Outfit styles, event skins | **Cosmetic** | Bundled in passes | Not a complaint driver |

---

## 6. How monetization changed over time

| When | Change | Source |
|---|---|---|
| May–Jun 2017 | Launch: coins, real-money boxes, energy, rewarded video. Kefir targets $2M/month | [PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/), [wnhub](https://wnhub.io/zh/news/other/item-12740) |
| 2019 | Seasons with paid Premium (Season 3 by Nov 2019; iPhoneSoft confirms Season 3 only, so paid Premium in 2019 rests on a 2019 review and is unverified); Unknown Box ad crates, 24/day; free energy drinks reportedly removed (Dec 2019 review) | [iPhoneSoft](https://iphonesoft.fr/2019/11/17/last-day-earth-saison-3-disponible), [App Store CA reviews](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews) |
| By Feb 2021 | Energy cap raised 100 → 200; guns sold by the in-game dealer | [App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews) |
| By Dec 2021 | VIP zone / VIP tiers with lapse timer; whale backlash over cost and loot nerfs | [FAQ 477](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/477-vip-zone-and-vip-status-why-can-t-i-get-into-the-vip-zone-anymore/), [App Store CA reviews](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews) |
| ~2023–24 | Survivor's Path with its own Premium / Premium+ (Kefir mentions the Path in a Jan 2024 reply) | [FAQ 841](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/841-survivor-s-path-and-its-premium-access/), [App Store US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews) |
| ~2025 (v1.38) | Fridges reworked into levelled store items with store-sold upgrade blueprints | [FAQ 1218](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1218-fridges-what-s-changed-and-how-does-it-all-work-now/) |
| 2025 | Ad revive and ad loot restore; one reviewer says the game "got alot more free to play friendly" (Aug 2025) | [App Store US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews), [App Store GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews) (loot restore) |
| Oct–Nov 2025 | Store coin items diversified (v1.40); Black Friday 2025 sale | [Version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history) |
| Sept 2026 | **Resurrection for coins**; ads clear factory debris (v1.52.0) | [App Store CA](https://apps.apple.com/ca/app/id1241932094?l=en-ca) |

**Inference:** The arc runs from simple packs plus energy (2017), to recurring passes (2019), to spend-tier loyalty (VIP, about 2021), to multiple stacked passes (2023+), to monetized base storage and a monetized death penalty (2025–26). Each layer was added on top; nothing was removed. That fits the developer's sense that it "became far too aggressive".

---

## 7. What players hate vs tolerate

**Hated most (ranked by how often it recurs across sources):**
1. **Energy and its paid refill.** Named in CSM, MMOHuts, MMOs.com, GameBrain, TapTap and App Store reviews from 2019, 2021, 2022, 2023 and 2025.
2. **Losing paid gear on death or to durability.** "You die, you lose EVERYTHING. Even stuff you paid for." (Darknoss, App Store CA, 2019). A 2023 reviewer says a few hundred dollars buys about a week of play ([App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews)).
3. **Feeling that progress requires spending.** "What's left is a pay-to-win game disguised as free-to-play." (Pheklom, TapTap, Sept 2025). CSM's parent-review summary uses the phrase "money trap".
4. **Opaque or low-odds random boxes** ("rigged"; no published odds).
5. **VIP tiers and nerfs to paid areas** (whale churn).
6. **Season timing.** Paying for a pass late in a season, or content changing mid-progress (2019).

**Tolerated or praised:**
- Rewarded ads as an opt-in alternative to paying.
- Cheap starter packs.
- The season pass when it's good value ("worth buying", 2021).
- Generosity for free players: "even if you're F2P the game is still quiet generous." (Oliver, TapTap, 2024).
- Several reviewers love the game despite the monetization. The US App Store rating is 4.6★, while GameBrain's digest scores user sentiment at 67%, with monetization the top complaint.

---

## 8. Developer statements

- 2017: Kefir described an in-game store selling resources, weapons, clothing and crafting parts, and a $2M/month goal ([wnhub](https://wnhub.io/zh/news/other/item-12740)). PocketGamer.biz (Oct 2017) judged the purchases "strictly optional" and "considered" ([PocketGamer.biz](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/)).
- 2019: Kefir said revenue was "several million", with 95% from IAP and about $1M/month in UA ([wnhub](https://wnhub.io/news/marketing/item-15996)).
- Kefir's stock line in review replies from 2019 to 2024 is that the store is the player's choice. Example (2022): "Visiting the game store isn't the responsibility of the players." ([App Store AU](https://apps.apple.com/au/app/id1241932094?l=en-au)). It also says all resources can be found or crafted. No public developer letter about monetization reform turned up. The devblog page at kefirgames.com didn't expose posts to fetching.

---

## 9. Gaps (what I could not verify)

- **Current US Season Premium price** in the US storefront. It is inferred as $9.99 from the USD-priced UZ store and from tier matching. Survivor's Path Premium / Premium+ and event premium prices: **not found**.
- **Coins per pack today**, coin cost of energy, speed-ups and resurrection today, and VIP point thresholds, tier rewards and lapse timer: **not found**.
- **Loot box and crate odds**: no published odds found.
- **Reddit threads** (r/LastDayonEarthGame): could not fetch, so sentiment comes from App Store, TapTap and aggregators instead. **YouTube**: channel pages didn't render, so no titles or view counts were recorded.
- **Fandom wiki** blocked (HTTP 402). Season 21 prices come from a search snippet only.
- No AppMagic data and no Sensor Tower lifetime totals or 2025–26 US snapshots. No Naavik, Deconstructor of Fun or GameRefinery teardown found before the search budget ran out.
- **Inference:** One to two hours of hands-on play (or an Android emulator) with screenshots of the store, pass screens, VIP tab and offer pop-ups would fill most of these gaps cheaply. For monetization specifically, the user's idea of playing the game is worth doing.

---

## Design implications for our game

1. **Make a public fairness pledge the brand: "Anything that can be raided can only be earned."** LDoE sells weapons, armor, food, storage, speed-ups and now loot-preserving revives, all of which feed raids and PvP. If raiding is our highlight, no purchase may touch raid outcomes: no gear, ammo, meds, building materials, base HP, turrets, storage capacity, raid shields or revives. This is our clearest wedge against LDoE.
2. **Never monetize death.** Full-loot death is what makes raiding exciting (a DayZ/Rust truth). LDoE's Sept 2026 "Resurrection for coins" and the ad-to-restore-loot option show where F2P pressure leads. Ban both by design rule, including via ads.
3. **No energy meter.** Gate travel with *risk and logistics* instead: distance, fuel, vehicles found and repaired in-world, and night danger. Energy has been one of LDoE's most persistent complaints for eight years (this document's own tally ranks it first; GameBrain's digest ranks monetization overall first).
4. **No sellable timers on anything that matters for PvP.** If crafting or base upgrades have timers for pacing, keep them short and make them non-skippable with money. Coin speed-ups make base progression partly purchasable, as the LDoE fridge-and-blueprint model shows.
5. **One pass at a time, cosmetic-only, fixed published price (~$5–10), at least 6–8 weeks long.** LDoE stacks a $9.99 pass every 21 days plus Path Premium+ plus event premiums. Let players earn back part of the premium currency (the Fortnite pattern) so the pass feels like a deal rather than a tax. No paid level skips that unlock anything functional.
6. **Base cosmetics are our biggest revenue opportunity, not base power.** Sell wall, door and roof skins, decor, banners, lighting and trophy displays. Hard rule: skins must not change hitboxes, HP, silhouette readability or visibility. Raiding guarantees an audience for a beautiful base: your base gets seen by the people breaking into it.
7. **No VIP or spend tiers, no lapse timers, no daily-fee zones.** LDoE's VIP system shows how this alienates the very whales it targets.
8. **Transparent store:** named SKUs, no personalized "Product $X" price-tier offers, no paid random boxes for functional items. If we ever sell random cosmetics, publish the odds and add duplicate protection. Better still, sell cosmetics directly.
9. **Rewarded ads only for small PvE conveniences on mobile** (for example cosmetic currency trickle or a daily cosmetic reroll). Never energy, revives, loot or anything usable in PvP.
10. **Set realistic revenue expectations.** LDoE still grosses roughly $2–4M/month (Baijing, May 2026, source of figure not named), and the US alone was roughly $0.8–1.1M/month in late 2023 (Inference from Sensor Tower weekly data). A cosmetic-first model will earn less per user, so it needs higher retention and concurrency. Rust-style raiding drama and a social, visible base are the levers that make cosmetics sell. Consider a modest buy-to-play price on PC (DayZ/Rust precedent) alongside a F2P mobile build with identical fairness rules.
11. **Treat "pay-to-skip" for PvE content as the grey zone and default to "no".** If anything functional is ever sold, restrict it to PvE-only cosmetic-adjacent convenience: extra character slots, extra outfit loadouts, name changes, base blueprint save slots. Never inventory or storage size.

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. The shared web-search budget was already used up when this pass ran, so no independent corroborating searches could be made. Each claim below was checked by re-opening its cited source directly (Kefir help center, App Store pages in US/CA/GB/AU/UZ/KZ/PK/LU/RU, Sensor Tower blog, Baijing, wnhub, PocketGamer.biz, AppPricingLab, Aptoide, AppGoblin, TapTap, GameBrain, Common Sense Media, MMOHuts, iPhoneSoft). Fandom still returns HTTP 402.*

**Confirmed against the cited source (no change):**
- Seasons last 21 days, Premium is bought separately each season, and unclaimed rewards go to the Inbox (FAQ 340). Post-cap bonus chests are only for the paid pass, with no cap except season length (FAQ 730). Unopened crates are randomized at season end (FAQ 1248).
- Season Premium is USD 9.99 (UZ), 5,990₸ (KZ) and Rs 2,900 (PK). "Season + 5 lvl. (Sale)" is €2.99 (LU), Rs 900 (PK) and 149 RUB (RU). All other storefront lists in §4, including the AppPricingLab 6 Apr 2026 snapshot (Silenced pack x5 $3.99, x10 $6.99), match.
- US App Store: 4.6★ from 104K ratings. The 10 US IAPs are as listed.
- v1.52.0 (16 Sept 2026) "Resurrection for coins so that you don't lose valuable loot" and ad-cleared debris at the Abandoned Factory. Black Friday 2025 sale in v1.41.0/v1.42.1. More coin store items in v1.40.0 (Oct 2025).
- Fridges (FAQ 1218): L1 is 8 slots × 100 and sold in the store, L4 is 10 slots × 300 as a limited-time offer, 4 blueprints, and pre-1.38 fridges became L4.
- Raids: level 150 plus CB Radio (FAQ 104), 24-hour attack window that grows if you attack or retaliate (FAQ 106). No paid protection is mentioned (FAQ 99).
- VIP zone at the Gas Station, prestige after VIP 10, suspension after a long spell without purchases, no lapse while prestige is active (FAQ 477). Earlier purchases don't count (FAQ 478).
- Survivor's Path Premium+ benefits, time limit, and separate purchases for Path, season and event premiums (FAQ 841). Purchased items are lost on death, break and can be recycled (FAQ 32). Coins boost crafts and trips (FAQ 9). Drone relaunch for coins (FAQ 927). Purchasable reputation (FAQ 914).
- wnhub 2019: 130M downloads in two years, 80% Google Play, Habr source, $2.4M in July 2019 (DataMagic), 95% IAP, about $1M/month UA. wnhub 2017: $2M/month target (producer, 14 Jun 2017) and #28 US App Store grossing in July 2017.
- Sensor Tower: Q1 2021 US ($410K end of Dec, then $323K end of Mar; WAU 267K peak, 225K at quarter end). Q4 2023 US ($182K late Oct, $263K late Dec; WAU 196K peak, 151K at year end). Q3 2024 EU iOS ($97K peak, $94K end of Sept). The discarded Q2 2024 post does contain the inconsistent $3.6M, 7.9M and 31K figures.
- PocketGamer.biz 2017: coins $1.99/50 to $29.99/750, 70 energy for 25 coins, +15 energy per ad, 20-minute walk, Survivor's Pack and Zombie Warfare Pack contents and prices, "strictly optional".
- Unknown Box: "you can open it 24 times per day" (Kefir reply, GB, 2019). Energy cap 100 → 200 (Pawafallz, GB, Feb 2021). Darknoss quote (CA, Dec 2019). Kefir's "Visiting the game store isn't the responsibility of the players" (AU, 18 Jan 2022). CSM "Timer-based play" quote, and "money trap", which is in CSM's AI-generated parent summary. Aptoide "over 100 million" (12 Jun 2024). AppGoblin "<$10K". Pheklom and Oliver TapTap quotes. GameBrain 67% score.

**Corrected:**
1. **Baijing $2–4M/month (TL;DR, §1, design implication 10):** Baijing (11 May 2026) gives the figure without a source. Sensor Tower is cited only for the claim that LDoE and Sunday City are Kefir's only real earners. The attribution "citing Sensor Tower" was removed.
2. **$7.2M/month peak (§1):** wnhub gives no source or platform for it, and only the $2.4M July figure is credited to DataMagic. Relabelled to match.
3. **EU iOS "#1" (§1):** The Sensor Tower post lists LDoE first but assigns no rank. Reworded.
4. **VIP cost (TL;DR, §3.5, §5):** The single 2021 review says about $300 to *max out at VIP 10*, plus a later level at an extra $10/day. "Players report top tiers costing hundreds" overgeneralized one reviewer.
5. **"Watching a 30-second ad restores lost loot" (§3.7):** These were not the reviewer's words, and the review is on the GB store, not the US one. Rewritten as a paraphrase with attribution (Popcorn Rose, GB, 5 Nov 2025). §6 now cites GB reviews too.
6. **Auto-farm window (§3.7):** The TapTap review says a 12-hour window, not "daily".
7. **"Events are money grabs" (§5):** Not a real quote. Replaced with Pheklom's actual wording.
8. **"has become more free-to-play friendly" (§6):** Replaced with the reviewer's actual words, "got alot more free to play friendly".
9. **GameBrain 10% weapon bonus (§3.1):** This is a user review quoted on GameBrain, not GameBrain's own digest.
10. **Event skins (§3.10):** Skins did not first "arrive" in Oct 2026. Earlier updates (v1.41.0, v1.51.1) also added skins.
11. **"Number-one complaint" (TL;DR, design implication 3):** This ranking is the document's own tally. GameBrain's digest of 9,997 reviews ranks monetization and grinding as the top negatives. Softened accordingly.

**Marked unverified:**
- Fandom Season 21 prices (~$4.49 / ~$9.99 "-60%"): still HTTP 402, and no corroboration was possible.
- "a little p2w" (Oct 2025): not found on TapTap or the App Store review pages checked.
- Paid Season Premium in 2019: iPhoneSoft confirms Season 3 existed by Nov 2019 but says nothing about a paid pass.
- Whether the Sept 2025 daily login bonus (v1.39.6, added in §2) pays coins.
- Not re-checked, so these remain single-source: the 2021 energy regen estimate (~4–5 min per point), the "money grab" Season Premium review (2019), the dog-crate review, MMOs.com, Mercenary contracts (FAQ 775) and the Unknown Box's location.

**Relevant finding not in the original text:** v1.50.0 (19 Jul 2026) added home-location expansion by clearing debris with a "Site Plan" item for new land (App Store CA version history). It is unknown whether Site Plans are sold, and this is worth checking for the base-building monetization question.

**Overall reliability: medium** (high for the numbers, prices and FAQ rules; lower for attributions and quotes, and nothing could be corroborated beyond the cited sources). Every number, price, date and FAQ rule spot-checked matched its source. The errors were in attribution (Baijing/Sensor Tower, DataMagic), in quotation marks around paraphrases, and in turning single-player anecdotes into general claims. Nothing was fabricated outright except two quote strings presented as verbatim (fixed above). Revenue figures are third-party estimates and should be treated as order-of-magnitude.

---

## Sources

- [PocketGamer.biz — How does Last Day on Earth: Survival monetise? (Oct 2017)](http://www.pocketgamer.biz/how-does-last-day-on-earth-survival-monetise/)
- [App Store US listing](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) · [US reviews](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews) · [US version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)
- [App Store CA](https://apps.apple.com/ca/app/id1241932094?l=en-ca) · [CA reviews](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews)
- [App Store GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094) · [GB reviews](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews)
- [App Store AU](https://apps.apple.com/au/app/id1241932094?l=en-au) · [UZ](https://apps.apple.com/uz/app/id1241932094?l=en-gb) · [OM](https://apps.apple.com/om/app/id1241932094?l=en-gb) · [LU](https://apps.apple.com/lu/app/id1241932094?l=en-gb) · [KZ](https://apps.apple.com/kz/app/id1241932094?l=en-gb) · [PK](https://apps.apple.com/pk/app/id1241932094?l=en-gb) · [RU](https://apps.apple.com/ru/app/last-day-on-earth-survival/id1241932094?l=en-GB) · [BG](https://apps.apple.com/bg/app/id1241932094?l=en-gb) · [SA](https://apps.apple.com/sa/app/id1241932094?l=ar-eg)
- [AppPricingLab — LDoE IAPs (Apr 2026)](https://apppricinglab.com/iap/apple/1241932094)
- [Kefir Help Center — LDoE index](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/)
- [FAQ 340 — Seasons](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/340-what-seasons-are-and-how-do-i-take-part-in-them/) · [FAQ 730 — Season pass bonus rewards](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/730-season-pass-bonus-rewards-and-how-to-get-them/) · [FAQ 1248 — Unopened season crates](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1248-what-will-happen-to-season-rewards-if-i-don-t-open-the-crates-before-the-season-ends/) · [FAQ 841 — Survivor's Path Premium](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/841-survivor-s-path-and-its-premium-access/)
- [FAQ 477 — VIP zone](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/477-vip-zone-and-vip-status-why-can-t-i-get-into-the-vip-zone-anymore/) · [FAQ 478 — VIP and past purchases](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/478-i-ve-made-purchases-before-why-don-t-i-have-a-vip-status-now/)
- [FAQ 32 — Purchases lost after death](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/32-i-lost-my-purchases-after-death/) · [FAQ 9 — Lost resources (coin speed-ups)](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/9-i-lost-my-resources/) · [FAQ 35 — Refunds](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/35-how-can-i-get-a-refund/)
- [FAQ 58 — Energy for ads](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/58-why-can-t-i-receive-energy-for-watching-ads/) · [FAQ 901 — Ad bonuses](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/901-bonuses-from-ads-are-not-available-in-the-game/)
- [FAQ 1218 — Fridges](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1218-fridges-what-s-changed-and-how-does-it-all-work-now/) · [FAQ 958 — Workbench upgrades](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/958-how-do-i-upgrade-workbenches/) · [FAQ 775 — Mercenary contracts](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/775-didn-t-get-a-mercenary-contract-i-always-get-contracts-from-the-same-mercenaries/)
- [FAQ 927 — Pursuit of Luck](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/927-pursuit-of-luck/) · [FAQ 914 — Hunter's Instinct](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/914-hunter-s-instinct/) · [FAQ 1222 — Forlorn Fair](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1222-forlorn-fair/) · [FAQ 956 — Genesis](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/956-what-is-genesis-how-can-i-get-genesis-collection-currency/)
- [FAQ 104 — Summon raiders](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/104-how-do-i-summon-raiders/) · [FAQ 106 — When base can be attacked](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/106-when-can-my-base-be-attacked-by-other-survivors/) · [FAQ 99 — Why base was raided](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/99-why-was-my-home-base-raided/)
- [Sensor Tower — Q1 2021 US survival games](https://sensortower-china.com/blog/2021-q1-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) · [Q4 2023 US survival games](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) · [Q3 2024 Europe iOS](https://sensortower.com/blog/2024-q3-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791) · [Q2 2024 Android (discarded, inconsistent)](https://sensortower.com/blog/2024-q2-android-top-5-survival%20games-revenue-ar-60144bdd241bc16eb8136791)
- [Baijing — Kefir / LDoE monthly revenue (May 2026)](https://www.baijing.cn/article/55133)
- [wnhub — Kefir announces LDoE (Jun 2017)](https://wnhub.io/zh/news/other/item-12740) · [wnhub — 130M downloads, 95% IAP (Aug 2019)](https://wnhub.io/news/marketing/item-15996) · [wnhub — July 2017 chart ranks](https://wnhub.io/news/stores-and-publishing/item-13062)
- [Aptoide Connect case study (Jun 2024)](https://connect.aptoide.com/blog/last-day)
- [AppGoblin (estimates, unreliable)](https://appgoblin.info/apps/1241932094)
- [Common Sense Media review](https://www.commonsensemedia.org/app-reviews/last-day-on-earth-survival) · [CSM parent reviews](https://www.commonsensemedia.org/app-reviews/last-day-on-earth-survival/user-reviews/adult)
- [TapTap user reviews](https://www.taptap.io/app/51131) · [GameBrain review digest](https://gamebrain.co/game/last-day-on-earth-survival) · [MMOHuts review](https://mmohuts.com/review/last-day-on-earth-survival) · [MMOs.com](https://mmos.com/review/last-day-on-earth-survival)
- [iPhoneSoft — Season 3 (Nov 2019)](https://iphonesoft.fr/2019/11/17/last-day-earth-saison-3-disponible)
- [Fandom — Season 21 (search snippet only; page blocked)](https://last-day-on-earth-survival.fandom.com/wiki/Season_21)
- [Kefir — Last Day on Earth game page](https://kefirgames.com/games/last-day-on-earth)
