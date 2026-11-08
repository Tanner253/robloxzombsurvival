# Zombix Online: Monetization, Retention and Player Sentiment

*Research date: 2026-11-07. Live-game data changes with every patch. Figures are dated, and anything older than 2024 is marked as possibly out of date.*
*Convention: sourced facts link to a source in the Sources list. My own analysis starts with **Inference:**. Russian text is translated and paraphrased by me.*

---

## TL;DR

- **Small but long-lived.** Zombix Online launched on Android on 2019-08-30 and on iOS on 2024-05-07. Google Play shows the **1M+** install bracket; the store's exact counter is **4,793,955**. That is about 1/30 of Last Day on Earth's 140.6M. Players say concurrency is now in the low hundreds per server, and the developer himself put Server 4 at about 50 players in October 2026.
- **Monetization is IAP-only with no ads, and cheap per item.** Google Play lists **$0.49–$74.99 per item**, against LDoE's $0.49–$199.99 *plus* ads. Revenue comes from kits, a $4.99 monthly battle pass ("Zombix Pass"), **paid keys for loot boxes** that drop for free in the world, gem-bought **"contracts" (gacha cards that unlock characters)**, and a **direct-to-consumer web shop** that takes Russian cards and SBP, Russia's instant bank-transfer system.
- **Sentiment has split.** The store average is 4.5★ from 61.9K ratings, and many of those are short 5★ reviews from new players. Long-time players, mostly Russian-speaking, increasingly describe it as "донат в донате" ("donation inside donation"), a grind treadmill controlled by entrenched clans. In my sample of 1,500 Russian reviews, the average fell from **4.33★ (H2 2025)** to **3.97★ (H2 2026)**, and to **3.48★ after the 5.0 update** (Oct 26, 2026).
- **What keeps people playing:** clan wars over capturable **"Survivor Bases" (Базы выживших, БВ)**, the social and trading scene, nostalgia, cozy loops (fishing, farming), and that it runs on weak phones with no ads. **What drives them away:** grind, gacha contracts, entrenched mega-clans holding bases for years, ping and outages (servers are mostly hosted in Russia), lost accounts, multi-account botting and scripts, and long gaps between content updates from a developer who is effectively solo.

---

## 1. Who makes it, and how it is run

| Item | Finding | Source |
|---|---|---|
| Publisher name | "MMORPG Dev" on Google Play. The App Store seller is **Vladislav Okhotnikov**, with a Warsaw, Poland address on the Play listing. RuStore names the developer as "Berzerk Games". | [Google Play], [App Store US], [RuStore] |
| Team size | The official Telegram channel is written in the first person ("I'm the developer"). Posts mention a single designer who "took vacation" and side projects (Custom Cats Online, Spell Crit, a fantasy MMO). | [TG 149], [TG 202], [TG 206] |
| Other games | Desert Pixel Online (100K+ installs), Custom Cats Online (100K+), Spell Crit: Idle MMORPG (50K+, released Feb 2026) | Google Play pages |
| Servers | Four game servers. Server 3 has RU/EU/US/Asia regions. Server 4 is a separate ruleset launched 2023-10-08, beta open only to rank 40+. Hosting is mostly in Russia: the developer cites outages from Runet (Russian internet) disruptions and has moved hosting providers repeatedly. | [TG 26], [TG 29], [TG 173], [TG 194], [TG 208], [TG 213] |
| Tech | Built in Unity, with Firebase analytics. AdMob is detected, but ad monetization is 0%. | [AppGoblin] |

**Inference:** This is a hobby-scale, one-person live MMO with a loyal core. Its business limits (cheap prices, few content drops, unstable hosting) come from team size, not strategy. That means its "depth" was built slowly over 7 years and is very hard for a polished newcomer to copy quickly. Its weaknesses are also exactly the ones a funded team can fix.

---

## 2. Scale, ratings and community signals

### Store metrics (fetched 2026-11-07)

| Store | Installs / downloads | Rating | Rating count | Notes |
|---|---|---|---|---|
| Google Play | **1M+ bracket** (exact counter 4,793,955) | 4.5 (4.505 in the first fetch; 4.53 in a fact-check re-fetch the same day) | 61.9K reviews (61,944 on re-fetch) | Phone histogram (unverified: Play serves different histograms by device and client, and these five figures sum to 57,071, not 57,131): 5★ 44,115 · 4★ 6,761 · 3★ 1,126 · 2★ 1,126 · 1★ 3,943. The re-fetch showed 5★ 47,481 · 4★ 8,507 · 3★ 1,063 · 2★ 1,063 · 1★ 3,721. Last updated Oct 28, 2026. Rated Everyone 10+, no "Contains ads" flag. |
| App Store | n/a | 4.5 (US, 40) · 4.3 (RU, 77) · 4.5 (UA, 30) · 4.3 (KZ, 23) · 4.4 (BY, 14) · 4.3 (TR, 13) | about 215 across 13 storefronts checked | iOS since 2024-05-07; v5.01 |
| RuStore | "up to 100,000" | 4.0 | 74 ratings / 44 reviews | v5.01, Oct 28, 2026 |
| Trashbox.ru (APK mirror) | — | 4.6 | 10 | Comments are mostly requests for newer APKs |
| AndroidRank | 1M+, estimated 3.52M | 4.49 | 61,887 | Install milestones: 10K (Dec 2019), 100K (Jan 2020), 500K (May 2020), 1M (Sep 2020). Ratings grew only 0.4% in the last 30 days. |
| GameBrain aggregate | — | 74% user score | about 1,100 reviews | Most praised: graphics, gameplay. Most criticized: story, grind. |

