# Platform Economics: Google Play vs Roblox for a Solo Dev Starting From Zero

*Research date: 2026-11-07. Question: which platform pays more for the time invested, and how fast can each turn a project around, for a solo developer with no existing audience? The developer already has a Google Play Console account and a live app, so the Play workflow is familiar.*

> **How to read this file**
> - Statements with a link are sourced. Lines starting with **Inference:** are my analysis, not facts.
> - Revenue figures are third-party estimates (Sensor Tower, AppMagic) unless a company reported them.
> - Roblox genre and live-player rankings come mostly from SEO-style blogs and conflict with each other. Use them for direction only.

---

## 1. TL;DR

1. **For money per hour in the next 6–12 months with no audience, Roblox is the better bet.** Each attempt costs weeks instead of months, and Roblox's recommendations send players to new games. Google Play lets you keep far more of each dollar, but you have to find the players yourself.
2. **Revenue = traffic × conversion × spend per payer × your cut.** Roblox provides traffic (if retention is good) and keeps most of the revenue. Google Play keeps little of the revenue and provides almost no traffic.
3. **Both platforms are hit-driven, and most projects earn close to nothing.** What changes the math is the cost of each attempt. On Roblox you can try 5–10 small games a year. On Play, a mid-core game is one or two attempts a year.
4. **This zombie survival game is an unusually good fit for Roblox.** Servers, multiplayer, saves and matchmaking come free. On Play the backend is ours to build and pay for, and the "survival" keyword is owned by 4X games that spend millions on ads (see [competitor-landscape.md](competitor-landscape.md)).
5. **Recommended path:** spend 4–8 weeks building a stripped-down version of the core loop on Roblox and see whether players stay. Keep the Unity/Play project as the long-term game we own, and commit to a full Play launch only once there is a way to get players.

---

## 2. Comparison table

