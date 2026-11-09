# LDoE Monetization Playbook for Ember Outpost (Roblox)

*Researched and written 2026-11-08. This turns Last Day on Earth's (LDoE, by Kefir) pay-to-win model into a Roblox shop plan for Ember Outpost. Live-service facts change with every update, so each fact carries its source and date. Lines starting with **Inference:** are my analysis, not sourced fact.*

**Binding stance (the developer, 2026-11-08; [DECISIONS.md](../DECISIONS.md)):** copy LDoE's hard-grind pay-to-win model. Player complaints are read here as evidence of which levers earn money, not as reasons to soften them. The only limits are Roblox platform rules (paid random items show odds; rewarded ads only for 13+; discounts and timers must be genuine, see §1.4) and the revenue-protecting raid rules: purchases are raid-proof, and **we never sell shields, raid immunity or PvP immunity**.

**Builds on (not repeated here):** [ldoe-monetization.md](ldoe-monetization.md) (store teardown, currencies, sinks, 2017–2026 price points), [ldoe-retention-sentiment.md](ldoe-retention-sentiment.md) (1,000 US reviews, YouTube, churn archetypes), [ldoe-core-systems.md](ldoe-core-systems.md) (systems and numbers), [fair-monetization.md](fair-monetization.md) and [platform-economics.md](platform-economics.md) (fees, law, benchmarks), [roblox-genres-monetization.md](roblox-genres-monetization.md) (Roblox rules and genre prices), and [rec1–rec9 NOTES](../reference/ldoe-recordings/NOTES.md) (the 11 conversion levers seen on screen). Earlier docs written under the old fairness charter recommend against these levers. Their facts still stand; their recommendations are superseded by the 2026-11-08 decision.

**New evidence gathered for this doc:**
- **3,170 App Store reviews** from Apple's public RSS feeds for the US, GB, CA and AU storefronts (pages 1–10 of "most recent" and "most helpful", 2019–Nov 2026). They were keyword-tagged, and every quote below was read in full.
- **About 1,100 r/LastDayonEarthGame posts** pulled from the Arctic Shift Reddit archive. Reddit itself blocks fetching, which is why the earlier docs had no Reddit data.
- **LDoE wiki pages** read as wikitext through the MediaWiki API: VIP, Survivor's Path, Season 99, Packs, Death, Rations, Energy, Repair Station, Inbox and others.
- **Live store pages:** Google Play, plus App Store in-app purchase lists from 17 storefronts.
- **Roblox's own monetization rules** and Robux pack prices.

---

## TL;DR

1. **LDoE still nets about $2–3M a month** after store cuts (AppMagic, through March 2026, [Baijing](https://www.baijing.cn/article/55133); a companion piece is [here](https://www.baijing.cn/article/55143)). It has **140.6M Google Play installs**, and its Play listing shows **in-app purchases from $0.49 to $199.99 per item** ([Google Play](https://play.google.com/store/apps/details?id=zombie.survival.craft.z&hl=en_US&gl=US), fetched 2026-11-08). That corrects the earlier inference of a $19.99 ceiling: big-ticket packs exist, and players quote £100–£160 room kits.
2. **The top eight levers by revenue** (ranking in §2):
   1. the 21-day season pass and its level skips
   2. consumable gear packs, fed by death and durability (the re-buy loop)
   3. premium currency and Rations (time)
   4. the VIP spend ladder with a weekly lapse
   5. big-ticket base and capacity packs
   6. long-goal parts with FILL UP and last-piece offers
   7. the questline premium row and 30-day subscriptions
   8. event premiums
3. **Loss is the engine.** Among reviewers who say they spent money, **26% complain about losing items on death**, more than twice the rate across all reviews (11.6%). Paid gear breaks and drops, so it gets bought again. The same loss is also the top reason payers quit, for example "never came back after losing tactical backpack over and over" ([App Store GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews), May 2025).
4. **LDoE's best first-purchase lever is an offer only non-payers ever see.** The Legendary Survivor's Pack cost about $2–5 and held roughly $200 of value. It popped up every 2–3 weeks for players who had never paid, and vanished once they bought anything. Players hunted for it on Reddit for four years (§2.9).
5. **Roblox needs a premium currency.** Developer products have fixed prices, so FILL UP and timer speed-ups, which are priced by the shortfall or time left, need a wallet. Use LDoE's coin prices one-for-one in "Gold" (§7).
6. **Price ladder:** 79 / 99 / 149 / 199 / 249 / 399 / 799 / 1,199 / 1,699 / 2,499 / 4,499 / 9,999 / 17,999 R$. Each price fits Roblox's Robux packs exactly or as a pair of packs (400 / 800 / 1,700 / 4,500 / 10,000 R$). LDoE's $9.99 maps to 799 R$ (§4).
7. **The v0.1 shop has 10 SKUs** (§6): Firestarter Kit 99, Scavenger's Kit 79, Supply Bundle 99, Builder's Crate 399, Reinforced Room Kit 1,699, Energy Refill 99, Gold Pouch 149, Gold Chest 799, Pack Expansion pass 199, and VIP Lounge pass 399.
8. **The retention line** (§5): keep a miserable free path to every gate, because premium-locked parts make players uninstall rather than pay. Never raise a recurring price; add a tier instead. Never nerf anything already sold. Purchase delivery must be bulletproof. Light fog stays PvE, so free players stick around as content and raid targets.

---

## 1. What this research added

### 1.1 Scale over time (new rows marked ★)

| When | Metric | Value | Source |
|---|---|---|---|
| Jun 2017 | Revenue goal | $2M/month | [wnhub](https://wnhub.io/zh/news/other/item-12740) |
| Jul 2019 | Monthly revenue | ~$2.4M (DataMagic); 130M downloads; 95% from in-app purchases | [wnhub](https://wnhub.io/news/marketing/item-15996) |
| Q1 2021 | US weekly revenue (iOS+Android) | $410K → $323K | [Sensor Tower](https://sensortower-china.com/blog/2021-q1-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| Q4 2023 | US weekly revenue (iOS+Android) | $182K–$263K | [Sensor Tower](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| ★ Q3 2024 | US weekly revenue (Android only) | $54K → $83K; weekly actives 17.6K → 19.2K | [Sensor Tower](https://sensortower.com/blog/2024-q3-android-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) |
| ★ Q1 2025 | Europe weekly revenue (iOS) | $150K → $87K; weekly actives ~100K (peak 107K) | [Sensor Tower](https://sensortower.com/blog/2025-q1-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791) |
| ★ Q4 2025 | US weekly revenue (Android only) | peak ~$96K (late Dec); weekly actives 16–20K. Listed first; Kefir's Grim Soul second at $38K | [Sensor Tower](https://sensortower.com/blog/2025-q4-android-top-5-survival-games-revenue-us-60144bdd241bc16eb8136791) |
| ★ Through Mar 2026 | Net monthly revenue | **~$2–3M after store cuts** (AppMagic) | [Baijing 55143](https://www.baijing.cn/article/55143) |
| ★ Nov 2026 | Google Play | 140,603,418 installs; **IAP $0.49–$199.99 per item**; first release 24 May 2017 | [Google Play](https://play.google.com/store/apps/details?id=zombie.survival.craft.z&hl=en_US&gl=US) |

**Inference:**
- Android-only US snapshots can't be compared directly with the unified (iOS+Android) ones.
- Europe iOS alone produced about $0.9–1.5 per weekly active user per week in early 2025.
- The December peak shows up in every year's data, so a holiday sale is the single most reliable spike in the calendar.

### 1.2 What 3,170 reviews say

The sample is 3,170 App Store reviews from 4 storefronts, of which 841 are 1–2★. Mentions are keyword-tagged and approximate. The 2023–26 rates are lower partly because recent reviews are shorter.

| Theme | All reviews | 1–2★ reviews | 2019–22 | 2023–26 | Self-declared spenders (n=223) |
|---|---|---|---|---|---|
| Monetization, P2W, prices | 15.1% | **30.1%** | 16.4% | 14.1% | 42% |
| Bugs, lost account, purchase not delivered | 13.8% | 18.9% | 16.8% | 11.4% | 20% |
| Death and losing items | 11.6% | 17.6% | 16.1% | 7.9% | **26%** |
| Random boxes and odds | 8.5% | 11.3% | 13.3% | 4.5% | 18% |
| Energy and waiting | 10.3% | 10.1% | 13.2% | 7.8% | 10% |
| Vehicle and part walls | 9.6% | 9.5% | 12.9% | 6.9% | 12% |
| Season pass and premium track | 3.4% | 5.4% | 4.7% | 2.4% | 11% |
| Durability and repair | 4.5% | 4.4% | 5.5% | 3.7% | 6% |
| Storage and capacity | 4.1% | 6.5% | 5.8% | 2.7% | 10% |
| VIP | 1.3% | 2.0% | 0.6% | 1.8% | 4% |

Sources: Apple RSS feeds for [US](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json), [GB](https://itunes.apple.com/gb/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json), [CA](https://itunes.apple.com/ca/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json) and [AU](https://itunes.apple.com/au/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json) (pages 1–10, mostRecent and mostHelpful).

The 223 self-declared spenders average **2.6★**, and only 34% of them rate 4–5★.

**Inference:** spenders are the angriest group, yet they keep paying. Their specific grievances, in order, are losing what they bought (26%), bugs eating purchases (20%) and random contents (18%). Those are the levers to tune, not to remove.

### 1.3 New LDoE facts

**VIP ladder** ([wiki VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone)):
- **Points:** every purchase earns points. Per-level costs are 10 / 50 / 90 / 150 / 200 / 250 / 300 / 350 / 400 / 500 for VIP 1–10, then **100 per Prestige level**, for **2,400 points total** to reach Prestige.
- **Points per dollar:** the $0.99 Survivor's Pack gives 10 points. **Inference:** that's roughly 10 points per $1, so Prestige costs about $240. That fits the 2021 claim of "about 300USD" to max out at VIP 10 ([App Store CA](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews)).
- **Prestige upkeep:** each level earned past VIP 10 extends Prestige by 24 h, which players describe as "$10 a day for VIP Prestige" ([App Store GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews), Sep 2024).
- **Lapse:** VIP bonuses switch off if you stop buying, and the window is now about a week. Reviews describe it three ways: you "lose access to the vip section if you don't make a purchase every week" ([App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews), Dec 2023); "we now only get a week of VIP" (GB, Apr 2025); and "the 7 day vip pass tempted me" (US, Dec 2024).
- **Perks:**

  | Level | Perk |
  |---|---|
  | VIP 1 | VIP zone access, Wheel of Fortune, Black Market |
  | VIP 3, 5, 7, 9, 10 | −10% travel Energy each |
  | VIP 3, 5, 9 | +10% bench speed each |
  | VIP 2, 4, 6, 8, 10 | +10% XP each |
  | **VIP 5** | **Repair Workbench** |
  | Prestige | −50% Energy, +30% benches, +50% XP; an indestructible weapon for 1 h a day; loot from neutral-location corpses and stashes auto-delivered to VIP storage |

- **Players lean on VIP repair:** one player asks whether climbing VIP levels is worth it just for the repair bench, and works out that a week of VIP repairs about 14 guns ([Reddit, Jul 2026](https://www.reddit.com/r/LastDayonEarthGame/comments/1urzgzw/is_getting_to_higher_vip_level_worth_it_just_for/)).

**Questline subscriptions** ([wiki Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path)):
- **Ultra:** 30 days, unlocks the locked rewards and +10% XP, and is worth 100 VIP points.
- **Ultra Plus:** 30 days, +20% XP, +10% season XP, no ads and an outfit, worth 150 VIP points.
- **Inference:** at about 10 points per $1, that puts them at roughly $9.99 and $14.99 a month (unverified).

**Season structure and price history:**
- **Season 99** ran 13 Oct–2 Nov 2026 (21 days) with **80 levels plus an infinite tier** ([wiki Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99)).
- **Premium level 1 gives a fully modded VSS plus an Extremely Rare Infinite Pack the moment you buy.**
- **The premium track adds up to:** 150 coins, 29 Rations, 7 Energy Drinks (+50 Energy each), 2 Reanimators, 300 genome, and four armor sets (Motorcycle, Ghillie, Raider, Kevlar).
- **The free track is strong too:** a Colt Python at level 7, Crossbow, M16, AK-47, the SWAT set, FN SCAR and Dragunov.
- **The price doubled from $5 to $10 in Sept 2023** while 20 rewards were added ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/167xpun/season_pass_doubled_in_price/); GB review, 8 Sep 2023).
- **Premium + 20 levels costs £19.99** (GB review, Aug 2023).
- **A second "Premium+" pass, about 3× the normal price,** arrived in Apr 2026 ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/1sxm99m/new_season_pass/), [Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/1sy3zc4/two_season_premium_passes_kefirwhy_stop_there/)).
- **Mar 2025 experiment:** the free track was gutted and a "choose your reward" mechanic added ([Kefir post](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkedim/new_season_rewards/)). Players called it a "bad" pass and organized a boycott ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkqxzd/boycott_new_season_pass/), 54 upvotes; [Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkte2x/is_the_new_season_pass_an_early_april_fools_joke/), 52 upvotes). It was partly reversed by Aug 2025 ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/1mwoka8/new_season_pass/)).

**Packs** ([wiki Packs](https://last-day-on-earth-survival.fandom.com/wiki/Packs)):
- **Raider's Starter Pack:** a SWAT set, VSS and 100 coins, offered only for the **first 48 h after first spawn** ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Raider%27s_Starter_Pack)).
- **Savings pack (a piggy bank):** "The more experience you earn, the more rewards the pack will contain," with 12 rewards unlocked by 65,000 XP. It sits at the $4.99 tier (269 RUB), and a "large savings pack" costs about $12 ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Savings_pack); [Reddit, Aug 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1ml4tb8/season_or_savings/)).
- **Week Pack:** 50 coins at once plus 25 coins a day for 7 days, plus a Milkor MGL ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Week_Pack)).
- **Brick Room 3×3:** 575 steel plates, 90 titanium bars, 235 bricks and more ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Brick_Room_3X3)).
- **Gunsmith's and Armorer's crates:** paid random boxes with pity. You get one item per opening, plus a chance of more, and "every 5th crate" is very rare or better ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith%27s_crate)).
- Coins for gasoline: 10 / 30 / 70 gasoline for 50 / 100 / 200 coins.