Sources: [Google Play], [iTunes lookup], [App Store US], [RuStore], [Trashbox], [AndroidRank], [GameBrain].

**Third-party estimates (treat with caution).** AppGoblin, crawled 2026-11-07, models **about 220K MAU**, **under $10K monthly revenue**, and **about 14K new installs a month** ("steady") [AppGoblin]. **Inference:** the MAU figure conflicts with first-hand evidence. The developer said Server 4 has "around 50 players in total" [TG 217]. Reviewers in 2026 report "fewer than 100 people on the server" and "at most 100 players in the daytime". Read AppGoblin's MAU as a crude model output. The revenue band (under $10K/month) is plausible for an ad-free game with cheap IAP and a few thousand daily players, but it is unverified. No Sensor Tower, AppMagic or Naavik coverage of Zombix exists that I could find.

### Community size

| Channel | Size | Activity |
|---|---|---|
| Discord "Zombix Online Official" (discord.gg/zombix, created 2020-06-10) | **7,458 members**, 175–245 online when checked | English-language hub [Discord] |
| Telegram @zombixnews (official, developer-run) | **4,004 subscribers** | 213 posts since Sep 2022. Median post views: 2023 ≈14.9K, 2024 ≈10.4K, 2025 ≈15.2K, 2026 ≈6.7K. Views keep accumulating after posting, so recent posts read low. [Telegram] |
| Forum | zombix.featurebase.app, launched 2026-10-02 | [TG 216] |
| VK | The site links vk.com/desertpixel; one player says the old VK support channel was closed | VK blocks automated fetching, so I could not verify size |
| Instagram | @zombixonline | not checked |

**YouTube** (stats pulled from video pages; I could not watch the videos):

| Video | Channel | Views | Date |
|---|---|---|---|
| "Zombix Online#1 Гайд Как играть" (how-to-play guide) | AMID | 54,392 | 2019-12 |
| "Zombix Online - Gameplay Walkthrough Part 1" | Pryszard Android iOS Gameplays | 21,950 | 2020-01 |
| "Zombix Online mod menu latest version" | CG MODS OFFICIAL | 16,870 | ~2022 |
| "Zombix Online Pet Review" | STALEVAR | 10,798 | ~2021 |
| "Как нафармить много голды?" (how to farm lots of gold) | Disti | 10,364 | 2023-10 |
| "zombix online the duplicate glitch" | Jjmon SelivaYT | 5,434 | ~2022 |
| "THE GREAT CLAN WAR IN 2025 TAKES OVER THE REGION" | Ryo AM | 934 | 2025-01 |
| "ZOMBIX ONLINE - PvP [Krostik vs Bixudy]" | Bixudy | 429 | 2026-03 |
| "Обновление 5.0! ... коллекцию РЫБЫ" (5.0 update, fish collection) | NlCK-name | 289 | 2026-11-01 |
| "Глобальное обновление (Zombix online)" (global update) | Snoozi | 296 | 2026-10-27 |

**Inference:** YouTube interest peaked in 2019–2021. Current creator activity is a handful of sub-1K-view videos, mostly clan-war montages (Indonesian and Filipino creators) and Russian update reviews. Cheat, mod-menu and dupe-glitch videos are among the most-viewed, which is a red flag for integrity.

### LDoE scale for comparison

Last Day on Earth on Google Play: **100M+ (exact counter 140,558,641)**, 4.4★ (4.35) from about 4.76M ratings, **IAP $0.49–$199.99 per item, "Contains ads"**, updated Nov 5, 2026. Its own description says the core journey is single-player, with multiplayer confined to "the Crater" [LDoE Play].

---

## 3. How Zombix makes money

### Currencies and paid systems (pieced together from store pages, the web-shop UI, the developer's Telegram, and reviews)

| Element | What it is | Paid? | Evidence |
|---|---|---|---|
| **Zombux** (зомбаксы) | Main soft currency; also sold in the shop | Earned, and sold in "Gems and zombux" packs | A clan costs 1,000 zombux, a clan icon 10,000, a name change 3,500 (2025 review). The shop has a "Gems and zombux" tab. |
| **Gems** (гемы) | Premium currency | Players repeatedly say gems can only be bought with real money (2021–2023 reviews). | Gems buy contracts, coins and **small turrets (2 gems each, raised from 1)** [TG 101]. A one-time "unban for 1,000 gems" amnesty was offered [TG 150]. |
| **Gold** (золото/голда) | Scarce crafting resource | Farmed; players report gold sold for rubles between players (RMT) | 2026 review complaint about gold-for-rubles. In Oct 2026 the developer capped fishing, which players called the main gold source for newcomers. |
| **Keys → Zombix Boxes** (loot boxes) | Boxes drop from monsters; **keys are paid** | Yes | Shop: "one key, one box", sold as 1/5/20. The App Store age rating lists "Contains loot boxes". |
| **Contracts** (контракты) | Gacha cards that unlock and level characters (classes such as Soldier, Brawler, Shaman, Technos, Darken, Radiy, "mythic" characters) | Bought with gems or currency | Players call it "basically a gacha system" (2022). Duplicate cards for maxed characters keep dropping (2025). Players say Technos is instant with money and takes about 2 months to farm (2025). |
| **Battle pass** ("Zombix Pass") | Monthly seasons with seasonal rewards | $4.99 / 449₽ | App Store version notes show a new season almost every month. Players say the rewards are mostly emotes. |
| **Kits** | One-time Newbie kit; Small/Medium/Large/Great; Legend kit (resources, XP injectors, zombux); Seasonal kit (Toxic Cannon, Titanium Helmet, **motorcycle**, resources); Crafter kit; "Anomalous survivor kit"; "Predator" pet | Yes | [Shop UI]. Note: in the web shop, Small/Medium/Large/Great are **gem + zombux currency packs** (30/80/170/360 gems), not item kits; the App Store calls them "Kits". |
| **Server 4 economy** | Silver tokens, **auctions for workbench territory**, **renting other players' buildings**, a player marketplace, clan prize-fund payouts | Mixed | [TG 37], [TG 66], [TG 115], [TG 156] |
| **Ads** | None. AdMob SDK is present, but 0% ad monetization and players repeatedly praise "no ads". | — | [AppGoblin], reviews |

