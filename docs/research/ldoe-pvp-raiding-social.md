# Last Day on Earth: Survival: Multiplayer, PvP and Raiding Deep Dive

*Research date: 2026-11-07. LDoE is at iOS version 1.53.2 (released 2026-11-06). The US App Store rating is 4.56 from about 103.6K ratings ([iTunes lookup](https://itunes.apple.com/lookup?id=1241932094)). This live game changes with each 21-day season, so anything dated before 2025 is flagged as possibly outdated.*

**Access notes.**
- **Kefir's help center and App Store data were read directly.** That covers the official FAQ (Kefir Helpshift), App Store listings, version history, and US customer-review feeds for LDoE and Frostborn.
- **The Fandom wiki was not read directly.** Both wiki domains returned HTTP 402 to my fetches. Wiki facts here come from search-engine summaries of those pages, or from our sibling teardown [ldoe-base-building.md](ldoe-base-building.md), which read the wiki through its API.
- **Reddit (www and old) was blocked to the fetch tool.** Reddit content below comes only from search-result snippets.
- **YouTube pages would not render.** No titles, view counts or transcripts were retrievable.
- **The shared web-search budget ran out partway through.** Later sources were reached by direct URL only. See Gaps.

---

## TL;DR: the decision-relevant findings

1. **There is no live defender in an LDoE raid, ever.** In the single-player world, you raid a base that is empty of people. Your own base can only be hit by AI "raiders" during a timer you triggered yourself. Real-time PvP exists only in the Crater, a separate mode with a second character, and there it is a small 4-player arena, not base raiding.
2. **Being raided is opt-in by design.** Your base becomes attackable only for 24 hours after *you* make a deal with the Raiders. Players on Reddit say plainly that nobody attacks you unprovoked. That is the mechanical root of "nobody comes to raid you".
3. **Raiding is heavily gated and full of friction.**
   - You need level 150 just to unlock it.
   - Each target costs a five-task quest chain, and coins can skip the tasks.
   - Each target expires after 8 hours.
   - A noise meter caps how long you can loot.
   - You may leave and return only once.
4. **The defender's top tier is effectively immune.** The fan wiki lists L4/L5 walls as unbreachable by players, and shop-bought specialized storage as unraidable. So late-game raids pick at the soft outer layer. (L4 immunity is corroborated by a 2024 guide. L5 and storage immunity are wiki-only and unverified here.)
5. **Monetization touches raiding at several points.** Coins skip raider tasks and clear the "threat" timer (the timer clear is wiki-only, unverified). Since Sept 2026, coins also let you resurrect and keep your loot. Reviewers in 2025-26 still call the game pay-to-win, and the Crater "pay to play".
6. **The Oct 2026 reviews show that raiding is many players' favorite activity**, and that recent task changes made it worse. "The only fun ingame was raiding and you ruined that" (App Store, Oct 2026).
7. **Kefir's own real-PvP experiment, Frostborn (2020), shows the opposite failure mode.**
   - Players report forced raids, being raided while offline, and mismatched raid matchmaking.
   - They report griefing in PvP zones, *paid* protection orbs, and thinning servers.
   - LDoE's asynchronous design looks like a deliberate retreat from those problems.

---

## 1. Architecture: two separate worlds

| Layer | Who is there | Base raiding? | PvP? | Items |
|---|---|---|---|---|
| **Home world** (single-player map, Home base, bunkers, regions) | Only you. Players cannot co-op in the same single-player location, even on the same server ([FAQ 805](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/805-how-can-i-find-out-the-name-of-my-server-or-change-the-server/)). | Yes, asynchronous, from level 150 | No real players. AI "survivors" and NPC Raiders only. | Your main character's inventory |
| **Crater** (multiplayer city hub plus zones) | Real players, cross-server ([FAQ 805](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/805-how-can-i-find-out-the-name-of-my-server-or-change-the-server/)) | No home-base raiding found | Yes. A PvP battle zone of up to 4 players per map. | Separate **second character**. Items may not leave the Crater ([FAQ 267](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/267-how-do-i-bring-items-out-of-crater/)). |

- **Getting into the Crater.** Reach level 100 (raised from 30), complete a special quest, then create a second character at a "convoy" event on the global map ([FAQ 126](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/126-i-want-to-play-with-other-survivors-what-should-i-do/), [FAQ 852](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/852-i-m-level-30-but-i-have-no-convoy-event-no-access-to-the-crater-1737185542/)).
- **Kefir's stated rationale for the higher gate** is only that "only survivors who are well acquainted with the game come to the Crater" ([FAQ 852](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/852-i-m-level-30-but-i-have-no-convoy-event-no-access-to-the-crater-1737185542/)).
- **Servers.** The game auto-assigns the "nearest and the most optimal" server. The FAQ describes no way for players to choose or change it ([FAQ 805](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/805-how-can-i-find-out-the-name-of-my-server-or-change-the-server/)). No public list of regions or shards was found.

**Inference:** LDoE is a single-player survival game with an online persistence layer. Multiplayer is bolted on as a walled-off second economy. Its signature raiding feature never puts two humans in the same place.

---

## 2. Home-world raiding: how it actually works

### 2.1 History (dates are approximate, and partly from secondary sources)

- **v1.5.3, Aug 2017.** A hatchet let you break into other bases on the map. Before that, you could loot only outside objects such as furnaces and racks ([PwrDown, updated Feb 2022](https://www.pwrdown.com/gaming/last-day-on-earth/last-day-earth-base-looting-raiding-lde/)).
- **Beta v1.7.** The current Raider/CB-Radio raiding system arrived (Fandom [Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System), via search summary) (unverified).
- **Beta v1.17.2.** Raiding was locked to level 150 (same source; version number unverified). A Jan 2024 guide dates this to "after season 10" ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)).

### 2.2 Getting a target

1. **Reach level 150** and build a **CB Radio**. Tuning it reaches the Raiders' leader, who sends his thugs to your base "in a matter of minutes", and you must deal with them (the FAQ gives no head count) ([FAQ 104](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/104-how-do-i-summon-raiders/), [FAQ 364](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/364-i-don-t-get-raiders-raiders-stopped-showing-up/)).
2. **Complete five Raider tasks.**
   - Reddit users describe three kinds of task: combat (kill a special zombie or boss), crafting, and timed or trade tasks ([r/LastDayonEarthGame "Raiders", Mar 2025, via search snippet](https://www.reddit.com/r/LastDayonEarthGame/comments/1j0s61l/raiders/)).
   - Tasks can be skipped with coins ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)). The wiki lists 45-125 coins per task ([ldoe-base-building.md](ldoe-base-building.md)) (price unverified).
   - Refusing a task resets progress, and calling the Raiders again gives the same tasks ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)).