**Death, energy and repair:**
- **Recover all** (inventory plus vehicle trunk) costs **100 coins, or one ad per 24 h** ([wiki Death](https://last-day-on-earth-survival.fandom.com/wiki/Death)).
- **The Reanimator** revives you once within 4 h. It's sold in the shop ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Reanimator)), at "£1" per a 2021 GB review.
- **Rations:** auto-clear a location into the inbox, skip regional dailies, and **replaced coins for Energy refills** ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Rations)). A reviewer says "Rations are 20x the price of coins" and impossible to earn for free ([App Store AU](https://apps.apple.com/au/app/last-day-on-earth-survival/id1241932094?see-all=reviews), Oct 2023).
- **Energy:** 200 cap, +15 per ad up to 5 ads a day, and the Healer gives +140 for an ad ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Energy), [Healer](https://last-day-on-earth-survival.fandom.com/wiki/Healer)).
- **Repair Station:** costs 3,600 genome plus 10 Borealis kills, and the timer can be skipped with coins ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station)).

**Top in-app purchases** (Apple lists up to 10 per storefront; fetched 2026-11-08):
- **"Pile of coins" ($1.99) is listed first** in 9 of the 17 storefronts: US, GB, CA, AU, DE, LU, RU, JP and PK.
- **"Product 0,99$"** is first in BR, IN, TR, MX and PH.
- **"Season Premium"** ($9.99 tier) is listed in UZ, KZ and PK.
- **"Season + 5 lvl. (Sale)"** ($2.99 tier) is listed in DE, LU, PK and RU.