### Price points

| SKU | App Store US | App Store RU |
|---|---|---|
| 1 Key | $0.99 | 99₽ |
| 5 Keys | — | 399₽ |
| 20 Keys | $15.99 | 1,490₽ |
| Newbie Kit | $0.99 | 99₽ |
| Small Kit | $2.49 | 199₽ |
| Legendary Kit | $3.49 | 299₽ |
| Medium Kit | $4.49 | 399₽ |
| Zombix Pass | $4.99 | 449₽ |
| Seasonal Kit | $5.99 | — |
| Large Kit | $8.99 | 799₽ |
| Great Kit | $19.99 | 1,790₽ |
| Google Play range | **$0.49 – $74.99 per item** | |

Sources: [App Store US], [App Store RU], [Google Play]. The App Store shows only its top 10 SKUs.

### Direct-to-consumer web shop

- **shop.zombixonline.com** sells kits, keys, gems and zombux, and the battle pass. Buyers enter a **character ID and server number**, and items arrive in the in-game mailbox, "usually within 5 minutes", sometimes up to 24 hours. Server 4 has its own shop [Shop UI].
- On 2024-03-29 the developer announced that the shop now properly accepts **SBP and Russian bank cards** [TG 70]. A 2026 Russian review says card payment inside the game does not go through.
- The shop's public offer says it is run by a Russian sole-proprietor **agent acting for the rights holder**. That is a common post-2022 arrangement for taking payments from Russia.
- The developer plans a shop update with search by character, "so you don't mix up the ID during purchase" [TG 212]. The live shop code already contains a character lookup, but the shop API reported it switched off (`playerLookup: false`) on 2026-11-07.
- Live web-shop prices, read from the shop's public product API on 2026-11-07 during fact-checking: Zombix Pass 449₽; Small pack 199₽ (30 gems + 1,000 zombux); Medium 499₽ (80 + 2,500); Large 849₽ (170 + 5,500); Great 1,490₽ (360 + 12,500); one-time Anomalous Survivor pack 599₽ (250 gems + 5,000 zombux, plus "Predator" pet); keys 90₽ / 399₽ (5) / 1,499₽ (20); Newbie kit 99₽; Legend kit 299₽; Seasonal kit 469₽; Crafter kit 249₽. **Inference:** charging the whole pack price to the gems (ignoring the zombux), gems cost at most about 4.1–6.6₽ each, so a 2-gem small turret costs at most about 8–13₽.

**Inference:** The audience is mostly Russian-speaking, and Google Play and the App Store cannot take Russian cards, so the web shop is probably a major, maybe the main, revenue channel. Store-based revenue estimates such as AppGoblin's would then *undercount* real revenue.

### Is it pay-to-win?

Players have argued both sides throughout the game's life:

- **Early praise (2020):** "non p2w/pay to win game mechanics that I adore" (Play review, 2020-06-15). Packs were called "surprisingly cheap" (2020-07).
- **Turning point (2021–2022):** the **contract system** arrived. "Contract system that basically gacha system" (2022-02-15, 1★, 28 helpful). Players noted that items once earned by grinding became buyable with real money (2021-04).
- **2025–2026:** Russian veterans list "cases, contracts, kits, gifts, donation characters" as the core of the game (2026-10-28, 1★). Clan-war players say paying lets clans hold regions (2026-02). Turrets for base defense cost premium gems [TG 101].
- **Against that:** many current reviews still call donations "cheap" or "inexpensive", say "the balance suits me" (2026-08-01, 5★), and say "the donation isn't critical, it doesn't sell overpowered guns" (2022-11).

**Inference:** The P2W power is mostly *time compression*: kits with motorcycles and helmets, instant characters through contracts, gems for turrets. There is little exclusive gear. Prices are low, so it does not feel predatory the way LDoE does at $199.99 with ads. The resentment comes from **gacha randomness (duplicate cards)**, **paid keys for loot that drops for free**, and the sense that new content is mostly monetization (cases, pass emotes) rather than gameplay.

---

## 4. Update cadence and live ops

**App Store version history, iOS** [App Store US]:

| Period | What shipped |
|---|---|
| Jul 2024 – Jun 2025 | Monthly "New Battle Pass Season + bug fixes". Content: new quests and more EXP (4.94, Sep 2024), Halloween (Oct–Nov 2024), New Year (Dec 2024). |
| Aug–Sep 2025 | "New content", then fishing content (4.97, 4.98) |
| Oct 2025 – Aug 2026 | Halloween, New Year, then only battle-pass seasons (4.98a–g). No release in Jun–Jul 2026. |
| **Oct 26, 2026 – v5.0** | "Quality of Life patch; Halloween Event; New Content". The first large patch in years; the developer: "we haven't had big patches for how many years now" [TG 219]. Shipped with new cases [TG 215]. |
| Oct 28, 2026 – v5.01 | Hotfix. The same day the developer announced that auto-aim during manual shooting *would be* removed on servers 1–3 and maybe replaced with something else [TG 223]. That it shipped in 5.01 is (unverified). |

