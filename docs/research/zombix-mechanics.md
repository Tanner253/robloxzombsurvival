# Zombix Online: how the game works (mechanics deep-dive)

*Research date: 2026-11-07. Scope: Zombix Online: Survival (Android package `com.ZombixDev.ZombixOnline`, iOS id 6482997204). Patch 5.0 shipped on 26–28 Oct 2026, so some details below (especially from 2021–2023 wiki pages) may be out of date. The age of each source is flagged where it matters.*

**How this was researched.** Primary sources were the Google Play and App Store listings, the official site and its JS bundle, the developer's official Telegram channel (all ~213 posts, Sept 2022 to Oct 2026, read in full), the official Featurebase feedback forum (343 posts, read via its public API), a Russian-language Fandom wiki (89 pages) and a smaller English one (16 pages), RuStore, Trashbox, AppGoblin, GameBrain, the Discord server listing, and YouTube video metadata. **I could not access** YouTube transcripts (the endpoints were blocked), Reddit and VK (both blocked to my fetcher), or the inside of the Discord server. YouTube findings are limited to titles, channels, view counts and descriptions. The web-search budget ran out late in the work, so a few questions below are marked as gaps.

---

## TL;DR

- Zombix is essentially **a solo-developer project**: "MMORPG Dev" is Vladislav Okhotnikov (address in Warsaw, Russian-speaking), who works with a contract artist. It launched on 30 Aug 2019 and still gets monthly battle-pass updates. The community is mostly Russian-speaking, with English, Turkish, Indonesian and Latin-American pockets.
- The world is **a set of separate zone maps** (safe hub, PvE lair, two PvP zones, a private personal base, and an instanced arena), spread across **4 servers that each keep their own characters**. Server 4 is an experimental server with different rules and very few players.
- The depth comes from **systems that interlock**: drop-based crafting with rarity merging, durability and repair decay, anomalies that produce artifacts (you can lure zombies into them), 11 gacha-style "characters" that act as classes, pets, spheres and a workbench, farming, fishing, a player-run gold economy, and clan territory wars.
- **Building has three layers.** (1) A private, instanced personal base that can never be raided. (2) Flag-claimed outposts in the PvP zones holding walls, turrets and generators. Destroying the flag deletes everything on it and scatters 50% of the crafting cost. (3) Pre-built "Survivor Bases" that clans capture from NPC bots and hold for clan XP and resources.
- **Raiding in Zombix means fighting over territory and income, not breaking into stashes.** Players report that it is dominated by zergs and alliances, that clans hold bases "for years," that respawning costs nothing, and that pay-to-win characters decide fights. They also say constant siege pressure burns people out and ask for scheduled war windows.

---

## 1. Developer, history and scale