3. **Receive coordinates.** The Raiders give the coordinates of "a nearby survivor's base" in exchange for a share of your loot. The base appears on the global map and **disappears 8 hours later, visited or not** ([FAQ 736](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/736-another-player-s-base-disappeared-during-a-raid)).

The target is not chosen by the player. There is no list to browse, no scouting from afar, and no way to pick a rich target.

### 2.3 The raid session (a PvE puzzle against zombies, not a fight)

- **Noise meter.**
  - Breaking walls and crates, riding your chopper, and crafting from blueprints all add noise. So does re-entering the base ([FAQ 736](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/736-another-player-s-base-disappeared-during-a-raid), [FAQ 98](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/98-why-did-zombies-arrive-while-i-was-raiding-a-base/)).
  - Zombie waves spawn at roughly 20/50/70 noise according to GamesKeys, or about 24/46/72 according to the wiki.
  - At 100, "The Big One" spawns (wiki: 1,000 HP, 300 armour, unverified) ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/), [ldoe-base-building.md](ldoe-base-building.md)).
- **Leaving and dying.**
  - You may leave and return **once**, and only if noise was not too high. Crafting during the raid forfeits the return.
  - Disconnects, switching apps and incoming calls all count as leaving.
  - If you die quietly you can come back. A second death loses the base and everything you brought and looted ([FAQ 736](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/736-another-player-s-base-disappeared-during-a-raid)).
- **Breaching works like lock-and-key, by tier.**
  - L1 takes a Hatchet, L2 an Iron Hatchet, and L3 a C-4.
  - L4 "cannot be damaged until the Metal Cutter is added" (wiki). The 2024 GamesKeys guide instead says L4 cannot be destroyed "since metal cutters are no longer in the game".
  - L5 cannot be damaged at all ([ldoe-base-building.md](ldoe-base-building.md), unverified; the 2024 [GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/) guide agrees that L4 was unbreakable).
  - Kefir's Halloween 2026 FAQ says a Metal Cutter "may come in handy" at Cult's Camps ([section 41](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/41-seasons-events-and-premium-access-1694691630/), [FAQ 1325](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1325-what-should-i-bring-to-a-cult-s-camp/)). Whether it is new in 1.53, or can breach L4 walls in home-world raids, is unverified. The 1.53 patch notes do not name it.
- **What you can take.** You can take anything in ordinary containers and stations. A 2017 example lists chests, furnace bars, cooked meat, hides and gold watches ([PwrDown](https://www.pwrdown.com/gaming/last-day-on-earth/last-day-earth-base-looting-raiding-lde/)). What you cannot take:
  - Shop-type specialized storage (Warehouse, Ore Storage and similar), which cannot be raided ([ldoe-base-building.md](ldoe-base-building.md)).
  - More than one backpack's worth per trip. Combined with the single return, this caps the haul. One Sept 2026 reviewer contrasts this with how fully their own base could be emptied ([App Store reviews](https://itunes.apple.com/us/rss/customerreviews/page=3/id=1241932094/sortby=mostrecent/json)).
- **Defenses you meet.**
  - Walls, plus spikes, barbed wire, bear traps and land mines aimed at zombies.
  - Spike traps are "not very effective" against raiding survivors (Fandom [Spike Trap](https://last-day-on-earth-survival.fandom.com/wiki/Spike_Trap), via search summary).
  - The old fuel-powered base turret was removed in 1.51.1 (Aug 2026) and turned into a deployable *Portable Turret*. The 1.51.1 notes confirm only that "portable turrets" were added. The removal and conversion of the base turret are wiki-only and unverified ([App Store version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history), [ldoe-base-building.md](ldoe-base-building.md)).
  - **No human, NPC guard or turret actively defends a raided base.** The pressure comes from zombies drawn by noise.

### 2.4 Paying the Raiders, threat timers and revenge

- **The Raiders' cut.**
  - After the raid you hand the Raiders a share. The wiki grades it in tiers from under 25% to over 100% (Fandom [Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System), via search summary) (unverified).
  - Short-change them and they may "pay a visit to your base" ([FAQ 99](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/99-why-was-my-home-base-raided/), which gives no timing). GamesKeys and the wiki say they come back about 2 hours later ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)).
  - Per the wiki, their SWAT trio can blow at most 4 stone walls and cannot touch L4/L5 ([ldoe-base-building.md](ldoe-base-building.md)) (unverified).
- **Threat window.** Making a Raider deal opens your base to attack "by other survivors" for 24 hours. Taking revenge or raiding again raises the odds and extends the window ([FAQ 106](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/106-when-can-my-base-be-attacked-by-other-survivors/)).
  - A skull icon with a timer shows it ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)).
  - An attack "attempt" may steal items, damage walls, or do nothing. The timer clears either way ([FAQ 929](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/929-why-did-the-threat-timer-disappear/)).
  - Coins can clear the threat timer (wiki, about 5.75 min per coin, via [ldoe-base-building.md](ldoe-base-building.md)) (unverified; FAQ 929 does not mention coins).
  - Attacks happen while you are offline or away from your base ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)).