**What 5.0 changed, according to the developer and players:** a new UI (the old one could not fit planned features), a **3v3 arena replacing the old arena**, a Survivor Bases map, auto-heal and character switching, fishing limits, spoilable fish. Some players report lost contract progress, lost safes and workbench, and reset cards. The reaction was polarized: "return the old Zombix" (several Russian reviews, Oct 27–29, 2026) against "I see more players now" (unverified: not in the [TG 221] post text or the Russian reviews I re-checked).

**Ops reliability:** the Telegram channel is dominated by outage posts: hosting reboots, a disk fault on Server 2, Runet outages, Server 3's Asia region moving between Hong Kong, Singapore and Malaysia, oversold CPU at a host [TG 173], [TG 194], [TG 206], [TG 208], [TG 213]. The developer also notes App Store review rejections delaying patches [TG 206].

**Inference:** The monthly pass gives a revenue heartbeat, but players read pass-only months as "the developer abandoned the game". That reading shows up in 2025–2026 reviews again and again: "no updates, lazy dev", "abandoned", "only donation is added".

---

## 5. Player sentiment

### Method

I pulled the 1,500 most recent **Russian-language** Google Play reviews (2025-01-07 → 2026-11-06) and the 1,000 most recent **English** reviews (2021-01 → 2026-11) from Google Play's public review feed, plus RuStore and App Store reviews. I counted themes by keyword matching. Treat the counts as rough, because Russian word stems cause some false matches.

**Inference:** The volume itself is a signal. There are about 68 Russian text reviews a month against about 12 English ones since 2024, so the active audience is mostly Russian-speaking.

### Star trend, Russian-language Google Play reviews

| Half-year | Reviews | Avg ★ | % 1★ |
|---|---|---|---|
| 2025-H1 | 457 | 4.28 | 11% |
| 2025-H2 | 487 | 4.33 | 10% |
| 2026-H1 | 349 | 4.19 | 13% |
| 2026-H2 | 207 | 3.97 | 17% |
| **After v5.0 (Oct 26 – Nov 6, 2026)** | 54 | **3.48** | 28% |

English reviews hold around 4.0–4.3★, but there are few of them. Overall, 70% of Russian reviews are 5★, and many are one-liners ("good game"). One reviewer alleges the ratings are inflated with bots; I could not verify that.

### Themes, by share of reviews mentioning them and their average stars

| Theme (keyword-based) | RU share (n=1,500) | RU avg ★ | EN share since 2024 (n=414) | EN avg ★ |
|---|---|---|---|---|
| Content shortage / "no updates" | 9.0% | 3.6 | 2.2% | 3.0 |
| Donation / P2W / cases / contracts | 6.7% | **3.2** | 2.9% | **2.1** |
| Lag / ping / servers | 4.6% | 3.4 | **6.5%** | 2.7 |
| Clans / clan wars / base capture | 4.0% | 4.0 | 0.7% | 2.3 |
| Bugs / crashes / can't launch | 3.9% | 3.2 | 2.2% | 3.0 |
| Grind / farming | 3.8% | 3.4 | 1.2% | 3.0 |
| PvP / arena | 3.4% | 3.6 | 2.7% | 3.1 |
| Account loss | 2.5% | 3.3 | 1.7% | 3.0 |
| Personal base / building | 2.3% | 4.1 | 1.4% | 3.5 |
| Dead / low online | 1.9% | **2.8** | 0% | — |
| Pixel graphics (positive) | 1.8% | 4.3 | 2.7% | **4.8** |

### What players praise

- **Rare on mobile: an open, persistent MMO survival world.** "The first open world MMO survival zombie apocalypse game I've ever seen on mobile" (EN, 2026-10). Others compare it to Project Zomboid or call it "basically dayz pixelated" (EN, 2026-06). Russian players compare it to STALKER: anomalies, artifacts, the "stalker" theme.
- **No ads, cheap donations, runs on weak phones.** These come up repeatedly in Russian 5★ reviews, for example 2026-04-19, which lists pixel graphics, weak-phone support, a kind community and cheap donations as the four pluses.
- **Social play.** Chopping trees or fishing with a friend on voice chat; finding a good clan; trading and recruiting.
- **Nostalgia.** Many reviews from players who started at 6–12 years old, play since 2019–2021, and come back.

### What players complain about

1. **Monetization drift:** gacha contracts with duplicates, paid keys, the pass being "only emojis", donation characters. A Russian 1★ review jokes that the only thing missing is microloans.
2. **Grind and economy:** gold is scarce; items lose durability fast; repair kits are weak; the 5.0 fishing cap removed the gold source for newcomers; "economy killed".
3. **Entrenched clans and base control:** "the same clans control the Survivor Bases" (several 2025–26 reviews); "clans that are 5 years old don't let anyone do anything on PvP bases"; requests to cap how many bases one clan can hold (15 bases in a 2021 review, 25 in a 2024 review). One player describes ten hours of clan fighting to take ten bases, then two level-60 players retaking them overnight.
4. **Ping, regions, language:** non-Russian players face 200–400 ms ping, the arena was RU-only, and some see Russian players "gatekeeping" (EN, 2026-04). English reviews since 2020 say there are no English speakers on US servers.
5. **Integrity:** multi-account botting, auto-fishing scripts, auto-aim cheats, mod menus and dupe glitches on YouTube, scammers in trades, a weekly forced "anti-scam" popup (EN 1★, 2026-05).
6. **Account loss:** no account recovery by policy, to stop players stealing accounts from each other [TG 211]. App Store: a player who spent $40 could not recover a character (2026-03).
7. **Onboarding:** the tutorial is long and confusing; quests lack map markers. This is a constant since 2019.
8. **Combat feel:** auto-attack against manual aim swings back and forth across patches. Veterans want skill-based manual PvP; newcomers like the automatic firing.