| | Google Play (Unity) | Roblox |
|---|---|---|
| **Your share of each $1 players spend** | About 85–90¢. Google's service fee is moving to 10% on the first $1M a year, with a 15% tier still listed for markets not yet switched over. Check the Play Console for your rate ([PocketGamer.biz](https://www.pocketgamer.biz/google-play-expands-billing-options-and-lowers-fees-for-developers/), [Google](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)) | About 20–30¢. Roblox takes 30% of each sale, then pays out Robux at $0.0038 each (rate since Sep 5, 2025) ([gam3s.gg](https://gam3s.gg/news/roblox-increases-creator-payouts)). Spend by age-verified US players aged 18+ pays out about 42% more, starting Jun 8, 2026 ([Tubefilter](https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/)) |
| **Where players come from** | Paid ads or going viral on social media. Store browsing brings almost nothing ([mobilegamer.biz](https://mobilegamer.biz/app-store-discovery-is-dead-so-what-do-indies-do-now)) | Roblox's recommendations test new games on real players. In Aug 2026, 28% of the top 100 games by hours played had launched in the previous 90 days ([IBTimes](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)) |
| **Time to a first playable release** | **Inference:** mid-core survival game, 6–24 months solo; hybridcasual, about 1–2 months | Days to weeks. Grow a Garden's first version was reportedly built in about 3 days ([IBTimes](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)) |
| **Pushing an update** | Build, upload, wait for review | Publish instantly |
| **Servers, multiplayer, saves** | We build them and pay for them (see [unity-online-tech.md](unity-online-tech.md)) | Free and built in |
| **Who owns the game** | We do, and it can be ported to iOS or Steam | It only exists on Roblox, under Roblox's rules |
| **Typical outcome** | Median near $0 (no reliable Play-specific figure found) | Of the 42K+ creators who cashed out in the 12 months to Jun 30, 2026, the median got about $1,500 ([IBTimes](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403), [Dexerto](https://www.dexerto.com/roblox/robloxs-top-creators-average-65-7-million-a-year-but-most-make-far-less-3408675/)). Most creators never earn enough to cash out |

**How the Roblox share works out (Inference):** a player spends roughly $0.01–0.0125 per Robux, depending on pack size. The developer receives 70% of each sale in Robux, then cashes out at $0.0038 per Robux. That gives about $0.0027 per Robux spent, or roughly 21–27% of what the player paid. Check Roblox's current Robux prices before relying on this.

---

## 3. Mobile market snapshot (2026)

- **Top grossing games:** Honor of Kings, Last War: Survival, Whiteout Survival, Royal Match, Monopoly Go, Gossip Harbor, Candy Crush, Kingshot ([Sensor Tower Jan](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-january-2026), [Feb](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-february-2026), [Jun](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-june-2026), [mobilegamer.biz Q3](https://mobilegamer.biz/data-digest-q3s-top-earners-2026s-biggest-new-launches-apple-and-google-fined-47-6m-more/)).
- **Revenue by genre, H1 2026** ([PocketGamer.biz](https://www.pocketgamer.biz/mobile-gaming-iap-dipped-2-as-ad-spend-climbed-in-h1-2026/)):
  - Strategy (mostly 4X) leads at $9.3B but fell about 5%.
  - Puzzle grew almost 20% to $8.1B.
  - RPG made $6.1B and casino $5B.
- **The overall market is shrinking:** downloads fell 12% to 24B, in-app spending fell 2% to $40B, and gaming ad spend rose 8% to $7B. Buying players costs more while each player is worth less (same source).
- **Growing vs. shrinking:** hybridcasual games (simple casual games with extra progression systems, like Block Blast) are the clear growth area. Mid-core games are still the largest group but are losing ground (same source).
- **Free-to-play dominance:** in 2025, 96% of mobile game downloads were free-to-play, and 99% on Google Play ([Sensor Tower State of Gaming 2026](https://sensortower.com/blog/state-of-gaming-2026)).
- **Inference:** the top grossers are live-ops operations earning $100M+. They are not realistic indie targets. The lanes open to an indie are hybridcasual, niche premium games, and mid-core games with a clear hook plus a way to find players.

---

## 4. Roblox market snapshot (2026)

- **Creator payouts:** about $1.7B in the 12 months to Jun 30, 2026, up about 50% year on year. The top 10 creators averaged $65.7M each, about 39% of the total ([IBTimes](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)).
- **The platform shrank in 2026:** Q3 2026 bookings fell about 12% year on year to $1.697B, and daily active users fell about 9% to around 138M ([securities.io](https://www.securities.io/roblox-q3-revenue-rises-16-as-bookings-fall-12-to-1-7-billion/)). Daily paying users dropped from about 2.3M to 1.8M ([stockhub.kr](https://stockhub.kr/en/insights/view_1793323972300_ak32xsw0a)). Q4 bookings are guided 10–15% lower again ([gaming.net](https://gaming.net/roblox-q3-revenue-rises-16-as-bookings-fall-12-to-1-7-billion)).
- **Genres that are working** (low-reliability sources: [ExitLag](https://www.exitlag.com/blog/roblox-game-genres-and-popularity/), [Rowatcher](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players)):
  - Roleplay: Brookhaven.
  - "Brainrot" collect-and-sell simulators: Steal a Brainrot, Grow a Garden, Escape Tsunami for Brainrots.
  - Survival horror: 99 Nights in the Forest.
  - Anime fighting games and fishing games (Fish It!).
- **Earnings per hour:** a Roblox game earning 500K Robux a month pays roughly $1,750–1,900 a month, depending on the payout rate used. Rowatcher argues that most mid-tier Roblox games pay below US minimum wage per hour of work ([Rowatcher](https://rowatcher.com/news/what-devex-actually-pays-per-hour-in-2026)). These are the author's worked examples, not survey data.

---

## 5. Things that count against Roblox

- **The platform is shrinking** (see section 4).
- **The audience skews young and follows fads.** Brainrot games show how fast trends come and go.
- **Unity C# does not carry over.** Roblox uses its own tools (Roblox Studio) and the Luau scripting language. **Inference:** for an experienced programmer that is a few weeks of learning. Art and design skills transfer.
- **Earnings are very concentrated** (top 10 creators took about 39% of payouts).
- **Platform risk.** Roblox sets the payout rate, the recommendation rules and the content policies, and the game cannot leave the platform.

## 6. Things that count against Google Play

- **No free traffic.** App store featuring and browsing have lost most of their power for small developers, and paid ads are hard to make profitable on an indie budget ([mobilegamer.biz](https://mobilegamer.biz/app-store-discovery-is-dead-so-what-do-indies-do-now)).
- **Rising ad costs.** Gaming ad spend rose 8% in H1 2026 while in-app spending fell 2% ([PocketGamer.biz](https://www.pocketgamer.biz/mobile-gaming-iap-dipped-2-as-ad-spend-climbed-in-h1-2026/)).
- **The "survival" keyword is taken** by 4X games (Whiteout Survival, Last War: Survival) with huge ad budgets ([competitor-landscape.md](competitor-landscape.md)).
- **Long development cycles** for mid-core online games, plus the cost of servers, anti-cheat and live operations.

---

## 7. Recommendation for this project

1. **Build a Roblox version of the core loop (4–8 weeks).** Scavenge, build, defend, and if possible a light raid. Use it to measure retention and session length with real players at almost no cost. 99 Nights in the Forest shows survival games can do well on Roblox.
2. **Keep the Unity/Play game as the long-term game we own.** It is portable to iOS and Steam, and we keep 85–90% of revenue.
3. **Commit to a full Play mid-core launch only once there is a way to get players:** a social media following, a Discord community, or a proven hook from the Roblox test.
4. **Use the existing Play app as a baseline.** Its organic installs per day in the Play Console show how many players Play sends us for free.

---

## Gaps (what I could not verify)

- **Current Robux prices per pack**, needed to pin down the 20–30% creator share precisely.
- **The DevEx minimum cash-out threshold.** Sources disagree (figures from 30,000 to 100,000 Robux appear).
- **Median Google Play earnings for an indie game.** No reliable 2026 figure found, and no reliable 2026 cost-per-install benchmarks.
- **Roblox genre rankings** come from SEO blogs rather than Roblox's own charts.
- **Which Google Play fee tier applies** to this account and region. Check the Play Console.

---

## Sources

- [Sensor Tower – top 10 mobile games, January 2026](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-january-2026)
- [Sensor Tower – February 2026](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-february-2026)
- [Sensor Tower – June 2026](https://sensortower.com/blog/top-10-worldwide-mobile-games-by-revenue-and-downloads-in-june-2026)
- [Sensor Tower – State of Gaming 2026](https://sensortower.com/blog/state-of-gaming-2026)
- [mobilegamer.biz – Q3 data digest](https://mobilegamer.biz/data-digest-q3s-top-earners-2026s-biggest-new-launches-apple-and-google-fined-47-6m-more/)
- [mobilegamer.biz – App Store discovery is dead (Mar 2023)](https://mobilegamer.biz/app-store-discovery-is-dead-so-what-do-indies-do-now)
- [PocketGamer.biz – mobile gaming IAP dipped 2% as ad spend climbed in H1 2026](https://www.pocketgamer.biz/mobile-gaming-iap-dipped-2-as-ad-spend-climbed-in-h1-2026/)
- [PocketGamer.biz – Google Play expands billing options and lowers fees](https://www.pocketgamer.biz/google-play-expands-billing-options-and-lowers-fees-for-developers/)
- [Google – Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)
- [IBTimes – Roblox top creators' DevEx payouts](https://www.ibtimes.co.uk/roblox-top-creators-devex-payouts-2026-1819403)
- [Dexerto – most Roblox creators make far less](https://www.dexerto.com/roblox/robloxs-top-creators-average-65-7-million-a-year-but-most-make-far-less-3408675/)
- [Rowatcher – what DevEx actually pays per hour](https://rowatcher.com/news/what-devex-actually-pays-per-hour-in-2026)
- [Rowatcher – most popular Roblox games by live players](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players)
- [Tubefilter – Roblox 18+ DevEx increase](https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/)
- [gam3s.gg – Roblox increases creator payouts](https://gam3s.gg/news/roblox-increases-creator-payouts)
- [securities.io – Roblox Q3 2026 results](https://www.securities.io/roblox-q3-revenue-rises-16-as-bookings-fall-12-to-1-7-billion/)
- [gaming.net – Roblox Q3 2026 results](https://gaming.net/roblox-q3-revenue-rises-16-as-bookings-fall-12-to-1-7-billion)
- [stockhub.kr – Roblox paying users](https://stockhub.kr/en/insights/view_1793323972300_ak32xsw0a)
- [ExitLag – Roblox genres](https://www.exitlag.com/blog/roblox-game-genres-and-popularity/)
