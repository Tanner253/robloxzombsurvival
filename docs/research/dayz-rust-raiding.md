# DayZ and Rust: What Makes PvP Survival and Raiding Fun, and How They Handle It

*Research date: 2026-11-07. Scope: Rust (PC/console), DayZ, and mobile or "Rust-like" adaptations (Last Island of Survival, Rust Mobile, Once Human RaidZone, Undawn, Earth: Revival). Facts carry a source link. Lines that start with **Inference:** are my own analysis.*

> **Method and limits.** I ran about 30 web searches until the session's search budget ran out, then fetched primary sources: Facepunch devblogs (2020-2026), the Facepunch Rust wiki, DayZ wiki.gg, official Once Human pages, App Store listings, Wikipedia, and press. **Reddit could not be fetched** (old.reddit.com was blocked for the fetch tool), so Reddit sentiment below comes only from search snippets. **YouTube was not searched or watched.** The budget ran out before those searches, and I cannot watch video anyway. Live games change monthly, so check every number against the date given.

---

## TL;DR: the most decision-relevant findings

1. **Facepunch has started limiting raids to scheduled windows.** In July 2026 Rust's official Softcore mode added **raid windows: by default, building blocks and doors can only be raided from 6 PM to 9 PM server-local time**. Outside the window, a Tool Cupboard projects raid protection. A TC must be at least 1 hour old before it gives that protection ([Facepunch, "Common Ground", 2 Jul 2026](https://rust.facepunch.com/news/common-ground)). Their stated reason: *"It's hard to handle raids for more casual players."*
2. **Facepunch now taxes big groups directly.** Since September 2026, Tool Cupboard upkeep rises with the number of authorized players. The first 4 players are free, players 5-10 add +2% each, every player past 10 adds +4%, and the total is capped at +300% ([Facepunch, "Breach and Clear", 3 Sep 2026](https://rust.facepunch.com/news/breach-and-clear)).
3. **A raid in Softcore no longer means losing everything.** Since April 2025, destroyed storage drops 50% of its contents and keeps the other 50% for the owner, who can repair the debris. A destroyed TC keeps authorization for 48 hours, so raiders cannot seal the base. For an average large base, door upkeep was raised to about 90%, versus about 30% in vanilla (the post does not say what the percentage is of; most likely the daily upkeep rate against the door's build cost), explicitly to "encourage more raiding" ([Facepunch, "Soft Refresh", 3 Apr 2025](https://rust.facepunch.com/blog/soft-refresh)).
4. **Raids are paid for in one currency.** Every Rust explosive costs sulfur: C4 is 2,200, a rocket 1,400, a satchel 480, and explosive ammo 25 per round. A sheet-metal wall takes 4 C4 and an armored wall takes 8 ([GameServerKings raid chart, Sep 2026 build](https://www.gameserverkings.com/knowledge-base/rust/rust-raid-chart/)). The defender's choice of building tier sets the attacker's price.
5. **Push alerts turn offline raids into online fights.** Rust+ Smart Alarms have sent phone push notifications since 2020 ([Facepunch, Jun 2020](https://rust.facepunch.com/blog/companion-app-update)). Rust Mobile's marketing also advertises raid notifications ([Deltia's Gaming via search snippet](https://deltiasgaming.com/?p=303491)) (unverified: the page could not be fetched and the official site and press pages checked do not mention it).
6. **DayZ's tension comes from permadeath plus persistence, and its bases are not its centrepiece.** Dean Hall credited DayZ's appeal to permadeath giving *"a sense of value, because you could lose something"* combined with ownership ([Game Developer interview](https://www.gamedeveloper.com/design/dean-hall-discusses-i-dayz-i-s-development-process)). DayZ raiding is slow and expensive: about 1,100 sledgehammer hits per wall, or 2 plastic explosives. It is usually done against offline players ([guided.news, Jan 2024, v1.23](https://guided.news/en/guides/dayz-ultimative-raid-guide-explosives-firearms-or-fists/)).
7. **Mobile Rust-likes have converged on structured conflict.** Rust Mobile (still in beta as of Nov 2026 (unverified: no global launch found, but no news after the Aug-Sep 2026 beta could be checked)) ships Hardcore, Standard, Softcore (with raid protection) and a **15-minute 4v6 attack-versus-defense mode called "Territory Clash"** ([Pocket Gamer, 21 Nov 2025, on the Dec 2025 closed beta](https://www.pocketgamer.com/rust-mobile/first-closed-beta-test-on-mobile)). Once Human: RaidZone makes territory immune from 00:00 to 12:00 server time and resets servers every 14 days ([Once Human FAQ, May 2025](https://www.oncehuman.game/news/update/20250524/40780_1236481.html); [launch post, Jul 2025](https://www.oncehuman.game/news/wiki/20250814/40782_1250063.html)).

---

## 1. Why raiding is Rust's emotional peak

**Facts**
- Raiding is described as a major part of Rust. Clans build shared housing, pool supplies and run organized raids ([Wikipedia: Rust](https://en.wikipedia.org/wiki/Rust_(video_game))).
- Critics name the same thing as the main pain. IGN noted that players can lose their base to a raid and have to start over. Game Informer found it demotivating to be killed simply because a more experienced player ran into them (summarized on [Wikipedia](https://en.wikipedia.org/wiki/Rust_(video_game))).
- An essay on Rust's wipe cycles argues that weekly wipes manufacture a structure of growth and decay ([Heterotopias zine, 2017](https://heterotopiaszine.com/2017/06/20/cyclical-apocalypse-rust)).
- The audience is large and still growing. The all-time Steam peak was 259,646 concurrent players (Jan 2025 per [SteamCharts](https://steamcharts.com/app/252490); Facepunch says only "in 2025"). Across 2025 the game had 5.8M unique players and over 700M hours played ([Facepunch, "Surviving 12 Years", 1 Jan 2026](https://rust.facepunch.com/news/surviving-12-years)). In June 2026 SteamCharts showed an average of about 104K and a monthly peak of about 219K; by Oct 2026 it was about 85K average and 162K peak ([SteamCharts](https://steamcharts.com/app/252490)). (An earlier draft cited SteamPulse at ~106K average / ~145K peak; SteamPulse could not be reached and its peak conflicts with SteamCharts.)

**Inference: why the raid is the peak**
- **Everything you have built is at risk in one event.** Hours of farming, crafting and upkeep exist as one physical object that can be broken. No other moment in the game risks that much at once.
- **Both sides plan for it.** Attackers save sulfur for days and scout the target ("how many rockets is that?"). Defenders design bunkers, honeycomb layers and turret coverage. The raid is where both sides find out whether their plans worked.
- **The world knows when a raid happens.** Explosions can be heard across the map. Third parties ("roofcampers", counter-raiders) arrive, and the event grows into a server-wide story.
- **Raiding is the progression.** The best way to get ahead in a wipe is to take another group's stockpile. A successful raid gives the biggest jump in the game.
- **The wipe makes it safe to risk everything.** All progress resets on a known date, so the end of a wipe brings huge "throw it all" raids because nothing is worth saving.

---

## 2. Rust's raid systems in concrete detail

### 2.1 Tool Cupboard (TC), building privilege, upkeep and decay
Source: [Facepunch Rust wiki: Tool Cupboard](https://wiki.facepunch.com/rust/the_tool_cupboard).

- **The TC is the heart of a base.** It costs 1,000 wood. It grants building privilege over a radius projected from the foundations connected to it, and blocks other players from building inside that radius. If raiders reach the TC and authorize themselves, they own the base.
- **Upkeep.** The TC uses up a fraction of the base's build cost every 24 hours. Walls, foundations, roofs, doors and windows count toward it, but deployables do not. High external walls add no upkeep.
- **Decay once upkeep runs out:** twig in 1 h, wood 3 h, stone 5 h, metal 8 h, armored 12 h. Decay starts at the outer layers and moves inward.
- **Grief protection.** A destroyed TC that still held resources pays up to 24 h of upkeep, so a raided base does not instantly decay.
- **Inference:** Upkeep is Rust's hidden limit on base size. A bigger base costs more every day, so it needs more farming and more time online. That cost is what keeps raidable targets in reach.

### 2.2 Raid tools and the explosive economy

| Target (full HP) | HP | C4 | Rockets | Satchels | Explosive 5.56 |
|---|---|---|---|---|---|
| Wood wall | 250 | 1 | 2 | 3 | ~48 |
| Stone wall | 500 | 2 | 4 | 10 | ~183 |
| Sheet metal wall | 1,000 | 4 | 8 | 23 | ~400 |
| Armored wall | 2,000 | 8 | 15 | 46 | ~798 |
| Sheet metal door | 250 | 1 | 2 | 4 | 63 |
| Garage door | 600 | 2 | 3 | 9 | 150 |
| Armored door | 1,000 | 3 | 5 | 15 | 250 |

Sulfur cost per explosive: **C4 2,200, rocket 1,400, satchel 480 (20% dud rate), explosive ammo 25 per round.** Source: [GameServerKings, built on the 22 Sep 2026 server build](https://www.gameserverkings.com/knowledge-base/rust/rust-raid-chart/). These are a third-party's calculations, not official numbers. Other guides disagree on some door figures ([xgamingserver](https://xgamingserver.com/blog/rust-raid-cost-chart-how-much-c4-rockets/), [supercraft](https://supercraft.host/wiki/rust/raiding-guide)).

- **2026 additions:** a **Mortar**, a long-range deployable that can hit players or structures. It has no aiming guide (you estimate range with binoculars), and recoil plus spread stop it from repeating exact shots. The **Tin Can Alarm** can now be loaded with grenades, molotovs or flashbangs to make tripwire traps ([Facepunch, "Upgrade hard, raid harder", 7 May 2026](https://rust.facepunch.com/news/upgrade-hard-raid-harder)).
- **Wall sides:** each wall has a hard side facing outward and a weaker soft side facing in. The hard side gets 90% less blunt/stab damage and 50% less bullet damage, but **no extra protection against explosions**: C4, satchels and rockets take the same count from either side, while melee, bullets and beancans do much better on the soft side (e.g. a stone wall needs 46 beancans from the soft side vs 64 from the hard side) ([GameServerKings](https://www.gameserverkings.com/knowledge-base/rust/rust-raid-chart/); [xgamingserver raiding guide](https://xgamingserver.com/blog/rust-raiding-guide/), which also says "explosives deal the same damage to a wall regardless of which side they hit"). xgamingserver's separate cost chart claims soft-side raids take about half the explosives, which contradicts both.
- **Inference:** Sulfur is the raid currency. It comes from contested nodes and loot, and the defender's choice of tier sets the price of a raid. "How much sulfur is in that base?" is the question that drives the economy. The 1:2:4:8 HP ladder from wood to armored lets players read a base's value from the outside.

### 2.3 Raid defense
- **Auto turrets need electricity and line of sight. SAM sites need power and ammo** ([xgamingserver defense guide](https://xgamingserver.com/blog/rust-base-defense-turrets-traps/); [Physgun turret guide](https://physgun.com/blog/game-hosting/rust/how-to-setup-turrets-in-rust/)). The Auto Turret was named the June 2026 Workshop skinnable item, with community submissions accepted from 11 June 2026 ([Facepunch "Built Different"](https://rust.facepunch.com/news/built-different)).
- **Shooting floors and peek windows** let defenders shoot back during an online raid. Guides advise designing them in from the start ([xgamingserver](https://xgamingserver.com/blog/rust-base-defense-turrets-traps/)).
- **Bunkers.** Players build sealable rooms that can only be reached by deconstructing and rebuilding pieces, which makes offline raids very expensive. In a 2024 thread a Facepunch developer (/u/Alistair_Mc) said stability bunkers are allowed, have existed for about 10 years, and are only patched when they rely on exploits ([devtrackers.gg](https://devtrackers.gg/rust/p/da080db2-open-letter-to-facepunch-if-you-don-t-like-bunkers-you-should-nerf-offline-raiding)). The original poster argued that bunkers exist because offline raiding is too easy.
- **Raid alarms on your phone.** Smart Alarms paired with the Rust+ companion app send a push notification to every paired player who still has building privilege ([Facepunch, 4 Jun 2020](https://rust.facepunch.com/blog/companion-app-update)). Players also chain them into phone calls through IFTTT and third-party apps ([IFTTT applet](https://ifttt.com/applets/yFAixSZg-get-a-call-when-a-rust-smart-alarm-is-triggered-with-raid); [Physgun](https://physgun.com/blog/game-hosting/rust/how-to-set-up-a-raid-alarm-in-rust/)).
- **Inference:** Rust's real answer to offline raiding is to make every raid potentially an online raid. The alarm pulls the defender back into the game, and the raid becomes a fight rather than a robbery. The tools for this are optional, so many casual players never set them up.

### 2.4 Wipe cycles and server types
- **Forced wipe:** the monthly update lands on the first Thursday of each month and forces a map wipe on all servers (19:00 UK time). A blueprint wipe is only forced when Facepunch changes the item or blueprint system, with no fixed cadence, though most community servers also wipe blueprints on force-wipe day by convention ([GameSpot](https://www.gamespot.com/articles/rust-force-wipes-schedule-explained/1100-6505244/); [GameServerKings wipe guide](https://www.gameserverkings.com/knowledge-base/rust/wipe-day-guide/)). Many community servers also wipe weekly or every two weeks.
- **Official game modes:** vanilla and softcore are live. **Official Hardcore servers were shut down in November 2023** ([Facepunch wiki: Server Gamemodes](https://wiki.facepunch.com/rust/Server-Gamemodes)). Hardcore had no map, no teams, local chat only, no Rust+, and a 5-sleeping-bag cap.
- **Group limits:** at least some official vanilla servers now carry a group cap: Rustalyzer lists the official "[US East] Facepunch 4" with a **group limit of 8** ([Rustalyzer listing for Facepunch 4](https://www.rustalyzer.com/server/13066791)). I did not confirm whether every official server has the same cap. Smaller solo, duo, trio and quad caps are a community-server feature enforced by plugins and admins. Some ban teams that ally beyond the cap ([space-node admin guide, Mar 2026](https://space-node.net/blog/rust-server-admin-guidelines-2026)).
- **Typical community raid rules:** full PvP at any time (suited to wipes under 7 days); **raid hours** (common on casual or EU servers); or **no offline raiding** enforced by plugins such as NoOfflineRaid ([space-node](https://space-node.net/blog/rust-server-admin-guidelines-2026); plugins: [Offline Raid Limiter](https://lone.design/product/offline-raid-limiter), [Raid Time Protection](https://codefling.com/plugins/raid-time-protection)).
- **Clans (Jul 2026):** an official clan system with roles, clan chat and a clan table. The devblog states no member cap ([Facepunch, "Common Ground"](https://rust.facepunch.com/news/common-ground)).

### 2.5 How Softcore evolved: Facepunch's answer for casual players

| Date | Change | Source |
|---|---|---|
| Feb 2021 | Softcore launches on 10 official servers. Teams are capped at 4, counting TC and turret authorizations. You keep 50% of your inventory on death through reclaim. You can spawn at safe zones. | [Facepunch blog](https://rust.facepunch.com/blog/softcore-gamemode-update) |
| Apr 2025 | Destroyed containers, TCs and workbenches leave repairable debris. 50% of contents drop and 50% stays for the owner. A destroyed TC keeps authorization for 48 h, so raiders cannot seal the base. Door upkeep goes to about 90% (vanilla is about 30%). PvP bullet damage is cut by 25%. | [Facepunch "Soft Refresh"](https://rust.facepunch.com/blog/soft-refresh) |
| Jul 2026 | **Raid windows**, 6-9 PM server time by default. Outside the window, walls and doors inside a TC radius cannot be damaged, but deployables and an exposed TC still can. A TC must be at least 1 h old. Admins can tune all of this with ConVars. | [Facepunch "Common Ground"](https://rust.facepunch.com/news/common-ground) |

- **Inference:** Facepunch now has a two-tier design. Vanilla is the brutal sandbox for core players. Softcore buys casual players three things: raids happen at a predictable time, a lost raid is survivable, and nobody can permanently lock you out of your base. They also added extra door upkeep to keep raids happening, because protection alone would let bases grow until nobody raids them.

---

## 3. DayZ: persistence, loot tension and "every encounter matters"

### 3.1 Where the tension comes from
- In his Game Developer interview, Dean Hall describes DayZ's appeal as permadeath giving value, because you could lose something, combined with ownership, and stresses persistence: what you build "is going to be there tomorrow" ([Game Developer](https://www.gamedeveloper.com/design/dean-hall-discusses-i-dayz-i-s-development-process)).
- Hall has also said that permadeath only works if you "go all the way", and that it is risky because it upsets customers ([PC Gamer interview](https://www.pcgamer.com/day-z-interview-how-zombies-arma-2-created-gamings-best-story-machine)) (unverified: the article body could not be retrieved).
- DayZ is still growing. Search coverage reports a Steam record of about 79K concurrent players at the Frostline launch in October 2024 ([PC Gamer](https://pcgamer.com/games/survival-crafting/after-more-than-10-years-on-steam-dayz-sets-another-new-concurrent-player-record/); I saw only search snippets, not the full article). [SteamCharts](https://steamcharts.com/app/221100) confirms the all-time peak of 78,739 in October 2024, and no month in 2025 or 2026 has beaten it (highest: 75,508 in Feb 2025, 74,297 in Mar 2026). Update 1.29 (Apr 2026) brought a server and character wipe and made player spawn points more random ([Shacknews](https://www.shacknews.com/article/148621/dayz-update-1-29-patch-notes)).
- **Inference: why encounters feel heavy.**
  - You have one life and a full-loot body.
  - It takes a long time to gear up again.
  - You cannot read another player's intent: there are no nameplates, only proximity voice and body language.
  - The world is sparse, so meeting someone is rare.
  - Every meeting raises the same question, "friendly or not?". That uncertainty, not the gunfight, is the core experience. DayZ makes fights rare and costly, and Rust makes them frequent and cheap.

### 3.2 Base building
Sources: [DayZ wiki: Base Building](https://dayz.wiki.gg/wiki/Base_Building), [DayZ wiki: Fence](https://dayz.wiki.gg/wiki/Fence).
- **Building in stages.** Place a Fence Kit or Watchtower Kit, then add 2 logs to build the base. Each frame needs 4 planks and 8 nails. Each wall section needs either 5 planks and 10 nails (wood) or 3 sheet metal and 12 nails (metal). A basic fence needs at least 2 logs, 18 planks and 36 nails.
- **Gate:** a fence becomes a gate with metal wire and pliers. It locks with a 3- or 4-digit combination lock. Barbed wire (up to 2 reels) and a camo net can be attached. Fences can only be dismantled from the inside.
- **Persistence:** a fence has a 45-day lifespan. A raised **flag pole** stops items in its radius from despawning, but the flag lowers over time and must be raised again. Sources disagree on the radius: about 60 m in vanilla guides, 75-150 m on modded servers ([supercraft](https://supercraft.host/wiki/dayz/base-building-fence-watchtower/); [DayZ modding wiki](https://stardz-team.github.io/DayZ-Modding-Wiki/en/09-server-admin/07-persistence)).
- **Other storage:** tents, crates and barrels, plus buried stashes dug in with a shovel. Many players rely on hidden or buried stashes more than on fortresses.

### 3.3 Raiding
Source: [guided.news raid guide, Jan 2024, DayZ 1.23; values may be outdated](https://guided.news/en/guides/dayz-ultimative-raid-guide-explosives-firearms-or-fists/).
- **Explosives per wall:** 2 plastic explosives (wood or metal), 3 claymores (wood) or 5 (metal), or about 12 grenades or mines. A charge placed at a junction can take out two walls.
- **Guns:** about 300-500 rounds per wooden wall, around 27-42 seconds of continuous fire. It is loud.
- **Melee:** about 825 hits per wall with an axe or pickaxe, about 1,100 with a sledgehammer, and about 4,000 with fists (around 45 minutes). It is nearly silent but very slow.
- **Codes:** a 3-digit lock takes about 10-15 minutes to brute-force and a 4-digit lock about 1-2 hours.
- **Defense advice:** build compact bases with 1-2 entrances, several wall rows 2-3 m apart, barbed wire as an early warning, and traps (mines, bear traps, tripwires) set before logging out.
- **Servers:** on vanilla-style community servers such as DayZed, raiding is allowed at any time with no window and no offline protection. The flag stops decay, not raids ([DayZed wiki](https://dayzed.gg/wiki/features/codelocks)). Server owners can disable or limit raiding and tune base damage ([xgamingserver, Jun 2026](https://xgamingserver.com/blog/dayz-raiding-guide-how-to-raid-bases/)).
- **Inference:** DayZ raiding is a heist, not a siege. Bases are slow to build and slow to break, servers hold about 60 players, and owners are usually offline. So most raids are someone patiently chewing through a wall or a code while nobody is home. That is the "nobody comes to fight" problem the developer dislikes in LDoE. DayZ's PvP excitement lives in the open world, not at bases.

---

## 4. Problems and how they have been handled

| Problem | How it shows up | Official or community solutions | Notes |
|---|---|---|---|
| **Offline raiding** | Victims log in to an empty base with nobody to fight. A r/playrust post snippet complains of being "offlined at 3am" ([search snippet](https://axebps-redlib.hf.space/r/playrust/comments/1jqketp/and_no_one_is_happy)). Raids on offline bases also come up in Last Island of Survival App Store reviews (two of the visible reviews, one asking for offline protection) ([App Store](https://apps.apple.com/us/app/last-island-of-survival/id1463021419)). | Raid alarms on your phone (Rust+). Bunkers. Softcore raid windows (2026). Community no-offline-raid plugins, raid hours, and damage that scales with how long owners have been offline ([lone.design](https://lone.design/product/offline-raid-limiter)). | Full offline immunity is easy to abuse: players log off to become invulnerable. Facepunch chose fixed time windows instead, and requires a TC to be 1 h old so players can't drop a fresh TC mid-fight for protection. |
| **Zergs** (huge groups) | Big groups ignore difficulty through sheer numbers. Players say solo and duo play is not viable on vanilla servers ([Steam / Reddit snippets](https://redlib.hbubli.cc/r/playrust/comments/1ji2ruc/how_to_easily_nerf_zergs_and_improve_quality_of)). | Upkeep group scaling (Sep 2026). Softcore team cap of 4. Community solo/duo/trio/quad servers with bans for allying. | Facepunch's rationale: large groups *"bypass most difficulty mechanics in the game via sheer numbers"*, but they did not want to make big groups unviable ([Breach and Clear](https://rust.facepunch.com/news/breach-and-clear)). Players say small-team servers lose population quickly (snippet). |
| **Griefing** (sealing or locking victims out) | Raiders take over the TC and wall the owner out of their own base. | Softcore: 48 h during which raiders cannot seal the base, TC authorization survives, and debris can be repaired ([wiki](https://wiki.facepunch.com/rust/Server-Gamemodes); [Soft Refresh](https://rust.facepunch.com/blog/soft-refresh)). | A raid should take loot, not end your wipe. |
| **Toxicity** | Critics describe the community as toxic. Proximity voice makes many players less likely to shoot on sight ([Wikipedia](https://en.wikipedia.org/wiki/Rust_(video_game))). | Mostly cultural plus moderation. Hardcore servers used local-only chat. | **Inference:** proximity voice is a feature that creates social play (trading, betrayal), not just a moderation risk. |
| **Cheating** | 2025: more than 338,000 bans (about 296,000 permanent) and more than 16M cheat reports. Most cheaters are now caught within 7 hours of playtime ([Facepunch](https://rust.facepunch.com/news/surviving-12-years)). | EasyAntiCheat, Premium servers (entry requires a Steam inventory worth $15+), server-side culling, a public bug bounty, and a new third-party anti-cheat layer planned for 2026. Once Human RaidZone bans by account, device and IP ([Once Human](https://www.oncehuman.game/news/wiki/20250814/40782_1250063.html)). | Raiding multiplies the damage cheaters do: ESP shows where loot is stashed. |
| **New-player wall** | It is demotivating to die to more experienced players over and over (Game Informer via [Wikipedia](https://en.wikipedia.org/wiki/Rust_(video_game))). A progression update was criticized for leaving solos stuck at tier 1-2 workbenches ([PC Gamer](https://www.pcgamer.com/games/survival-crafting/rusts-pivot-or-die-update-was-meant-to-shake-up-the-meta-but-its-a-nightmare-for-solo-survivors-that-leaves-me-no-choice-but-to-die)) (unverified: only the headline could be retrieved; the tier 1-2 detail was not confirmed). | Softcore (safe-zone spawns, 50% reclaim, -25% PvP damage). Monument Blockers that slow early-wipe access to keycard loot ([Breach and Clear](https://rust.facepunch.com/news/breach-and-clear)). Rust Mobile's second 2026 beta added "new-player-friendly features" and more accessible gameplay options ([Final Weapon](https://finalweapon.net/2026/07/31/rust-mobile-second-beta-test/)). | |
| **Time commitment** | Upkeep, farming and being online to defend. | Wipes cap the commitment. Raid windows tell you when you need to be online. | **Inference:** this is the main barrier for mobile players. |

---

## 5. How mobile and other games adapted real-time raiding

| Game | Status (Nov 2026) | How raiding works | What seems to work or fail |
|---|---|---|---|
| **Rust Mobile** (Facepunch license; Level Infinite/Tencent) | **No global launch found.** Revealed Aug 2025. CBT1 in Dec 2025 had over 1M pre-registrations. Regional open beta in Hong Kong and Macao from 9 Jul 2026. Second beta 23 Aug-30 Sep 2026. Reported 3M+ pre-registrations (unverified: no cited or checked source gives this figure). A China launch was reported for Jul 2026 but is unconfirmed. Facepunch's Jan 2026 post planned a global release in 2026. | Modes: **Hardcore** (classic Rust), **Standard**, **Softcore** (raid protection, lighter death penalties) and **Territory Clash**, a 15-minute 4v6 attack-versus-defense mode. Building is adapted for touch and keeps clan bases, trap bases and auto turrets. Raid notifications are advertised. | It offers several modes instead of one ruleset. **Territory Clash** guarantees a raid-style fight inside a session that fits a phone. Sources: [Pocket Gamer](https://www.pocketgamer.com/rust-mobile/first-closed-beta-test-on-mobile), [Pocket Gamer 1M](https://www.pocketgamer.com/rust-mobile/1-million-pre-registrations), [GamingonPhone](https://gamingonphone.com/news/rust-mobile-is-bringing-its-acclaimed-survival-action-to-select-regions-on-android-with-a-regional-open-beta-test-on-july-9-2026/), [Final Weapon](https://finalweapon.net/2026/07/31/rust-mobile-second-beta-test/), [ACN Newswire](https://www.acnnewswire.com/press-release/english/101604/), [Facepunch](https://rust.facepunch.com/news/surviving-12-years). |
| **Last Island of Survival** (HK Hero Entertainment) | Live. US App Store: 3.9★ from about 12K ratings, version 2.45.0. In-app purchases range from $0.99 to $99.99. | A PvP-focused Rust-like: raid forts, steal loot, clans, and structures that rust without maintenance. Version 2.27.0 (Jul 2024) added a PvE zombie mode ("Doomsday Frenzy"); later versions, including 2.45.0, add social servers. | Reviews ask for PvE servers and offline protection, complain about pay-to-win and hackers, and object to storage that is protected from raid damage ([App Store](https://apps.apple.com/us/app/last-island-of-survival/id1463021419)). The cited Sensor Tower snapshot covers **Israel only**, not the US: in Q2 2024 LIOS revenue there peaked at about $1.7K in mid-June, with about 1K active users in April falling to 812 by end of June. It gives no US or global figure, and I found no reliable US/global revenue estimate ([Sensor Tower](https://sensortower.com/blog/2024-q2-unified-top-5-survival%20games-revenue-il-60144bdd241bc16eb8136791)). I did not find detailed official raid rules. |
| **Once Human: RaidZone** (Starry Studio/NetEase) | Early access from 21 May 2025, global launch 29 Jul 2025. The main game launched on PC in Jul 2024 with over 230K concurrent players on Steam, on mobile in Apr 2025, and on PS5 and Xbox Series in Aug 2026 ([Wikipedia](https://en.wikipedia.org/wiki/Once_Human_(video_game))). | A separate hardcore PvP mode. Players can attack "anytime and anywhere". Territory structures are immune from **00:00 to 12:00 server time** (May 2025 FAQ). Offline characters stay in the world. Up to 3 territories each. Servers reset every **14 days**. All stored loot can be taken if the territory is breached. Gear from the main game cannot be brought in. | It walls PvP raiding off from the PvE main game, so PvE players are never forced into it. The fixed daily immunity resembles Rust's later raid windows. In the main game, Steam users report that on PvP servers a base generally cannot be raided unless its owner is online and PvP-flagged or is running a "purification" (a timed horde event); always-PvP "Frontier" regions are the main source of PvP. The thread gives no weekly event count ([Steam thread](https://steamcommunity.com/app/2139460/discussions/0/4330853975918964404)). A 2026 report of Casual/Standard/Hardcore server labels is unverified ([pulse.bot](https://www.pulse.bot/gaming/news/once-humans-pvp-mode-will-get-casual-and-hardcore-mode-plus-new-enemies-and-items-a8d7fb65-b7e6-4ea0-a42b-dd01d338a258/)). |
| **Undawn** (LightSpeed/Level Infinite) | Launched 15 Jun 2023. Reuters (Mar 2024) said it "flopped", with about $287K monthly revenue according to AppMagic ([Wikipedia](https://en.wikipedia.org/wiki/Undawn)). I could not verify whether it is still running. | Clan "camps" with shared bases ([BlueStacks](https://www.bluestacks.com/ar/blog/game-guides/undawn/udw-game-preview-ar.html)). **No raid mechanics found.** | **Inference:** a big budget and a celebrity (Will Smith) could not save a survival MMO without a compelling conflict loop. |
| **Earth: Revival** | **Not researched.** The search budget ran out, and the official domain I tried is parked. | Unknown | Gap. |

**Inference: what worked across mobile adaptations**
1. **Separate modes instead of one compromise.** Rust Mobile, Once Human and LIOS all give PvE or protected players a home and keep raiding where it is wanted.
2. **Time-boxed vulnerability.** Daily windows (Rust Softcore, RaidZone) and short seasons of 14 days match how mobile players actually play.
3. **Instanced, guaranteed fights.** Rust Mobile's Territory Clash shows that "raiding as a highlight" can be guaranteed on a schedule instead of hoping two groups collide.
4. **What fails:** selling power, especially protection or explosives; storage that raids cannot touch, which makes raids pointless; and unrestricted 24/7 offline raiding on mobile, where players cannot be online all the time.

---

## 6. Design principles: raiding that is fun for attackers, fair for defenders, and happens often

1. **A raid should be a fight, not a robbery.** Design so that most raids happen while defenders can respond. Use windows, push alerts and breach times long enough for someone to answer the alert.
2. **Breaching costs scarce resources the attacker has to commit.** The defender's build tier sets the price, using a clear HP ladder like Rust's 1:2:4:8. Raiders must spend something they gathered under risk, like sulfur in Rust.
3. **Defenders get an advantage, but not immunity.** Turrets, peeks, traps and layered walls should make attacking cost more than defending, without making bases impossible to crack.
4. **Losing a raid hurts but does not end your season.** Use partial loot loss (Rust Softcore's 50%), repairable debris, and a short no-seal period (48 h).
5. **Bigger bases and bigger groups pay more.** Upkeep should grow with base size and with group size (Rust's upkeep group scaling), and doors should cost extra (Softcore's ~90% door upkeep), so the big bases with the most loot stay raidable.
6. **Make targets findable and tempting.** Raids happen when attackers can find a worthwhile target nearby. Loud explosions, visible bases and noise from production all help.
7. **Resets give a reason to cash out.** With wipes, the endgame becomes a big raid instead of hoarding.
8. **Close exploits that bypass the rules.** For example, require bases to be aged before protection applies (Rust's 1-hour TC rule), and count recent de-authorizations toward group size.
9. **Treat anti-cheat as part of raid design.** ESP and wallhacks break raiding first, because they reveal where loot is.

---

## Design implications for our game

These are my own opinionated recommendations, built on the findings above.

1. **Use time windows, not offline immunity, as the default PvP ruleset.** Copy and improve Rust Softcore's 2026 design:
   - A daily **raid window of about 2-3 hours in the server's prime time**, announced in-game with a countdown.
   - Walls and doors cannot be damaged outside the window. Loose loot and unsecured outposts stay vulnerable.
   - A base core must be at least 1 hour old before it gives protection.
   - Also run a **"Hardcore 24/7"** server type for DayZ and Rust veterans, and a **PvE/protected** type for builders.

   This fixes the developer's LDoE complaint directly: raids concentrate into a predictable evening "raid hour" when both sides are online.
2. **Ship a raid alarm in version 1.** When the first structure takes damage, push a notification to every authorized member, with the location and the attackers' squad size. Make breaching take long enough to answer the alert: armed charges with fuse timers, layered walls, and a minimum breach time per tier of about 5-15 minutes. Rust only added this through a companion app. For us it should be built in.
3. **Make one scarce resource the raid currency.** Pick a contested resource ("chemicals" or "black powder", our equivalent of sulfur) that comes mainly from dangerous zones: zombie hotspots, military POIs, PvP areas. Every explosive costs it, priced on a published HP ladder (wood 1 : stone 2 : metal 4 : reinforced 8). Players should be able to read a base's raid cost from the outside.
4. **Losses hurt but are survivable.** Default to Rust Softcore rules:
   - Breached storage drops 50% and keeps 50% for the owner.
   - Debris can be repaired.
   - For 48 hours raiders cannot seal the base or take over its core.

   Allow at most one **small** protected stash per player, enough for a respawn kit. LIOS reviews show that raid-proof storage kills the point of raiding. **Never sell protection, shields, extra stash space or explosives.**
5. **Scale costs with group size from day one.** Upkeep should rise with the number of authorized members, as in Rust's September 2026 model (no tax for 4 players, then +2% each, then +4% each). Doors should carry extra upkeep. Offer **Solo/Duo**, **Squad (4)** and **Open** server types, and cap clans per server.
6. **Make sure raids actually happen** (the LDoE failure):
   - Keep the shared persistent map dense enough that bases are near each other.
   - Show **large or production-heavy bases on the map** (noise and smoke from generators and workbenches).
   - Add a **"raid board"** that lists nearby bases within your power band.
   - Run short **seasons of 2-4 weeks** so groups reach the raiding stage within a season.
   - Hold end-of-season "purge" events.
   - Pay defenders for repelling raids: dead attackers drop their charges and gear.
7. **Add an instanced siege mode for short mobile sessions.** Model it on Rust Mobile's Territory Clash: a 15-minute 4v6 attack-versus-defense match on a player-built base layout or a curated one. It guarantees the raid highlight every session, teaches raid tactics, and works as an on-ramp for new players before persistent servers.
8. **Use zombies as the third party in every raid.** Explosions draw hordes, and defenses also have to handle zombies. This is how we differ from Rust: zombies make loud raids risky for attackers, and they keep turrets and walls useful outside the raid window through PvE horde nights.
9. **Borrow DayZ's encounter tension for the open world, not for bases.** Use proximity voice, no nameplates by default, full-loot death outside your base, and sparse high-value loot. Keep base raiding scheduled and readable, and keep roaming PvP unpredictable.
10. **Build anti-cheat and server authority before raiding launches.** Make it server-authoritative, send no stash positions to clients, and cull players server-side. Plan for constant ban waves: Rust banned more than 338K accounts in 2025 alone.
11. **Do the hands-on homework.** The user asked whether we should play these games ourselves. That is worth it here. Before locking these numbers, play a vanilla and a Softcore Rust wipe, including one raid-window evening, plus one DayZ week on official servers. Time how long breaches take and how long an alert takes to bring defenders back. The pacing numbers above are hypotheses to test, not facts.

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. About 30 claims were re-checked by fetching the cited pages and, where possible, a second source. The shared web-search budget was already used up when this check ran, so corroboration came from direct page fetches (SteamCharts, the Facepunch wiki, the publishers' own posts) rather than fresh searches.*

**Confirmed against the source (no change needed):**
- Softcore raid windows (2 Jul 2026): 6-9 PM by default in server-local time, Softcore only, deployables and an unprotected TC still attackable, TC must be 1 h old, ConVars for admins, and the "casual players" quote. Clans have roles, clan chat and clan tables, with no member cap stated.
- Upkeep group scaling (3 Sep 2026): first 4 free, next 6 at +2% each, then +4% each, capped at 300%. The "bypass most difficulty mechanics" quote and the Monument Blockers are also confirmed.
- Soft Refresh (3 Apr 2025): 50% of destroyed container contents drop, 48 h of TC authorization, 25% lower PvP bullet damage, and the "encourage more raiding" quote.
- Sulfur costs (C4 2,200, rocket 1,400, satchel 480, explosive 5.56 at 25) and the whole raid table, including the armored door at 3 C4 / 5 rockets / 15 satchels, which xgamingserver's chart also gives.
- The Tool Cupboard wiki: 1,000 wood, decay times of 1/3/5/8/12 h, decay from the outside in, and 24 h of grief protection.
- Softcore launch (4 Feb 2021): 10 servers, team cap of 4 that counts TC and turret authorizations, 50% reclaim, and safe-zone spawns.
- Official Hardcore servers shut down in November 2023, and the rule list is correct.
- The forced wipe falls on the first Thursday of each month.
- Rust+ Smart Alarms (4 Jun 2020).
- Mortar and Tin Can Alarm (7 May 2026).
- The bunker reply from /u/Alistair_Mc.
- From "Surviving 12 Years": 259,646 peak, 5.8M players, 700M hours, 338K bans (296K permanent), 16M reports, under 7 h to catch cheaters, the Premium server rule ($15+ inventory), HackerOne bug bounty, server-side culling, the third-party anti-cheat layer, and the 2026 global Rust Mobile release plan.
- The Dean Hall quote about permadeath giving "a sense of value".
- DayZ 1.29 (Apr 2026, with a wipe and more random spawns).
- The fence figures (2 logs, 18 planks, 36 nails; 45-day lifespan).
- DayZed allows raiding around the clock, and the flag does not stop raids.
- All guided.news DayZ raid numbers.
- The Rust Mobile modes, including Territory Clash (15 min, 4v6), 1M+ pre-registrations (Dec 2025), the HK/Macao Android beta on 9 Jul 2026, and the second beta from 23 Aug to 30 Sep 2026.
- Once Human RaidZone: 00:00-12:00 immunity, 3 territories, 14-day resets, all stored loot can be taken, account, device and IP bans, early access on 21 May 2025, global launch on 29 Jul 2025, and console release on 25 Aug 2026.
- The LIOS App Store listing: 3.9 stars from 12K ratings, version 2.45.0, IAPs from $0.99 to $99.99.
- Undawn: Reuters "flopped" and about $287K a month.

**Corrected:**
1. **Sensor Tower LIOS revenue (Section 5): wrong.** The cited page covers Israel, not the US. LIOS peaked at about **$1.7K** in mid-June 2024 there, not "$496K in the US". The $496K figure does not appear on the page. Rewritten.
2. **Soft-side raiding (Section 2.2): wrong.** The cited xgamingserver guide says the opposite: explosives do the same damage from either side. GameServerKings agrees, saying the hard side gets no extra explosion protection. Only melee, bullets and beancans benefit from the soft side. Rewritten.
3. **Official group limits (Section 2.4): wrong.** The cited Rustalyzer page lists the official Facepunch 4 server with a **group limit of 8**, not "no group limit". Rewritten. I did not confirm that every official server has the cap.
4. **Rust June 2026 player figures (Section 1): unreachable source, conflicting data.** SteamPulse returned an error. SteamCharts gives a June 2026 average of about 104K and a monthly peak of about **219K**, not 145K. Replaced with the SteamCharts figures, and added the Jan 2025 date for the all-time peak from SteamCharts.
5. **Dean Hall "saved to a database" (Section 3.1): not in the cited source. Removed.** The Game Developer interview (May 2013) does not say this. It was replaced with the interview's actual persistence point.
6. **Once Human main-game PvP (Section 5): misstated.** The Steam thread says bases generally can't be raided unless the owner is online and PvP-flagged or is running a purification event. It gives no "few a week" count. Rewritten.
7. **Door upkeep (TL;DR #3):** the post says "door upkeep around 90%, compared to 30% in vanilla" for an average large base and does not say "of build cost". Wording softened.
8. **Turret Workshop skins (Section 2.3):** the Auto Turret was named the June 2026 skinnable item, with submissions opening on 11 June. Turrets were not already "open for skins". Reworded.
9. **Blueprint wipes (Section 2.4):** these are forced when Facepunch changes the blueprint or item system, with no fixed cadence, and most servers wipe blueprints on force-wipe day by convention. Reworded.
10. **Rust Mobile "beginner-friendly" (Section 4):** the source says "new-player-friendly features". The quote is fixed.
11. **Pocket Gamer citation date (TL;DR #7):** the article is from 21 Nov 2025, about the Dec 2025 beta.
12. **LIOS "Doomsday Frenzy":** this was added in version 2.27.0 (Jul 2024) and is not recent. The offline-raid complaint is softened to match the two reviews actually seen.
13. **DayZ record (Section 3.1):** now confirmed through SteamCharts: 78,739 in Oct 2024, with no higher month through 2026.

**Marked (unverified):**
- Rust Mobile "3M+ pre-registrations". No checked source gives this figure.
- Rust Mobile raid notifications (Deltia's page could not be fetched).
- Rust Mobile still in beta as of Nov 2026. No global launch was found, but nothing after the second beta could be searched.
- The Dean Hall PC Gamer quotes ("go all the way", "upsets customers"), because the article body could not be retrieved.
- The PC Gamer "Pivot or Die" complaint that solo players are stuck at tier 1-2 workbenches. Only the headline could be retrieved.
- Already flagged in the original and still unverified: the Rust Mobile China launch (pulse.bot unreachable), the Once Human Casual/Hardcore labels, and Undawn's current service status.

**Overall reliability: medium.** The core Rust mechanics and the 2025-2026 Facepunch devblog claims that drive the design recommendations hold up well. Three cited figures were wrong or reversed: the Sensor Tower revenue, the soft-side explosives and the official group limit. One quote was attributed to a source that does not contain it. So any business number (revenue, pre-registrations, CCU) here should be re-checked before use.

---

## Sources

- [Facepunch, "Common Ground" (raid windows, clans), 2 Jul 2026](https://rust.facepunch.com/news/common-ground)
- [Facepunch, "Breach and Clear" (upkeep group scaling, monument blockers), 3 Sep 2026](https://rust.facepunch.com/news/breach-and-clear)
- [Facepunch, "Upgrade hard, raid harder" (mortar, tin can alarm), 7 May 2026](https://rust.facepunch.com/news/upgrade-hard-raid-harder)
- [Facepunch, "Built Different", 4 Jun 2026](https://rust.facepunch.com/news/built-different)
- [Facepunch news index](https://rust.facepunch.com/news)
- [Facepunch, "Soft Refresh", 3 Apr 2025](https://rust.facepunch.com/blog/soft-refresh)
- [Facepunch, Softcore gamemode update, 4 Feb 2021](https://rust.facepunch.com/blog/softcore-gamemode-update)
- [Facepunch, "Surviving 12 Years", 1 Jan 2026](https://rust.facepunch.com/news/surviving-12-years)
- [Facepunch, Companion app update (Rust+), 4 Jun 2020](https://rust.facepunch.com/blog/companion-app-update)
- [Facepunch Rust wiki, Tool Cupboard](https://wiki.facepunch.com/rust/the_tool_cupboard)
- [Facepunch Rust wiki, Server Gamemodes](https://wiki.facepunch.com/rust/Server-Gamemodes)
- [devtrackers.gg, Facepunch dev reply on bunkers (2024)](https://devtrackers.gg/rust/p/da080db2-open-letter-to-facepunch-if-you-don-t-like-bunkers-you-should-nerf-offline-raiding)
- [GameServerKings, Rust Raid Chart (2026)](https://www.gameserverkings.com/knowledge-base/rust/rust-raid-chart/)
- [GameServerKings, Wipe day guide](https://www.gameserverkings.com/knowledge-base/rust/wipe-day-guide/)
- [GameSpot, Rust force wipes explained](https://www.gamespot.com/articles/rust-force-wipes-schedule-explained/1100-6505244/)
- [xgamingserver, Rust raid cost chart](https://xgamingserver.com/blog/rust-raid-cost-chart-how-much-c4-rockets/)
- [xgamingserver, Rust raiding guide](https://xgamingserver.com/blog/rust-raiding-guide/)
- [xgamingserver, Rust base defense](https://xgamingserver.com/blog/rust-base-defense-turrets-traps/)
- [Supercraft, Rust raiding guide](https://supercraft.host/wiki/rust/raiding-guide)
- [Physgun, Rust turret setup](https://physgun.com/blog/game-hosting/rust/how-to-setup-turrets-in-rust/)
- [Physgun, Rust raid alarm](https://physgun.com/blog/game-hosting/rust/how-to-set-up-a-raid-alarm-in-rust/)
- [IFTTT Rust Smart Alarm applet](https://ifttt.com/applets/yFAixSZg-get-a-call-when-a-rust-smart-alarm-is-triggered-with-raid)
- [space-node, Rust server admin guidelines (Mar 2026)](https://space-node.net/blog/rust-server-admin-guidelines-2026)
- [Rustalyzer, Facepunch 4 listing](https://www.rustalyzer.com/server/13066791)
- [Lone.design, Offline Raid Limiter plugin](https://lone.design/product/offline-raid-limiter)
- [Codefling, Raid Time Protection plugin](https://codefling.com/plugins/raid-time-protection)
- [Wikipedia, Rust (video game)](https://en.wikipedia.org/wiki/Rust_(video_game))
- [SteamPulse, Rust stats](https://www.steampulse.org/game/252490) (unreachable at fact-check)
- [SteamCharts, Rust](https://steamcharts.com/app/252490)
- [SteamCharts, DayZ](https://steamcharts.com/app/221100)
- [PC Gamer, Rust "Pivot or Die" and solo players](https://www.pcgamer.com/games/survival-crafting/rusts-pivot-or-die-update-was-meant-to-shake-up-the-meta-but-its-a-nightmare-for-solo-survivors-that-leaves-me-no-choice-but-to-die)
- [Heterotopias zine, "Cyclical Apocalypse: Rust"](https://heterotopiaszine.com/2017/06/20/cyclical-apocalypse-rust)
- [Reddit r/playrust snippet (via mirror, search snippet only)](https://axebps-redlib.hf.space/r/playrust/comments/1jqketp/and_no_one_is_happy)
- [Reddit r/playrust zerg thread (search snippet only)](https://redlib.hbubli.cc/r/playrust/comments/1ji2ruc/how_to_easily_nerf_zergs_and_improve_quality_of)
- [Game Developer, Dean Hall on DayZ development](https://www.gamedeveloper.com/design/dean-hall-discusses-i-dayz-i-s-development-process)
- [PC Gamer, Dean Hall DayZ interview](https://www.pcgamer.com/day-z-interview-how-zombies-arma-2-created-gamings-best-story-machine)
- [PC Gamer, DayZ concurrent record (Oct 2024)](https://pcgamer.com/games/survival-crafting/after-more-than-10-years-on-steam-dayz-sets-another-new-concurrent-player-record/)
- [Shacknews, DayZ 1.29 patch notes (Apr 2026)](https://www.shacknews.com/article/148621/dayz-update-1-29-patch-notes)
- [DayZ wiki.gg, Base Building](https://dayz.wiki.gg/wiki/Base_Building)
- [DayZ wiki.gg, Fence](https://dayz.wiki.gg/wiki/Fence)
- [guided.news, DayZ raid guide (Jan 2024)](https://guided.news/en/guides/dayz-ultimative-raid-guide-explosives-firearms-or-fists/)
- [xgamingserver, DayZ raiding guide (Jun 2026)](https://xgamingserver.com/blog/dayz-raiding-guide-how-to-raid-bases/)
- [DayZed wiki, territory flags and codelocks](https://dayzed.gg/wiki/features/codelocks)
- [Supercraft, DayZ fence and watchtower](https://supercraft.host/wiki/dayz/base-building-fence-watchtower/)
- [DayZ Modding Wiki, persistence](https://stardz-team.github.io/DayZ-Modding-Wiki/en/09-server-admin/07-persistence)
- [Pocket Gamer, Rust Mobile first closed beta](https://www.pocketgamer.com/rust-mobile/first-closed-beta-test-on-mobile)
- [Pocket Gamer, Rust Mobile 1M pre-registrations](https://www.pocketgamer.com/rust-mobile/1-million-pre-registrations)
- [ACN Newswire, Rust Mobile reveal (Aug 2025)](https://www.acnnewswire.com/press-release/english/101604/)
- [GamingonPhone, Rust Mobile HK/Macao open beta (Jul 2026)](https://gamingonphone.com/news/rust-mobile-is-bringing-its-acclaimed-survival-action-to-select-regions-on-android-with-a-regional-open-beta-test-on-july-9-2026/)
- [Final Weapon, Rust Mobile second beta (Jul 2026)](https://finalweapon.net/2026/07/31/rust-mobile-second-beta-test/)
- [Deltia's Gaming, Rust Mobile overview (search snippet only)](https://deltiasgaming.com/?p=303491)
- [pulse.bot, Rust Mobile China launch claim (unverified)](https://www.pulse.bot/gaming/news/rust-mobile-eyes-china-launch-this-july-2026-across-pc-and-mobile-638babd0-5e19-4445-b863-63629981899f/)
- [App Store, Last Island of Survival](https://apps.apple.com/us/app/last-island-of-survival/id1463021419)
- [Sensor Tower, Q2 2024 survival games snapshot](https://sensortower.com/blog/2024-q2-unified-top-5-survival%20games-revenue-il-60144bdd241bc16eb8136791)
- [Once Human, RaidZone FAQ (May 2025)](https://www.oncehuman.game/news/update/20250524/40780_1236481.html)
- [Once Human, RaidZone launch (Jul 2025)](https://www.oncehuman.game/news/wiki/20250814/40782_1250063.html)
- [Steam Community, Once Human PvP territory discussion](https://steamcommunity.com/app/2139460/discussions/0/4330853975918964404)
- [pulse.bot, Once Human RaidZone modes report (unverified)](https://www.pulse.bot/gaming/news/once-humans-pvp-mode-will-get-casual-and-hardcore-mode-plus-new-enemies-and-items-a8d7fb65-b7e6-4ea0-a42b-dd01d338a258/)
- [Wikipedia, Once Human](https://en.wikipedia.org/wiki/Once_Human_(video_game))
- [Wikipedia, Undawn](https://en.wikipedia.org/wiki/Undawn)
- [BlueStacks, Undawn preview](https://www.bluestacks.com/ar/blog/game-guides/undawn/udw-game-preview-ar.html)