---

## 6. What retains players: a closer look at clans, bases and trade

**Survivor Bases (Базы выживших, "БВ"): the endgame.**
- Capturable PvP base points on the map, guarded by bot mercenaries, that **generate resources and items** from their machines for the holding clan [Google Play description], [Trashbox], [BlueStacks].
- About 50 bases ("+50≈") were added over the years, and capture became harder (2026-07 review).
- Clans fight for them across regions. Clan-war montages are the main English-language YouTube content (Ryo AM, 7FalconGamer, GREZNOR EDITS).
- **Bases can be contested at any time, with no offline protection:** players lose bases while asleep.
- A December 2022 developer post (before Server 4 existed) *planned* **clan storage that only the leader can distribute**, **temporary clan territories**, and **neutral mercenary bases** that upgrade them, and warned that some planned features might not ship [TG 13]. Which of these shipped is (unverified). On Server 4, part of the **prize fund for holding clan bases** goes into clan storage, and the leader pays it out to members [TG 156].

**Personal base.**
- It exists, with garden beds, storage cabinets, workbenches and generators. Players call it "a box without customization, nowhere even to sit" (RU, 2022) and ask for walls, floors, doors and windows (RuStore, 2026).
- You cannot remove your own garden beds to make room for storage (RU, 2026).
- **Inference:** personal-base building is shallow. The retention value sits in *clan-owned territory*, not in crafting a home.

**Arena base-defense mode (Feb 2024).**
- Teams of three players: build walls and turrets on your base, then raid others. The launch layout appears to have been four teams ("3x3x3x3", 12 players) [TG 158]; on Feb 26, 2024 an experiment cut it to two teams [TG 63]. **Radiation destroys bases and forces the match to end.** Its start time moved repeatedly during launch week: minute 15, then 30, then 20, with bases destroyed within about 10 minutes of it appearing; by Feb 26 light radiation started at minute 10 and lethal radiation at minute 20 [TG 47], [TG 49], [TG 51], [TG 63].
- Your **base flag is your respawn**: a player dies permanently only at 0 HP *and* with their base destroyed [TG 62].
- In late 2024 the arena was flooded with bots and AFK farmers. Rewards changed to "first 3 wins per day" [TG 150], [TG 158].
- 5.0 replaced it with 3v3. Players now complain about bot teammates.

**Death and loot stakes are low.**
- By April 2020 the developer had *removed* item loss on death. A developer reply dated 2020-04-09, to a review from January 2020, says the "recent update" removed losing items on death [Google Play reviews].
- Since then the stakes differ by server. A 2026 review of the "Hardmod" server (likely Server 4, judging by the T-tier zones) describes dying to an Ent and the dropped gear vanishing before the player could get back to it. On the arena, equipped gear drops only on final death [TG 62].
- Players still ask for loot to drop on PvP kills: "Add some Raid like Loot & Extract" (EN, 2026-02); "what's the point of killing him otherwise" (RU, 2020).
- The developer has floated a "mini-Tarkov" extraction mode with gear-score-matched 20-minute raids and a marketplace [TG 115]. As far as I can tell it has not shipped.

**Trading and social.**
- Item trading (a 10-second confirm timer, which players say has a skip bug), a Server 4 marketplace, clan recruiting, chat.
- Trading is both a retention driver and the main scam and RMT vector.

**Inference:** Zombix keeps players through **territory and identity** (my clan holds bases) and **social habit**, not through progression. That is also why it decays: once a few clans lock up the territory, newcomers have nothing to fight for, and veterans have nothing new to build.

---

## 7. Integrity and anti-cheat, as the developer describes it

- **Multi-account play** (one person running several characters at once) is the main offense. It led to permanent bans and public "ban waves" with player names [TG 150], [TG 168]. One post removed a botter's "300 accounts and 2 storages" [TG 222].
- The developer says mobile anti-cheat at the kernel level is not realistic. His two strategies: make cheaters' advantage minimal, or give normal players what cheaters have (for example, official auto-features) [TG 211].
- Planned: a **server-side replay system** to verify reports, a complaints site, chat auto-moderation, more languages, and a Brazil server [TG 212].

---

## 8. Zombix Online vs Last Day on Earth

| Dimension | Zombix Online | Last Day on Earth |
|---|---|---|
| Installs (Play) | 1M+ (4.79M exact counter) | 100M+ (140.6M exact counter) |
| Play rating | 4.5 (61.9K) | 4.4 (about 4.76M) |
| IAP range | $0.49–$74.99 | $0.49–$199.99 |
| Ads | None | "Contains ads" |
| Structure | Every zone is shared MMO; clans fight over persistent bases | Single-player core; multiplayer only in "the Crater" |
| Raiding real players | Clan base capture, live and contested 24/7; arena base raids | Limited to the Crater (see the developer's own complaint) (unverified: LDoE's description confirms only that multiplayer and PvP are confined to the Crater; the "developer's complaint" has no source here) |
| Death penalty | Item loss removed in early 2020 (by April). The hardcore server and the arena's final death drop gear. | Lose loot outside base; safe at base |
| Personal base depth | Shallow box | Deep: walls, traps, workbenches, storage |
| Team | Effectively solo developer | Large studio (Kefir!) |

Sources: [Google Play], [LDoE Play]. For LDoE monetization details, see the companion research files.