| Item | Finding | Source |
|---|---|---|
| Store developer name | "MMORPG Dev" on Google Play. "Vladislav Okhotnikov" is the iOS seller and the GP developer contact (zombixhelp@gmail.com, Człuchowska 2F, Warsaw, Poland). | [Google Play](https://play.google.com/store/apps/details?id=com.ZombixDev.ZombixOnline), [App Store](https://apps.apple.com/us/app/zombix-online/id6482997204) |
| Discrepancy | RuStore lists the developer as "Berzerk Games" (v5.01, 28 Oct 2026). I could not explain this. It may be a publishing entity. | [RuStore](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline) |
| Team | The dev writes in the channel as "the developer" in the first person ("the channel is official, but I'm the developer"). Players stress that "the developer is one person." A contract designer makes content for loot-box cases. Players call the dev "Kuroko" / "Kuroko Tetsuya." | [Telegram #149](https://t.me/zombixnews/149), [#211](https://t.me/zombixnews/211), [forum](https://zombix.featurebase.app) |
| Release | Google Play: 30 Aug 2019. iOS: 7 May 2024, sharing servers with Android. | GP page data, [iTunes API](https://itunes.apple.com/lookup?id=6482997204), [Telegram #87](https://t.me/zombixnews/87) |
| Other titles by the same dev | Desert Pixel Online (pixel battle royale), Custom Cats Online, SpellCrit: Idle MMORPG (2026). **I found no evidence that "Stalk-X Online" shares this developer.** It does not appear on the GP or App Store developer pages. | [GP developer page](https://play.google.com/store/apps/developer?id=MMORPG+Dev), [Telegram #202](https://t.me/zombixnews/202) |
| Engine/tech | Unity, Firebase, AdMob SDK present. The store says no ads. | [AppGoblin](https://appgoblin.info/apps/com.ZombixDev.ZombixOnline) |
| Installs/ratings | GP badge "1M+" (the raw page data shows 4,793,955), 61.9K ratings at 4.5★, rated Everyone 10+. iOS: 40 ratings at 4.47★. | GP page (fetched 2026-11-07), iTunes API |
| Third-party estimates | AppGoblin estimates 4.8M installs, about 220K MAU, revenue under $10K/month, and roughly +14K installs/month. *Treat these as rough. The MAU figure looks high compared with the community signals below.* | [AppGoblin](https://appgoblin.info/apps/com.ZombixDev.ZombixOnline) |
| Community size | Discord: 7,458 members (created 10 Jun 2020). Telegram news channel: about 4K subscribers, with 2K–20K views per post. The dev himself put server 4 at "maybe 30 players" during active hours (March 2025). | [Discord](https://discord.com/servers/zombix-online-official-720251932710666261), [Telegram](https://t.me/s/zombixnews), [Telegram #175](https://t.me/zombixnews/175) |

**Timeline (key mechanics milestones)**

| Date | Event |
|---|---|
| Aug 2019 | Android release (Google Play). |
| Feb 2021 | English Fandom wiki founded. Its 2021 text described **3** servers (the "4 servers" wording dates from a Dec 2025 edit) and says characters do not transfer between them ([EN wiki](https://zombix.fandom.com/wiki/Zombix_Wiki)). |
| Dec 2022 | Clan overhaul announced: temporary clan buffs, a leader-controlled clan warehouse, neutral mercenary bases, and temporary clan territories that generate clan XP and host resource generators ([Telegram #13](https://t.me/zombixnews/13)). |
| Aug 2023 | Clan flag system ([#25](https://t.me/zombixnews/25)). |
| Oct 2023 | Server 4 launches. Closed beta for rank 40+ players in Sept ([#26](https://t.me/zombixnews/26)–[#29](https://t.me/zombixnews/29)). Dec 2023: knuckles, pet system, building-rent timers, auto-attack nearest target ([#37](https://t.me/zombixnews/37)). |
| Feb 2024 | New Arena: an in-match crafting and base-building mode for 4 teams of 3 with a radiation timer ([#46](https://t.me/zombixnews/46)–[#63](https://t.me/zombixnews/63)). |
| May 2024 | iOS launch. A new character with a golem summon (Azara) ([#80](https://t.me/zombixnews/80), [#87](https://t.me/zombixnews/87)). |
| Sep 2024 | Big quality-of-life (QoL) and rebalance patch: 4 pockets, 10-slot temporary storage, a dedicated motorbike slot, 100-item stacks, more XP sources ([#131](https://t.me/zombixnews/131)). |
| Nov 2024 | First ban wave (884 in total): 4 permanent bans for multi-accounting (unlockable for 1,000 gems, with items confiscated), 714 characters barred from the arena for AFK farming, and 166 zombuck balances zeroed ([#149](https://t.me/zombixnews/149)–[#150](https://t.me/zombixnews/150)). |
| Oct 2026 | Feedback forum opens ([#216](https://t.me/zombixnews/216)). **Patch 5.0** (26–28 Oct): new UI, a Survivor Base map, a Raven pet, a new 3v3 arena and a Halloween event. On 28 Oct the dev announced that auto-aim in manual fire would be removed from servers 1–3 in the follow-up patch ([#221](https://t.me/zombixnews/221)–[#223](https://t.me/zombixnews/223), [App Store notes](https://apps.apple.com/us/app/zombix-online/id6482997204)). |

Ops reality: many posts deal with hosting outages, server migrations, and region lag (server 3 has RU, EU, US and Asian regions). The dev himself says large clan wars of "several hundred players" were throttled by bad hosting ([#194](https://t.me/zombixnews/194)).

---

## 2. World structure

**Servers.** Servers 1–3 run the "classic" ruleset. Server 4 is an experimental fork with tiered T1–T6 locations, ore mining, silver farming, a hub marketplace, auctions for "machine territories," and rentable buildings ([#37](https://t.me/zombixnews/37), [#66](https://t.me/zombixnews/66), [#156](https://t.me/zombixnews/156)). Each server keeps its own characters.

**Zones (servers 1–3).** These are separate maps, reached by talking to the Conductor NPC or by walking to edges. Motorbikes speed up travel. Summary from the RU wiki main page (last edited 2024-08) and its zone pages:

| Zone | Rules | Content |
|---|---|---|
| **Home Zone** (Домашняя Зона) | Safe hub: no PvP, but hostile mobs exist outside the safe area. 9 small and 2 large map squares. Mob levels run 1–5 up to 20–29. | All quest NPCs (Trader, Scientist, Adviser, Collector, Conductor, Healer, Fisherman, Schultz, Sharp Hawk). Zombies drop rust, glue, cloth and Ruby; wolves drop leather. Red berries, "Soda" anomalies, ponds. |
| **Monster Lair** (Логово монстров) | PvE | Zombies, dark zombies, wolves, bears. Boss "Bloodsucker" (Кровосос, also called Vampire) and a hammer-wielding boss (Молотоборец). All berry types and all three anomaly types. Rarer components drop here. |
| **Hot Spot** (Горячая точка) | PvP. Radiation deals 2 dmg/s unless you wear a gas mask or play the Shaman. Players say it unlocks at level 40. | Stronger mobs, a boss with 45,000 HP, orange berries, and a sphere generator that drops weapon-upgrade spheres. "Weapon control" (manual aim) applies here. Flags and walls can be placed. |
| **Survivor Bases** (Базы выживших / "БВ", wasteland) | PvP | No mobs, only NPCs and bots that guard the pre-built bases. The General NPC sells small turrets. Clans capture bases (see §6). Blue berries are rare. |
| **Personal Base** (Личная база) | Private and peaceful: only the owner can enter | Storage, planters, statues, workbench (see §6). |
| **Arena** | Instanced matches | See §4 and §6. |

Sources: [RU wiki main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики), [Домашняя Зона](https://zombix-online.fandom.com/ru/wiki/Домашняя_Зона), [Босс](https://zombix-online.fandom.com/ru/wiki/Босс).

The official site describes "dozens of locations with capturable territories" and "local markets" ([zombixonline.com](https://zombixonline.com), bundle text, 2026).

---

## 3. Character progression

**Rank (level).** The cap is **60**. Monster levels top out around 49–55, so the last ranks are a grind. Players at rank 55+ rely on XP injectors ([Оранжевый инъектор](https://zombix-online.fandom.com/ru/wiki/Оранжевый_инъектор), forum "Идеи для развития"). XP sources include mob kills (+20% since Sept 2024), the Trader quest chain, NPC "wishes" (turn-in requests), daily tasks, the "Recruit's Path" list, seasonal tasks, fishing, woodcutting, harvesting, destroying crafted items for crafting-skill XP, and injectors.
- **Injectors** are a crafted XP item. An empty injector takes 25 glue, 25 metal and 15 bolts. Fill it with a berry flask (75 red/blue berries or 150 orange) plus 3–9 gold. Red gives +1,000 XP, blue +2,000, orange +3,333 ([Пустой Инъектор](https://zombix-online.fandom.com/ru/wiki/Пустой_Инъектор)).
- **"Abundance" (Изобилие)** is a recurring boosted-farming event; that it runs alongside each battle-pass season is (unverified), though players say it is pushed "into every gap." Veterans say it has devalued progression and accounts: a full account fell from 5,000–7,000 in 2022–23 to 1,000–2,000 (the post gives no currency; presumably RUB) ([forum](https://zombix.featurebase.app), "В чем смысл данного форума?").

**Characters work as classes, obtained by gacha.** Players switch between owned characters in the inventory. In 2022 there were 7, with stated drop chances: Fighter 30%, Soldier 30%, Shaman 11%, Dodger 11%, Medic 8%, Kibela 5%, Technos 5%. Each levels from 1 to 10 and gains perks ([Персонажи](https://zombix-online.fandom.com/ru/wiki/Персонажи), 2022). Examples:
- **Fighter:** +damage and fist damage, then −15% monster damage, +10% XP, and +3 HP/s at level 10.
- **Soldier:** stacking armor, +speed.
- **Shaman:** immune to radiation, +15% XP.
- **Dodger:** +25% dodge in total, −30% roll cooldown.
- **Medic:** a healing aura (3% → 7% max HP/s for 5 s, 30 s cooldown, with an anti-stacking debuff).
- **Kibela:** an auto-attacking desert bird and +30% harvest speed.
- **Technos:** up to 3 attack drones.

By 2026 players count **11 characters**, including Azara (golem), Darken (shield, and carrying a weapon does not slow his run), Radiy (shield support) and Sniper. They report that only 4 are used for combat and 2 for support, and they call Darken pay-to-win (forum: "Теория возможного изменения баланса," "Донат"). Characters are now upgraded through "contracts" bought with coins.

**Skills.** Crafting raises a crafting skill per item type, and upgrading at the workbench raises a "Mechanic skill" that improves the odds of rare or legendary upgrade rolls ([Верстак](https://zombix-online.fandom.com/ru/wiki/Верстак)). Players say weapon skills have been stuck since 2021 on the sniper, Deagle and Glock (forum). A YouTube skills guide exists (Disti, "Гайд на навыки," 2.8K views, 2023). I could not watch it.

**Gear rarity by merging.** Drag two items of the same rarity together to get the next rarity: green, blue, purple, orange, now shown as Roman numerals. On servers 1–3 the 2024 wiki says **rarity only affects durability** ([main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики)). Spheres add stat upgrades through the workbench.

---

## 4. Combat

**Controls.** Movement joystick plus an attack joystick, a dodge roll, and bushes for ambushes ([GP listing](https://play.google.com/store/apps/details?id=com.ZombixDev.ZombixOnline)).
- **Auto-fire** shoots the nearest target. It is the marketed feature for bad connections, and per the dev most fighting happens on auto-attack ([#168](https://t.me/zombixnews/168)).
- **Manual fire** gives aimed shots and is required to damage walls.
- Survivor Bases and the Hot Spot cycle between auto-attack and manual-shooting periods. Walls placed right against spawn could not be hit until the manual phase began ([Деревянная стенка](https://zombix-online.fandom.com/ru/wiki/Деревянная_стенка)).
- The dev described replacing server-authoritative movement with a client-predicted "responsive joystick." He says this blocked many mechanics, and in March 2025 he proposed a server 4 experiment with tap-to-move and select-target; whether it shipped is (unverified) ([#175](https://t.me/zombixnews/175)).
- Auto-aim during manual fire was proposed in May 2026 as an anti-cheat measure (it already ran on server 4). On 28 Oct 2026 the dev said it would be removed from servers 1–3 in the patch after 5.0 ([#211](https://t.me/zombixnews/211), [#223](https://t.me/zombixnews/223)).
- Damage numbers are colour-coded by source: acid, explosion, bite, anomaly, bullet ([#131](https://t.me/zombixnews/131)).

**Weapons (recipes from the wikis, 2021–2023; numbers may have changed).**

| Weapon | Recipe | Notes |
|---|---|---|
| Glock | 5 rust + 1 glue | Starter. Weak against players. |
| AK-47 | 25–50 rust + 15 glue | 19 damage, 2.22 shots/s, 30-round magazine, 400 durability. Also a Trader reward. |
| M4A1 | 50 metal + 15 glue | Same damage as the AK, better fire rate and durability. |
| Desert Eagle | 15 metal + 10 glue (+5 green tokens in a 2021 recipe; tokens were removed from recipes in v3.99f2) | High damage, slow. |
| Sniper (M24) | 30–50 gold + 25–50 metal (+blue tokens in old recipe) | "Perfect" for wolf hunts and base capture. |
| RPG | 50 gold + 35 big nuts (Большая гайка) | Area damage that ignores armor. |
| Later additions | Acid gun, minigun, SMG, shotgun, knuckles (dash and root, 2023), axe (15 dmg), bat (25), sword | Players say the RPG and acid gun dominate the meta and newer guns go unused. |

**Armor.** Helmets give armor plus a perk: the Dangerous Helmet reflects 25% of damage, the Moto, Avia and Cosmo helmets add speed, and the Titanium helmet is heaviest. The Biker Jacket gives 65 armor, +45 HP and +1 HP/s. Combat Boots come in tiers IV–VI. Speed perks were nerfed in Sept 2024 ([#131](https://t.me/zombixnews/131), [Байкерская Куртка](https://zombix-online.fandom.com/ru/wiki/Байкерская_Куртка)).

**Healing and buffs.** The medkit heals 100 HP on a 15 s cooldown (recipe: 5 cloth + 15 red berries). Berries, vegetables and cooked fish (since Nov 2024, one fish per 60 s on server 4) provide other healing. Artifacts: Ruby gives regeneration and blocks radiation, Ice gives a speed boost, and Sunny blocks the next hit ([EN wiki: Ruby/Sunny/Ice](https://zombix.fandom.com/wiki/Sunny)). Players complain that the meta is "oversaturated with heals," so 1v1 fights stall.

**PvE.**
- Zombies range from 42 to 3,062 HP depending on zone. Their drops: Ruby ~90%, cloth ~100%, rust ~60%, glue ~70%, tape ~50%, sensor ~5%, and gold 1% ([Зомби](https://zombix-online.fandom.com/ru/wiki/Зомби)).
- Wolves have 350–5,000 HP, are fast and hard-hitting, and drop leather, Ice, components and gold.
- Bears: limited data.
- The boss (Bloodsucker) has 45,000 HP, hits for 100–140 unarmored, gives 1,500 XP and drops 15 gold. Its gold payout scales with damage dealt, and it **moves faster as its HP drops**. Bosses aggro on turrets first, which players exploit ([Турель](https://zombix-online.fandom.com/ru/wiki/Турель)).
- A Halloween mini-event turned a random *player* into a boss who had to survive for 5 minutes ([#154](https://t.me/zombixnews/154)).

**PvP rules and death.** The Home Zone has no PvP. The Hot Spot and Survivor Bases are open PvP. Turrets ignore clanmates, party members, and the owner clan's bots and mercenaries. Players can get knocked "unconscious" before dying ([#175](https://t.me/zombixnews/175)).
- **Death penalty on servers 1–3: not documented anywhere I could reach.** Inference from the forum: dying at Survivor Bases costs little. Players ask for "resource drops or a death cooldown, like server 4," complain about "spam" from naked players running back to bases, and want a respawn cooldown "at the place where you died." That suggests fast, low-cost respawns and **no full-loot drop** in those zones.
- On server 4 you respawn with 60–80% HP after a cooldown (forum "4 server patch").
- In the Arena (Feb 2024 rules), equipped items don't drop when you are downed but lose 10% durability. They do drop on "final death" (0 HP **and** your team base destroyed) ([#55](https://t.me/zombixnews/55), [#62](https://t.me/zombixnews/62)).

---

## 5. Gathering and crafting

- **Drop-driven resources.** Almost everything comes from kills. Common drops are rust, cloth, glue, tape and Ruby. Lair and Hot Spot mobs add metal (~20%) and rare parts at ~5% (bolts, copper wire, sensors, gears, nails, nuts). Gold drops at 1% from any mob type and the level doesn't change that ([Золотой слиток](https://zombix-online.fandom.com/ru/wiki/Золотой_слиток), [Металл](https://zombix-online.fandom.com/ru/wiki/Металл)).
- **Wood.** Equip an axe (25 rust + 25 metal + 10 tape, 1,000 durability). Trees have 500 HP and give 6–7 wood and +1 XP, then regrow from the stump ([Топор](https://zombix-online.fandom.com/ru/wiki/Топор)).
- **Fishing.** Craft a rod that breaks after 20 casts. Fishing is a timing minigame that keeps a bobber inside a moving band. Fish give XP and can be cooked for regeneration. Bots auto-fish, and spoilage of raw fish is "Planned" on the forum ([Обычная удочка](https://zombix-online.fandom.com/ru/wiki/Обычная_удочка), [forum](https://zombix.featurebase.app/p/ryba-portitsya-so-vremenem)).
- **Farming.** Planters (25 wood) go only on the personal base and grow carrots, grapes and peppers ([Грядка](https://zombix-online.fandom.com/ru/wiki/Грядка)).
- **Anomalies to artifacts.** There are three hazards: Soda (common) yields Ice, Whirlwind yields Ruby, and Acid (rare) yields Sunny. Any creature taking damage inside the anomaly has a chance to spawn the artifact. The known trick is to **kite slow zombies around an anomaly** so they "farm" it for you ([Газировка](https://zombix-online.fandom.com/ru/wiki/Газировка), [Ледышка](https://zombix-online.fandom.com/ru/wiki/Ледышка)).
- **Crafting rules.** Recipes use fixed resource counts. Rewards from quests can't be traded or upgraded. Repair kits restore 25% durability, but each use adds an "F" counter and makes the item wear 10% faster ([Ремонтный набор](https://zombix-online.fandom.com/ru/wiki/Ремонтный_набор)).
- **Inventory.**
  - Simple bags add +5 slots. Survivor backpacks add more.
  - Bags can't go in trade windows; that was used for scams, so bags are now traded by dropping them on the ground.
  - Since Sept 2024: 4 quick pockets, 100-item stacks, and a 10-slot overflow store that keeps items for 60 minutes and can still be used for crafting ([#131](https://t.me/zombixnews/131)).
  - Arena matches use a carry-weight limit, 50 → 60 kg ([#74](https://t.me/zombixnews/74)).

---

## 6. Building, territory and raiding (the critical section)

Zombix has **four distinct building contexts**, and the split is the most important design lesson.

### 6.1 Personal Base: private and unraidable
An instanced map that only the owner can enter, with only the Conductor NPC present. You place storage, planters, statues and a workbench on a **grid of cells**: you pick an empty cell and place the item. Storage starts at 8 slots, can be expanded, and you can have up to 10 storages. A storage costs 100 rust + 50 metal + 25 tape, or 3 gems. The workbench (150 wood + 100 metal + 20 gold) upgrades items with spheres ([Хранилище](https://zombix-online.fandom.com/ru/wiki/Хранилище), [Верстак](https://zombix-online.fandom.com/ru/wiki/Верстак)). **Nobody can attack it**, so your wealth sits safely here. On the forum after 5.0, players complain that storage and planter *crafting* was removed. It is unclear whether these are now shop-only.

### 6.2 Flag outposts in PvP zones
- **The flag claims the land.** A Base Flag costs 50 leather, 100 glue and 100 wood, trading at about 4–5 gold. It goes **only on neutral ground** in the Hot Spot or Survivor Bases, not on the pre-built bases, and claims a beige circle around it ([Флажок для базы](https://zombix-online.fandom.com/ru/wiki/Флажок_для_базы)).
- **First hour:** the flag is invulnerable. After that **anyone can destroy it**. When it falls, *every structure on it is destroyed and 50% of the resources spent crafting them scatter on the ground* for others to loot.
- **Per flag:** up to **2 generators** and **4 turrets**.
- **Generators** are timed production buildings that mail the output to the owner.
  - A Motorbike generator (25 sensors + 25 gears + 25 copper wire) delivers a bike after 25 minutes (the wiki's separate Мотоцикл page says 45 minutes, so the exact timer is uncertain).
  - A Sidecar generator (60 of each) delivers after 60 minutes.
  - The generator self-destructs after delivering and dies with the flag ([Генератор](https://zombix-online.fandom.com/ru/wiki/Генератор)).
  - This makes guarding flags a real activity: one player recalls standing guard "for hours," fearing someone would break them. A YouTuber claims to have placed 50 generators solo (2020) (unverified).
- **Turrets** auto-target monsters, bosses, mercenaries, bots and hostile players, but not your clan, party or your clan's bots.
  - Small turret: 750 HP. Recipe 50 rust + 50 tape + 15 copper wire, or bought from the General NPC for 350 since April 2023.
  - Turret: 3,000 HP. Recipe 50 metal + 10 gold + 25 copper wire.
  - July 2024: small turret damage cut from 33 to 26, turrets banned near *any* safe zone, and stacks of 3 turrets can't sit near another stack ([#101](https://t.me/zombixnews/101)).
- **Walls** (also placeable in the Hot Spot and Survivor Bases):
  - Wood: 500 HP, 25 wood.
  - Metal: 2,500 HP, 25 metal.
  - Gold: 5,000 HP, 15 gold.
  - Each can be shaped as a wall, an **arch or a slope**, so players assemble "buildings" from them. A ghost preview appears before placement. Placed walls can't be moved. Destroyed walls drop a little material.
  - AI (mobs, bosses, bots and mercenaries) path around walls. Only players can break them.
  - Walls placed against spawns trapped players until manual-fire mode started. That exploit led to placement bans near spawns and safe zones ([Золотая стенка](https://zombix-online.fandom.com/ru/wiki/Золотая_стенка), [Металлическая стенка](https://zombix-online.fandom.com/ru/wiki/Металлическая_стенка)).
  - The dev floated letting auto-fire shoot *through* walls. The backlash was "unambiguous," and he dropped it ([#122](https://t.me/zombixnews/122)–[#123](https://t.me/zombixnews/123)).
- **Changes over time:** a clan flag system arrived in Aug 2023. Players now refer to a flag "save" (protection) and ask for the old breakable flags back, because the old risk made guarding exciting (forum list post, Oct 2026). *Exact current flag rules are unverified.*

### 6.3 Survivor Bases: clan-capturable strongholds
- Pre-built bases are marked on the map and **guarded by bots**. When a clan captures one, it earns **clan XP every 30 minutes** ([RU wiki main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики)) and **the base's machine output**. Per the store copy, captured bases contain machines that produce resources. Per the dev, outputs include shoe schematics, Toxic Gun parts, seeds and a sword ([#13](https://t.me/zombixnews/13)).
- Since 5.0, output goes **straight into the clan warehouse** instead of dropping on the ground. A new Survivor Base map was added, but at launch it did not yet show each base's clan, flag or output; the dev promised that in a follow-up patch (forum "Обнова 5.0 Баги," [#221](https://t.me/zombixnews/221)). Seeds yield heals, and players say clans holding bases "for years" hoard heal items.
- **How capture works.** *Inference:* players fight through bots, walls and turrets to destroy the base's flag. In the Arena, base flags have HP and players "hid inside the flag while breaking it" ([#175](https://t.me/zombixnews/175)). YouTube creators describe "LOUD" vs "SMART" capture approaches (Tim_Ruru, 2021, 970 views). Sniper rifles are the noted capture weapon.
- **Clan wars.** These are large, scheduled-by-nobody brawls: "Raid on American Bases," a 1.5-hour alliance war on 16 Jan 2024 ([YouTube, Cosmi](https://www.youtube.com/watch?v=AWFQt35Csfc)), and "Europe raid vs 100+ mercenaries" ([YouTube, Ryo AM](https://www.youtube.com/watch?v=HxOhC0Zi36w)). *Inference:* bases appear to be named by region or continent.
- **Mercenaries.** Clans can field mercenary bots, which turrets owned by the same clan won't shoot. Neutral mercenary bases boost clan territories ([#13](https://t.me/zombixnews/13)).

### 6.4 Server 4 and the Arena (experiments)
- **Server 4.**
  - Clans bid at **auctions** for "machine territories."
  - Players can see when a rival's building **rent** expires.
  - Clan-base holding pays a prize pool into the clan warehouse, and the leader distributes it ([#66](https://t.me/zombixnews/66), [#37](https://t.me/zombixnews/37), [#156](https://t.me/zombixnews/156)).
  - Players say the gameplay collapsed into "hold bases or farm silver," and the server "died once" within six months.
- **Arena (Feb 2024).** 4 teams of 3 each start with a base and flag, gather and craft from zero (pickaxe, fiber from bushes, axes), build walls and turrets, and raid each other. Radiation appears at about minute 15–20 and becomes lethal around 20–30 to force an ending.
  - The dev warned players: "don't try to fortify your base too much."
  - He tuned the radiation timer live because longer matches starved matchmaking ([#47](https://t.me/zombixnews/47)–[#63](https://t.me/zombixnews/63)).
  - He calls this mode his personal favourite, but says only a small share of players touch it (he used "roughly 10%" as an illustrative figure, not a measured one) and that players went AFK to farm its rewards ([#150](https://t.me/zombixnews/150), [#158](https://t.me/zombixnews/158)).
  - 5.0 replaced it with a new 3v3 mode.
- A **"mini-Tarkov" server** was drafted in July 2024: 20-minute extraction matches, gear-score brackets, full loot on death, and a hub marketplace ([#115](https://t.me/zombixnews/115)). There is no evidence it shipped.

### 6.5 What raiding actually is in Zombix
- **You cannot raid a player's stash.** The personal base is private. What you *can* destroy is flag outposts, with 50% of their material cost spilling out, and the income streams of clan bases.
- **The loop is territorial:** farm, convert to gold and gear, then spend it holding or taking Survivor Bases. In one player's words: farming and then spending it at Survivor Bases is "the whole point" (forum).
- **Player-reported problems** (forum, Oct 2026):
  - Alliances of 6–10 clans lock down whole servers, despite a 3-clan alliance code.
  - Clan wars shrank from 50v50 to 10v10 as clans fragmented. Clan creation costs 1,500 coins, and players want 15–30K.
  - Constant sieges exhaust working adults. A post with 12 votes asks for **Albion-style capture windows of 1–2 hours**.
  - Respawns cost almost nothing.
  - Paid characters and heal stockpiles decide fights, and "a buyer can play on par with a 5-year veteran."
  - Multi-accounting and bots are used to defend bases and farm.

---

## 7. Pets

The store copy describes upgradable pets that fight alongside you ([GP ru](https://play.google.com/store/apps/details?id=com.ZombixDev.ZombixOnline&hl=ru)).
- Servers 1–3 have three pet types. A 2021 review video covers them (STALEVAR, 10.8K views). The pets I could name are the shepherd dog and a "predator" that gives regeneration.
- Server 4 got **4 pets** that give small owner buffs and level up with **food from airdrop boxes** ([#34](https://t.me/zombixnews/34), [#37](https://t.me/zombixnews/37)).
- Pets can pull boss aggro ([Босс](https://zombix-online.fandom.com/ru/wiki/Босс)). Players complain that pets and bikes block bullets.
- 5.0 added a **Raven** that auto-collects. A forum post argues this conflicts with the anti-AFK rules.
- Pet upgrades cost coins, and pet cosmetics come from event shops.

---

## 8. Economy and trading

**Currencies**

| Currency | Role |
|---|---|
| **Gold** (gold bar) | The *player-to-player currency*. 1% mob drop, boss payouts, and wall teardown. Items are priced in gold ([Золотой слиток](https://zombix-online.fandom.com/ru/wiki/Золотой_слиток)). |
| Silver | Received for selling junk to the Trader (e.g. rust at 1 silver each). |
| Zombucks / "coins" | Soft-premium currency. Sources: seasonal tasks, arena wins (50 for each of the first 2 daily wins in 2023), and quests. Used for clan creation (1,000 per the old wiki, 1,500 in 2026 per players), contracts, pet and character upgrades, and clan buffs. Players say they are scarce ([#33](https://t.me/zombixnews/33), forum). |
| Gems | Hard currency (IAP). Repair kit 1 gem, storage 3, Avia helmet 15. |
| Arena tokens (green/blue/purple) | Non-tradable. Spent in the Arena shop. |
| Event currencies | Pumpkin coins (Halloween), etc. |

**Trading.** Trades happen face to face through a 5-slot exchange panel. Bags and backpacks can't be traded through it because of past scams. Sellers stand at spawn "for hours" advertising, and players ask for an offline market (forum "Рынок без участия людей," "Торговая площадка," 92 votes). Real-money trading of gold and accounts happens on outside social platforms. Server 4 has a hub marketplace.

**Sample player prices** (wiki, mostly 2023):

| Item | Price |
|---|---|
| Wood wall | 2 for 1 gold |
| Turret | 15–16 gold |
| Gold wall | 15 gold |
| Sidecar generator | 17 gold |
| Motorbike | 5–7 gold |
| Sniper | 30–50 gold |
| Medkits | 5 per gold |
| Ice | 50 per gold |
| Wood | 50 per gold |
| Rust | 50 per gold |

**Monetization.**
- GP lists in-app purchases at $0.49–$74.99 per item.
- iOS in-app purchases: Keys $0.99 / 20 for $15.99 (case keys), **Zombix Pass $4.99**, kits from $0.99 to $19.99 ([App Store](https://apps.apple.com/us/app/zombix-online/id6482997204)).
- Apple flags **loot boxes**.
- A web shop ([shop.zombixonline.com](https://shop.zombixonline.com)) sells the battle pass, gems, zombucks, case keys and kits, delivered by in-game mail, and accepts Russian cards and SBP ([#70](https://t.me/zombixnews/70)).
- Battle-pass seasons run roughly monthly ([App Store notes](https://apps.apple.com/us/app/zombix-online/id6482997204)).
- Reviews split. GameBrain's summary includes praise for not being pay-to-win ([GameBrain](https://gamebrain.co/game/zombix-online-survival)). Veterans on the forum call Darken, contracts and heal stockpiles pay-to-win, and say content became "skins and emotes instead of mechanics."

---

## 9. Quests, NPCs and events

- **NPCs:** Trader (quests, buy and sell, repair kit for 750), Scientist, Adviser, Collector (each gives quests and "wishes"), Conductor (travel), Healer, Fisherman (fish exchange), Schultz, Sharp Hawk, and the General (sells turrets at Survivor Bases).
- **Trader starter chain** (2021): find the Scientist, then the Conductor, then gather 5 red berries for a Glock. Next: kill 1 zombie, use a berry, collect an Ice, and kill 50 zombies for an AK-47 ([Задания](https://zombix-online.fandom.com/ru/wiki/Задания)). It is a pure tutorial chain.
- **Seasonal tasks:** e.g. dodge 100 attacks for 25 Sunny, kill 100 wolves for purple boots, craft 25 AKs for a sniper ([Сезоны](https://zombix-online.fandom.com/ru/wiki/Сезоны), 2020).
- **Live events:** daily tasks, the "Recruit's Path," battle pass, Abundance, Halloween pumpkin hunts with a pumpkin shop and the player-boss event, a New Year event, a fish collection (4.98, Sept 2025), and new cases.
- **Players' view:** NPC quests are "finished very quickly." They ask for interactive quest lines rather than "kill N wolves" tasks, and the dev requested exactly this on the forum ([#216](https://t.me/zombixnews/216)). There are **no achievements yet**; laboratories and achievements were promised for server 4 in 2023 ([#37](https://t.me/zombixnews/37)).

---

## 10. Social systems

- **Clans:**
  - Created with zombucks or coins. Clan level raises the member cap.
  - Since 2022–23: temporary clan buffs (damage, XP, armor), a clan warehouse where only the leader can hand out items (e.g. mailing up to 50 swords), clan flags, and an alliance system with a "radio" alliance code.
  - Leaving a clan and joining another is instant, which used to be a `/switchClan` command ([Как менять клан](https://zombix-online.fandom.com/ru/wiki/Как_менять_клан), [#17](https://t.me/zombixnews/17)).
- **Parties and chat:**
  - Parties exist; turrets spare party members. A forum poster implies parties of up to 8 (unverified).
  - Over-head speech bubbles are truncated after 26 characters to fight spam.
  - Team chat and in-game mail exist.
  - There is **no friends list**. It is a top request on the forum, with 91 votes.
- **Moderation:**
  - Multi-accounting outside safe zones means a permanent ban.
  - The dev was planning a replay system for gathering evidence in 2026 ([#212](https://t.me/zombixnews/212)).
  - Account recovery was historically unsupported, so iOS and forum reviewers report losing paid accounts.

---

## 11. Endgame

- Rank 60.
- Characters at level 10. Collecting more characters through contracts.
- Legendary sphere rolls.
- Top gear: Titanium helmet, leather or biker jacket, Boots V, RPG, acid gun.
- Arena rating.
- Fish collection.
- Above all, **holding Survivor Bases with your clan or alliance**.
- Server 4 tops out at T6 crafts, and its players say "everyone hit the ceiling" and want T7.

*Inference:* the endgame is almost purely territorial PvP plus cosmetics. Without fresh PvE goals, populations peak during Abundance events and fade between them, as one player reported: "10 new near-maxed people" appear during Abundance and vanish for a month after.

---

## 12. Why it feels "deep" despite simple pixel visuals

*Inference, built on the sourced mechanics above:*

1. **Every item is part of a web.** Gold is a 1% drop yet feeds about 25 recipes, from turrets and injectors to the workbench, RPG and walls. That makes gold a real currency and every kill a small lottery.
2. **Emergent tricks from simple rules.** Luring zombies into anomalies to farm artifacts, using turrets to hold boss aggro, bosses that speed up as they weaken, walls blocking spawns, ambushes from bushes, and sniping during base capture.
3. **Loss and decay create demand.** Durability, repairs that accelerate wear (the F-counter), and flags that scatter 50% of their cost on destruction all keep consumption going, so the player market keeps moving.
4. **Many horizontal progression axes:** rank, 11 characters with 10 levels each, crafting and mechanic skills, rarity merging, spheres, pets, inventory capacity, clan level and clan buffs.
5. **The MMO social layer.** A player-priced gold economy, face-to-face trade, clan politics and alliances, and wars of hundreds of players on a 2D map that is cheap to render.
6. **A "Stalker" fantasy** (anomalies, artifacts, radiation zones) layered on zombie survival. Veterans explicitly want it to lean back toward Stalker, Metro or Rust rather than "Genshin-style" cosmetics.

---

## 13. Pain points to beat (player-sourced, 2024–2026)

- **Low fidelity and UX:** pixel art seen as dated, a confusing UI (5.0's redesign was divisive), unclear quests, and no tutorial depth ([GameBrain](https://gamebrain.co/game/zombix-online-survival)).
- **Infrastructure:** constant outages, lag in big wars, and unequal regions ([Telegram](https://t.me/s/zombixnews)).
- **Thin PvE:** "4 monster types that differ only by level," little boss variety, a level-60 grind with no mobs past level 55.
- **Snowballing territory:** alliance zergs, clans holding bases for years, newbies locked out. On server 4: "SAS took all bases."
- **Low skill expression:** auto-fire, heal saturation, P2W characters.
- **Economy friction:** no auction house, standing at spawn to sell, real-money trading, Abundance inflation, and bots and multi-accounts.
- **A solo dev bottleneck:** content cadence is mostly battle passes and emotes.

---

## Design implications for our game

1. **Separate "safe home" from "raidable outposts," but don't make everything safe.** Zombix's unraidable personal base protects players from loss, but it is exactly why raiding never touches anyone's stash. That matches the user's complaint about LDoE. Our approach: a small protected stash (an insured "lockbox" sized by progression) plus a **real, raidable base** that holds most of the wealth and production. The protected stash stops ragequits. The raidable base creates stakes.
2. **Copy the flag-claim mechanic and make it the backbone.** A crafted claim object creates a build radius with **caps per claim** (Zombix: 2 generators and 4 turrets). It gets a **short new-claim immunity** (Zombix: 1 hour). When it falls, **everything goes and part of the crafting cost spills as lootable salvage** (Zombix: 50%). This is a clean, readable raid payoff. Add an upkeep cost so abandoned bases decay and free up land.
3. **Production buildings are the reason to defend.** Zombix's timed generators that mail you a motorbike in 25 or 60 minutes made people guard flags "for hours." Build our economy around **timed, interruptible production on raidable land** (fuel, ammo presses, crop plots, workbench upgrades), so attackers have a reason to come and defenders a reason to stay.
4. **Walls need shape variety and clear destructibility tiers.** Zombix's wood (500), metal (2,500) and gold (5,000) HP walls with arch and slope variants are the right *shape* of system. Add Rust-style soft and hard sides, raid tools with real costs (explosives crafted from rare drops), and **AI that paths around walls while only players break them**. Ban placement near spawns and safe zones from day one, because Zombix had to patch spawn-blocking.
5. **Schedule or shield territory warfare.** Zombix players are burned out by 24/7 sieges and ask for Albion-style windows. Options: owner-chosen vulnerability windows, offline raid protection that scales with base size, or "raid alerts" plus a defense countdown. The goal is that raids *happen* and defenders can *show up*, which fixes LDoE's "nobody ever comes" problem without Zombix's burnout.
6. **Anti-zerg rules are mandatory.** Cap alliance sizes in the mechanics: no friendly-fire immunity beyond the clan, diminishing returns on holding multiple territories, territory upkeep that grows superlinearly, and decay of clan XP from held bases. Zombix shows that a 3-clan alliance limit is ignored if teaming carries no cost.
7. **Give death a price, but a fair one.** Zombix's near-free respawn turned base fights into "naked spam." Use DayZ- and Rust-style loss in PvP zones (inventory drops, equipped gear partly protected or degraded) plus respawn timers at contested sites. For bags, keep Zombix's anti-scam rule: no opaque containers in trades.
8. **Keep skill expression.** Offer optional aim assist for low-end and mobile players, but don't let auto-fire decide PvP. Zombix's dev himself regrets that client-predicted movement and auto-fire limited his design space. In Unity, plan server-authoritative movement with client prediction and lag compensation from the start.
9. **Use emergent "sandbox verbs" cheaply.** Anomalies that pay out when *anything* takes damage inside them (so you can kite zombies in), bosses that speed up as they weaken, turrets that pull aggro: these cost little and generate stories and YouTube guides. Design 10–15 such rules.
10. **Monetize like the user wishes LDoE had.** Zombix's mix of battle pass, cosmetics and a web shop is acceptable. Its gacha *power* characters (Darken) and paid heals poisoned trust. Sell cosmetics, convenience and a fair battle pass. Never sell combat power, raid protection or raid tools.
11. **Build a real market.** Players beg for an offline auction house. Offer regional trading posts with listing fees as a gold sink, keep gold drop-only, and add item decay or sinks (repair wear, raid salvage loss) so prices hold.
12. **Plan for bots and multi-accounts on day one.** Device or account binding, server-side behaviour detection, and replays for reports. Zombix had to bar 714 characters from its arena for AFK farming in one ban wave.

---

## Gaps and caveats

- Exact current (post-5.0) rules for death and loot drop on servers 1–3, the flag "save," Survivor Base capture conditions, and the full pet list were not confirmed by a primary source.
- I found no evidence on "Stalk-X Online" linking it to this developer.
- YouTube transcripts, Reddit, VK and the inside of the Discord server were inaccessible. Most wiki pages date from 2020–2023.

---

## Fact-check notes

*Adversarial re-check on 2026-11-07. About 30 claims were re-verified against the cited primary sources: the Google Play page (raw HTML), the App Store page and iTunes lookup API, AppGoblin, RuStore, the Discord listing, the GP developer page, the official site's JS bundle, Telegram posts with timestamps (t.me/s), all 343 Featurebase forum posts (public API), and RU and EN Fandom wiki wikitext and revision history (MediaWiki API). The web-search budget was exhausted during this pass, so corroboration came from the primary sources rather than from fresh searches.*

**Confirmed as written (selection):** GP developer "MMORPG Dev", contact VLADISLAV OKHOTNIKOV with the Człuchowska 2F, Warsaw address; GP release Aug 30, 2019; "1M+" badge with raw 4,793,955; 61.9K reviews at 4.5★; Everyone 10+; IAP $0.49–$74.99; no ads label. iOS: seller Vladislav Okhotnikov, released 2024-05-07, 40 ratings at 4.47, loot boxes flagged (iOS age rating is 13+). iOS IAPs: 1 Key $0.99, 20 Keys $15.99, Zombix Pass $4.99, kits $0.99–$19.99. Version 5.0 on Oct 26 and 5.01 on Oct 28, 2026. AppGoblin: 4.8M installs, 220K MAU, <$10K/month, +14K/month. RuStore "Berzerk Games", v5.01. Discord 7,458 members, est. 10 Jun 2020. Telegram about 4,004 subscribers. Other titles (Desert Pixel Online, Custom Cats Online, Spell Crit: Idle MMORPG) on the GP developer page. Flag recipe (50 leather, 100 glue, 100 wood), 1-hour invulnerability, 50% resource scatter, 2 generators and 4 turrets per flag. Generator recipes and the 60-minute sidecar timer. Turret HP and recipes, and the General price of 350 since April 2023. Wall HP and costs (500/25 wood, 2,500/25 metal, 5,000/15 gold). July 2024 turret change 33→26 (#101, 2024-07-01). Storage and workbench costs. 2022 character drop rates. Injector XP values. Boss 45,000 HP. Clan XP every 30 min at Survivor Bases. Clan creation at 1,500 coins. Forum vote counts (friends tab 91, marketplace 92, Albion-style windows 12). Dec 2022 clan overhaul (#13, 2022-12-26). Server 4 beta and launch dates. Arena rules (#47–#63). Sept 2024 QoL patch (#131). Mini-Tarkov draft (#115). Hosting post (#194). Forum opening (#216). Replay system plan (#212). The YouTube video titles and channels, and the Cosmi raid date and 1.5-hour length.

**Changes made:**
1. **Server 4 population** — corrected. It is not a player estimate of "30–50 in total". In #175 the dev says "maybe 30 players" play server 4 during active hours.
2. **EN wiki "4 servers" in Feb 2021** — corrected. The 2021 revisions say 3 servers. "4" was added in a Dec 2025 edit, which is consistent with server 4 launching in Oct 2023.
3. **Nov 2024 ban wave** — corrected. #150 is "Ban-wave #1 (884)": 714 *characters* were barred from the arena for AFK farming (not "bots banned"), 4 multi-account permanent bans could be unlocked for 1,000 gems, and 166 zombuck balances were zeroed. Design implication 12 was reworded to match.
4. **Auto-aim removal "in 5.0"** — corrected. Auto-aim in manual fire was proposed in May 2026 (#211). On 28 Oct (#223) the dev said it *would be* removed from servers 1–3 in the follow-up patch. It was not part of 5.0 itself.
5. **5.0 Survivor Base map "shows owner and output"** — corrected. #221 says the clan name, flag and generated resource were not yet shown and would be added in a later patch. The forum bug report agrees.
6. **Server 4 tap-to-move / select-target "experimented"** — downgraded. #175 only proposes the experiment, so whether it shipped is marked (unverified).
7. **Arena "got about 10% of players"** — reworded. In #158 the dev uses 10% as an illustrative ("условно") figure, not a measurement.
8. **RPG recipe** — corrected from "35 gears" to "35 big nuts (Большая гайка)" per the RPG wiki page.
9. **Wood per tree** — corrected from 5–7 to 6–7 per the Топор page. The arena axe's "5 wood per hit" is a separate mechanic.
10. **Motorbike generator timer** — flagged. The Генератор page says 25 min, but the Мотоцикл page says 45 min.
11. **Abundance "alongside each battle-pass season"** — marked (unverified). The account-price post gives no currency, so "RUB" is now labelled as presumed.
12. **"50 generators solo" YouTuber claim** — marked (unverified). There was no transcript or search budget to check it.
13. **Clan-creation cost "1,000 in 2021"** — reworded to "per the old wiki", because the wiki page is undated. A garbled phrase ("1,500 per players") was also fixed.

**Not independently re-checked:** the Stalk-X Online question (no search budget, although the GP developer page lists only the four MMORPG Dev titles above), the Home Zone map-square and mob-level details, the 2021 weapon recipes beyond the AK-47, RPG and sniper, the Trader's repair-kit price (the wiki gives both 350 and 750), YouTube view counts, and server 3's regional split. The GameBrain summary does support "not pay-to-win" praise and "lack of tutorial", but it does not mention the UI.

**Overall reliability: high.** The numbers, recipes, dates and store data that drive design and business decisions held up against primary sources. No fabricated claims were found. The errors were overstatements of dev intentions as shipped features (auto-aim removal, the 5.0 map, the server 4 experiments), one misattributed population figure, a misdated wiki claim, and small recipe slips.

---

## Sources

- [Google Play listing (EN, RU), fetched 2026-11-07](https://play.google.com/store/apps/details?id=com.ZombixDev.ZombixOnline)
- [Google Play: MMORPG Dev developer page](https://play.google.com/store/apps/developer?id=MMORPG+Dev)
- [App Store listing: IAPs, version history, reviews](https://apps.apple.com/us/app/zombix-online/id6482997204)
- [iTunes lookup API (release date, seller)](https://itunes.apple.com/lookup?id=6482997204)
- [RuStore listing](https://www.rustore.ru/catalog/app/com.ZombixDev.ZombixOnline)
- [Trashbox listing](https://trashbox.ru/link/zombix-online-android)
- [AppGoblin app page (estimates, SDKs)](https://appgoblin.info/apps/com.ZombixDev.ZombixOnline)
- [GameBrain review summary](https://gamebrain.co/game/zombix-online-survival)
- [BlueStacks listing](https://www.bluestacks.com/apps/casual/zombix-online-on-pc.html)
- [Official site](https://zombixonline.com) and [web shop](https://shop.zombixonline.com)
- [Official Discord listing](https://discord.com/servers/zombix-online-official-720251932710666261)
- [Official Telegram news channel (dev posts 2022–2026)](https://t.me/s/zombixnews). Key posts: [#13 clan system](https://t.me/zombixnews/13), [#37 server 4](https://t.me/zombixnews/37), [#47](https://t.me/zombixnews/47)/[#55](https://t.me/zombixnews/55)/[#62](https://t.me/zombixnews/62) Arena, [#101 turret rules](https://t.me/zombixnews/101), [#115 mini-Tarkov](https://t.me/zombixnews/115), [#131 Sept 2024 patch](https://t.me/zombixnews/131), [#150 bans](https://t.me/zombixnews/150), [#158 arena retrospective](https://t.me/zombixnews/158), [#175 netcode](https://t.me/zombixnews/175), [#194 hosting](https://t.me/zombixnews/194), [#202 dev's other games](https://t.me/zombixnews/202), [#211](https://t.me/zombixnews/211)/[#212 roadmap](https://t.me/zombixnews/212), [#221–223 patch 5.0](https://t.me/zombixnews/221)
- [Official feedback forum (Featurebase)](https://zombix.featurebase.app) and [fish-spoilage post](https://zombix.featurebase.app/p/ryba-portitsya-so-vremenem)
- Russian Fandom wiki: [main page](https://zombix-online.fandom.com/ru/wiki/Zombix_Online_вики), [Персонажи](https://zombix-online.fandom.com/ru/wiki/Персонажи), [Флажок для базы](https://zombix-online.fandom.com/ru/wiki/Флажок_для_базы), [Генератор](https://zombix-online.fandom.com/ru/wiki/Генератор), [Турель](https://zombix-online.fandom.com/ru/wiki/Турель), [Деревянная стенка](https://zombix-online.fandom.com/ru/wiki/Деревянная_стенка), [Золотая стенка](https://zombix-online.fandom.com/ru/wiki/Золотая_стенка), [Хранилище](https://zombix-online.fandom.com/ru/wiki/Хранилище), [Верстак](https://zombix-online.fandom.com/ru/wiki/Верстак), [Грядка](https://zombix-online.fandom.com/ru/wiki/Грядка), [Зомби](https://zombix-online.fandom.com/ru/wiki/Зомби), [Босс](https://zombix-online.fandom.com/ru/wiki/Босс), [Задания](https://zombix-online.fandom.com/ru/wiki/Задания), [Сезоны](https://zombix-online.fandom.com/ru/wiki/Сезоны), [Ремонтный набор](https://zombix-online.fandom.com/ru/wiki/Ремонтный_набор), [Топор](https://zombix-online.fandom.com/ru/wiki/Топор), [Обычная удочка](https://zombix-online.fandom.com/ru/wiki/Обычная_удочка), [Газировка](https://zombix-online.fandom.com/ru/wiki/Газировка)
- English Fandom wiki: [Zombix Wiki](https://zombix.fandom.com/wiki/Zombix_Wiki), [Gold Wall](https://zombix.fandom.com/wiki/Gold_Wall), [Sunny](https://zombix.fandom.com/wiki/Sunny), [Starting Off](https://zombix.fandom.com/wiki/Starting_Off)
- YouTube (metadata only, no transcripts):
  - [Pryszard walkthrough, 22K views, 2020](https://www.youtube.com/watch?v=9ViBSO54AEI)
  - [RUFFY "survival from zero", 11.5K, 2022](https://www.youtube.com/watch?v=-2HMZelFRig)
  - [STALEVAR pet review, 10.8K, 2021](https://www.youtube.com/watch?v=6P1Lip5RlEs)
  - [Disti skills guide, 2.8K, 2023](https://www.youtube.com/watch?v=BtYScTO1I78)
  - [Tim_Ruru "New Raid Ways", 2021](https://www.youtube.com/watch?v=L3LHVyzOd4A)
  - [Tim_Ruru raid tips, 2021](https://www.youtube.com/watch?v=FbjXLYBB05E)
  - [Cosmi "Raid On American Bases", 2024](https://www.youtube.com/watch?v=AWFQt35Csfc)
  - [Ryo AM "Europe raid vs 100+ mercenaries", 2024](https://www.youtube.com/watch?v=HxOhC0Zi36w)
  - [NlCK-name base capture guide, 2026](https://www.youtube.com/watch?v=18uyjFeqAO4)
  - [FASBET weapon tier list, 2026](https://www.youtube.com/watch?v=5yFpD-9kx84)
  - [FASBET character tier list, 2026](https://www.youtube.com/watch?v=BSZF6t5H8G8)
  - [NlCK-name update 5.0 overview, 2026](https://www.youtube.com/watch?v=9TNHapL3lyo)
  - [Verdus Survivor Bases guide (ES), 2024](https://www.youtube.com/watch?v=BYiBKSae85w)