Storefronts: [US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) · [GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094) · [DE](https://apps.apple.com/de/app/last-day-on-earth-survival/id1241932094) · [BR](https://apps.apple.com/br/app/last-day-on-earth-survival/id1241932094) · [UZ](https://apps.apple.com/uz/app/last-day-on-earth-survival/id1241932094) · [PK](https://apps.apple.com/pk/app/last-day-on-earth-survival/id1241932094) · [RU](https://apps.apple.com/ru/app/last-day-on-earth-survival/id1241932094).

**Inference:** Apple doesn't document how it orders this list, but it is consistent with sales rank. If so, the volume comes from $0.99–$1.99 impulse buys and coins, and the $9.99 pass is the steady mid-ticket.

### 1.4 Roblox facts that bind the shop

**Presentation rules** ([Creator Hub, Monetization](https://create.roblox.com/docs/production/monetization)), paraphrased. These are platform rules, so they apply on top of LDoE practice:
- Discounts "must be genuine and fair".
- An item that is always "on sale" at the same price isn't a genuine discount.
- A discount offered for only a very short time isn't fair.
- A countdown timer must be accurate and must never restart automatically for the same item.
- Don't claim scarcity that isn't true.
- Avoid pushy or urgent messages with minors. Use "View Item" or "Open Shop", not "LAST CHANCE".

**Inference:** LDoE's "−85%" anchors and recurring "limited" timers have to become real windows on Roblox: the reference price is actually charged first, the sale lasts days, timers never reset, and contents can change between windows.

**Other platform facts:**
- **Robux packs** (2026, USD): 400 = $4.99, 800 = $9.99, 1,700 = $19.99, 4,500 = $49.99, 10,000 = $99.99. Roblox Premium members get +10% ([RoWatcher](https://rowatcher.com/news/robux-prices-bundles-2026-guide)).
- **What the developer nets:** 70% of the Robux, cashed out at $0.0038 each, so **about $0.00266 per Robux a player spends**. Spend by age-verified US 18+ players in "novel" R15 games pays 42% more ([roblox-genres-monetization.md](roblox-genres-monetization.md) §4).
- **Inference:** a 799 R$ pass therefore nets about $2.13, or about $3.02 at the 18+ rate. LDoE's $9.99 pass nets about $7 after store fees. A Roblox sale is worth roughly 30–45% of an LDoE sale at the same player price, which argues for LDoE-parity prices, not lower ones.
- **Rewarded video:** viewers must be 13+. Creators need ID verification and 2K+ monthly visitors. Subscriptions are priced in Robux (from 49 R$), and regional pricing and price optimization are available (same doc §4).
- **Genre benchmark, Dead Rails** (Mar 2025): permanent +5 storage 79 R$, permanent weapon 148 R$, self revive 45 R$, revive everyone 200 R$ ([Slyther Games](https://www.slythergames.com/?p=16058)).

---

## 2. (a) The levers, ranked by revenue impact

**How they're ranked (Inference):** revenue = how often it's bought × price × share of payers who buy it. The evidence for each lever:
1. **Frequency:** recurring cadence, or a top-10 position in Apple's lists.
2. **Price:** the known price points.
3. **Complaint volume as a proxy for reach:** the §1.2 shares, Reddit thread counts and upvotes.
4. **Conversion psychology:** why the lever works.

The bigger and more persistent a complaint, the more players the lever touches.

| # | Lever | LDoE price evidence | Complaint proxy | Roblox format | When |
|---|---|---|---|---|---|
| 1 | **Season pass and level skips** | $9.99 per 21 days; +5 levels $2.99; +20 levels £19.99; Premium+ about 3× | Pass 3.4% of reviews but 11% of spenders; boycott threads with 50+ upvotes | Developer product per season, plus level-skip products | M2 |
| 2 | **Consumable gear packs (the re-buy loop)** | $0.99–$9.99 packs; Silenced and Special Forces packs ×1/×5/×10 | Death and loss 17.6% of 1–2★ reviews and **26% of spenders**; durability 4.5% | Repeatable developer products with fixed contents | v0.1 |
| 3 | **Premium currency and Rations (time)** | "Pile of coins" $1.99 is #1 in 9 of 17 storefronts; Tin $9.99; Rations replaced coins for Energy | Energy 10.3%; "spent over $2000… buying rations and coins" | Gold wallet (developer products) and Rations bought with Gold | v0.1 |
| 4 | **VIP spend ladder with lapse** | ~$240 to Prestige; ~$10 a day to keep Prestige; lapses after about a week | VIP mentions rose from 0.6% to 1.8%; whale reviews | Server-side status built from Robux spent | M3 (seeded in v0.1) |
| 5 | **Big-ticket base and capacity packs** | Up to $199.99 per item; 3×3 rooms at £99.99–£160; Rack $19.99 at "−85%"; Storages $5.99 | "£100 for a 2×2 METAL BASE"; a Reddit thread on a $100 room | Developer products from 1,699 to 17,999 R$; capacity passes | v0.1 (1,699), M2–M4 |
| 6 | **Long-goal parts, FILL UP and last-piece offers** | Chopper Parts Pack $19.99; "£20 for 1 wheel"; motorbike pack $30 | Part walls 9.6%; reinstalled "almost 10 times" for one wheel | Fill Up with Gold, part-pack products, a trigger at ≥80% complete | v0.1 (Fill Up), M4 (parts) |
| 7 | **Questline premium and 30-day subscriptions** | Ultra and Ultra Plus, 30 days each; old Survival Guide $4.99 | "you have to buy premium for each act" | Robux subscription, "Survivor Club" | M3 |
| 8 | **Event premiums and currencies** | "Every event has premium"; £30 exclusive events; 18,000 coins spent on one event | 2025–26 threads: "Every new event is behind a paywall" | Developer product per event, Gold for attempts | M3 |
| 9 | **First-purchase and win-back offers** | Raider's Starter (48 h); Legendary Survivor's Pack (~$2–5, ~$200 value); Hermit's Pack (returners) | Dozens of "is the Legendary pack still a thing?" threads, 2022–25 | A once-only developer product for non-payers; a win-back product | v0.1 (starter), M2 (win-back) |
| 10 | **Chance-based companions and crates** | Gunsmith and Armorer crates with every-5th pity; kitten boxes | Random boxes 8.5%, 18% of spenders; "40 bucks for 5 cats… all level 1s" | Odds shown, PolicyService alternative | M3–M4 |
| 11 | **Death recovery and revives** | Recover all 100 coins or 1 ad a day; Reanimator ~£1; coin resurrection | Bundled into the death complaint | Gold, ad and developer product | M2 |
| 12 | **Rewarded ads** | 5% of revenue (2019); energy, AUTO, TAKE, revive, box | Mostly "the ad didn't pay out" | Roblox rewarded video, 13+ | v0.1 |

### 2.1 Season pass and level skips (#1)

**What LDoE does:**
- A season lasts 21 days and has free and premium tracks, with 80 levels plus an infinite tier.
- **Premium pays out at purchase:** level 1 gives a fully modded VSS.
- The premium track returns about 150 coins and 29 Rations, so part of the price comes back as currency that gets spent on events.
- Levels earned before you buy are claimed retroactively.
- **Level skips:** +5 levels at the $2.99 "Sale" tier, and Premium + 20 levels at the $19.99 tier.
- After the last reward, premium owners keep earning chests every level ([FAQ 730](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/730-season-pass-bonus-rewards-and-how-to-get-them/)).
- The price went from $4.99 to $9.99 in 2023. Premium+ (about 3×) was added in Apr 2026.

**Why it converts:**
- **Endowed progress:** the gold premium row sits beside the rewards you have already earned.
- **Instant gratification:** a top gun the moment you pay.
- **A recurring habit:** "I always buy premium."
- **FOMO at season end**, which is what the +5 and +20 skips monetize.
- **Payers say it's the best value in the store:** "Season & Story Mode… a more than reasonable cost" ([App Store GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews), May 2023); "About $15 Aussie for the season pass will allow plenty of progress each month" ([App Store AU](https://apps.apple.com/au/app/last-day-on-earth-survival/id1241932094?see-all=reviews), Feb 2025); "it's well worth 9.99" ([App Store US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews), May 2026).
- **Skips as a value anchor:** buying "the premium with 20+ levels" at level 80 nets 20 purple prints for $20, against packs that sell 10 for $60 ([Reddit, Sep 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1nm5htb/purple_prints_for_p2w_players/)).

**Pain monetized:** the guns-and-armor grind, plus the deadline.

**Roblox implementation:**
- **Season Premium** (799 R$) is a developer product per season, not a game pass, because passes are permanent. The server stores `seasonId → premium = true`.
- **+5 levels** (249 R$) is a repeatable developer product, offered in the last 5 days or whenever you're within 5 levels of a reward.
- **Premium Bundle** (premium + 20 levels, 1,699 R$).
- Rewards earned before buying are claimed retroactively. Premium owners get a chest every level after the cap.
- A strong free track keeps free players playing. LDoE's free track carries real guns; it's the premium versions that are modded.
- Seasons last 21 days (§7).

### 2.2 Consumable gear packs and the re-buy loop (#2)

**What LDoE does:**
- It sells weapons, armor, meds and food as ordinary items. They lose durability, drop on death, and only the latest corpse can be recovered ([FAQ 32](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/32-i-lost-my-purchases-after-death/), [wiki Death](https://last-day-on-earth-survival.fandom.com/wiki/Death)).
- Packs come in ×1, ×5 and ×10 sizes: Silenced pack $0.99 / $3.99 / $6.99, Special forces €2.99 / €12.99 / €22.99.
- **Repair is withheld** until VIP 5 or the endgame Repair Station.

**Why it converts:**
- Loss aversion, plus an immediate need before a hard location, at an impulse price.
- Reviewers describe giving in: "I paid 5 dollars in a moment of regrettable desperation" (US, Oct 2020); "I finally gave in and decided to buy a few packs", then spent $4 on one weapon that would soon wear out (US, Feb 2020).
- Small offers arrive right after a loss, at $1 or $4: "you knew exactly when to make me an offer" (CA, May 2023).

**Pain monetized:** durability ("guns break before even clearing an area", US, Mar 2026) and the full drop on death.

**Roblox implementation:**
- **Scavenger's Kit** (79 R$, repeatable) with fixed contents: no randomness, so no odds disclosure is needed.
- Bought items land in the inbox or locked stash and are raid-proof there. **Once carried into a run, they can be lost like anything else.** That keeps the re-buy loop working without breaking the rule that purchases are raid-proof.
- Tiered kits arrive in M2: Scrap kit 249, a Standard Firearms kit of 799 analogous to "Special Forces", and ammo bundles.
- Keep durability at LDoE rates and no repair before VIP 5 (§7).

### 2.3 Premium currency and Rations: selling time (#3)

**What LDoE does:**
- **Coins buy:** timer skips, raider-task skips (45–125), event attempts and boosts (100), cat growth (299), recover-all (100) and resurrection ([wiki Coins](https://last-day-on-earth-survival.fandom.com/wiki/Coins), [core-systems](ldoe-core-systems.md)).
- **Rations buy:** Energy refills, auto-clear of a location into the inbox, TAKE ALL on bonus loot, and skips of regional dailies.
- **Coins sell the most:** "Pile of coins" ($1.99) heads Apple's list in 9 of 17 storefronts.

**Why it converts:**
- A currency makes prices feel small, and leftover balances pull you back.
- It converts money into time at the exact moment you're frustrated.
- Whales buy it in bulk: "I've spent over $2000 on this game… by buying rations and coins" (AU, Jan 2022, a 5★ review); "I just bought 200 of them [rations]" ([Reddit, 2019](https://www.reddit.com/r/LastDayonEarthGame/comments/dvybaf/umm_how_do_i_go_about_getting_a_refund_for_the/)).

**Pain monetized:**
- **Energy:** 1 point per 5 min, 16 h 40 m for a full bar. One returner ran dry after about 10 minutes and said it was why they had quit the first time (GB, Apr 2026).
- The repetitive farm loop, which AUTO removes.

**Roblox implementation (Gold is required, Inference):**
- Developer products have fixed prices, so a Fill Up of "37 plates" or a speed-up priced by time left can only be paid from a wallet.
- **Gold** comes as six developer products with a bonus ladder (§7). Rations are bought with Gold, and Energy Refill stays a direct one-tap developer product.
- The Gold balance with a "+" sits on every screen ([checklist 4.8](../PLAYER_EXPERIENCE_CHECKLIST.md)).

### 2.4 VIP spend ladder with a lapse (#4)

**What LDoE does:** §1.3. Every purchase earns points, and status suspends after about a week without buying. The perks most players rely on are the repair bench (VIP 5), Energy discounts, bench speed and XP. Prestige adds the auto-loot storage and the daily indestructible weapon.

**Why it converts:**
- **It multiplies every other lever:** any purchase, even $0.99, reactivates it, so the lapse turns a monthly spender into a weekly one.
- **Endowment:** losing perks hurts more than never having them.
- **Visibility:** "Can friends see your vip level?" ([Reddit, 2021](https://www.reddit.com/r/LastDayonEarthGame/comments/qnli4r/can_friends_see_you_spent_money_on_the_game/)).
- **Dependency:** a repeat-Prestige whale writes "I really rely heavily on that repair bench" (US, Dec 2023); "i have to choose between feeding my kids or keeping the vip active" (US, Sep 2026, 5★).

**Pain monetized:** durability (repair), Energy and bench timers.

**Roblox implementation:**
- **VIP status is server-side** and built from Robux spent across developer products, passes and subscriptions: 1 point per 10 R$. Levels use LDoE's increments (§7).
- **Active for 7 days after each purchase.** The Survivor Club subscription keeps it active.
- **Keep the paid pass and the status separate.** The VIP Lounge game pass is permanent, because game-pass perks must not lapse. The status perks, which are earned by spending rather than sold as an item, can lapse if the rule is shown in plain words before purchase.
- **v0.1 seed:** any purchase opens the Haven VIP Lounge for 7 days. That's LDoE's "VIP 1 after any purchase" rule, and it makes every first purchase visible to the whole Neighbourhood.

### 2.5 Big-ticket base and capacity packs (#5)

**What LDoE does:**
- Room kits, storage racks, fridges, lockers, extra furnaces and placement capacity. Its biggest single SKU is $199.99.
- Players quote "3x3 rooms with maxed walls for £160" (GB, Aug 2026), "£99.99 on building a 3x3 base" to keep loot safe from raiders (GB, Feb 2023), "£100 for a 2x2 METAL BASE" (GB, May 2024), "a 100 dollar 3x3 Metal room" ([Reddit, 2020](https://www.reddit.com/r/LastDayonEarthGame/comments/icknps/i_stg_i_wish_this_game_would_just_to_p2w_micro/)) and "$100+ storage lockers" (Google Play, Sep 2026, per [retention doc](ldoe-retention-sentiment.md)).
- The shop sells "+1 max furnace can be placed" packs, and the Rack sells at "−85%" ([rec2, rec8](../reference/ldoe-recordings/NOTES.md)).
- **Sales on big tickets create the stories players tell:** "I bought the metal base when it was $20" ([Reddit, 2021](https://www.reddit.com/r/LastDayonEarthGame/comments/q58qwt/i_love_this_season_after_a_1yr_of_playing_im/)).

**Why it converts:**
- Base pride, raid safety, and skipping the longest grind (late-tier materials).
- It's the ceiling for whale spend.
- Deep, real sales on these items drive the December and event spikes.

**Pain monetized:** storage scarcity, plus the steel and titanium grind.

**Roblox implementation:**
- **Room kits** are developer products delivered to the inbox. At home, building draws from the inbox, so a kit far bigger than any bag is usable at once ([GAME_DESIGN](../GAME_DESIGN.md) inbox rule).
- **Ladder:** Reinforced Room Kit 1,699 (v0.1), Outpost Pack 4,499 (M2), Fortress Kit 9,999 (M4), Stronghold 17,999 (M4, VIP 5+).
- **Capacity products** are permanent game passes (+slots, +1 placement) or Gold upgrades on each crate's arrow (LDOE_PARITY #16).
- **Raid rule:** sold capacity is **raidable** storage only (§7).

### 2.6 Long-goal parts, FILL UP and last-piece offers (#6)

**What LDoE does:**
- Vehicles need hundreds of parts, tracked on a visible checklist with FILL UP for coins (rec4).
- It sells part packs: the Chopper Parts Pack $19.99 (rec2), and Mechanic's and Specialist's packs with wheels, a fork and a gas tank ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Packs)).
- Some parts are premium-locked: "2 parts which are locked because they are premium" (US, Aug 2026).
- **Last-piece targeting:** once the drop chance of a player's last ATV Transmission fell below 1%, the game "forces a pop-up ad" selling that part (CA, Dec 2024).
- **Quest nudges:** "the game keeps telling me to buy the chopper for 30$" (AU, Mar 2025).

**Why it converts:**
- The goal-gradient effect: the closer the goal, the harder the pull.
- The last missing piece converts best. "I refuse to pay £20 for 1 wheel" (GB, Nov 2024) is the refusal of exactly the offer that works on others.

**Pain monetized:** RNG part drops. One player has "uninstalled and reinstalled the game almost 10 times" hunting a single motorcycle wheel (US, May 2026).

**Roblox implementation:**
- **v0.1:** FILL UP in every craft, build and upgrade panel, paid in Gold (already in MVP_LAUNCH). The wrecked hauler checklist (CONTENT_MVP) gets a FILL UP button from day one.
- **M4:** part packs (1,699 R$, LDoE's $19.99 tier), plus a triggered offer when a checklist reaches 80% done and the missing part is rare.

### 2.7 Questline premium and 30-day subscriptions (#7)

**What LDoE does:**
- A premium row sits on every Survivor's Path reward ("BUY ULTRA", rec5). Ultra and Ultra Plus run 30 days each (§1.3).
- The earlier "Survival Guide" sold the full version at $4.99, which players called "great value" (GB, Jun 2019).
- **Cross-selling:** "+10% season XP" sits in the Path subscription, not the season pass ([Reddit, Apr 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1jxry09/brainwashed/)).

**Why it converts:**
- Earned-but-locked rewards, with a timer on claiming.
- Each act or chapter is sold again: "during the storyline you have to buy premium for each act" (GB, Aug 2023).

**Roblox implementation: a Robux subscription, "Survivor Club"** (499 R$/month):
- the Ember Trail premium row
- +10% XP and +10% pass XP
- **claim every rewarded-ad bonus without watching** (within the daily caps)
- VIP kept active
- 5 Gold a day

**Inference:** players under 13 can't see rewarded ads on Roblox, so for them the Club is the only way to get ad rewards. That makes it a stronger conversion lever on Roblox than on mobile.

### 2.8 Event premiums and currencies (#8)

**What LDoE does:**
- Monthly events of about 11 days, each with free and premium reputation tracks.
- **The free track falls short of the headline reward by design:** "You only get around 2000 eggs from free rewards, the coop costs 5000" ([Reddit, Apr 2026](https://www.reddit.com/r/LastDayonEarthGame/comments/1sadw18/p2w_event/)); "Just spent 18000 coins during pursuit of luck and came up 1200 clovers short" ([Reddit, Jan 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1i22zpj/just_spent_18000_coins_during_pursuit_of_luck_and/)); "exclusive events priced at £30" (GB, Aug 2026).

**Why it converts:** a time-limited exclusive, plus sunk effort near the end.

**Roblox implementation (M3):**
- Event Premium track (499 R$) and an Event Bundle (2,499 R$, LDoE's ~$30 tier).
- Gold for extra attempts or boosts (100 Gold, LDoE parity).
- **Free players earn about 40% of the headline cost.** That's LDoE's ratio; see §5 for where the line sits.

### 2.9 First-purchase and win-back offers (#9)

**What LDoE does:**
- **Raider's Starter Pack:** only in the first 48 h ([wiki](https://last-day-on-earth-survival.fandom.com/wiki/Raider%27s_Starter_Pack)).
- **The Legendary Survivor's Pack** went to non-payers only:
  - It popped up on the map with a "Later" button and "used to… pop up every 2~3 weeks" for players who had never paid ([Reddit, May 2023](https://www.reddit.com/r/LastDayonEarthGame/comments/13qeiwd/for_those_interested_in_buying_the_legendary/)).
  - It disappeared for good after any purchase: a player who bought a £0.99 puppy lost it ([Reddit, Apr 2023](https://www.reddit.com/r/LastDayonEarthGame/comments/12wo0sk/legendary_survivors_pack/)).
  - It cost about $2 ("I bought the legendary survivor pack for 2 dollars", [Reddit, Apr 2023](https://www.reddit.com/r/LastDayonEarthGame/comments/12vph43/good_way_to_spend_coins_i_bought_the_legendary/)), or 250 INR ([Reddit, 2022](https://www.reddit.com/r/LastDayonEarthGame/comments/uu22qq/difference_between_legendary_survivors_pack_and/)).
- **The returner version (Hermit's Pack)** appeared after about a week away ([Reddit, 2022](https://www.reddit.com/r/LastDayonEarthGame/comments/t7k3a5/about_the_hermits_pack/)). One player back after a year got a $5 offer holding a 3×3 metal room, 1,000 coins, about 500 caps, a complete Chopper and about 200 rations, which they valued at "about $200" ([Reddit, Dec 2020](https://www.reddit.com/r/LastDayonEarthGame/comments/k9ctla/did_anyone_else_get_some_extremely_good_deal/)).
- **Demand evidence:** at least 20 threads from 2022–2025 ask whether the Legendary pack still exists.

**Why it converts:**
- It breaks the first-purchase barrier with outsized value.
- The first purchase turns on VIP 1, and players who have paid once pay again.
- Segmenting by payer status means non-payers see the deal that converts them.

**Roblox implementation:**
- **Firestarter Kit** (99 R$): offered **only to accounts that have never purchased**, and only once, with an accurate 48 h countdown after the first win. Contents are worth about 10–20× the price (§6).
- **Win-back Cache** (399 R$, M2): for players back after 7+ days away, with different contents each time so no countdown ever "restarts for the same item".

### 2.10–2.12 Chance items, death recovery, rewarded ads

**Chance items (#10)**
- LDoE's pity crates ("every 5th crate") and kitten boxes convert collectors: "Spent 40 bucks for 5 1-4 level cats" (US, Jun 2026). Another player opened six crates and "still didn't got the damn chopper wheel" ([Reddit, Mar 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1j13u2s/i_want_slowly_to_quit/)).
- **On Roblox:** every paid random outcome shows all outcomes and odds before purchase. Where `PolicyService` restricts paid random items, offer a direct-purchase alternative instead. Ship them with the Kennel's Prime Feast in M3 (odds shown in the breeding panel, per [GAME_DESIGN](../GAME_DESIGN.md)), and crates with pity only once the odds UI exists.

**Death recovery (#11)**
- LDoE: 100 coins or 1 ad per 24 h, the Reanimator, and coin resurrection since Sept 2026.
- **Ours (M2):** "Recover all" for 1 ad a day (13+) or 100 Gold, plus the Ember Heart (CONTENT_S2's Reanimator) at 79 R$ for 3.
- **Integrity rule:** recovery restores only what is still on the body when the lobby closes. It never restores items another player looted, because that would duplicate loot and gut PvP fog (§7).

**Rewarded ads (#12)**
- Ads were 5% of LDoE's revenue in 2019. Players tolerate them, and the complaints are about ads that fail to pay ("Watched 3 ads, only to receive an astounding 0 energy!", [Reddit, 2020](https://www.reddit.com/r/LastDayonEarthGame/comments/i8d3e9/ads_for_energy/)).
- **On Roblox:** viewers must be 13+. Caps follow LDoE (§7). The reward must be granted server-side even if the client crashes mid-ad, because a broken ad is a lost payer.

---

## 3. (b) Offer timing and triggers

**Global rules (Inference, built from LDoE evidence and Roblox's rules):**
1. **Modal offers:** at most one per session, at login, chosen by the player's state. Never in the first session before the first win.
   - LDoE floods the login screen ("As soon as you log in your smothered with deals", GB, May 2024; "Every time you log in they are putting new 'deals' in your face", US, Jul 2025). The flooding drew complaints but kept selling.
   - One well-targeted modal captures most of that value with less churn.
2. **Contextual offers:** non-modal chips inside the panel where the need arises (travel, craft, inventory toast, death screen). There's no session cap on these, but each trigger type shows at most once per 24 h as a highlighted chip.
3. **Never interrupt combat or a run in progress.** Offers appear on the map, at home, on the death screen and on the loading screen (LDOE_PARITY #43 allows one offer card during the Run load).
4. **Timers are always accurate and never restart for the same SKU.** A re-offer is a different SKU with different contents, and every "discount" is against a price actually charged before (§1.4).
5. **Neutral calls to action everywhere:** "View offer", "Open shop", "See price". That's Roblox's guidance for minors, and using it globally avoids having to detect age.
6. **Log every impression and conversion by trigger** (the Analytics service exists). Retire triggers that convert under 0.5% of impressions after 14 days, and let Price Optimization test the top four SKUs.

| Trigger | LDoE evidence | Our condition | Offer (R$) | Surface | Milestone |
|---|---|---|---|---|---|
| **First purchase** | Raider's Starter 48 h; the Legendary pack for non-payers only, popping on the map | First win: the first night survived or the first extraction, never purchased before | Firestarter Kit 99, accurate 48 h timer, once | Full-screen card after the win, then the shop's "Best" tab until it expires | v0.1 |
| **Out of Energy (moment of need)** | "+" beside Energy; refill in the travel panel (rec1, rec3) | Run pressed with Energy below the Run cost | Energy Refill 99, or spend 2 Rations | The Run/Walk panel (Refill button beside Walk) | v0.1 |
| **Missing materials** | FILL UP on blueprints (rec4); storage upgrade BUY (rec8) | Any craft, build or upgrade with a shortfall | Fill Up in Gold (§7); if Gold is short, Gold Pouch 149 or Gold Chest 799 | The have/need row of the panel | v0.1 |
| **Waiting on a timer** | Coins skip benches; the cat skip at 299 | A station or converter has a job with ≥ 2 min left | Speed-up in Gold, priced by time left | Station row | v0.1 |
| **Death** | Recover all for coins or an ad; "offer advertisements when you die" (US, May 2023) | Death in any location | v0.1: Scavenger's Kit 79. M2: Recover all (ad once a day or 100 Gold) | Death screen, one chip | v0.1, M2 |
| **Broken weapon** | Auto-switch on break; "guns break before even clearing an area" | A weapon breaks during a run (offer at home or on the map, never mid-fight) | Scavenger's Kit 79 | Toast after extraction; chip on the map | v0.1 |
| **Inventory full** | Pack scarcity; backpacks sold in packs | A pickup is refused for lack of space | Pack Expansion pass 199 (once per session until owned); then TAKE ALL to inbox for 1 Ration | The "inventory full" toast | v0.1 |
| **Storage or placement full** | Storage packs, "+1 max furnace" (rec8) | A deposit is refused, or a placement hits "Installed x/y" | Crate upgrade in Gold (BUY on the arrow); M2: capacity passes | Storage header, build tray | v0.1 (Gold), M2 |
| **Travel** | Travel pop-up offer with a 22 h timer (rec3); events popping when Energy is low ("always pop up when my energy is too low", CA, Aug 2024) | Loading into a location whose recommended gear score is above yours; or a timed event pin while Energy < 30 | Scavenger's Kit 79; Energy Refill 99 on the event card | Loading-screen card; event card | v0.1 |
| **New tier unlocked** | Settlement offers after Chapter 2 ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/13qeiwd/for_those_interested_in_buying_the_legendary/)) | Scrap tier unlocks (quest 8); Reinforced tier unlocks | Builder's Crate 399 (Rivets are the star); Reinforced Room Kit 1,699 | Unlock celebration card, then the "Best" tab for 72 h (no countdown) | v0.1 |
| **Last piece** | Pop-up for the last ATV transmission when drop odds are under 1% | A parts checklist is ≥ 80% complete and the missing part is rare | Part pack 1,699, or FILL UP | The checklist screen | M4 |
| **Returning player** | Hermit's Pack after about a week away; the $5 → $200 offer after a year | 7+ days since last session | Win-back Cache 399 (new contents each time) | Login modal | M2 |
| **Season end** | "+5 lvl (Sale)" | Last 5 days of a pass, or within 5 levels of a premium reward | +5 levels 249; Premium Bundle 1,699 | Pass screen | M2 |
| **VIP lapsing** | Weekly lapse; "7 day vip pass" | VIP active with < 24 h left | Any product; the Club keeps it active | VIP badge, accurate timer | M3 |
| **Raided (M2)** | (Not applicable: LDoE raids are AI-only) | Your base was raided | Rebuild kit (materials) and defense pack (turrets and traps). **Never a shield.** | Raid log screen | M2 |
| **Inbox opened** | "the offers showed when I open the inbox" (US, Oct 2026) | Inbox opened | Passive banner for the current best offer | Top of the inbox | v0.1 |

---

## 4. (c) The price ladder in Robux

**Conversion rule (Inference):**
- A player buys Robux in packs: 400 for $4.99, 800 for $9.99, 1,700 for $19.99, 4,500 for $49.99, 10,000 for $99.99. Small packs cost about 1.25¢ per Robux and the 10,000 pack 1.0¢.
- LDoE's USD price is mapped to Robux at about **80 R$ per $1** up to $20, and about **90–100 R$ per $1** above that.
- **Each price is then snapped so that it fits exactly one pack or a pair of packs.** A player with an empty wallet then pays exactly one "real" price, with nothing stranded.
- Prices under 400 leave a leftover balance. For example, 79 R$ leaves 321 R$ from a 400 pack. **Inference:** that balance is the cheapest second purchase there is, because the next moment-of-need chip is one tap away. It's LDoE's leftover-coins effect, free on Roblox.

| LDoE USD tier | LDoE examples (source) | Robux | Pack fit | Our products |
|---|---|---|---|---|
| $0.49 | Lowest Play SKU ([Google Play](https://play.google.com/store/apps/details?id=zombie.survival.craft.z&hl=en_US&gl=US)) | **49** | 400 pack, leaves 351 | (M2) single Ember Heart, Daily Deal unlock |
| $0.99 | Survivor's Pack, Silenced pack, the "£0.99 Husky puppy" | **79** | 400 pack, leaves 321 | Scavenger's Kit; Ember Heart ×3 (M2) |
| $0.99 (first buy) | Legendary pack (~$2) | **99** | 400 pack, leaves 301 | Firestarter Kit; Supply Bundle; Energy Refill |
| $1.99 | Pile of coins (the #1 IAP) | **149** | 400 pack, leaves 251 | Gold Pouch (50 Gold) |
| $2.49 | (fills the step) | **199** | 400 pack, leaves 201 | Pack Expansion pass |
| $2.99 | Special forces pack; Season +5 levels | **249** | 400 pack, leaves 151 | +5 pass levels (M2); Scrap weapon kit (M2) |
| $4.99 | Savings pack; Survival Guide; Product 4,99 | **399** | exactly 400 | VIP Lounge pass; Builder's Crate; Gold Satchel; Win-back Cache (M2); Event Premium (M3, at 499) |
| $9.99 | Season Premium; Tin with Coins; Zombie Warfare Pack | **799** | exactly 800 | Season Premium (M2); Gold Chest; Standard Firearms kit (M2) |
| $14.99 | Product 14,99; Ultra Plus (inferred) | **1,199** | 800 + 400 | Club+ (if tested); Kennel bloodline (M3) |
| $19.99 | Chopper Parts Pack; Rack; Premium + 20 levels; drone pack | **1,699** | exactly 1,700 | Reinforced Room Kit; Premium Bundle (M2); Vehicle Part Pack (M4) |
| $29.99 | Motorbike pack ($30); £30 event exclusives; Premium+ (~3×) | **2,499** | 1,700 + 800 | Event Bundle (M3); Premium+ pass tier (M3) |
| $49.99 | (Product tiers) | **4,499** | exactly 4,500 | Outpost Pack (M2); Gold Strongbox |
| $99.99 | 3×3 metal room (~$100 / £99.99) | **9,999** | exactly 10,000 | Fortress Kit (M4); Gold Vault |
| $199.99 | Top Play SKU; £160 maxed rooms | **17,999** | 10,000 + 4,500 + 1,700 + 1,700 (≈ $190) | Stronghold Kit (M4, offered to VIP 5+ only) |
| Subscription | Ultra / Ultra Plus, 30 days (§1.3) | **499 / month** | (Robux subscription) | Survivor Club (M3); test 799 |
| Spend ladder | VIP Prestige ≈ $240 (2,400 points) | **24,000 R$ total** | — | VIP ladder (M3): 1 point per 10 R$ |

**What we net (Inference):** the developer receives about $0.00266 per Robux spent, or about $0.0038 for 18+ uplift spend.

| Purchase | Net (18+ rate) |
|---|---|
| 99 R$ | $0.26 ($0.37) |
| 399 R$ | $1.06 ($1.51) |
| 799 R$ | $2.13 ($3.02) |
| 1,699 R$ | $4.52 ($6.42) |
| 9,999 R$ | $26.60 ($37.80) |

**Price testing:** read every price from MarketplaceService (already done in CONTENT_MVP), turn on regional pricing for passes, and enroll all developer products in Price Optimization. Subscriptions can't be optimized.

---

## 5. (d) The retention-vs-monetization line

### 5.1 What made LDoE players quit (churn), ranked

1. **Losing the one big item.** Death and loss show up in 17.6% of 1–2★ reviews.
   - A parent's two sons spent $200+ and "never came back after losing tactical backpack over and over again" (GB, May 2025).
   - "I lost all my fur… Fur is hard to get so i gave up" (US, Apr 2026); "losing all your gear 6 times makes me want to quit" (US, Sep 2026).
   - "i was not going back to a smaller backpack, therefore I deleted the app" (CA, Mar 2022).
2. **Bugs, lost accounts and undelivered purchases** (18.9% of 1–2★). The commonest payer rage is "I bought X and didn't receive it" or "I watched the ad and the restore failed" ([Reddit, 2023](https://www.reddit.com/r/LastDayonEarthGame/comments/173wyae/does_one_quit_after_this/), 105 comments).
3. **Hard walls on a single part**, especially premium-locked parts.
   - Reinstalled "almost 10 times" over one wheel (US, May 2026).
   - Another player will quit "if I can't get the last chopper wheel" (US, May 2026).
   - "Reality Check… quit after you complete the ATV" ([Reddit, 2024](https://www.reddit.com/r/LastDayonEarthGame/comments/1b9ii68/reality_check/)).
4. **Price shocks on recurring products, and nerfs to paid things.**
   - Pass $4.99 → $9.99: a monthly buyer at $4.99 stopped buying once "they upped the price to 9.99" (US, May 2024).
   - The VIP-zone loot nerf: "I spent 350$ Canadian on that and the nerf it" (CA, Nov 2021).
   - The 2025 pass that gutted the free track drew a boycott thread.
5. **Fully paywalled events.** "Every new event is behind a paywall now", so the poster stopped caring about new ones ([Reddit, Jun 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1llmzoi/losing_my_excitement_for_upcoming_events/)); "Kefir needs to chill" ([Reddit, Oct 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1nxymkb/kefir_needs_to_chill/), 58 comments).
6. **Energy for binge players.** "Ok im done with this garbage, this energy system needs to go" ([Reddit, May 2025](https://www.reddit.com/r/LastDayonEarthGame/comments/1kv7i7l/ok_im_done_with_this_garbage_this_energy_system/)). Yet raising the cap to 200 "made the game super less stressful" ([Reddit, 2021](https://www.reddit.com/r/LastDayonEarthGame/comments/nttfen/when_they_made_energy_to_200_it_made_the_game/)).
7. **Coming back to a wrecked base.** "a week off… you come back to a raided base… an instant uninstall" (CA, Mar 2026).
8. **Rigged-feeling RNG** (11.3% of 1–2★).

### 5.2 What made them pay anyway, ranked

1. **The season pass as the value buy:** a reviewer spends only "when there's a sale or a season pass" (GB, Nov 2023); an 8-year player has spent hundreds and adds "I subscribe monthly to premium also" (CA, Aug 2023).
2. **Cheap packs at the moment of loss or need:** "in a moment of regrettable desperation" (US, Oct 2020); "I finally gave in" (US, Feb 2020).
3. **Deep, real one-off deals:** "DISCOUNT! 90% off?! Amazing!" (US, Apr 2021); a returner at Lunar New Year "saw some amazing deals" and spent $40 (AU, Feb 2021); the Legendary and Hermit packs (§2.9).
4. **VIP dependency:** repair and Prestige (§2.4).
5. **Near-complete long goals:** chopper and ATV parts (§2.6).
6. **Time for whales:** "over $2000… buying rations and coins" (AU, Jan 2022).
7. **Questline premium value:** "paying the £4.99 for the full survival guide is great value" (GB, Jun 2019).
8. **Sunk cost:** "i have spent probably close to… £100… is half the reason i keep it" (GB, Apr 2023).

**Inference:** the levers that make players pay and the ones that make them quit are mostly the same mechanics, at different intensity. Loss sells gear until it wipes out the one irreplaceable item. Walls sell parts until the part can't be found at all. Prices sell until a recurring one jumps. So the line isn't "monetize less". It's: keep every pain recoverable by money **and** by grind, and never take back what was sold.

### 5.3 Why free players must stay (revenue logic, not fairness)

Free players are:
- **content:** they fill the 8–12 player lobbies and the 6–8 plot Neighbourhoods, and they appear on the Blood Moon leaderboard
- **raid and PvP targets:** payers need someone to raid, and an empty server has no one
- **future payers:** returners buy on sales and win-back offers

LDoE's own raid feature withered because "nobody raids, nobody gets raided": only 2% of recent reviews even mention raids ([retention doc](ldoe-retention-sentiment.md)). Our raid and PvP pillar only earns money if a large, grinding free population exists.

### 5.4 The line: ten rules

1. **A free path to every gate, made miserable.** Every part, material and blueprint must also drop somewhere, even at under 1% or at the end of a long chain. A premium-only part makes players uninstall and reinstall. A brutal free path keeps them grinding next to the offer, and that is where it converts.
2. **Carried items are at risk, stored items are not.** Bought gear is raid-proof in the inbox and stash, but can be lost once carried into a run. That keeps the re-buy loop. To protect against rage-quits, the secure pouch (GAME_DESIGN), the 2 h death bag (CONTENT_MVP) and ad or Gold recovery (M2) mean one bad death can always be undone, for a price.
3. **Never raise a recurring price. Add a tier.** LDoE lost monthly buyers going from $4.99 to $9.99. Launch the pass at its final price (799) and grow revenue with the Premium Bundle and Premium+ above it.
4. **Never nerf anything already sold.** Tune with new SKUs and new content, never by weakening the VIP Lounge, a kit or a pass that people paid for (the VIP-zone loot nerf drove a whale to stop spending).
5. **Events: the free track pays out a real mid-tier reward and about 40% of the headline cost.** That's LDoE's ratio. Below that, "I stopped caring" posts appear and event participation, the funnel for event premiums, collapses.
6. **Energy bites heavy players, not short sessions.** The binding numbers (200 cap, +1 per 5 min, Runs at 15/22/33) give a fresh bar 6–13 runs, so a 20-minute session never hits zero. Energy refills then sell to the 3-hours-a-day player, which is exactly where LDoE's Rations money comes from.
7. **Light fog stays PvE forever,** so free players always have a safe lane, and gear-score power bands in Dense and Black keep payers' bought guns aimed at other geared players and AI raiders. **Inference:** payers still win more fights at equal skill, which is the P2W product. Free players can always choose not to be prey.
8. **New-player protection, and protection after being raided,** stay free and are never sold (GAME_DESIGN raid rules). That avoids the "came back to a raided base" uninstall.
9. **Purchase delivery is bulletproof.** ProcessReceipt is idempotent, everything goes to the inbox, and ad rewards are granted server-side after the ad completes, even if the client crashes. In LDoE this is a top payer rage point (§1.2: 20% of spenders).
10. **Win-back over write-off.** LDoE players binge, quit and come back. Every lapsed player gets a win-back offer, a pass catch-up (+5 levels at a genuine discount), and an inbox gift waiting for them.

**Kill switches (watch weekly):**
- D7 and D30 retention for payers versus non-payers
- the share of free players raided more than twice a week
- churn within 48 h of losing an item worth 400+ R$
- conversion by trigger
- refund and support tickets per 1,000 purchases

If free-player D7 falls below the Roblox survival median (§3.8 of [roblox-genres-monetization.md](roblox-genres-monetization.md)), loosen the specific wall, not the prices.

---

## 6. (e) The v0.1 launch shop and post-launch roadmap

### 6.1 The v0.1 shop: 10 SKUs

All four planned products are kept. Six new ones are added, plus the Haven Square VIP pass. Everything is delivered to the inbox (raid-proof, never expires). Prices are display fallbacks; the live price comes from MarketplaceService.

| # | SKU (ID) | Type | R$ | Limit | Contents | Main surfaces |
|---|---|---|---|---|---|---|
| 1 | **Firestarter Kit** (`product.starter_offer`) | Dev product | 99 | Once; never-purchased accounts only; 48 h after the first win | Scrapblade, Padded Hood, Padded Vest, 10 dressings, 5 Hearth Stew, 3 tonics, 30 planks, 10 plates (current), **plus a Scrap Room 3×3 materials set, a +10 satchel, 100 Gold and 5 Trail Rations**. Target value about 10–20× the price (the Legendary pack lesson) | Post-win card; Best tab |
| 2 | **Scavenger's Kit** (`product.scavenger_kit`, new) | Dev product | 79 | Repeatable | Scrapblade, Padded Vest, 5 dressings, 5 Hearth Stew, 5 boiled water. Fixed contents | Death screen; broken-weapon toast; loading-screen card |
| 3 | **Outpost Supply Bundle** (`product.resource_pack`) | Dev product | 99 | Repeatable | 60 timber, 60 stone, 40 scrap, 30 planks, 10 plates (current). ECONOMY checks it equals about 1.5 grind-hours (§7) | Fill Up fallback; Building tab |
| 4 | **Builder's Crate** (`product.builders_crate`, new) | Dev product | 399 | Repeatable | Timber-to-Scrap ladder materials, about 6 grind-hours, **with Rivets (the Scrap bottleneck) as the star** | Scrap-tier unlock card; Best tab |
| 5 | **Reinforced Room Kit 3×3** (`product.room_kit_reinforced`, new) | Dev product | 1,699 | Repeatable | At launch a long start on a 3×3 Reinforced room (30 Ironbark Planks, 12 Copper Wire, 30 plates, 20 rivets, 60 blocks), about 32 of the room's ~145 grind-hours; the card says exactly that, never "every material". LDoE's room-kit lever | Reinforced unlock card; Outpost tab |
| 6 | **Energy Refill** (`product.energy_refill`) | Dev product | **99** (was 49) | Repeatable | +100 Energy; can overfill to the 400 hard cap | Run panel Refill button; event cards |
| 7 | **Gold Pouch** (`product.gold_50`, new) | Dev product | 149 | Repeatable | 50 Gold | Fill Up and speed-up shortfall; Currency tab |
| 8 | **Gold Chest** (`product.gold_300`, new) | Dev product | 799 | Repeatable | 300 Gold (+12% over the Pouch rate) | Currency tab; prompted when the shortfall is over 50 Gold |
| 9 | **Pack Expansion** (`product.backpack_upgrade`) | Game pass | **199** (was 149) | 1 | +5 backpack slots, permanent | Inventory-full toast |
| 10 | **VIP Lounge** (`pass.vip_lounge`, new) | Game pass | 399 | 1 | Permanent Haven VIP Lounge access; flame aura; **+40 Energy cap** (200 → 240); a **daily fixed VIP crate** in the inbox (1 Hearth Stew, 1 boiled water, 1 dressing, plus 1 Trail Ration every 7th consecutive day). Fixed contents, so no odds rule applies | The Lounge gate (visible from the plaza); VIP tab |

**v0.1 behaviours that go with the shop:**
- **Gold sinks:** Fill Up, speed-ups, crate upgrades, Rations (20 Gold each, 5 for 90), and TAKE ALL or AUTO via Rations.
- **Any purchase unlocks the VIP Lounge for 7 days.** It's LDoE's VIP 1 rule and a social billboard.
- **A daily free claim** in the shop (LDoE's daily free box, rec8): one fixed item.
- **Rewarded ads for 13+:**
  - AUTO 10 a day
  - TAKE one item per ad, 10 a day
  - Energy +15, 5 a day
- **The moment-of-need triggers** in §3 marked v0.1.

### 6.2 Post-launch roadmap by milestone

| Milestone | Levers added | SKUs (R$) |
|---|---|---|
| **v0.1.1 (launch + 2–3 weeks)** | **First real holiday sale.** Black Friday is 27 Nov 2026, and LDoE runs Black Friday and December sales every year. Only SKUs that have been at full price for 14 days or more get a discount badge. Newer SKUs get "+50% Gold" bonus contents instead, which isn't a price discount. The sale runs at least 72 h with an accurate timer. Also: **Ember Cache**, the savings-pack piggy bank (fills with XP, pay to open), and the **Week Pack** (Gold now plus a daily drip for 7 days, which needs daily logins) | Ember Cache 399; Week Pack 399 (100 Gold now + 30 a day ×7); Gold Satchel 399 (140) |
| **M2 (raids and PvP)** | **Season pass #1**, pulled forward from "Later" because it's the #1 recurring lever. Death recovery (ad or Gold); Ember Heart; Daily Deals in Gold, with refreshes by ad; weapon and ammo packs; secure-pouch upgrades (game passes; a Tarkov-proven lever); breach-charge packs and turret or trap defense packs (allowed; **no shields**); capacity passes (+Trunk, +Rack, +1 placement); win-back offer; a 48 h "Raider's" pack on first entry to Dense fog; Outpost Pack | Season Premium 799; +5 levels 249; Premium Bundle 1,699; Ember Heart ×3 79; Scrap weapon kit 249; Standard Firearms kit 799; Ammo bundle 149; Pouch +1 slot 299 then +2 slots 799; Breach pack 399; Defense pack 399; Rebuild kit 249; capacity passes 199–399; Win-back Cache 399; Raider's 48 h pack 399; Outpost Pack 4,499; Gold Crate 1,699 (680) and Strongbox 4,499 (1,900) |
| **M3 (guilds, companions, live defense)** | **Survivor Club subscription** (Ember Trail premium row, ad-free claims, VIP kept active); **VIP points ladder** with a 7-day lapse and Prestige, the **Repair Bench at VIP 5**, and Prestige auto-delivery of loot in Light fog only; Kennel (Prime Feast with odds shown, bloodline pups, slots, speed-ups); gifting; crew storage (raidable); guild banners; the first **event premium track**; cosmetics (outfits, Hearth flames, base themes, R15 for the 18+ uplift) | Club 499/month; Prime Feast ×5 199; Bloodline pup 1,199; Kennel +2 slots pass 249; Event Premium 499; Event Bundle 2,499; Premium+ pass tier 2,499; cosmetics 149–799 |
| **M4 (Vaults, vehicles)** | Vehicle parts checklist with FILL UP and the last-piece trigger; part packs; Vault keycard packs; the big-ticket kits; paid crates with pity (odds shown, PolicyService alternative) | Vehicle Part Pack 1,699; Keycard pack 399; Fortress Kit 9,999; Stronghold Kit 17,999 (VIP 5+); Gold Vault 9,999 (4,500); crates 249 each or ×5 at 999 |

---

## 7. (f) The GAME_DESIGN and ECONOMY numbers this implies

**These are recommendations only.** `docs/ECONOMY.md` is being written by another agent and was not edited. Binding LDOE_PARITY numbers are left as they are.

### 7.1 For GAME_DESIGN.md

1. **Pass cadence:** run each pass for **21 days** (LDoE parity), so a 6-week content season holds two passes. This replaces "Season (6–8 weeks): a new region and a pass". The 2020 top post asking Kefir for 4-week seasons ([Reddit](https://www.reddit.com/r/LastDayonEarthGame/comments/hhajtj/20_things_kefir_should_change_to_make_ldoe_better/), 98 upvotes) is evidence that the shorter cadence sells more passes.
2. **Pass shape:**
   - **Levels:** 60, plus a post-cap chest every level for premium only.
   - **Premium (799 R$):** a tier-up weapon **at premium level 1**, about 150 Gold back, 25 Trail Rations, 2 Ember Hearts and two armor sets.
   - **Free track:** guns at regular intervals.
   - **Level skips:** +5 levels 249 R$; Premium Bundle (+20 levels) 1,699 R$.
   - **Pull Season 1 into M2.**
3. **Monetization section:** split "VIP" into three distinct things:
   - **VIP Lounge game pass** (399 R$, permanent: lounge, aura, +40 Energy cap, daily fixed crate)
   - **VIP status ladder** (M3, built from spend, lapses after 7 days)
   - **Survivor Club subscription** (M3, 499 R$/month)

   That replaces the single line "A VIP subscription (daily rewards plus Energy cap)". Also add "any purchase opens the Lounge for 7 days" (v0.1).
4. **First 10 minutes:** the starter offer goes **only to accounts that have never purchased**, with an accurate 48 h countdown from the first win. It's removed after any other purchase or when the timer ends, and never restarts.
5. **Buy at the moment of need:** add the frequency rules from §3 (one modal per session at login; contextual chips once per 24 h per trigger; never mid-combat; neutral calls to action).
6. **Raid rules, two additions:**
   1. **Sold capacity is raidable storage only.** The locked stash grows only with Hearth level, and players can never deposit into the inbox. Otherwise money buys raid immunity for goods, and raids lose their targets.
   2. **Death recovery** (ad or Gold) restores only what is still on the body when the lobby closes, never items another player looted. Prestige auto-delivery works in Light fog only.
7. **Durability and repair:** confirm LDoE parity. No repair until VIP 5 (M3) or the late Repair Station (LDOE_PARITY #21). Keep firearm decay fast, because it drives Scavenger's Kit and weapon-pack demand.
8. **Platform rules box:** add Roblox's presentation rules (§1.4). Discount badges only against a price charged at least 14 of the last 30 days, sale windows of at least 72 h, timers that never restart for the same SKU, and no claims of false scarcity.
9. **Scale line:** "LDoE runs about 100k daily players" can stay as an order of magnitude, but add the evidence: about $2–3M net a month (AppMagic via Baijing), about 100K weekly actives on Europe iOS alone (Q1 2025), and 140.6M Play installs.

### 7.2 For ECONOMY.md

**1. Premium currency.** Name it **Gold** if no name is set yet. It is LDoE's coin analogue, and "Ember" is already taken by items.

| SKU | R$ | Gold | R$ per Gold | Bonus |
|---|---|---|---|---|
| Gold Pouch | 149 | 50 | 2.98 | — |
| Gold Satchel | 399 | 140 | 2.85 | +5% |
| Gold Chest | 799 | 300 | 2.66 | +12% |
| Gold Crate | 1,699 | 680 | 2.50 | +19% |
| Gold Strongbox | 4,499 | 1,900 | 2.37 | +26% |
| Gold Vault | 9,999 | 4,500 | 2.22 | +34% |

LDoE's 2017 coin packs were flat at about 25 coins per $1, with no bonus. The bonus ladder is added to pull spend up into larger packs.

**2. Gold sinks at LDoE coin parity (1 Gold ≈ 1 LDoE coin):**

| Sink | Price |
|---|---|
| Recover all | 100 Gold |
| Contract or quest-step skip | 45–125 Gold |
| Event extra attempt or boost | 100 Gold |
| Companion growth skip (4-day timer) | 299 Gold |
| Trail Ration | 20 Gold (5 for 90) |
| Daily Deals items | 10–200 Gold |

**3. Speed-up curve:** `Gold = max(2, ceil(3.9 × sqrt(minutesLeft)))`. That gives 1 min = 4, 10 min = 13, 1 h = 31, 4 h = 61, 12 h = 105, and a 4 d 3 h timer = 299. That last value matches LDoE's cat skip.

**4. Fill Up rate:** **40 Gold per free-player grind-hour** of the missing materials. Each material's Gold price = 40 × hours per unit, from the pacing simulation, minimum 1 Gold. That's about 110 R$ per grind-hour.

**5. Bundle value rule** (from LDoE: "You can buy things for 20 bucks for like 2 weeks of hard work", CA, Jan 2024; and the size of the Brick Room kit):

| Bundle size | Grind-hours per 100 R$ |
|---|---|
| Small (99 R$ or less) | **about 1.5** |
| Medium (399–799 R$) | about 1.6 |
| Large (1,699 R$ and up) | about 1.8–1.9 |

Fill Up stays at about 0.9 h per 100 R$, so bundles always look like the better deal and Fill Up wins on immediacy. Check the current Supply Bundle (99 R$) against about 1.5 h, the Builder's Crate (399) against about 6 h, and the Reinforced Room Kit (1,699) against about 30 h, which is roughly the free Reinforced-tier milestone of days 10–14.

**6. Energy (binding: 200 cap, +1 per 5 min, Runs 15/22/33):**
- Energy Refill **99 R$ for +100**, which is LDoE parity (70 Energy ≈ $1 in 2017).
- Trail Ration +60 Energy (CONTENT_S2).
- VIP Lounge +40 cap.
- Ads give +15, up to 5 a day.
- Hard overfill cap 400 (Tuning).

**7. Rewarded-ad caps (13+):**

| Ad reward | Cap |
|---|---|
| AUTO | 10 a day (binding #31) |
| TAKE | 1 item per ad, 10 a day |
| Recover all | 1 a day (binding #46) |
| Energy +15 | 5 a day |
| Daily Deals refresh (M2) | 10 a day |

Survivor Club members claim all of these without watching, within the same caps.

**8. Rations:**
- AUTO costs 1/2/3 Rations by tier, and TAKE ALL costs 1 (Tuning, already in place).
- Free income is about 1 Ration a day across quests, death milestones and the VIP crate.
- The pass grants about 25.
- The rest is bought with Gold. LDoE players say Rations are "impossible to get for free", and that scarcity is the product.

**9. VIP ladder (M3):**
- 1 point per 10 R$ spent.
- Per-level points 10 / 50 / 90 / 150 / 200 / 250 / 300 / 350 / 400 / 500, then Prestige at 100 per level (24,000 R$ to reach Prestige).
- Active for 7 days after each purchase. Each Prestige level adds 24 h.

| Level | Perk |
|---|---|
| VIP 3, 5, 7, 9, 10 | −10% travel Energy each |
| VIP 3, 5, 9 | +10% bench speed each |
| VIP 2, 4, 6, 8, 10 | +10% XP each |
| VIP 5 | Repair Bench |
| Prestige | −50% Energy, +30% benches, +50% XP, Light-fog auto-delivery of loot |

**10. Product price corrections to CONTENT_MVP's Products table:**
- Energy Refill 49 → **99 R$**.
- Pack Expansion 149 → **199 R$**.
- Firestarter Kit stays at 99 R$, but gets **non-payer-only, a 48 h window from the first win, and the bigger contents** in §6.1. This replaces "offered up to L10".
- Add the six new SKUs.

**11. Tuning conflicts to settle (not edited):**
- CONTENT_MVP's tuning table still lists an Energy cap of 100 and walks of 4/7/12 min. LDOE_PARITY #38 (binding) and `Data/Tuning.luau` both say cap 200 with walks of 12/19/29.
- CONTENT_MVP's "slightly more generous" deviations predate the 2026-11-08 no-softening decision: tool durability 60 instead of LDoE's 50, 4 per tree and 5 per boulder instead of 3 and 3, and 3-cloth bandages instead of 5. LDoE parity would raise demand for the gear and resource SKUs.

---

## Gaps and caveats

- **Reddit:** gathered from the Arctic Shift archive (titles plus the first ~900 characters of each body; comments not read). Eight of the 22 title searches timed out (VIP, money, quit, lost, repair, coins, premium, ultra), so VIP and premium sentiment leans on reviews and the wiki.
- **Prices not verified:** Ultra and Ultra Plus (inferred as $9.99 and $14.99 from VIP points); Premium+ (about 3× by player report); the current Rations pack price; the Legendary pack's price in USD (about $2–5 by player report).
- **App Store order:** treating Apple's top-10 IAP order as sales rank is an inference.
- **Sensor Tower and AppMagic** figures are model estimates. The Android-only and unified series aren't comparable.
- **Keyword tagging is approximate.** The four storefronts are English-language only. The Russian, Spanish and Portuguese audiences, a large share of LDoE's players, aren't sampled.
- **Grind-hours:** the value rule (§7.2 item 5) needs the pacing simulation's grind-hours per material, which ECONOMY owns.
- **YouTube:** no YouTube creator transcripts were obtained. The video titles are in [ldoe-retention-sentiment.md](ldoe-retention-sentiment.md).

## Sources

**LDoE store and market data**
- [Google Play listing (installs, IAP range)](https://play.google.com/store/apps/details?id=zombie.survival.craft.z&hl=en_US&gl=US)
- App Store listings (IAP lists): [US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) · [GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094) · [DE](https://apps.apple.com/de/app/last-day-on-earth-survival/id1241932094) · [BR](https://apps.apple.com/br/app/last-day-on-earth-survival/id1241932094) · [UZ](https://apps.apple.com/uz/app/last-day-on-earth-survival/id1241932094) · [PK](https://apps.apple.com/pk/app/last-day-on-earth-survival/id1241932094) · [RU](https://apps.apple.com/ru/app/last-day-on-earth-survival/id1241932094)
- App Store reviews: [US](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=reviews) · [GB](https://apps.apple.com/gb/app/last-day-on-earth-survival/id1241932094?see-all=reviews) · [CA](https://apps.apple.com/ca/app/last-day-on-earth-survival/id1241932094?see-all=reviews) · [AU](https://apps.apple.com/au/app/last-day-on-earth-survival/id1241932094?see-all=reviews)
- Apple RSS review feeds: [US](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json) · [GB](https://itunes.apple.com/gb/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json) · [CA](https://itunes.apple.com/ca/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json) · [AU](https://itunes.apple.com/au/rss/customerreviews/page=1/id=1241932094/sortby=mostRecent/json)
- [AppPricingLab (Apr 2026 snapshot)](https://apppricinglab.com/iap/apple/1241932094)
- [Baijing 55143 (AppMagic, May 2026)](https://www.baijing.cn/article/55143) · [Baijing 55133](https://www.baijing.cn/article/55133)
- Sensor Tower: [Q1 2021 US](https://sensortower-china.com/blog/2021-q1-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) · [Q4 2023 US](https://sensortower.com/blog/2023-q4-unified-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) · [Q3 2024 US Android](https://sensortower.com/blog/2024-q3-android-top-5-survival%20games-revenue-us-60144bdd241bc16eb8136791) · [Q1 2025 Europe iOS](https://sensortower.com/blog/2025-q1-ios-top-5-survival%20games-revenue-europe-60144bdd241bc16eb8136791) · [Q4 2025 US Android](https://sensortower.com/blog/2025-q4-android-top-5-survival-games-revenue-us-60144bdd241bc16eb8136791)
- wnhub: [2017](https://wnhub.io/zh/news/other/item-12740) · [2019](https://wnhub.io/news/marketing/item-15996)

**LDoE wiki (wikitext through the MediaWiki API, 2026-11-08)**
- [VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone) · [Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path) · [Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99) · [Packs](https://last-day-on-earth-survival.fandom.com/wiki/Packs) · [Raider's Starter Pack](https://last-day-on-earth-survival.fandom.com/wiki/Raider%27s_Starter_Pack) · [Savings pack](https://last-day-on-earth-survival.fandom.com/wiki/Savings_pack) · [Week Pack](https://last-day-on-earth-survival.fandom.com/wiki/Week_Pack) · [Brick Room 3X3](https://last-day-on-earth-survival.fandom.com/wiki/Brick_Room_3X3) · [Gunsmith's crate](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith%27s_crate) · [Armorer's crate](https://last-day-on-earth-survival.fandom.com/wiki/Armorer%27s_crate)
- [Death](https://last-day-on-earth-survival.fandom.com/wiki/Death) · [Reanimator](https://last-day-on-earth-survival.fandom.com/wiki/Reanimator) · [Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations) · [Coins](https://last-day-on-earth-survival.fandom.com/wiki/Coins) · [Energy](https://last-day-on-earth-survival.fandom.com/wiki/Energy) · [Healer](https://last-day-on-earth-survival.fandom.com/wiki/Healer) · [Inbox](https://last-day-on-earth-survival.fandom.com/wiki/Inbox) · [Repair Station](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station) · [Cat](https://last-day-on-earth-survival.fandom.com/wiki/Cat) · [Fridge](https://last-day-on-earth-survival.fandom.com/wiki/Fridge) · [In-Game Shop](https://last-day-on-earth-survival.fandom.com/wiki/In-Game_Shop)
- Kefir FAQ: [32 (purchases lost on death)](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/32-i-lost-my-purchases-after-death/) · [730 (season bonus chests)](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/730-season-pass-bonus-rewards-and-how-to-get-them/)

**r/LastDayonEarthGame (through the Arctic Shift archive)**
- Season pass: [Season Pass DOUBLED in price (2023)](https://www.reddit.com/r/LastDayonEarthGame/comments/167xpun/season_pass_doubled_in_price/) · [Boycott new season pass (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkqxzd/boycott_new_season_pass/) · [Is the new season pass an April fools joke? (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkte2x/is_the_new_season_pass_an_early_april_fools_joke/) · [Kefir: new season rewards (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1jkedim/new_season_rewards/) · [New Season Pass (Aug 2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1mwoka8/new_season_pass/) · [New Season Pass, Premium+ (Apr 2026)](https://www.reddit.com/r/LastDayonEarthGame/comments/1sxm99m/new_season_pass/) · [TWO season premium passes (2026)](https://www.reddit.com/r/LastDayonEarthGame/comments/1sy3zc4/two_season_premium_passes_kefirwhy_stop_there/) · [Purple prints via +20 levels (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1nm5htb/purple_prints_for_p2w_players/) · [Brainwashed (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1jxry09/brainwashed/)
- First-purchase and win-back offers: [Legendary pack, offer cadence (2023)](https://www.reddit.com/r/LastDayonEarthGame/comments/13qeiwd/for_those_interested_in_buying_the_legendary/) · [Legendary pack disappears after a £0.99 buy (2023)](https://www.reddit.com/r/LastDayonEarthGame/comments/12wo0sk/legendary_survivors_pack/) · [Legendary pack for $2 (2023)](https://www.reddit.com/r/LastDayonEarthGame/comments/12vph43/good_way_to_spend_coins_i_bought_the_legendary/) · [Legendary vs Hermit prices (2022)](https://www.reddit.com/r/LastDayonEarthGame/comments/uu22qq/difference_between_legendary_survivors_pack_and/) · [Hermit's Pack after a week away (2022)](https://www.reddit.com/r/LastDayonEarthGame/comments/t7k3a5/about_the_hermits_pack/) · [$5 offer worth $200 (2020)](https://www.reddit.com/r/LastDayonEarthGame/comments/k9ctla/did_anyone_else_get_some_extremely_good_deal/) · [Season or savings (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1ml4tb8/season_or_savings/)
- VIP: [VIP for the repair bench (2026)](https://www.reddit.com/r/LastDayonEarthGame/comments/1urzgzw/is_getting_to_higher_vip_level_worth_it_just_for/) · [Can friends see VIP? (2021)](https://www.reddit.com/r/LastDayonEarthGame/comments/qnli4r/can_friends_see_you_spent_money_on_the_game/)
- Events: [P2W event: eggs (2026)](https://www.reddit.com/r/LastDayonEarthGame/comments/1sadw18/p2w_event/) · [18,000 coins short (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1i22zpj/just_spent_18000_coins_during_pursuit_of_luck_and/) · [Kefir needs to chill (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1nxymkb/kefir_needs_to_chill/) · [Losing excitement for events (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1llmzoi/losing_my_excitement_for_upcoming_events/)
- Big-ticket base: [$100 3×3 metal room (2020)](https://www.reddit.com/r/LastDayonEarthGame/comments/icknps/i_stg_i_wish_this_game_would_just_to_p2w_micro/) · [Metal base at $20 (2021)](https://www.reddit.com/r/LastDayonEarthGame/comments/q58qwt/i_love_this_season_after_a_1yr_of_playing_im/)
- Churn and quitting: [Does one quit after this? (2023)](https://www.reddit.com/r/LastDayonEarthGame/comments/173wyae/does_one_quit_after_this/) · [Reality Check (2024)](https://www.reddit.com/r/LastDayonEarthGame/comments/1b9ii68/reality_check/) · [I want slowly to quit (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1j13u2s/i_want_slowly_to_quit/) · [20 things Kefir should change (2020)](https://www.reddit.com/r/LastDayonEarthGame/comments/hhajtj/20_things_kefir_should_change_to_make_ldoe_better/)
- Energy, Rations and ads: [Energy system needs to go (2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1kv7i7l/ok_im_done_with_this_garbage_this_energy_system/) · [Energy at 200 less stressful (2021)](https://www.reddit.com/r/LastDayonEarthGame/comments/nttfen/when_they_made_energy_to_200_it_made_the_game/) · [Bought 200 Rations (2019)](https://www.reddit.com/r/LastDayonEarthGame/comments/dvybaf/umm_how_do_i_go_about_getting_a_refund_for_the/) · [Ads for Energy paid 0 (2020)](https://www.reddit.com/r/LastDayonEarthGame/comments/i8d3e9/ads_for_energy/)

**Roblox**
- [Creator Hub: Monetization (presentation rules)](https://create.roblox.com/docs/production/monetization)
- [RoWatcher: Robux bundle prices 2026](https://rowatcher.com/news/robux-prices-bundles-2026-guide)
- [Slyther Games: Dead Rails Robux items (Mar 2025)](https://www.slythergames.com/?p=16058)
- Subscriptions, rewarded video, paid random items, DevEx and the 18+ uplift: sources in [roblox-genres-monetization.md](roblox-genres-monetization.md) §4