---

## Gaps (what I could not get)

- **Live web-shop prices** (gem and zombux packs, pass price in rubles). The shop loads prices from an API I did not query. *Fact-check update: now filled; see "Direct-to-consumer web shop" in section 3.*
- **VK community size.** VK blocks automated fetching.
- **Any professional market-intelligence coverage** (Sensor Tower, AppMagic, Naavik, Deconstructor of Fun). I found none for Zombix. My web-search budget ran out partway through, so I could not run further searches on 4PDA threads, Pikabu or Russian YouTube guides on donation value. 4PDA and Reddit turned up no Zombix threads in the searches I did run.
- **Real concurrency and DAU.** Only anecdotes and one developer remark (Server 4 ≈ 50 players). AppGoblin's 220K MAU is unverified and likely too high.
- **In-game gem prices** of contracts, characters and pets. Reviews give fragments only.
- **Video content.** I can't watch videos, so for YouTube I have titles, channels, views, dates and descriptions only.

---

## Design implications for our game

1. **Win on fairness and price, the way Zombix does, but keep power out of the shop entirely.** The two most-praised business traits are *no ads* and *cheap donations*. The most-hated are *gacha with duplicates*, *paid keys for free-dropping boxes*, and *buying time-to-power* (Technos, kits with motorcycles, gem turrets). Ship with:
   - no forced ads
   - no loot-box keys, or fully disclosed odds and duplicate protection
   - cosmetics, convenience and a fair battle pass
   - no premium-currency defenses
   - no character gacha

   A $4.99 pass with real cosmetic content, not emoji filler, plus cosmetic base skins is enough at our scale.
2. **Make raiding have stakes and targets.** Zombix shows that clan territory keeps people for years. Its two failures are (a) bases held forever by the same mega-clans and (b) no loot loss, so PvP feels pointless. Design:
   - wipe or season cycles for contestable territory
   - caps on clan size and holdings, or diminishing returns
   - raid windows or offline protection, so players don't lose everything while asleep yet raids still happen
   - **real loot at risk** in the raid zone (DayZ and Rust-style), kept separate from a safe home base