- **Revenge.**
  - If the attacker stole enough value, they leave **footprints** on the map that lead to their base. That base stays up for at most 8 hours. Small thefts leave no trail ([FAQ 735](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/735-another-player-left-no-trace-after-attacking-my-base/)).
  - Revenge raids give the Raiders no cut (Fandom, via search summary) (unverified).
  - Revenge raids are not guaranteed: "Not all survivors are ready to revenge" ([FAQ 110](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/110-why-do-i-not-get-revenge-raided/)).
  - The community meta is a **bait chest** outside the walls, so that AI raiders take something and leave footprints ([GamesKeys](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/), [ldoe-base-building.md](ldoe-base-building.md)).

### 2.5 Are the targets real players? (official wording vs community)

- **Kefir's FAQ language implies real people.**
  - It refers to "a nearby survivor's base".
  - One article is titled "Another player left no trace after attacking my base".
  - Making a deal with the Raiders means "disclosing the coordinates to other survivors" ([FAQ 736](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/736-another-player-s-base-disappeared-during-a-raid), [FAQ 735](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/735-another-player-left-no-trace-after-attacking-my-base/), [FAQ 99](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/99-why-was-my-home-base-raided/)).
- **The community and the wiki say otherwise.**
  - The fan wiki states that outside the Crater you raid AI bases and are raided by AI ([ldoe-base-building.md](ldoe-base-building.md)).
  - Fandom forum posts describe raids as hitting a *copy* of a base, with real losses coming only from AI raids ("it's a bot that raids back") (Fandom forum ["Protecting the stuff"](https://last-day-on-earth-survival.fandom.com/f/p/3100000000000000461), via search summary).
  - App Store reviewers reach the same conclusion. One wrote that "the people/bases, when you join are NPC's" (Apr 2020). Another said the starting raidable bases "are AI bases" and asked for new bases, "AI or actual player" (Feb 2021) ([most-helpful feed](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1241932094/sortby=mosthelpful/json), [p.1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mosthelpful/json)).
- **Inference:** Whatever the back end does, nobody has to be online for any of it. The attacker experiences a frozen, unattended base, and the defender experiences an AI-resolved attack report. Neither side ever meets the other.

### 2.6 NPC "neighbor" bases (the "Player 1234" bases)

- **What they are.** Red-roofed bases on the global map look like player bases, but no AI survivors live there. You can loot them, and nobody raids you back (Fandom [NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base), via search summary).
- **Kefir's framing.** Kefir calls them practice "for your first real raid" that "disappear a few hours after your visit" ([FAQ 325](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/325-where-did-the-neighbors-bases-go/)).
- **How long they last.** The wiki says they vanish 1 hour after a visit since Beta 1.8.1, and 12 hours for older accounts (unverified). That conflicts with the FAQ's "a few hours".
- **Names.** They carry player-style names. Video titles such as "Raid Base Player0001" and "Player5420" appear on an aggregator page of unknown reliability ([avitmarine](https://www.avitmarine.com/last-day-on-earth-raid-player0001.html)).
- **"Player 6728" specifically:** not verified in any source I could reach.
- **Personal items stored in a neighbor's base or a bunker can be stolen by raiders** ([FAQ 107](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/107-why-did-my-items-disappear-from-the-bunker-neighbor-s-base/)).

---

## 3. Crater: the real multiplayer (current, Nov 2026)

### 3.1 City life and economy

- **Distribution Center.** New arrivals get accommodation, a workshop, personal storage and company "in exchange for a little service" ([FAQ 316](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/316-how-to-get-out-of-the-crater-1737185593/)).
- **Rent and the Slums.** Rent comes due periodically. Missing it, or leaving or being kicked from a clan, sends you to the **Slums**. There you have no jobs, no workbenches and cannot join a clan until you earn your way out ([FAQ 319](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/319-slums/), [FAQ 731](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/731-what-happens-if-i-leave-the-clan/)).
- **Business level** gates the Crater's features:
  - PvP needs business level 15 or higher.
  - Renting out your own storage to other players needs level 40 or higher. Renters pay you in **bonds**.
  - Bonds can also be bought in the shop, or earned from some PvP wins ([FAQ 398](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/398-how-to-get-bonds/)).
- **Player trading.**
  - Clan leaders run "sales" from counters stocked by members, with a cooldown of at least one day ([FAQ 449](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/449-i-can-t-start-sale-in-the-crater/)).
  - A 2022 reviewer praised the "multiplayer shopping district" ([most-helpful feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mosthelpful/json)).
  - **No open, free-form player-to-player trade or gifting was found.** A Nov 2026 review asks for gifting between friends ([recent feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostrecent/json)).
- **Death.** Crater residents scavenge your body. It lasts "a minute or so", and recovered items come back with lower durability ([FAQ 298](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/298-my-body-is-missing-in-crater/)).

### 3.2 The PvP battle zone

Source for this section: [PvP: Rules and Overview](https://kefirgames.helpshift.com/a/last-day-on-earth/?s=multiplayer&f=pvp-rules-and-overview&l=en).

| Rule | Detail |
|---|---|
| Access | Business level 15 or higher. Talk to Nat the Fighter. Open only during set time intervals. Gear Score (GS) 120 or higher. |
| Gear Score | The average of all clothing slots plus the weapon slot. Empty slots count as 0 ([FAQ 353](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/353-gear-score-gs/)). |
| Map | Up to **4 players**. Radiation. Bushes for hiding. A central chest opens a couple of minutes in, and the first player to reach it takes it. |
| Matchmaking | **Random**, even for clanmates who queue together ([FAQ 400](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/400-how-do-i-start-pvp-with-my-clanmates-only/)). |
| Rewards | Dog tags, from the chest, player kills and zombies. Trade them to Nat for bonds. |
| Death | You can return to your corpse within minutes, but only if other players were on the map from the start. |

**Inference:** This is a mini extraction arena, not raiding. It is tiny (4 players), separated from your real base, and gated by business level and Gear Score. It does not touch home-world progress.

### 3.3 Clans, co-op, chat

- **Clans.**
  - Joining needs level 100 or higher. Clans are open, request-only or invite-only.
  - After leaving a clan you must wait 24 hours before joining another. Clans cannot be renamed or deleted ([FAQ 184](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/184-how-do-i-join-or-leave-a-clan/)).
  - Roles are Leader, Right Hand, Officer, Member and Recruit. Recruits have no storage access. The FAQ jokes that an absent leader may come back to an emptied clan ([FAQ 366](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/366-clan-roles/)).
  - A clan location in the Crater replaces rent and provides workbenches ([FAQ 320](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/320-clan-location/)).
- **Clan content from 2025-26** ([App Store version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)):
  - 1.43.0 (Dec 2025): "Clans in the Wastelands", with co-op in new locations and co-op-only equipment.
  - 1.44.0 (Feb 2026): the Clan Tournament returns, with clans going down tunnels together.
  - 1.48.0 (Apr 2026): clan rating now comes from recovering fallen operatives in the Wastelands.
  - 1.53.0 (Oct 2026): "Occult Tournament" clan challenge.
  - Tournaments are limited to 5 per day per player ([FAQ 350](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/350-i-have-no-tournaments-i-don-t-have-a-tournament-button/)).
  - **No clan-vs-clan base wars found.** A 2020 reviewer explicitly asked to "battle other clan bases" ([most-helpful p.2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1241932094/sortby=mosthelpful/json)).
- **Co-op groups.** You form groups at the chopper by picking friends or clanmates. At least one member must have developed their Crater business first ([FAQ 269](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/269-how-do-i-invite-people-to-my-group/)).
- **Chat and friends.**
  - Both unlock with the second-character quest after level 100.
  - Names are a nickname plus a 4-digit tag. Nicknames run up to 12 characters and can be changed every 30 days ([FAQ 165](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/165-how-do-i-contact-my-friends/)).
  - A Frostborn review notes that game has no global or alliance chat. I found no equivalent LDoE data on global chat.

### 3.4 Where Kefir is investing instead: PvE "raids" and "defense" (2026)

- **Halloween 2026: Cult's Camps.**
  - A raid on an NPC camp with breaching tools (lockpick, bolt cutter, Metal Cutter) and three safe tiers.
  - You can carry out a crate by chopper.
  - Three camps are on the map at a time, refreshing daily, with **2 hours** to loot after your first visit ([section 41](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/41-seasons-events-and-premium-access-1694691630/), [FAQ 1324](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1324-how-do-cult-s-camps-work/), [FAQ 1329](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1329-how-do-new-coordinates-for-cult-s-camps-work/)). "New Coordinates" to reroll all three camps can be bought from the Scout. Safes award Clan Tournament ranking points ([FAQ 1335](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1335-what-are-safes-used-for/)).
- **Base Defense (Signal Scanning).**
  - You start zombie waves from the radio and defend the radio itself.
  - New defensive structures are Friend, Thorns, Tripwire and Slicer.
  - A "Base's Power" score is computed from the objects you have placed.
  - Walls and structures are **restored after the battle** ([FAQ 1320](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1320-can-my-base-be-destroyed/), [FAQ 1321](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1321-where-can-i-find-new-defensive-structures/), [FAQ 1322](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1322-what-is-base-s-power/)).
- **Other recent additions.** Portable turrets (1.51.1), an ATV turret module (1.49.0), and paying coins to resurrect while keeping your loot (1.52.0, Sept 2026) ([version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)).

**Inference:** Kefir is building the *feel* of raiding and defending in PvE: breach tools, safes, waves and a power score, with no persistent consequences. That is the opposite of the direction a Rust-like raiding game needs.

---

## 4. Diagnosis: why LDoE raiding feels underwhelming

| # | Symptom players report | Evidence | Root cause |
|---|---|---|---|
| 1 | "I never fight a real person in a raid" | 2020 review: "the people/bases, when you join are NPC's". 2021: the starting bases "are AI bases", so add new ones, "AI or actual player". Jul 2026: wishes to "raid people that are online the game" ([feeds](https://itunes.apple.com/us/rss/customerreviews/page=6/id=1241932094/sortby=mostrecent/json)). | The raid is asynchronous, against an unattended snapshot or AI base. |
| 2 | "Nobody ever raids me" | Reddit: you won't be raided unless you start raiding ([thread, Apr 2025, via snippet](https://www.reddit.com/r/LastDayonEarthGame/comments/1jtf67l/help_a_newbie_out/)). Official: the 24 h window opens only after your own Raider deal ([FAQ 106](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/106-when-can-my-base-be-attacked-by-other-survivors/)). | Vulnerability is opt-in, AI-resolved and short, and coins can clear it. |
| 3 | "Raids can't really hurt a good base" | L4/L5 are unbreachable. Specialized storage is unraidable. AI raiders blow at most 4 stone walls ([ldoe-base-building.md](ldoe-base-building.md)). | The top tier is immune, so late-game stakes collapse. |
| 4 | "Too long before I can even raid" | 2020: can't play with others until level 150. 2026: "takes way too long to unlock multiplayer". Oct 2026 Russian review: "Multiplayer from level 100?!" ([p.5](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1241932094/sortby=mostrecent/json), [p.1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostrecent/json), [most-helpful p.2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1241932094/sortby=mosthelpful/json)). | Level gates of 150 for raids and 100 for the Crater. |
| 5 | "The pre-raid grind kills it" | Oct 2026: back-to-back Raider tasks taking "days or even weeks". Sept 2026: "getting the gens for the raiders is very difficult" ([p.1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostrecent/json), [p.3](https://itunes.apple.com/us/rss/customerreviews/page=3/id=1241932094/sortby=mostrecent/json)). | A five-task quest chain per target, skippable with coins. |
| 6 | "My base can be emptied, but I can only carry a backpack" | Sept 2026: "Broken raid mechanics, which allows your base to be fully emptied". 2019: "losing them to a raid was hard to swallow" (unverified; not found in the cited feeds). | Asymmetric attacker caps (noise, one return) versus AI raids on the defender. |
| 7 | "The real PvP is somewhere else, and pay-to-win" | 2024: the Crater is "100% pay to play". Jun 2026: Crater multiplayer is "a very pricey and painful failure", with whales bullying others out of rewards ([most-helpful p.3](https://itunes.apple.com/us/rss/customerreviews/page=3/id=1241932094/sortby=mosthelpful/json), [p.8](https://itunes.apple.com/us/rss/customerreviews/page=8/id=1241932094/sortby=mostrecent/json)). | A separate character and economy. Tiny 4-player maps. Paid gear decides fights. |
| 8 | "It's not even multiplayer" | Jul 2026: the store listing claims you fight other survivors, "but the base game is single player". Several reviewers can't play with a friend ([p.5](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1241932094/sortby=mostrecent/json), [p.9](https://itunes.apple.com/us/rss/customerreviews/page=9/id=1241932094/sortby=mostrecent/json)). | Co-op is barred from single-player locations. |

**Developer statements.** I found no Kefir interview or dev post that explains *why* raids are asynchronous. The only stated framings are these:
- Raids are for "experienced players" who can attack and defend, and bring both reward and risk ([FAQ 364](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/364-i-don-t-get-raiders-raiders-stopped-showing-up/)).
- The Crater is for players "well acquainted with the game" ([FAQ 852](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/852-i-m-level-30-but-i-have-no-convoy-event-no-access-to-the-crater-1737185542/)).

**Inference: likely design reasons.**
1. **Protect monetization.** Losing a paid base to a human feels worse than losing it to a bot.
2. **Mobile session reality.** Players can't defend while offline.
3. **Cost and anti-cheat.** Server-authoritative real-time raids cost more and are harder to keep free of cheats. Cheating complaints persist: a May 2026 review says cheaters go unbanned.
4. **What Frostborn taught them** (section 5).

---

## 5. Kefir's other multiplayer attempts

| Title | Facts | Raiding model and outcome |
|---|---|---|
| **Frostborn: Co-op Survival** (Vikings) | iOS release 2020-11-10. v1.60.19. 4.36★ from 7,243 US ratings ([iTunes lookup](https://itunes.apple.com/lookup?id=1646459921&entity=software)). The description promises co-op base building, raids and random PvP encounters, trading or ambushing other players, and "families" (clans) that defend or betray each other ([App Store](https://apps.apple.com/us/app/frostborn-co-op-survival/id1477237220)). Kefir's site lists "PvP and Raids" as a feature under "About the game" ([kefirgames.com](https://kefirgames.com/games/frostborn)). | Real PvP raiding of player camps. Review themes are summarized below the table. |
| **Sunday City: Life Simulator** | iOS release 2025-11-05. 4.64★ from 8,554 ratings. A social life sim ([lookup](https://itunes.apple.com/lookup?id=1646459921&entity=software)). | Not survival. Shows Kefir moving into social games. |
| **LDoE spin-offs** | None found on Kefir's current games page ([kefirgames.com/games](https://kefirgames.com/games)) or iOS developer listing. | Gap: earlier delisted titles may exist. |

**What Frostborn reviewers say about its raiding** ([most-helpful p.1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1477237220/sortby=mosthelpful/json), [p.2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1477237220/sortby=mosthelpful/json), [recent](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1477237220/sortby=mostrecent/json)). Every point here is a player claim, not confirmed rules.
- **Forced and offline raids.** One reviewer says players "lose everything to a high level group of raiders, even if they're offline" (2021). Another says you get thrown into raids while not online (2022). A 2021 review claims raids are forced every 90 days. Several players ask for an opt-out.
- **Matchmaking failures.**
  - A family of four was matched with inactive solo players whose bases had already been raided (2021).
  - Low-level players were matched with players over level 150 (2021-22).
  - In 2026, solo players still face 4-player teams.
- **Shields and paid protection.**
  - Players report buying "orbs of protection" (2021, 2023).
  - One reviewer complained of getting no shield after being raided (2021).
  - A 2024 reviewer says "defend your base for 20 minutes and you will literally never get raided".
  - In Apr 2026 a reviewer whose family base was raided asked for an opt-out mode where "you can't raid and can't get raided", and wrote "I refuse to pay $$ for protection". This is a request for an option, not a report that bases are already unraidable.
- **Griefing.** High-level players ganked low-level ones and trained monsters onto looters, even in no-PvP areas (2021-23). Some reviewers dropped the game over it.
- **Population.** Players reported few people at their level (2023) and only one working server (May 2026). The May 2026 review ("none of the servers except new heim is working") reads as an outage report, not evidence of population size.
- **Praise.** "PvP is the true endgame" (2023). "the pvp is fantastic" (2024). Co-op with family is a recurring positive.

**Inference:** Frostborn shows how real raiding fails when it is forced, unmatched and has protection for sale. It then calcifies once shields make bases unraidable and the population thins. LDoE shows how fake raiding fails: no stakes and no human. Our game must avoid both.

---

## 6. What a satisfying raiding system would need

This section is analysis, building on the Rust and DayZ findings in [dayz-rust-raiding.md](dayz-rust-raiding.md).

1. **A real human owns every raidable base, and the losses are real but bounded.** No snapshots, no bots standing in for players.
2. **A guaranteed supply of targets.** Bases sit in a shared world with enough density, or a raid board lists real, attackable bases in your power band. Players should never wait days for a target.
3. **The defender can show up.** Push alerts, a breach that takes long enough for a response, and the ability to join from anywhere, as clan reinforcements.
4. **Fair offline rules.** Use raid windows or offline damage reduction, plus a **non-purchasable** post-raid cooldown. Protected loot should be a small fraction, earned and never sold.
5. **The attack costs something.** Explosives are crafted from contested resources, and the cost scales with the defender's tier. No tier is immune.
6. **Revenge and reputation.** The raider is always identified and traceable, with a revenge window, a bounty and a kill feed.
7. **Power-band matchmaking and new-player protection.** No griefing of beginners, and no forced raids before players have the tools to answer.
8. **Clan scale.** Group raids, clan bases, alliances, and scheduled "raid nights" or territory wars that guarantee peak-time fights.
9. **Unlock early.** Give a first taste in the first few hours (for example, an outer-ring PvP zone), not at level 150.
10. **No pay-for-safety.** Never sell shields, timer clears, resurrection with loot kept, or breach tools.

---

## Gaps (what I could not verify)

- **Fandom (HTTP 402), Reddit (blocked) and YouTube (no render) were not readable directly.** Wiki and Reddit content is second-hand via search summaries or the sibling doc. No YouTube titles, view counts or transcripts were gathered.
- **"Player 6728" and the naming scheme of NPC bases** remain unverified.
- **I have not definitively confirmed whether raid targets are copies of real players' bases or generated AI bases.** Kefir's wording and the wiki conflict.
- **Exact loot-loss percentages for the defender** in AI raids, the Raider task pool for 1.52-1.53, and the "new Raider tasks" change of Oct 2026 are not fully documented.
- **Timeline gaps.** I did not find when the Crater launched, the history of earlier multiplayer locations, or when the Gear Score cap and time windows were introduced. Possibly relevant hints: 2020 reviews mention Season 7 NPC Raiders and a police-station advantage.
- **No market data** (Sensor Tower/AppMagic) on LDoE's multiplayer engagement was found. The search budget was exhausted.
- **Frostborn's actual raid rules** (shield length, raid windows, how matchmaking works) come only from player reviews. Kefir's Frostborn help pages weren't reachable.
- **Hands-on testing is impractical.** Verifying any of this first-hand needs a level-150 account for raids and a level-100 account for the Crater, which would mean many hours of play. Watching long-form raid videos, or interviewing a veteran player, is the practical alternative.

---

## Design implications for our game

1. **Make raiding a live, two-sided event, never a bot simulation.** Every raid hits a real player's real base. The defender gets a push alert and a meaningful response window, through breach times and the noise mechanic below. This alone fixes LDoE's top two complaints.
2. **Steal LDoE's best idea, the noise meter, but make it PvPvE.** Breaching draws escalating zombie waves *and* gets announced to nearby players, so it acts as a public beacon. That creates third-party fights and a natural cap on how long a siege can last.
3. **Do not make vulnerability opt-in through a quest chain.** Anyone outside a safe zone or newbie window is raidable under the server's rules. Replace "5 tasks to get one 8-hour target" with discoverable bases in the world, plus a scouting or intel tool.
4. **No immune tiers and no unraidable storage that can be bought.** Top walls should be expensive to breach, never impossible. If we offer a protected stash, make it small, earned in play, and the same for everyone.
5. **Offline protection must be fair and unsellable.** Choose one of these models and test it:
   - Server raid windows, for example 18:00-24:00 local time.
   - Offline damage reduction.
   - A post-raid cooldown that cannot be bought.

   Frostborn's paid "orbs of protection" and LDoE's coin-cleared threat timer are both anti-patterns.
6. **Use matchmaking or regions by power band, and give new players protection.** Frostborn shows that unbalanced raids and ganking drive players out. Base Raid targets should come from a comparable band, while open-world PvP risk scales by zone.
7. **One character, one economy.** Don't wall multiplayer off into a second character with items that can't leave, the way the Crater does. Players should be able to carry loot from their raids back to their home base.
8. **Unlock social play in hour one.** Co-op with a friend from the start. First PvP risk within the first session or two, in edge zones. Raiding within days, not at level 150. Reviews from 2019 to 2026 keep asking for exactly this.
9. **Make clans matter at base scale.** Shared clan bases, reinforcing a clanmate under attack, scheduled territory or raid nights, and alliances. LDoE's clans are a Crater storage and tournament club. Ours should be war parties.
10. **Make revenge legible.** Always reveal the attacker. Give a revenge window and a bounty on them. Don't stake revenge on whether the thief "took enough to leave footprints".
11. **Keep monetization strictly out of raid outcomes.** No paid task skips for raid access, no paid timer clears, no paid shields, no paid resurrection with loot kept, and no paid breach tools. This is the developer's own reason for quitting LDoE (unverified: an internal project premise with no external source), and reviews show it poisons PvP trust in both Kefir games.
12. **Design for population density from day one.** Region-based shards sized so every base has raidable neighbors, plus seasonal wipes or soft resets that close power gaps. An empty server reproduces LDoE's "nobody raids me" even when the rules allow it, as Frostborn's 2023 reviews suggest ("hard to find PVP players to fight against that are in your class range").

---

## Fact-check notes

*Adversarial fact-check, 2026-11-07. I re-opened about 30 Kefir Helpshift articles, the iTunes lookup and review feeds for LDoE and Frostborn, the LDoE version history, the Frostborn App Store and Kefir pages, GamesKeys and PwrDown. Fandom was still HTTP 402 and Reddit was still blocked. The web-search budget was exhausted, so nothing was corroborated by fresh search; every check below is a direct read of the cited page.*

**Confirmed against the source.**
- The LDoE lookup: v1.53.2 dated 2026-11-06, a 4.563 rating from 103,600 ratings. Seasons last 21 days, per section 41.
- Raid rules from FAQs 104, 106, 735, 736 and 929:
  - Raiding needs level 150.
  - A target expires after 8 hours.
  - You may leave and return once.
  - Disconnects count as leaving, and a second death loses the base.
  - The threat window lasts 24 hours. An attack attempt clears the timer whatever the result.
  - The attacker's base stays up for at most 8 hours.
- Crater rules:
  - The Crater gate was raised from level 30 to 100.
  - The PvP zone needs business level 15 and GS 120. It holds up to 4 players, uses random matchmaking and is run by Nat the Fighter.
  - GS is an average in which empty slots count as 0.
  - Renting out storage needs business level 40.
  - Clans need level 100, with a 24 h wait after leaving and no renaming or deleting.
  - Nicknames run up to 12 characters with a 4-digit tag, changeable every 30 days.
  - Tournaments are limited to 5 a day.
  - The Slums rules, the clan-sale cooldown, clan roles and the "a minute or so" body timer all match.
  - Items cannot leave the Crater.
- Cult's Camps and Base Defense: 3 camps at once, a daily refresh, a 2 h loot window and 3 safes per camp. Base Defense structures (Friend, Thorns, Tripwire, Slicer) are restored after battle.
- Version-history entries for 1.43.0, 1.44.0, 1.48.0, 1.49.0, 1.52.0 (resurrect for coins and keep loot) and 1.53.0 (Occult Tournament).
- The Frostborn and Sunday City lookup figures.
- PwrDown's 1.5.3 (7 Aug 2017) date. GamesKeys (23 Jan 2024): "after season 10", noise at about 20/50/70 and 100, and coin task skips.
- Most review quotes match, including:
  - "The only fun ingame was raiding…" (16 Oct 2026)
  - "100% pay to play" (Nov 2024)
  - "very pricey and painful failure" (Jun 2026)
  - the May 2026 cheaters review (Russian, p.9)
  - the Frostborn quotes on orbs, the 90-day rule, offline raids and the 20-minute claim.

**Corrected.**
1. FAQ 104 gives no head count for the Raiders' visit. I changed "three thugs" to "his thugs".
2. FAQ 99 gives no 2-hour retaliation delay. The 2 hours now rests on GamesKeys and the wiki only.
3. The quote "reveals your base's location to other survivors" is not in the FAQs. I replaced it with FAQ 99's actual wording, "disclosing the coordinates to other survivors".
4. The review quote "not only the AI bases" (Feb 2021) does not exist. I replaced it with the reviewer's actual words, in section 2.5 and in diagnosis row 1.
5. "The Metal Cutter shipped in 1.53" was an unsupported inference. The 1.53 notes don't name it. FAQ 1325 only says it "may come in handy" at Cult's Camps. GamesKeys (2024) says metal cutters were "no longer in the game", which implies the item existed before.
6. The removal of the base turret in 1.51.1 is not in the patch notes, which only add "portable turrets". It is now flagged as wiki-only.
7. FAQ 805 does not say players cannot choose a server. I softened this to "describes no way to choose or change it".
8. The Frostborn 2026 "can't raid and can't get raided" quote was a request for an opt-out mode, not a report that bases had become unraidable. I reworded it.
9. The May 2026 Frostborn "one working server" review is an outage report, not population data. I noted that, and design implication 12 now cites the 2023 population complaint instead.
10. "PvP and Raids" is a feature-list item on kefirgames.com, not a section.
11. Review citations were fixed:
    - The Oct 2026 Russian "level 100" review is on most-recent p.1, not p.5.
    - The Sept 2026 "gens for the raiders" review is on p.3.
    - The 2020 "level 150" and "battle other clan bases" reviews are on most-helpful p.2.
12. Added FAQs 1325, 1329 and 1335, which show that "New Coordinates" is sold by the Scout and that safes feed the Clan Tournament.

**Marked (unverified).** These are wiki-only numbers I could not reach:
- the Raiders' cut tiers
- task-skip prices of 45-125 coins
- about 5.75 min per coin to clear the threat timer
- the SWAT team's 4-stone-wall limit
- The Big One's 1,000 HP and 300 armour
- L5 and specialized-storage immunity
- Beta 1.7 and 1.17.2 dates
- the 1 h and 12 h neighbor-base timers
- no Raider cut on revenge raids

Also marked unverified: the 2019 "hard to swallow" review, which is not in the cited feeds, and the claim that the developer quit LDoE over monetization, which is an internal premise with no external source.

**Reliability: medium.**
- The official FAQ, App Store and version-history facts are solid. They carry most of the TL;DR.
- The wiki-derived numbers are second-hand and could not be re-checked.
- Several quotes and attributions were wrong or overstated.
- The core conclusions still hold: asynchronous raids with no live defender, opt-in vulnerability, level gates, and monetization touching raids.

---

## Sources

**Kefir official help center (Helpshift)**
- [Raids section](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/19-raids-1694691784/)
- [FAQ 736: Another player's base disappeared during a raid](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/736-another-player-s-base-disappeared-during-a-raid)
- [FAQ 106: When can my base be attacked](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/106-when-can-my-base-be-attacked-by-other-survivors/)
- [FAQ 929: Threat timer](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/929-why-did-the-threat-timer-disappear/)
- [FAQ 110: Revenge raids](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/110-why-do-i-not-get-revenge-raided/)
- [FAQ 735: Attacker left no trace](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/735-another-player-left-no-trace-after-attacking-my-base/)
- [FAQ 99: Why was my home base raided](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/99-why-was-my-home-base-raided/)
- [FAQ 364: Raiders don't show up](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/364-i-don-t-get-raiders-raiders-stopped-showing-up/)
- [FAQ 104: Summon raiders](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/104-how-do-i-summon-raiders/)
- [FAQ 98: Zombies during raid](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/98-why-did-zombies-arrive-while-i-was-raiding-a-base/)
- [General Questions section](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/7-general-questions-1694691682/)
- [FAQ 325: Neighbors' bases](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/325-where-did-the-neighbors-bases-go/)
- [FAQ 107: Items disappeared from bunker or neighbor base](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/107-why-did-my-items-disappear-from-the-bunker-neighbor-s-base/)
- [FAQ 57: Cheaters](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/57-what-will-happen-to-cheaters/)
- [Multiplayer section](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/23-multiplayer-1694691726/)
- [PvP: Rules and Overview](https://kefirgames.helpshift.com/a/last-day-on-earth/?s=multiplayer&f=pvp-rules-and-overview&l=en)
- [FAQ 805: Servers](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/805-how-can-i-find-out-the-name-of-my-server-or-change-the-server/)
- [FAQ 126: Play with others](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/126-i-want-to-play-with-other-survivors-what-should-i-do/)
- [FAQ 852: Level 100 for the Crater](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/852-i-m-level-30-but-i-have-no-convoy-event-no-access-to-the-crater-1737185542/)
- [FAQ 267: Items out of the Crater](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/267-how-do-i-bring-items-out-of-crater/)
- [FAQ 316: The Crater](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/316-how-to-get-out-of-the-crater-1737185593/)
- [FAQ 319: Slums](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/319-slums/)
- [FAQ 398: Bonds](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/398-how-to-get-bonds/)
- [FAQ 449: Clan sale](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/449-i-can-t-start-sale-in-the-crater/)
- [FAQ 350: Tournaments](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/350-i-have-no-tournaments-i-don-t-have-a-tournament-button/)
- [FAQ 353: Gear Score](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/353-gear-score-gs/)
- [FAQ 400: PvP with clanmates](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/400-how-do-i-start-pvp-with-my-clanmates-only/)
- [FAQ 184: Clans](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/184-how-do-i-join-or-leave-a-clan/)
- [FAQ 366: Clan roles](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/366-clan-roles/)
- [FAQ 731: Leaving a clan](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/731-what-happens-if-i-leave-the-clan/)
- [FAQ 320: Clan location](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/320-clan-location/)
- [FAQ 298: Body in the Crater](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/298-my-body-is-missing-in-crater/)
- [FAQ 165: Friends and chat](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/165-how-do-i-contact-my-friends/)
- [FAQ 269: Groups](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/269-how-do-i-invite-people-to-my-group/)
- [Seasons, Events and Premium section (Halloween 2026)](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/section/41-seasons-events-and-premium-access-1694691630/)
- [FAQ 1320](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1320-can-my-base-be-destroyed/), [FAQ 1321](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1321-where-can-i-find-new-defensive-structures/), [FAQ 1322](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1322-what-is-base-s-power/), [FAQ 1324](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1324-how-do-cult-s-camps-work/), [FAQ 1325](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1325-what-should-i-bring-to-a-cult-s-camp/), [FAQ 1329](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1329-how-do-new-coordinates-for-cult-s-camps-work/), [FAQ 1335](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1335-what-are-safes-used-for/)

**Stores and Kefir sites**
- [LDoE on the App Store](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)
- [LDoE version history](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094?see-all=version-history)
- [iTunes lookup: LDoE](https://itunes.apple.com/lookup?id=1241932094)
- [iTunes lookup: Kefir apps](https://itunes.apple.com/lookup?id=1646459921&entity=software)
- LDoE US reviews, most recent: [p1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mostrecent/json), [p2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1241932094/sortby=mostrecent/json), [p3](https://itunes.apple.com/us/rss/customerreviews/page=3/id=1241932094/sortby=mostrecent/json), [p5](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1241932094/sortby=mostrecent/json), [p6](https://itunes.apple.com/us/rss/customerreviews/page=6/id=1241932094/sortby=mostrecent/json), [p7](https://itunes.apple.com/us/rss/customerreviews/page=7/id=1241932094/sortby=mostrecent/json), [p8](https://itunes.apple.com/us/rss/customerreviews/page=8/id=1241932094/sortby=mostrecent/json), [p9](https://itunes.apple.com/us/rss/customerreviews/page=9/id=1241932094/sortby=mostrecent/json)
- LDoE US reviews, most helpful: [p1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1241932094/sortby=mosthelpful/json), [p2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1241932094/sortby=mosthelpful/json), [p3](https://itunes.apple.com/us/rss/customerreviews/page=3/id=1241932094/sortby=mosthelpful/json)
- [Frostborn on the App Store](https://apps.apple.com/us/app/frostborn-co-op-survival/id1477237220)
- Frostborn reviews: [most helpful p1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1477237220/sortby=mosthelpful/json), [most helpful p2](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1477237220/sortby=mosthelpful/json), [most recent p1](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1477237220/sortby=mostrecent/json)
- [Kefir games](https://kefirgames.com/games), [Frostborn page](https://kefirgames.com/games/frostborn), [LDoE page](https://kefirgames.com/games/last-day-on-earth)

**Guides and community** (second-hand where noted)
- [GamesKeys: How to raid a base in LDoE (Jan 2024)](https://gameskeys.net/how-to-raid-a-base-in-last-day-on-earth/)
- [PwrDown: Raiding and looting an enemy base (updated Feb 2022)](https://www.pwrdown.com/gaming/last-day-on-earth/last-day-earth-base-looting-raiding-lde/)
- Fandom pages, via search summaries (HTTP 402 to direct fetch): [Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System), [NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base), [Spike Trap](https://last-day-on-earth-survival.fandom.com/wiki/Spike_Trap), [Forum: Protecting the stuff](https://last-day-on-earth-survival.fandom.com/f/p/3100000000000000461), [Forum: Revenge raid](https://last-day-on-earth-survival.fandom.com/f/p/3274514825740657605)
- Reddit, via search snippets only (could not open): [Help a newbie out (Apr 2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1jtf67l/help_a_newbie_out/), [New to the game (Apr 2024)](https://www.reddit.com/r/LastDayonEarthGame/comments/1cdqxo2/new_to_the_game/), [Raiders (Mar 2025)](https://www.reddit.com/r/LastDayonEarthGame/comments/1j0s61l/raiders/)
- [Aggregator listing "Raid Base Player0001" video titles (low reliability)](https://www.avitmarine.com/last-day-on-earth-raid-player0001.html)

**Internal cross-references**
- [ldoe-base-building.md](ldoe-base-building.md), which has wiki data on wall tiers, the noise table, unraidable storage and the Threat of Attack timer
- [dayz-rust-raiding.md](dayz-rust-raiding.md), which covers Rust and DayZ raid systems and mobile adaptations