3. **Make the personal base a real building system, not a box.** Zombix players repeatedly ask for walls, doors, floors, storage and the freedom to rearrange. LDoE's strength here is the bar to beat. Tie the personal base into raiding, so that players actually raid each other, which LDoE doesn't deliver.
4. **Treat infrastructure and regions as product features.** Lag, ping and outages are Zombix's most common English complaint. Run Western, Asian and LATAM regions from day one, with server-authoritative netcode tuned for mobile, and never let one region (RU) gatekeep shared modes.
5. **Ship anti-multi-boxing and replay tools early.** Zombix's developer is only now building replays after years of botting. Budget for server-side detection, device and account linkage limits, rate-limited fishing and farming loops, and a report pipeline with replay evidence.
6. **Use account linking, not "lost forever."** Lost accounts generate steady 1★ reviews, including from paying players. Use platform sign-in and recovery flows.
7. **Keep a steady content cadence and talk to players openly.** Zombix's developer-run Telegram earns trust, but pass-only months read as abandonment. Plan quarterly gameplay drops (locations, enemies, base parts), not just seasons, and keep a public roadmap and forum.
8. **Onboard far better.** Zombix's tutorial is a 6-year-old complaint. Use quest markers, a short guided first session, and a starter area protected from geared players.
9. **Offer both combat modes.** Veterans want skill-based manual aim; casual players want auto-fire. Offer both, with matchmaking or zones that keep them fair, instead of flip-flopping the way Zombix did from 2023 to 2026.
10. **Opportunity:** a game is clearly missing that combines Zombix's open, social, persistent multiplayer world with LDoE's building depth and polish and fair monetization. Zombix's 4.8M lifetime installs from a solo developer with almost no marketing, and players' DayZ, Zomboid and STALKER comparisons, show the demand. Russian-speaking and SEA players are Zombix's core audience. Plan localization and payments (including web-shop options where store billing is blocked) with them in mind.

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. I re-fetched each cited source directly (Google Play listing data, the iTunes lookup API, App Store US/RU pages, RuStore, AndroidRank, AppGoblin, GameBrain, Trashbox, the Discord invite API, the Telegram public archive, the web-shop bundle and its product API, YouTube video pages, and Google Play's public review feed). The web-search budget for this run was already used up, so corroboration came from primary sources rather than new searches.*

**Confirmed exactly or near-exactly (no change):**
- Google Play: 1M+ bracket with exact counter 4,793,955; released Aug 30, 2019; $0.49–$74.99 per item; no "Contains ads" flag; Everyone 10+; updated Oct 28, 2026; developer "MMORPG Dev", contact Vladislav Okhotnikov, Warsaw address.
- LDoE: 100M+ with exact counter 140,558,641; 4.4 (4.353) from 4,755,178 ratings; $0.49–$199.99; "Contains ads"; KEFIR!; updated Nov 5, 2026; its description says the core journey is single-player, with multiplayer and PvP in the Crater.
- iOS: released 2024-05-07; v5.01 on 2026-10-28; seller Vladislav Okhotnikov; per-country ratings (US 4.47/40, RU 4.32/77, UA 4.53/30, KZ 4.35/23, BY 4.36/14, TR 4.31/13); all ten US and RU IAP prices; "Contains Loot Boxes"; version history, including no release in Jun–Jul 2026.
- RuStore (Berzerk Games, up to 100K, 4.0, 74 ratings / 44 reviews); AndroidRank (3,518,906 estimated, 4.49, 61,887, all four milestone dates); AppGoblin (4.8M, about 220K MAU, under $10K/month, +14K/month, IAP 100% / ads 0%, Unity/Firebase/AdMob); GameBrain (74%, 1,100); Trashbox (4.6 from 10).
- Discord: 7,458 members, created 2020-06-10 (165 online at re-check). Telegram: 4,004 subscribers, first post 2022-09-22, and yearly median views matching the table.
- Developer's other games: Desert Pixel Online 100K+, Custom Cats Online 100K+, Spell Crit 50K+ released Feb 23, 2026.
- Telegram claims: Server 4 at "about 50 players total" (TG 217, 2026-10-05); Server 4 beta for rank 40+ (TG 26) and launch on 2023-10-08 (TG 29); SBP and Russian cards on 2024-03-29 (TG 70); small turret raised from 1 to 2 gems (TG 101); 1,000-gem unban and 714 AFK arena bans (TG 150); "first 3 wins per day" (TG 158); "mini-Tarkov" plan (TG 115); account-recovery and anti-cheat stance (TG 211); replay system, Brazil server and shop search plans (TG 212); 300 botting accounts (TG 222); forum launch (TG 216); 5.0 shipping with new cases (TG 215); 3v3 arena and Survivor Bases map (TG 221); Asia region moving between Hong Kong, Singapore and Malaysia (TG 206).
- Web shop: character ID plus server, "usually 5 minutes, up to 24 hours", "one key, one box", Seasonal kit contents (toxic gun, titanium helmet, motorcycle), a separate Server 4 shop, and the public offer naming a Russian sole proprietor acting as the rights holder's agent.
- Russian star-trend table reproduced exactly from the public review feed (1,500 reviews, 2025-01-07 to 2026-11-06: 4.28 / 4.33 / 4.19 / 3.97, and 3.48 from 54 reviews after 5.0; 70% 5★). EN volume of 414 reviews since 2024 also reproduced. Spot-checked review quotes were all found with matching dates and stars (gacha 2022-02-15 with 28 helpful; "non p2w" 2020-06-15; "surprisingly cheap" 2020-07; "dayz pixelated"; "Raid like Loot & Extract"; "gatekeeping"; weekly anti-scam popup; the $40 App Store review; the clan-cost review; Technos in about 2 months; the "box, nowhere even to sit" review of 2022-11-25; the 10-hours / two level-60 players review; the fishing-cap and fish-spoilage complaints after 5.0).
- YouTube views, dates and channels checked for 7 of the 10 videos (AMID, Pryszard, CG MODS, Disti, Ryo AM, NlCK-name, Snoozi). All matched.

**Corrected:**
1. *Item loss on death:* "removed in January 2020" became "by April 2020". The developer reply that says so is dated 2020-04-09; only the review it answers is from January 2020. Changed in section 6 and in the section 8 table.
2. *Arena format:* "a 3-team match" became teams of three players (launch layout apparently four teams, 3x3x3x3, per TG 158; cut experimentally to two teams in TG 63). The radiation timing now records the actual sequence (15, then 30, then 20 minutes; by Feb 26, light at 10 and lethal at 20).
3. *Arena citations:* the final-death gear-drop rule and the "0 HP + base destroyed" rule come from TG 62, not TG 63 or the range TG 47–63.
4. *Clan storage and territories:* these were attributed to Server 4 via TG 13, but TG 13 is a December 2022 *plan*, posted before Server 4 existed, and it warns that features might not ship. Reworded, with shipping marked unverified. The Server 4 prize-fund mechanic (TG 156) is confirmed.
5. *Clan-cap requests:* "cap clans at 5 bases or 25 members" was wrong. The reviews found ask for a limit of 15 bases (2021) or 25 bases (2024) per clan. No request for a 25-member cap was found.
6. *Base count:* "more than 50 bases" became "about 50 ('+50≈')", matching the 2026-07-08 review's wording.
7. *v5.01 auto-aim:* TG 223 announces that auto-aim *will be* removed on servers 1–3. It does not confirm that the change shipped in 5.01.
8. *Play histogram:* the stated phone-histogram figures sum to 57,071, not 57,131, and a same-day re-fetch returned a different histogram and average (4.53). Both are now shown, and the original histogram is marked unverified. The 61.9K count is confirmed.
9. *Web shop:* the Small/Medium/Large/Great items are gem + zombux currency packs in the web shop, not item kits. The "could not retrieve live prices" gap is now filled from the shop's public product API, and the character-search feature is noted as built but switched off.

**Marked unverified:**
- "I see more players now" as a reaction to 5.0. It is not in the TG 221 post text or the re-checked Russian reviews; it may come from Telegram comments, which I could not read.
- The "developer's own complaint" about LDoE raiding (no source given).
- Which of the TG 13 clan features actually shipped.
- The original phone histogram and the 4.505 average, which differ by fetch.

**Not re-checked (left as written):** the keyword-theme share table, which depends on the author's keyword lists; the Discord online range; EU as a Server 3 region; YouTube rows for the pet review, the duplicate glitch and Bixudy; and LDoE's death-penalty and base-depth descriptions.

**Overall reliability: high.** Nearly every number that could drive a business decision (installs, prices, IAP ranges, ratings, dates, community sizes, third-party estimates, the sentiment trend) reproduced exactly from primary sources. The errors were in mechanic details (death-penalty date, arena format, clan-cap numbers, attributing a 2022 plan to Server 4) and in citations, not in the headline conclusions. Treat the design inferences in section 6 about loot loss and base control with slightly more care, since that is where the corrections cluster.

---

## Sources

- [Google Play]: [Zombix Online: Survival, Google Play](https://play.google.com/store/apps/details?id=com.ZombixDev.ZombixOnline&hl=en_US&gl=US). Listing, histogram, IAP range, developer address. [Google Play reviews]: reviews pulled from the same listing's public review feed (RU and EN), 2026-11-07, including developer replies.
- [App Store US]: [Zombix Online, App Store US](https://apps.apple.com/us/app/zombix-online/id6482997204). IAPs, version history, reviews.
- [App Store RU]: [Zombix Online, App Store RU](https://apps.apple.com/ru/app/zombix-online/id6482997204)
- [iTunes lookup]: [iTunes Lookup API, RU example](https://itunes.apple.com/lookup?id=6482997204&country=ru). Per-country ratings; same call with other country codes.
- [RuStore]: [RuStore listing](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline) and [RuStore reviews](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline/reviews)
- [AppGoblin]: [AppGoblin profile](https://appgoblin.info/apps/com.ZombixDev.ZombixOnline). Model estimates, SDKs.
- [AndroidRank]: [AndroidRank](https://www.androidrank.org/application/zombix_online_survival/com.ZombixDev.ZombixOnline)
- [GameBrain]: [GameBrain review aggregate](https://gamebrain.co/game/zombix-online-survival)
- [Trashbox]: [Trashbox.ru page](https://trashbox.ru/link/zombix-online-android)
- [Malavida review](https://malavida.com/en/soft/zombix-online/android)
- [BlueStacks]: [BlueStacks game page](https://www.bluestacks.com/apps/casual/zombix-online-on-pc.html)
- [Discord]: [Zombix Online Official Discord](https://discord.com/servers/zombix-online-official-720251932710666261)
- [Telegram]: [Official Telegram @zombixnews (public archive)](https://t.me/s/zombixnews). Posts cited: [TG 13](https://t.me/zombixnews/13), [TG 26](https://t.me/zombixnews/26), [TG 29](https://t.me/zombixnews/29), [TG 37](https://t.me/zombixnews/37), [TG 47](https://t.me/zombixnews/47), [TG 49](https://t.me/zombixnews/49), [TG 51](https://t.me/zombixnews/51), [TG 62](https://t.me/zombixnews/62), [TG 63](https://t.me/zombixnews/63), [TG 66](https://t.me/zombixnews/66), [TG 70](https://t.me/zombixnews/70), [TG 87](https://t.me/zombixnews/87), [TG 101](https://t.me/zombixnews/101), [TG 115](https://t.me/zombixnews/115), [TG 149](https://t.me/zombixnews/149), [TG 150](https://t.me/zombixnews/150), [TG 156](https://t.me/zombixnews/156), [TG 158](https://t.me/zombixnews/158), [TG 168](https://t.me/zombixnews/168), [TG 173](https://t.me/zombixnews/173), [TG 194](https://t.me/zombixnews/194), [TG 202](https://t.me/zombixnews/202), [TG 206](https://t.me/zombixnews/206), [TG 208](https://t.me/zombixnews/208), [TG 211](https://t.me/zombixnews/211), [TG 212](https://t.me/zombixnews/212), [TG 213](https://t.me/zombixnews/213), [TG 215](https://t.me/zombixnews/215), [TG 216](https://t.me/zombixnews/216), [TG 217](https://t.me/zombixnews/217), [TG 219](https://t.me/zombixnews/219), [TG 221](https://t.me/zombixnews/221), [TG 222](https://t.me/zombixnews/222), [TG 223](https://t.me/zombixnews/223)
- [Official site](https://zombixonline.com) · [Shop UI]: [Web shop](https://shop.zombixonline.com) (live prices from its public product API, `shopapi.zombixonline.com/api/products`, read 2026-11-07) · [Feedback forum](https://zombix.featurebase.app)
- [LDoE Play]: [Last Day on Earth, Google Play](https://play.google.com/store/apps/details?id=zombie.survival.craft.z&hl=en_US&gl=US)
- Developer's other games: [Desert Pixel Online](https://play.google.com/store/apps/details?id=com.BattleRoyale.DesertPixel), [Custom Cats Online](https://play.google.com/store/apps/details?id=com.MMORPGDev.KotikiOnline), [Spell Crit: Idle MMORPG](https://play.google.com/store/apps/details?id=com.idle.mmorpg)
- YouTube:
  - [AMID guide](https://www.youtube.com/watch?v=N-2vMt4VUDg)
  - [Pryszard walkthrough](https://www.youtube.com/watch?v=9ViBSO54AEI)
  - [Disti gold farming](https://www.youtube.com/watch?v=MuXm8wSG-oY)
  - [Disti character upgrades](https://www.youtube.com/watch?v=fXQ8O76_1zs)
  - [Ryo AM clan war 2025](https://www.youtube.com/watch?v=g1JoBPo1-r4)
  - [Ryo AM Europe raid](https://www.youtube.com/watch?v=HxOhC0Zi36w)
  - [Bixudy PvP](https://www.youtube.com/watch?v=U3tSoZB61e0)
  - [NlCK-name donate gifts (2022)](https://www.youtube.com/watch?v=-l6-Qf06Svc)
  - [NlCK-name 5.0 update](https://www.youtube.com/watch?v=D3bQzPBSJzo)
  - [Snoozi global update](https://www.youtube.com/watch?v=Jok_WWNeeaI)
  - [Duplicate glitch](https://www.youtube.com/watch?v=bunc_XFFeQ4)
  - [Mod menu](https://www.youtube.com/watch?v=esCxjVipwao)
  - [Pet review](https://www.youtube.com/watch?v=6P1Lip5RlEs)
