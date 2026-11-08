# Last Day on Earth: Survival: How the Game Works (systems teardown, Nov 2026)

**Scope:** The full systems design of *Last Day on Earth: Survival* (LDoE) by Kefir!, as it stands at version **1.53.x (27 Oct – 6 Nov 2026)**. It covers the FTUE, meters, gathering, crafting, stations, world map and energy, locations, enemies, combat, death, vehicles, pets, NPCs, endgame, update history, and the core loop at every time scale.

**Method and caveats**
- **Main source: the LDoE Fandom wiki.** Its HTML pages returned HTTP 402/403 to the fetch tool, so I read the wikitext directly through the wiki's MediaWiki API (about 120 pages, accessed 2026-11-07). The wiki's [Version page](https://last-day-on-earth-survival.fandom.com/wiki/Version) lists releases up to 1.53.0 (27 Oct 2026). The 1.53.2 patch (6 Nov 2026) is recorded on the [Version/1.53.0](https://last-day-on-earth-survival.fandom.com/wiki/Version/1.53.0) subpage and matches the App Store listing. Many individual articles still carry 2017–2020 text, so I flag stale items.
- **Cross-checks:** the Apple App Store listing and Kefir's official Helpshift FAQ.
- **What I could not reach:** Reddit (the fetch tool blocks it), YouTube view counts and transcripts (only titles and channels came through oEmbed), and market-intelligence sites (Google Play, AppMagic and APKPure returned empty pages or 403s). The shared web-search budget for this run also ran out partway through. See *Gaps* at the end.
- **Labels:** Everything prefixed **Inference:** is my analysis. Everything else is sourced.

---

## 1. One-paragraph summary

LDoE is a top-down, isometric, **mostly single-player** survival-crafting game. Its spine is a loop: you **build a home base on a fixed 20×18 tile plot** ([Home](https://last-day-on-earth-survival.fandom.com/wiki/Home)), then make short **instanced runs** to locations picked on a **global map**. Each run is limited by a regenerating **Energy** meter and by fuel. You bring raw materials home and feed them into **timer-based workstations** that turn them into tiered materials, which unlock better tools, armor, weapons, walls and vehicles.

Progression used to be gated by player level and craft points. Today it is gated by a **quest chain (Survivor's Path)** and by an **endgame currency (Infected Genome)** you spend in the **Genesis Collection** ([Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints)).

Real-player interaction is walled off:
- **The Crater** (multiplayer city, PvP, clans) requires **level 100 plus a quest** ([Kefir FAQ](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/126-i-want-to-play-with-other-survivors-what-should-i-do/)).
- **Base raiding** requires **level 150**. The wiki says it is asynchronous and only against AI or mirrored bases ([Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System)).

Live-ops content arrives roughly every 2–4 weeks: **21-day seasons**, an **event calendar**, and region expansions.

---

## 2. First-time user experience (Survivor's Path)

Since 1.20.9 (Aug 2023) the tutorial is the **Survivor's Path**, a multi-chapter quest book with **free and premium reward tracks**. Premium is bought separately from the season pass, and there are also 30-day "Ultra / Ultra Plus" subscriptions worth +10% or +20% XP, and no ads on Plus ([Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path)). Since 1.50.0 it has two tabs:
1. **Survival track:** adaptation, base, regions, bosses.
2. **Settlement track:** expeditions, drone.

**Opening minutes** ([Chapter "New beginning"](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_New_beginning), [Home](https://last-day-on-earth-survival.fandom.com/wiki/Home)):
1. **Spawn on a pre-built ruin.** It has L2/L3 walls and floors, a campfire, a Small Box, and an **unfinished Chopper and CB Radio** that act as visible long-term goals.
2. **"Settling In":** search the old pickup, equip the bat, kill a zombie, loot the body, eat berries.
3. **"Clean Home":** collect logs, limestone and fiber. The home plot holds about 20 pine trees, 7 limestone rocks, 5 iron rocks, 7 berry bushes and 20 fiber plants, and none of them respawn.
4. **"Restoration":** open the skill screen, craft a hatchet (3 log + 3 limestone), build a floor and walls, build a Small Box.

**Chapter "True friend"** ([template](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_True_friend)) moves the player outward:
1. Craft a pickaxe and backpack.
2. Exit to the **global map**.
3. Loot suitcases at the one-time **Crash Site** and pick up a **puppy**.
4. Build the **Dog Crate** and **Woodworking Bench**.
5. Visit **Pine Bushes** (kill 3 wolves).
6. Unlock the **Campfire / Meat Dryer**.

Each quest awards **blueprints**: Spear, Garden Bed, Woodworking Bench, Dog Crate, Bandages, Rain Catcher, clothing and more. Premium rows add items such as a Glock, Katana, Reanimator, reinforced armor, and higher-rank puppies.

Later chapters follow in order: *Powershot* (Gunsmith Bench, mods), *Iron Warrior* (Chopper, Recycler, Medical Table, Farm, Bunker Alfa, Police Station), *North*, *Off To New Shores*, *Islands*, *Heavy Machinery*, *Operation "Dead Water"* (added 1.51.1).

**Built-in safety nets**
- **Daily inbox:** 3 water and 3 canned beans per day until level 100 ([Inbox](https://last-day-on-earth-survival.fandom.com/wiki/Inbox)).
- **Death rewards:** a free Machete on the 5th death and a Glock on the 100th ([Death](https://last-day-on-earth-survival.fandom.com/wiki/Death)).
- **Level-up heal:** every level-up fully heals ([Health](https://last-day-on-earth-survival.fandom.com/wiki/Health)).

**Inference:** The FTUE is strong for one reason. It shows the end-state up front (a broken chopper in your yard) and then turns each early verb (chop, mine, build, travel, tame) into a one-screen quest. The premium column sits next to every free reward from minute one, and that is the start of the monetization pressure the developer complained about.

---

## 3. Survival meters and status effects

| Meter | Mechanics (sourced) |
|---|---|
| **Health** | 100 base, up to 120 with the *Bruiser* skill. Healed by food, bandages (40), First Aid Kits (100), and fully restored on level-up ([Health](https://last-day-on-earth-survival.fandom.com/wiki/Health)). |
| **Hunger / Thirst** | 0–100 scale. Testers measured roughly −1 point per 10 s. A warning icon appears at 20. At 0 you take damage: the [Hunger](https://last-day-on-earth-survival.fandom.com/wiki/Hunger) page says 2 HP/s, while the [Status Effects](https://last-day-on-earth-survival.fandom.com/wiki/Status_Effects) page says 5, so the sources disagree. The meters do **not** drain on the global map ([Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map)); an older FAQ says they do, so this is unverified. |
| **Cleanliness** | Drops over time, and sharply from Toxic Spitter spit or urinating. At red you **cannot sneak** and enemies detect you from farther away. Fixed by a Shower or by dying ([Cleanliness](https://last-day-on-earth-survival.fandom.com/wiki/Cleanliness)). |
| **Pee** | Drinking speeds it up and beer forces it. At red you walk very slowly. Peeing costs cleanliness and briefly disables attacking ([Pee](https://last-day-on-earth-survival.fandom.com/wiki/Pee)). |
| **Regional effects** | Cold in the North (fur armor, alcohol, heat sources), Radiation in the Bogs (Hazmat/CBRN, AntiRad; it also caps max HP), Spores on the Islands (Inhaler; drains HP and armor durability), plus Poison, Bleeding and Electrification ([Status Effects](https://last-day-on-earth-survival.fandom.com/wiki/Status_Effects)). |

- **Death resets every meter.** Players exploit this by dying at home to reset hunger, thirst and stink, because the corpse there is easy to recover ([FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ)).
- **Inference:** The meters are pacing taxes, not drama. They push you to build a Garden Bed and Rain Catcher early, and after that they rarely matter. Each region instead adds one environmental meter that gates its own gear set.

---

## 4. Resources, tiers and gathering

**Tools.** Hatchet for trees, pickaxe for rocks, iron versions later. Tools do not need to be equipped. They are used up in inventory order and break with durability ([FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ)). Stacks hold 20, except scrap and coupons at 50.

**Raw → processed tiers** (from [Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace), [Workbench](https://last-day-on-earth-survival.fandom.com/wiki/Workbench), [Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench)):

| Family | Tier progression | Where it is found |
|---|---|---|
| Wood | Pine log → pine plank; Oak (3 logs → plank); Ash (5 logs → plank); charcoal from logs or planks | Home plot, Pine zones, North (oak), Bogs (ash) |
| Stone | Limestone → stone brick → brick (L5 walls) | Limestone zones |
| Metals | Iron ore or 4 scrap → iron bar (4 min) → iron plate (20 min) → nails; bauxite or aluminium wire → aluminium bar → plate (1 h) → bolts; copper (5 ore → bar, 1 h); steel bar → plate (1.5 h); titanium (1.5 h), lead (1.51) | Limestone Cliffs (iron), later regions, Recycler |
| Fabric | Plant fiber, rope, cloth → thick fabric; rawhide → leather; fur (North) | Zones, animals |
| Parts | Bolts, wiring, rubber parts, duct tape, adhesive, ball bearings, engine parts, gun oil, factory parts | Loot containers, Recycler, bunkers |
| "Unobtainable" | **Tungsten bar** is still missing from the game: the wiki's Blueprints page (edited 27 Oct 2026, so 1.53) marks every tungsten recipe "Not Craftable". That covers the Tactical Backpack, AK-47, VSS Vintorez, The Dragunov, the Shotgun and the Assault armor set, and the Tungsten Bar page also lists the Mi-24 helicopter and the 6th Police terminal as "supposedly" needing it ([Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints), [Tungsten Bar](https://last-day-on-earth-survival.fandom.com/wiki/Tungsten_Bar)) | — |

**Node respawn**
- **Home-plot resources never respawn.**
- **Resource zones fully regenerate whenever you leave.** You can re-enter and farm again, and death also resets them ([FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ), [Death](https://last-day-on-earth-survival.fandom.com/wiki/Death)).
- Example yield, *Pine Bushes* (green): 27 pine trees giving about 51 logs (the wiki's figure; its other zone pages count 3 logs per pine tree, which would give about 81) (unverified), plus loose logs, limestone, 20 fiber, 10 berry bushes and 1–3 stashes, for about 2,050 XP if fully cleared.
- Example yield, *Limestone Cliffs* (yellow): 30 iron rocks giving about 90 ore, which is 500% more than the green Ridge ([Limestone](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires)).

**Ways to skip the gathering verb**
- **Auto Mode** (default skill): auto-harvests and auto-attacks. Players fill their backpack with split stacks so it only picks up the item they want.
- **Rations** (premium consumable): "auto-clear" a farmable location and drop the computed loot into the inbox with zero risk ([Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations)).
- **Late-game extractors**: ore extractors (1.36), sulfur/lead extractors (1.49), and drilling rigs in the Bogs that must be defended ([Kefir FAQ – Boggy](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1284-boggy-region-and-its-secrets/)).

**XP sources.** XP comes from harvesting and kills, not crafting. Each level grants **1 skill pick out of 3 random choices**, and a re-roll costs 10 coins. There are 7 active skills (Auto Mode, Sneak, Sprint, Roll, Self-Heal, Look Around, Animal Friend) and about 37 passives, such as Lumberjack +2%/level, Camel and Strict Diet −2% drain per level, Walker −3% map walk time, and Burglar lockpicking. The level cap was 200 (later 209) ([New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills)).

---

## 5. Crafting tree and how recipes unlock

- **2017–2022:** recipes unlocked by **player level + Craft Points**. 178 points existed in v1.16.4, and the system was removed in 1.18.14 in March 2022 ([Craft Points](https://last-day-on-earth-survival.fandom.com/wiki/Craft_Points)). Old item pages still show this, e.g. "Workbench: Level 28, 2 craft points".
- **Now:** only the Hatchet, Pickaxe, Basic Backpack and Small Box are available from the start. **Every other blueprint unlocks by finishing a specific Survivor's Path quest** or by **buying it in the Genesis Collection** with Infected Genome ([Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints)).

| Quest (examples) | Unlocks |
|---|---|
| Resource collecting / Preparation | Spear, Garden Bed, Woodworking Bench, Dog Crate |
| Exploring the Grounds | Melting Furnace, Bow |
| Home Comfort | Workbench, reinforced clothes, Cat Playpen / Cat Tree |
| Limestone Cliffs | Iron Hatchet / Iron Pickaxe |
| Crooked Creek Farm | Recycler, Shovel |
| Police Search | Medical Table, First Aid Kit |
| Bunker Alfa / Chopper | Electric Generator / Buzzsaw, Skull Crusher, Garage |
| Northern Watchtower | Tactical armor set |
| New Home / Storehouse / Intruders | SWAT armor / Kevlar armor + Land Mine / **C-4** |
| Lost assistant · Got connection · New responsibility · Toxic water · Alternating Current | Glock 17 · M16 · AK-47 · VSS · Dragunov (the AK-47, VSS and Dragunov blueprints unlock but can't be crafted, because they need the unobtainable Tungsten Bar) |
| Genesis Collection (purchase) | Flamethrower, Repair Station, Chainsaw, Portable Turrets T-I/II/III, Robodog dock, Protector, Resonator |

**Two-phase builds.** Many big items work this way: craft a "design" or frame, place it, then **finalize** it by depositing a long parts list. The Chopper, Dog Crate, ATV, Motorboat, Drone and Gunsmith Bench all do this ([Chopper](https://last-day-on-earth-survival.fandom.com/wiki/Chopper), [ATV](https://last-day-on-earth-survival.fandom.com/wiki/ATV)).
- **ATV finalization alone:** 250 rubber, 150 air filters, 16 ATV wheels, 200 steel plates, 30 gas cylinders, 10 transmissions, 200 carbon composite, 60 car batteries, 200 engine parts, 200 cogs.

**Crafting quality-of-life.** You can craft from the storages near you; the [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) page confirms this. The 1.20.12 notes only mention *repainting* with resources from nearby storages, so the version this arrived in is (unverified). A quantity slider arrived in 1.41, and a **"Fill" button** that pulls a recipe's inputs from base storage arrived in 1.53 ([Version 1.53.0](https://last-day-on-earth-survival.fandom.com/wiki/Version/1.53.0)).

**Weapon modifications**
- Built at the Gunsmith Bench from mod blueprints (common, rare, extremely rare) and recycled parts.
- **Stat steps:** each "+" step on a mod is about +5% damage or speed. Some mods add **active abilities** with cooldowns, e.g. Baseball Bat "Slugger with Thorns" adds bleed, Machete "Gut hook" slows enemy attacks ([Weapon Modifications](https://last-day-on-earth-survival.fandom.com/wiki/Weapon_Modifications)).
- **Recycler:** breaks items into parts. It has six recycling skills (to level 50), and item durability scales the drop odds ([Recycler](https://last-day-on-earth-survival.fandom.com/wiki/Recycler)).

---

## 6. Workstations and timers

| Station | Key facts |
|---|---|
| Campfire / Meat Dryer / Kitchen stove | Cooking. Fuel burns: log 2 min, plank 3 min, charcoal 5 min 20 s; recipes take 2–40 min ([Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire)) |
| Garden Bed / Rain Catcher | Carrots in 1 h. Rain Catcher refills 1 bottle per 10 min ([Rain Catcher](https://last-day-on-earth-survival.fandom.com/wiki/Rain_Catcher)) |
| Melting Furnace | Max 2 per base; 20-stack input, output and fuel; upgradable to L3 with blueprints (1.30.1) |
| Woodworking Bench / Stonecutter | Planks and bricks, 4 min – 1 h recipes |
| Workbench | Plates, nails, bolts. Needs a Plank (L2) floor; max 2 |
| Tanning Rack / Sewing Table | Leather, thick fabric |
| Gunsmith Bench, Recycler, Medical Table, Chemistry Station, Laboratory, Repair Station | Mid and late game |
| Specialized storage | Fridge, Fish Fridge, Storage for Explosives / Parts / Alloys, Cargo Shelving, Weapon Rack, Tabletop Food Pantry. Upgrade blueprints are sold in the Genesis Collection ([Genesis Collection](https://last-day-on-earth-survival.fandom.com/wiki/Genesis_Collection)) |
| Animal farms | Turkey Coop (1.48), Caiman Farm (1.49), Boar Farm (1.53) |

- **Timers run in real time while you're away.** A notification fires when a bench finishes ([Settings](https://last-day-on-earth-survival.fandom.com/wiki/Settings)).
- **Coins skip timers** ([Coins](https://last-day-on-earth-survival.fandom.com/wiki/Coins)). VIP 3/5/9 adds +10% workbench speed per tier ([VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone)).
- **Benches double as storage.** Most cap at 2 per base.

---

## 7. Base building (detailed, because it is the hardest pillar)

**Plot**
- **Size:** 20×18 tiles, 340 of them buildable, with the pickup truck taking 20 ([Home](https://last-day-on-earth-survival.fandom.com/wiki/Home)). The wiki also says "396 total tiles", but that doesn't add up: 20×18 = 360 = 340 + 20. The plot has since been widened (outer area in 1.49, debris in 1.50 and 1.53), so its current dimensions are (unverified).
- **Expansion (1.50, Jul 2026):** players who started after 1.50 begin with **66 debris patches (2×2), covering 264 tiles**, versus 9 for older accounts. Clearing debris costs resources plus **Site Plans**, bought for 100 Infected Genome each in the Genesis Collection ([Site Plan](https://last-day-on-earth-survival.fandom.com/wiki/Site_Plan)). 1.53 added 18 more debris on the north-east edge.

**Grid rules**
- **Floors first.** Walls, doors and windows sit on floor edges, and a wall can only be upgraded if its floor is at an equal or higher level ([Wall](https://last-day-on-earth-survival.fandom.com/wiki/Wall)).
- **Workstations need minimum floor tiers.** For example, the Workbench needs an L2 floor and the ATV design needs L3.
- **Furniture** has fixed footprints (1×1 up to 4×3) and 1–4 rotation states.
- **Removing parts:** until 1.53, walls and floors could only be deleted with no refund. 1.53 lets you return them to inventory.

**Tiers**

| Lvl | Wall cost | Floor cost | Horde interaction | Breach tool (raids) |
|---|---|---|---|---|
| 1 | 1 pine log | 1 pine log | Breaks on contact | Stone hatchet |
| 2 Plank | 5 brick + 10 plank | 5 brick + 5 plank | Deals 50 damage to zombies; can fall | Iron hatchet |
| 3 Stone | 15 brick + 10 oak plank | 15 brick + 10 iron plate | Deals 100 damage; horde can't break it | C-4 |
| 4 Metal | 20 steel plate + 15 alu plate | 15 steel + 20 iron plate | Immune | Metal Cutter (released in 1.53 only as a Cult Hunting event item for cult-camp iron walls; whether it works on regular raid targets is (unverified)) |
| 5 Brick | 20 brick + 10 steel plate | 20 ash plank + 10 titanium bar | Immune | None (indestructible) |

Sources: [Wall](https://last-day-on-earth-survival.fandom.com/wiki/Wall), [Floor](https://last-day-on-earth-survival.fandom.com/wiki/Floor), [Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System). Doors cost more than walls; windows cost the same as walls.

**Threats to the base**

**1. The Horde.** It arrives every 24 h, crossing the plot top to bottom. It only damages walls (never floors, benches or chests). It does less damage when you're offline. Killing the **Witch** in the Infected Forest and burning her head as a totem pauses hordes ([The Horde](https://last-day-on-earth-survival.fandom.com/wiki/The_Horde), [Kefir FAQ](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/140-how-do-i-stop-the-horde-approaching-my-base/)).

**2. Raid retaliation.** If you shortchange the Raiders, three SWAT-armored NPC raiders hit your base 2 h later. They can't break L4/L5 walls and blow up at most 4 stone walls. Raiding also turns on a *Threat of Attack* window during which "other survivors" (AI) may raid you. One wiki editor reported in 2018 that this happens at most once a day; no newer source confirms it ([Threat Of Attack](https://last-day-on-earth-survival.fandom.com/wiki/Threat_Of_Attack)).

**3. "Base Power" defense mode (1.53, Halloween 2026).** This is the *Signal Scanning* quest inside the **Cult Hunting** Halloween event, which the wiki lists as 11 days long. It is not confirmed as a permanent mode ([Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting)).
- **Base Power** is the sum of everything placed. A chest or stove is worth 1. Walls are worth Simple +5/50 HP, Wood +10/100, Stone +15/150, Iron +20/200, Reinforced +30/300.
- **Signal Scanning:** a radio scan triggers **timed waves from N/E/S/W**, 25–93 enemies over 1–3 minutes, with a recommended Base Power from 165 to 750.
- **Defensive structures:** delivered to the inbox daily (4 Thorns, 1 Friend, 1 Slicer). Thorns, Friend (turret) and Slicer (propeller) each have their own HP and a limit of 10; the wiki lists damage only for Thorns.
- **Repair:** destroyed pieces are **restored after each scan**. There are 3 scans a day.
- **Paid extras:** mortar "air support" costs 100 coins, and 3 more attempts cost 100 coins ([Signal Scanning](https://last-day-on-earth-survival.fandom.com/wiki/Signal_Scanning)).

**Emergent player design**
- **Honeycomb bases:** a grid of 1×1 cells, each holding one chest or bench. Every wall broken earns the raider noise but reveals very little loot ([Honeycomb](https://last-day-on-earth-survival.fandom.com/wiki/Honeycomb_Base_Design)).
- **Doormat placement:** a walled-in doormat makes a safe respawn spot.
- **Bait boxes:** a "bait" box outside the walls, stocked with modest loot, coaxes AI revenge raiders into leaving footprints that you can counter-raid.

**Second base: the Settlement (Act II, added in 1.19.4).** The 1.20 notes (Dec 2022) are where room construction, water and electricity first appear. It has rooms (Storehouse, Woodshop, Foundry, Assembly, Workshop), **generators, wiring and water pipelines** that must reach the benches, and buildings with 3–4 levels (Barracks, HQ, Wall, Garage) ([Settlement](https://last-day-on-earth-survival.fandom.com/wiki/Settlement)).

**Inference: verdict on LDoE base building**
- It is a **storage-and-production layout puzzle with a cosmetic defense layer**. For most of its life the only real threat was a daily horde that L3 walls solve forever, plus async AI raids.
- 1.53's Base Power waves are Kefir's first attempt to make the layout matter tactically. So far they are only an event activity, and they reset afterward, so nothing is ever lost.
- What worked: a readable tier ladder where each wall tier maps one-to-one to a breach tool, floors gating stations, and the honeycomb meta.
- What failed: no stakes, no reason for other humans to ever see your base, and expansion gated behind endgame currency.

---

## 8. World map, energy and travel

- **Exit to the map** by walking off any edge. The map shows **Walk / Run / Drive** per destination ([Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map)).
- **Energy budget:** max **200** (raised from 100 on 19 Mar 2020 as a COVID gesture and never reverted). It refills **1 point per 5 min**, so a full refill takes 16 h 40 min ([Energy](https://last-day-on-earth-survival.fandom.com/wiki/Energy)).
- **Example costs:** running to Pine Bushes costs 15 energy (or a 12-min walk). Bunker Alfa costs 31 (27 min walk). Blackport PD costs 51 (46 min walk) ([Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa), [Blackport PD](https://last-day-on-earth-survival.fandom.com/wiki/Blackport_PD)).
- **Energy sinks and sources:**
  - **Walking** is free but slow, and you can speed it up mid-walk with energy.
  - **Ads:** +15 each, up to 5 per day.
  - **Rations:** a premium item that refills energy and replaced coins for this in 1.20.12.
  - **Healer:** gives an ad-based +140.
  - **VIP:** cuts travel cost by up to −50% at Prestige ([VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone)).
  - **Walker skill:** walk time −3% per level.
  - **Vehicles:** travel on gasoline instead.
- **Airdrops:** up to **3 per day**, spawning as you spend energy below 140, 80 and 20. They give one crate guarded by spitters and a bloater, with AI survivors arriving at the 5- and 10-min marks ([Airdrop](https://last-day-on-earth-survival.fandom.com/wiki/Airdrop)).
- **Safe time:** the map screen is safe. You can craft, eat and re-gear there, and leaving a zone despawns hostile AI survivors and event-spawned mobs.

**Inference:** Energy is the master session timer. It stops players from chain-farming and creates "come back in 8 hours" pressure, and every way around it (rations, VIP, ads) is monetized.

---

## 9. Locations and danger tiers

**Threat levels.** Locations show **1–3 skulls**, which the community calls green, yellow and red. Zones also carry **level gates**: Pine Grove and Limestone Cliffs need L10, the Farm and North need L15, Bunker Alfa needs L40.

**Map halves**
- **The Wasteland:** single-player, with almost all content.
- **The Crater:** multiplayer ([Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map)).

**Reset types**
- Resource zones reset whenever you leave.
- Bunker Alfa and the Farm reset 48 h after you enter. Blackport PD resets every 3 days.
- Events vanish on a timer.
- Ground-floor storage in Bunker Alfa never resets: it has 7 lockers, 140 slots in all, and players use it as remote storage.

| Location (current name) | Type and how it works |
|---|---|
| Pine Bushes / Grove; Limestone Ridge / Cliffs / Spires | Farmable resource zones, tiers 1–3. *Pine Wood* was replaced by the **Abandoned Factory** in 1.19.4 |
| **Crash Site** (formerly "Crashed Plane") | Now a **one-time** FTUE location (puppy, 14+ suitcases); disappears 15 min after you leave ([Crash Site](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site)) |
| **Bunker Alfa** | Red, L40. Needs a CAC card A plus a passcode from soldier corpses or the CB Radio. Opening "for ads" added in 1.27. Four sub-floors with traps (lasers, gas, turrets, electric fences); damaged zombies regen between floors. Freed **Specialist** offers mods, **Hard Mode** (Exploders, The Blind One) and a reputation track with weapons ([Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa), [Specialist](https://last-day-on-earth-survival.fandom.com/wiki/Specialist)) |
| Bunker Bravo; (Bunker Charlie and Foxtrot inaccessible) | Card-gated dungeons |
| **Blackport PD** (the "Police Station") | Red. Unlocked by repairing the Eastern Watchtower. Up to **99 zombie waves** in the jail-yard arena. Four police-card tiers open loot crates (3–5 per reset), and Inspector crates hold extremely-rare blueprints and SWAT sets |
| **Crooked Creek Farm** | Red, L15, 48 h reset. Ravager boss, infected bulls, a locked chest you saw open while a horde attacks. Revised in 1.52 ([Farm](https://last-day-on-earth-survival.fandom.com/wiki/Crooked_Creek_Farm)) |
| Gas Station (VIP zone, Mechanic, Scout), Motel, Transport Hub, Port and Port Laboratory, Pier, Commune, Infected Forest | Hubs, dungeons and event venues |
| Regions behind watchtowers | **East** (L10; Blackport PD, Transport Hub, Greenwood Camping Park). **North** (L15; cold; daily tasks lead to the Ice-Trapped Ship boss Borealis). **Islands** (Motorboat; spores). **Bogs** (ATV only; radiation; Alpha Irradiator and **Leviathan**, 4,000 HP) ([Regions](https://last-day-on-earth-survival.fandom.com/wiki/Regions_on_Global_Maps)) |
| Scouting maps (1.47, now permanent) | Three of "the biggest locations in LDoE history". Drive your bike, find crates and load them into the trunk |
| NPC Survivor Bases | Red-roofed AI bases. Break walls with hatchets or C-4; they reset 1 h after a visit ([NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base)) |
| *Pine Hills* | **Could not verify this as an LDoE location name.** The closest are "Desolate Hills" and "Wooded Foothills". Possibly confused with another game |

---

## 10. Enemies and AI

| Enemy | HP / damage | Behavior |
|---|---|---|
| Roaming Zombie | 40 | Slow; you can outrun it |
| Fast Biter | 80 / 6 | Speed 43, about player speed; can't be outrun in poor shoes |
| Toxic Spitter | 80 / 6, spit 15 | Telegraphed cone spit. It **increases stink**, and spit and AoE hurt other zombies too |
| Floater Bloater | 240 / 10, slam 30 | Red circle telegraph, then a jump-slam |
| Toxic Abomination | 300 | Slam variant |
| Frenzied Giant | 500 / **200** | One-shots under-armored players; in Hard Mode it speeds up as it loses HP |
| The Big One (TBO) | 1,000 HP, 300 armor | Fast; mostly a "run away" encounter; the raid enforcer |
| Wolves, rabid wolves, bulls, bears, caimans | — | Animals; deer and turkeys flee |
| **AI Survivors** | 100 HP | Gather, hunt zombies, flee when hurt, **heal from their own inventory**, carry guns in red zones |
| Bosses | various | Witch, Ravager, Colonel, Borealis, Consilium, Leviathan, Alpha Irradiator, The Blind One, Doctor Dread, and more ([Bosses](https://last-day-on-earth-survival.fandom.com/wiki/Category:Bosses)) |

Sources: [Fast Biter](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter), [Toxic Spitter](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Spitter), [Floater Bloater](https://last-day-on-earth-survival.fandom.com/wiki/Floater_Bloater), [Frenzied Giant](https://last-day-on-earth-survival.fandom.com/wiki/Frenzied_Giant), [The Big One](https://last-day-on-earth-survival.fandom.com/wiki/The_Big_One), [AI Survivor](https://last-day-on-earth-survival.fandom.com/wiki/AI_Survivor).

**Senses** ([Minimap](https://last-day-on-earth-survival.fandom.com/wiki/Minimap)):
- Most zombies notice you at 50 units. Abominations and rabid wolves notice at 75. Spitters see up to 400.
- The minimap is a 100-unit-radius radar, and blip size hints at enemy size.

**AI weaknesses.** The "**wall trick**" is a long-standing exploit: zombies stand on the far side of a thin wall trying to hit you, and players dart out to strike. Kefir has acknowledged it in its marketing ([Wall trick](https://last-day-on-earth-survival.fandom.com/wiki/Wall_trick)). Exiting a zone or force-quitting resets fights.

---

## 11. Combat feel and controls

- **Controls:** virtual stick plus an action/attack button. Hold the button to keep attacking or harvesting. The left button toggles **Auto Mode**, the right toggles **Sneak**, and there are quick-slot "pockets" ([FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ), [New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills)).
- **Targeting:** 1.53 added **"tap to select a target"**, which the patch notes called long-awaited ([App Store](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)). **Inference:** before this, the game auto-targeted the nearest enemy.
- **Melee vs ranged:**
  - **Sneak attacks** from behind deal **3× damage** with melee only. Opening chests, looting or harvesting breaks sneak, and red stink disables it ([Sneaking](https://last-day-on-earth-survival.fandom.com/wiki/Sneaking)).
  - **Guns** are durability-expensive. Unsilenced shots raise **noise** in raids and summon TBO in red zones.
  - Weapons have damage, speed, range, crit and stability. Mods add actives.
- **Durability everywhere.** Weapons, tools and armor all wear out; armor loses durability when you take damage. Repair once didn't exist ("no way to repair" guns). It now comes from the **Repair Station**, which costs 3,600 genome plus 10 Borealis kills, or from the **VIP 5 repair bench** ([Repair Station](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station)). Auto-swap to the next weapon on break was added in 1.26.
- **Armor math:** damage reduction = A / (A + 50/3).
  - Normal clothes (8 AP): 32% DR
  - Tactical (24): 59%
  - SWAT (32): 66%
  - Kevlar (38): 70%
  - Assault (about 52): 76%, unconfirmed ([Armor](https://last-day-on-earth-survival.fandom.com/wiki/Armor_and_Armor_Points)).
- **Deployables:** Portable Turrets (max 3 per location), Land Mines, C-4, Molotovs. 1.53 added a buff system with icons under the HP bar.

---

## 12. Death and loot drop

- **On death** ([Death](https://last-day-on-earth-survival.fandom.com/wiki/Death)):
  - You drop **everything carried** on a corpse at the death spot.
  - You respawn at home or at your Doormat with all meters reset.
- **Recovering the corpse:**
  - Only the **most recent** corpse persists.
  - It is only recoverable if the location hasn't reset. Resource zones reset on death, so a death there loses the loot; bunkers keep it until their timer runs out.
- **Paid recovery:** restore the whole inventory, including vehicle trunk contents, for **100 coins or one ad per 24 h**. 1.52 (Sep 2026) re-promoted coin resurrection "so that you don't lose valuable loot".
- **Insurance:** the **Reanimator** auto-revives you within a 4 h window ([Reanimator](https://last-day-on-earth-survival.fandom.com/wiki/Reanimator)).
- **Stored items are safe:** items at Home and in the Settlement are safe. Kefir calls storage at other locations unsafe.

**Inference:** The death penalty is DayZ-like in theory and toothless in practice. Paid or ad recovery, corpse runs, and "die at home to reset meters" mean loss is mostly a monetization prompt rather than tension.

---

## 13. Vehicles, companions, NPCs

| Thing | Facts |
|---|---|
| **Chopper (bike)** | Arrives as an unfinished frame at home. Finalize with forks, wheels, a gas tank and 20 engine parts. 200 fuel, 4 trunk slots; rideable inside zones since 1.10.3. Required for Rest Stop and Junkyard. Upgraded at the Gas Station Mechanic since 1.47 ([Chopper](https://last-day-on-earth-survival.fandom.com/wiki/Chopper)) |
| **ATV** | The only vehicle for the Bogs. 500 fuel, durability, XP levels with 3 random "spec" choices, 4 module slots (tracks, ram, turret, winch), trunk 4→15 ([ATV](https://last-day-on-earth-survival.fandom.com/wiki/ATV)) |
| **Motorboat** | Built at home, then auto-operated from the Port to the Islands; 250 fuel, 4 slots ([Motorboat](https://last-day-on-earth-survival.fandom.com/wiki/Motorboat)) |
| Minivan, Drone, **Robodog** (1.51.6), Mi-24 | Expedition transport; combat and scanning drone with battery charges; a crate-hauling follower; a helicopter blueprint that can't be crafted yet |
| **Dogs** | 6 breeds. Breed puppies to Ranks I–IV. Up to 3 "walking on base" give passive traits, and only a Rank IV "True Friend" can follow you. Food timers keep them active ([Dog Crate](https://last-day-on-earth-survival.fandom.com/wiki/Dog_Crate)) |
| **Cats** (1.49) | 10 breeds × 13 coats. Growth takes 4 d 3 h, or **299 coins** to skip. Adults "hunt" at the Cat Tree for item finds ([Cat](https://last-day-on-earth-survival.fandom.com/wiki/Cat)) |
| NPCs | **Healer:** 1-h buffs for an ad. **Dealer Joe:** radio-summoned trades. **Raiders:** raid contracts. **Specialist:** Bunker Alfa. **Mechanic / Scout:** Gas Station. **Genesis:** endgame shop. Event traders take event tokens *or coins* ([Healer](https://last-day-on-earth-survival.fandom.com/wiki/Healer), [Dealer Joe](https://last-day-on-earth-survival.fandom.com/wiki/Dealer_Joe), [Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting)) |

---

## 14. PvP, raiding and multiplayer (how it actually works)

**Raiding**

**1. Unlock and setup.** Raiding unlocks at **level 150** ([Kefir FAQ](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/364-i-don-t-get-raiders-raiders-stopped-showing-up/)). You call Raiders on the CB Radio, and they give you **5 tasks** drawn from about 30, e.g. clear Bunker Alfa floor 3, craft 20 First Aid Kits, kill the Ravager. Each task can be skipped for 45–125 coins. After that you get an **8-hour window** to hit a marked base.

**2. Inside the target base.**
- **Noise meter:** breaking walls and furniture, unsilenced shots, and leaving and re-entering all add noise.
- **Thresholds:** zombie waves spawn at about 24, 46 and 72 noise, and **TBO at 100**.
- **One scout pass:** you get a single scouting visit before the raid.

**3. Afterwards.** The Raiders take a cut, scored by item value. Underpay them and they raid you. Your *Threat of Attack* timer also opens you to AI revenge raids, and those leave footprints you can counter-raid ([Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System)).
- **Real players or not?** The wiki states that in the Wasteland you raid and are raided **only by AI**. The original 1.7 notes (Jan 2018) promised attacks on "other survivors' bases", and the Workbench page mentions "Mirrored Survivor Bases". **Inference:** these are asynchronous snapshots or mirrors with no live owner, which matches the developer's experience that you rarely raid real people and nobody comes to raid you.

**The Crater**
- **Access:** level 100 plus a quest unlocks a separate second character with its own economy ([The Crater](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater)).
- **Economy:** Business Level grows by delivering items. PvP unlocks at Business Level 15 via "Nat the Fighter". There are **20-minute Crater Tournaments** (bronze, silver, gold; zombie-kill score races; 2 per day) and a player shop and rentals for Counterfoils ([Business Level](https://last-day-on-earth-survival.fandom.com/wiki/Business_Level), [Crater Tournaments](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater_Tournaments)).

**Clans and co-op (1.43.0, Dec 2025)**
- "Clans in the Wastelands" added **co-op runs** (FENA Tournament / Secret Subway). They take 2–4 clan members with Medic, Heavy Trooper or Sniper kits, and the kits consume "quantum batteries" ([Secret Subway](https://last-day-on-earth-survival.fandom.com/wiki/Secret_Subway)).
- 1.48 added a clan rating earned by finding fallen operatives' bodies in Wasteland locations.

**PvE raid prototype (1.53)**
- Cultist camps have tiered walls, and each tier needs a specific breaching consumable: **Assault Skull Crusher** for stone, **Metal Cutter** for iron, **Dynamite** for reinforced, plus Lockpicks and Bolt Cutters for caches.
- Tools are bought with event pendants **or coins (60–350)**: Iron Hatchet 60, Dynamite 100, Lockpick 175, Assault Skull Crusher 200, Metal Cutter 300, Bolt Cutter 350. New camp coordinates cost 200 coins. All of this belongs to the Cult Hunting event, and the breach tools are event-exclusive items ([Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting), [Dark Rituals](https://last-day-on-earth-survival.fandom.com/wiki/Dark_Rituals), [Metal Cutter](https://last-day-on-earth-survival.fandom.com/wiki/Metal_Cutter)).
- **Inference:** Kefir is iterating toward "raiding is fun". They're doing it entirely against AI, with breach tools as a coin sink.

---

## 15. Endgame and live ops

- **Genesis loop (since 1.30.1, Dec 2024):** do daily regional tasks, kill the regional boss for **Infected Genome**, then spend it in the **Genesis Collection** on blueprints, bench upgrades, skins and Site Plans.
  - Boss payouts: Borealis 300, Consilium 450, Leviathan 600.
  - Account cap: 5,000 ([Infected Genome](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Genome)).
  - Rations can auto-complete the dailies.
- **Other sinks:**
  - Bunker Alfa Hard Mode.
  - Blackport PD's 99 waves.
  - Port Laboratory.
  - **Expeditions:** three 40-stage auto-battlers with 13 levelable mercenaries ([Expeditions](https://last-day-on-earth-survival.fandom.com/wiki/Expeditions)).
  - Crater, raids, collections, cosmetics.
- **Seasons:** each lasts **21 days** with free and premium tracks ([Kefir FAQ](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/340-what-seasons-are-and-how-do-i-take-part-in-them/)). Season 89 (19 Mar–6 Apr 2026) had 80 levels plus an infinite tier, with premium rewards including a VSS, AK-47, Dragunov, SWAT, Kevlar and Raider armor, and energy drinks ([Season 89](https://last-day-on-earth-survival.fandom.com/wiki/Season_89)). Season 99 ran 13 Oct–2 Nov 2026, so Season 100 is presumably live now. The wiki's dates for Season 89 cover only about 19 days, so treat 21 days as the nominal length.
- **Event calendar:** recurring events of about 11 days each, each with its own **free and premium reputation track**. Examples: Fair, Hunter's Instinct, Leprechaun's Luck slot machine, Commune Trials, Headhunting, Scouting, Cult Hunting, VIP Marathon, Gold Rush. All share a **single 00:00 UTC daily reset** (1.28.0). A login daily bonus was added in 1.39.5 ([Event Calendar](https://last-day-on-earth-survival.fandom.com/wiki/Event_Calendar)).
- **VIP:** 10 levels plus "Prestige", reached at 2,400 points. Bonuses include −50% energy, +30% bench speed, +50% XP, an indestructible weapon for 1 h per day, and **auto-delivery of loot from neutral-location corpses and stashes to VIP storage** ([VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone)).

---

## 16. Major updates over the years (selected)

| Version (date) | Change |
|---|---|
| Launch, May 2017 | Anniversary events in May confirm the launch month ("9th anniversary" in 1.49, May 2026), and the wiki lists 1.0 on 27 May. No independent source was checked (unverified) |
| 1.6 (Sep 2017) | Northern region and watchtowers |
| 1.7 / 1.7.1 (Jan 2018) | **Raids** and C-4 |
| 1.7.12 (Mar 2018) | **Dogs** |
| 1.9.3 (Aug 2018) | Crooked Creek Farm |
| 1.11.5 (Jan 2019) | Skills overhaul (1 pick per level, cap 200) |
| 1.15 (Nov 2019) | Seasons era (S3), Bunker Bravo, ATV, fishing, **ration auto-clear** |
| 1.16.3 (Feb 2020) | **The Crater** MP city |
| 1.16.4 (Mar 2020) | Energy raised to 200 |
| 1.17.6 (Dec 2020) | Port and Motorboat |
| 1.17.9 (Feb 2021) | Crater PvP |
| 1.18.14 (Mar 2022) | Craft points removed |
| 1.19.4 (Aug 2022) | Settlement / Act II |
| 1.20 (Dec 2022) | Expeditions and mercenaries |
| 1.20.6 (May 2023) | Drone and Transport Hub |
| 1.20.9 (Aug 2023) | **Survivor's Path** |
| 1.20.12 (Sep 2023) | Energy refills with Rations |
| 1.30.1 (Dec 2024) | North rework and **Genesis Collection** |
| 1.35 (May 2025) | Island Region |
| 1.43 (Dec 2025) | **Clans and co-op in the Wastelands** |
| 1.47 (Mar 2026) | Permanent Scouting maps and bike upgrades |
| 1.49 (May 2026) | ATV modules and cats |
| 1.50 (Jul 2026) | **Home expansion via debris and Site Plans** |
| 1.51.1 (Aug 2026) | Boggy Region, Leviathan, new workbench levels, portable turrets |
| 1.52 (Sep 2026) | Coin resurrection |
| 1.53 (Oct 2026) | **Base Power waves and breach-tool camp raids (both inside the Cult Hunting event), tap-to-target, buffs, refundable walls** |

All rows come from [Version](https://last-day-on-earth-survival.fandom.com/wiki/Version) and the [App Store](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094) listing. The App Store listing shows 4.6★ from 104K ratings, a 1.4 GB download, iOS 15+, and IAPs from $0.99 to $9.99 among the visible entries.

---

## 17. Core loop at every scale

| Scale | Loop |
|---|---|
| **Minute-to-minute** | Move, sneak behind, 3× melee hit, harvest node (hold or Auto), watch durability, eat from pocket, loot container, dodge telegraphed AoE (spit cone, slam circle), exit at the edge when overwhelmed |
| **Session (10–30 min)** | Check benches and collect output, refuel and refill, pick a destination by energy cost, run 1–3 locations (farm or dungeon), come home, deposit into specialized storage, queue new crafts, advance a Survivor's Path or event task |
| **Daily** (00:00 UTC) | Spend the 200 energy across two or three play windows (it refills in 16 h 40 m). Claim the daily bonus and inbox items. Do regional daily tasks, then the boss, for Genesis currency. Take three event attempts. Watch ads for energy and buffs. Defend against the horde. Daily defensive structures (1.53) |
| **Weekly** | 48–72 h dungeon resets (Bunker Alfa, Farm, PD). Grow dogs and cats over multiple days. Push event reputation tracks (~11 days). Crater tournaments and clan challenges |
| **Seasonal** | 21-day season pass. Monthly-ish themed event (Halloween, Christmas, Lunar NY, Easter, anniversary). Region expansion every ~4–6 months that adds a vehicle, a hazard meter, a gear set and a boss |

---

## Design implications for our game

1. **Copy LDoE's tier ladder; give the defense real stakes.** Its one-to-one wall-tier to breach-tool mapping (hatchet → iron hatchet → C-4 → cutter) is clear and worth copying. But design the ladder **against human raiders from day one**. Walls need HP, a damage type per tool, and a measurable time-to-breach, rather than a binary "can't be broken" at L5. Avoid any indestructible top tier.
2. **Make raiding live or near-live against real players, not AI mirrors.** LDoE gates raids at level 150 and never lets a human see your base. That is exactly why the developer felt nobody ever came. Instead: small-to-mid servers (DayZ/Rust style) or **instanced raid windows with matchmaking by base value**. The defender gets a notification, a travel option or a stake, and offline protection rules. The noise-meter/TBO mechanic is a good **"raid clock"** to keep for the PvE pressure layer.
3. **Never sell breach tools, resurrection or loot insurance.** LDoE permanently sells raid skip-tasks (45–125 coins) and inventory recovery (100). During the 1.53 Cult Hunting event it also sold Metal Cutters (300 coins), new cult-camp coordinates (200) and extra defense attempts (100). In a raid-centric game, each of those is pay-to-win. Keep monetization to cosmetics, a fair battle pass, and convenience that doesn't affect PvP.
4. **Base layout must matter mechanically.** The honeycomb meta came about because noise per wall is the only thing layout affects. Give layout more levers: door, chokepoint and line-of-sight value for turrets; storage tiers with lockable containers; tool cupboards or claim radius; decay or upkeep. The "Base Power" idea (sum of placed objects) is fine as a **matchmaking signal**, not as the defense itself.
5. **Plot size should come from upkeep and claims, not endgame currency.** LDoE's debris and Site Plan expansion ties space to Genesis grinding. Prefer expansion limited by upkeep cost and raidability, as in Rust. Big bases should be stronger *and* juicier.
6. **Keep the instanced-location structure, but make zones shared.** LDoE's resource zones that regenerate on exit kill tension and scarcity. Use persistent node respawn timers on a shared map, so gathering spots are contested.
7. **Replace Energy with a time and risk cost, not a paywall.** Travel should cost real time and exposure (DayZ), fuel for vehicles, and carrying capacity. Drop any regenerating stamina-currency you can buy.
8. **Death must sting, but fairly.** Drop the carried inventory, allow a corpse run, and never offer paid recovery. Pair it with cheap "naked kits" so loss isn't rage-quit material. Insurance-style items wreck PvP integrity.
9. **Quest-gated blueprints are a good FTUE, but the gates should be diegetic and finite.** Survivor's Path teaches each verb in one screen and shows the end-goal (a broken chopper) at minute one. Copy that. But after the tutorial, unlock blueprints through **research or loot** (Rust research table, DayZ finds) instead of a premium-flanked quest list.
10. **Combat needs real targeting and readable telegraphs from day one.** LDoE only shipped tap-to-target in 2026 and still relies on exploitable "wall trick" AI. Build explicit lock-on or twin-stick aim, AI that pathfinds around thin walls, and the telegraph language LDoE already gets right (cone spit, slam circle).
11. **Use regional hazard meters as content keys.** Cold, spores and radiation, each paired with a gear set and a vehicle (bike, boat, ATV), is LDoE's best long-term content structure. Cheap to extend, and it makes exploration feel earned.
12. **Fix the gap between hands-on play and the wiki.** The wiki gives numbers, but not *feel*: hit-stop, input latency, how often you open the inventory, how annoying timers are. A short, structured hands-on session would close that gap. Install the current build, play 3–5 hours with a timing log of FTUE milestones, energy spend and bench waits, and screen-record the base editor. It is optional, but cheap and high-value for the base-building UX.

---

## Gaps (could not verify)

- **Reddit and community sentiment (2025–26):** the fetch tool blocks old.reddit and reddit.com. No first-hand player quotes are included.
- **YouTube:** only titles and channels came through oEmbed:
  - "400 TIPS AND TRICKS FOR BEGINNERS! - Last Day on Earth: Survival" by Doomeris
  - "Last Day on Earth – ATV Modules" by the official Kefir Games channel
  - "311 Tips and Tricks for Last Day on Earth Survival. Pro Guide (Red Magic)", which the wiki credits to the JCF channel

  View counts, dates and transcripts weren't accessible.
- **Market data:** no revenue or download figures. AppMagic, Sensor Tower and Google Play didn't render, and the shared web-search budget ran out mid-task.
- **Stale or conflicting numbers:** hunger damage at 0 (2 vs 5 HP), whether meters drain on the map, current Chopper unlock level, and exact wall/door costs after 1.53. Older wiki pages may predate rebalances.
- **"Pine Hills"** couldn't be matched to any LDoE location.
- **Real-player vs AI raid targets:** the evidence is the wiki's statement plus inference, with no official Kefir confirmation.

## Fact-check notes

Adversarial re-check on 2026-11-07. I re-read the cited wiki pages' current wikitext through the MediaWiki API, re-opened the Kefir Helpshift FAQs, the App Store listing and the Kefir About page, and cross-checked each claim against a second wiki page or official patch notes where one existed. The shared web-search budget was used up before I could search for independent third-party sources, so corroboration is mostly the wiki against Kefir's own material.

**Confirmed (no change):**
- Raiding unlocks at level 150: Kefir FAQ and the Raiding System page (since 1.17.2).
- The Crater needs level 100 plus a quest: Kefir FAQ.
- Raider tasks: skip costs run 45–125 coins. The raid window is 8 hours, with noise thresholds at about 24, 46, 72 and 100 (TBO).
- Shortchanged Raiders retaliate after 2 hours. They can't break L4/L5 walls and blow up at most 4 stone walls.
- The wiki states outright that Wasteland raids are AI-only.
- Wall and floor tier costs, and the horde rules for each wall tier.
- Debris: 66 patches covering 264 tiles for new accounts, versus 9 (36 tiles) for older ones. A Site Plan costs 100 Infected Genome, and 1.53 added 18 more debris.
- Energy: max 200 (raised 19 Mar 2020), 1 point per 5 min, ads give +15 up to 5 a day, and the Healer gives +140.
- Base Power and Signal Scanning: the wave and enemy counts and recommended Base Power numbers check out, as do the mortar and refresh prices (100 coins each).
- Death: corpse recovery costs 100 coins or one ad per 24 h, and 1.52 added resurrection for coins.
- Infected Genome boss payouts (300, 450, 600) and the 5,000 cap. The Repair Station costs 3,600 genome plus 10 Borealis kills.
- Seasons last 21 days (Kefir FAQ), and Season 99 dates check out.
- VIP: Prestige gives −50% energy cost, +30% bench speed and +50% XP.
- The armor formula A/(A+50/3).
- The quest-to-blueprint unlock table.
- ATV finalization costs.
- Cats: growth takes 4 d 3 h, or 299 coins to skip.
- Enemy HP: TBO, Frenzied Giant and Leviathan.
- The App Store listing: 4.6★ from 104K ratings, 1.4 GB, iOS 15+, version 1.53.2, and the visible IAPs from $0.99 to $9.99.
- Kefir's "more than half a billion players" claim.
- Spot-checked dates in the version history (1.7 through 1.53.0). All matched the wiki's release notes.

**Corrected:**
1. **Home plot size:** the "396 total" tiles figure copied from the wiki is arithmetically inconsistent with 20×18 (= 360 = 340 + 20). I flagged it, and the current dimensions after the 1.49–1.53 expansions are marked unverified.
2. **Tungsten Bar:** the impact was understated. The wiki marks the AK-47, VSS, Dragunov, Shotgun and Assault armor recipes "Not Craftable" too, not just the Tactical Backpack, Mi-24 and the 6th terminal. I also annotated the quest table, because three of its weapon unlocks can't be crafted.
3. **Base Power / Signal Scanning and the cult-camp breach tools:** these are part of the 11-day Cult Hunting Halloween event, not a confirmed permanent mode. Destroyed pieces are restored after each scan, not "after the event". The daily structure delivery is now spelled out.
4. **Breach-tool coin prices:** corrected from "100–350" to 60–350, with each item's price listed. Design implication #3 is reworded so that event-only coin sinks (Metal Cutter, camp coordinates, defense attempts) are not presented as permanent. "New raid targets" was really new *cult-camp* coordinates.
5. **Metal Cutter as the L4 breach tool:** it exists only as a Cult Hunting event item used on cult-camp iron walls. Whether it works on regular raid targets is marked unverified.
6. **Crafting from nearby storages "(1.20.12)":** the 1.20.12 notes only cover repainting, so the version is now marked unverified.
7. **Settlement:** it was added in 1.19.4, but room construction, water and electricity first appear in the 1.20 notes (Dec 2022).
8. **The "Version page is current to 1.53.2" wording:** the main page stops at 1.53.0, and 1.53.2 is on the subpage.
9. **Pine Bushes "27 trees ≈ 51 logs":** this is internally inconsistent with the wiki's 3-logs-per-tree convention, so it is marked unverified.
10. **Threat-of-Attack "once a day":** this is a single 2018 editor anecdote and is now labelled as one.
11. **Season length:** a note now says the wiki's Season 89 dates cover only about 19 days.

**Still unverified:**
- The launch month (May 2017) rests only on the wiki's "1.0 (May-27)" entry and the 9th-anniversary note.
- Whether Signal Scanning or cult-camp raiding outlives the event.
- Assault armor AP.
- Hunger damage at 0 (2 vs 5 HP/s).
- Whether meters drain on the map.
- The 13-mercenary count (wiki page last edited Jul 2024).

Nothing was found to be fabricated. "Pine Hills" was already flagged as unmatched, and a wiki search confirms no such location.

**Overall reliability: medium-high for mechanics, medium for "current state".** Almost every number traces faithfully to the wiki or to Kefir. The main risks are the wiki's own staleness and arithmetic slips, and the fact that 1.53's base-defense and raid features are event-scoped. Re-verify any number before it goes into a balance sheet.

## Sources

- [LDoE Wiki – Version history (1.0 → 1.53.2)](https://last-day-on-earth-survival.fandom.com/wiki/Version) · [Version 1.53.0](https://last-day-on-earth-survival.fandom.com/wiki/Version/1.53.0)
- [Survivor's Path](https://last-day-on-earth-survival.fandom.com/wiki/Survivor%27s_Path) · [Chapter: New beginning](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_New_beginning) · [Chapter: True friend](https://last-day-on-earth-survival.fandom.com/wiki/Template:Chapter:_True_friend)
- [Blueprints](https://last-day-on-earth-survival.fandom.com/wiki/Blueprints) · [Craft Points](https://last-day-on-earth-survival.fandom.com/wiki/Craft_Points) · [Workbench](https://last-day-on-earth-survival.fandom.com/wiki/Workbench) · [Melting Furnace](https://last-day-on-earth-survival.fandom.com/wiki/Melting_Furnace) · [Woodworking Bench](https://last-day-on-earth-survival.fandom.com/wiki/Woodworking_Bench) · [Campfire](https://last-day-on-earth-survival.fandom.com/wiki/Campfire) · [Rain Catcher](https://last-day-on-earth-survival.fandom.com/wiki/Rain_Catcher) · [Recycler](https://last-day-on-earth-survival.fandom.com/wiki/Recycler) · [Gunsmith Bench](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith_Bench) · [Weapon Modifications](https://last-day-on-earth-survival.fandom.com/wiki/Weapon_Modifications) · [Repair Station](https://last-day-on-earth-survival.fandom.com/wiki/Repair_Station)
- [Home](https://last-day-on-earth-survival.fandom.com/wiki/Home) · [Wall](https://last-day-on-earth-survival.fandom.com/wiki/Wall) · [Floor](https://last-day-on-earth-survival.fandom.com/wiki/Floor) · [Honeycomb Base Design](https://last-day-on-earth-survival.fandom.com/wiki/Honeycomb_Base_Design) · [The Horde](https://last-day-on-earth-survival.fandom.com/wiki/The_Horde) · [Site Plan](https://last-day-on-earth-survival.fandom.com/wiki/Site_Plan) · [Signal Scanning](https://last-day-on-earth-survival.fandom.com/wiki/Signal_Scanning) · [Settlement](https://last-day-on-earth-survival.fandom.com/wiki/Settlement)
- [Raiding System](https://last-day-on-earth-survival.fandom.com/wiki/Raiding_System) · [Threat Of Attack](https://last-day-on-earth-survival.fandom.com/wiki/Threat_Of_Attack) · [Raiders](https://last-day-on-earth-survival.fandom.com/wiki/Raiders) · [NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base) · [Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting) · [Dark Rituals](https://last-day-on-earth-survival.fandom.com/wiki/Dark_Rituals) · [Metal Cutter](https://last-day-on-earth-survival.fandom.com/wiki/Metal_Cutter)
- [The Crater](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater) · [Business Level](https://last-day-on-earth-survival.fandom.com/wiki/Business_Level) · [The Crater Tournaments](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater_Tournaments) · [Secret Subway / FENA Tournament](https://last-day-on-earth-survival.fandom.com/wiki/Secret_Subway)
- [Energy](https://last-day-on-earth-survival.fandom.com/wiki/Energy) · [Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map) · [Regions on Global Maps](https://last-day-on-earth-survival.fandom.com/wiki/Regions_on_Global_Maps) · [Airdrop](https://last-day-on-earth-survival.fandom.com/wiki/Airdrop) · [Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations) · [Inbox](https://last-day-on-earth-survival.fandom.com/wiki/Inbox)
- [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood) · [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires) · [Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa) · [Specialist](https://last-day-on-earth-survival.fandom.com/wiki/Specialist) · [Blackport PD](https://last-day-on-earth-survival.fandom.com/wiki/Blackport_PD) · [Crash Site](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site) · [Crooked Creek Farm](https://last-day-on-earth-survival.fandom.com/wiki/Crooked_Creek_Farm) · [Abandoned Factory](https://last-day-on-earth-survival.fandom.com/wiki/Abandoned_Factory) · [Scouting](https://last-day-on-earth-survival.fandom.com/wiki/Scouting)
- [Hunger](https://last-day-on-earth-survival.fandom.com/wiki/Hunger) · [Thirst](https://last-day-on-earth-survival.fandom.com/wiki/Thirst) · [Health](https://last-day-on-earth-survival.fandom.com/wiki/Health) · [Cleanliness](https://last-day-on-earth-survival.fandom.com/wiki/Cleanliness) · [Pee](https://last-day-on-earth-survival.fandom.com/wiki/Pee) · [Status Effects](https://last-day-on-earth-survival.fandom.com/wiki/Status_Effects) · [Death](https://last-day-on-earth-survival.fandom.com/wiki/Death) · [Reanimator](https://last-day-on-earth-survival.fandom.com/wiki/Reanimator)
- [New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills) · [Sneaking](https://last-day-on-earth-survival.fandom.com/wiki/Sneaking) · [Armor and Armor Points](https://last-day-on-earth-survival.fandom.com/wiki/Armor_and_Armor_Points) · [Minimap](https://last-day-on-earth-survival.fandom.com/wiki/Minimap) · [Wall trick](https://last-day-on-earth-survival.fandom.com/wiki/Wall_trick) · [Settings](https://last-day-on-earth-survival.fandom.com/wiki/Settings) · [Portable Turret T-I](https://last-day-on-earth-survival.fandom.com/wiki/Portable_Turret_T-I)
- [AI Survivor](https://last-day-on-earth-survival.fandom.com/wiki/AI_Survivor) · [Fast Biter](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter) · [Toxic Spitter](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Spitter) · [Floater Bloater](https://last-day-on-earth-survival.fandom.com/wiki/Floater_Bloater) · [Frenzied Giant](https://last-day-on-earth-survival.fandom.com/wiki/Frenzied_Giant) · [The Big One](https://last-day-on-earth-survival.fandom.com/wiki/The_Big_One) · [Leviathan](https://last-day-on-earth-survival.fandom.com/wiki/Leviathan) · [Category:Bosses](https://last-day-on-earth-survival.fandom.com/wiki/Category:Bosses)
- [Chopper](https://last-day-on-earth-survival.fandom.com/wiki/Chopper) · [ATV](https://last-day-on-earth-survival.fandom.com/wiki/ATV) · [Motorboat](https://last-day-on-earth-survival.fandom.com/wiki/Motorboat) · [Robodog](https://last-day-on-earth-survival.fandom.com/wiki/Robodog) · [Drone](https://last-day-on-earth-survival.fandom.com/wiki/Drone) · [Dog Crate](https://last-day-on-earth-survival.fandom.com/wiki/Dog_Crate) · [Cat](https://last-day-on-earth-survival.fandom.com/wiki/Cat) · [Healer](https://last-day-on-earth-survival.fandom.com/wiki/Healer) · [Dealer Joe](https://last-day-on-earth-survival.fandom.com/wiki/Dealer_Joe)
- [Genesis Collection](https://last-day-on-earth-survival.fandom.com/wiki/Genesis_Collection) · [Infected Genome](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Genome) · [Expeditions](https://last-day-on-earth-survival.fandom.com/wiki/Expeditions) · [Mercenaries](https://last-day-on-earth-survival.fandom.com/wiki/Mercenaries) · [Season 89](https://last-day-on-earth-survival.fandom.com/wiki/Season_89) · [Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99) · [Event Calendar](https://last-day-on-earth-survival.fandom.com/wiki/Event_Calendar) · [VIP zone](https://last-day-on-earth-survival.fandom.com/wiki/VIP_zone) · [Coins](https://last-day-on-earth-survival.fandom.com/wiki/Coins) · [In-Game Shop](https://last-day-on-earth-survival.fandom.com/wiki/In-Game_Shop) · [General Tips/FAQ](https://last-day-on-earth-survival.fandom.com/wiki/General_Tips/FAQ) · [Beginner's Guide](https://last-day-on-earth-survival.fandom.com/wiki/Beginner%27s_Guide)
- [Apple App Store – Last Day on Earth: Survival](https://apps.apple.com/us/app/last-day-on-earth-survival/id1241932094)
- Kefir official support FAQ: [index](https://kefirgames.helpshift.com/a/last-day-on-earth/) · [Play with other survivors](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/126-i-want-to-play-with-other-survivors-what-should-i-do/) · [Raiders](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/364-i-don-t-get-raiders-raiders-stopped-showing-up/) · [Threat timer](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/929-why-did-the-threat-timer-disappear/) · [Seasons](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/340-what-seasons-are-and-how-do-i-take-part-in-them/) · [Boggy Region](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/1284-boggy-region-and-its-secrets/) · [Horde](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/140-how-do-i-stop-the-horde-approaching-my-base/) · [Bunkers](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/13-what-is-a-bunker/)
- [Kefir – About](https://kefirgames.com/en/about) (claims more than half a billion players across its projects)
- [APKMirror – What's new in 1.43.0](https://www.apkmirror.com/?p=11862804) (from a search snippet; the page returned 403 to the fetch tool)
- YouTube (titles and channels only, via oEmbed): [Doomeris – 400 Tips and Tricks for Beginners](https://www.youtube.com/watch?v=mFQhJxGbdb8) · [Kefir Games – ATV Modules](https://www.youtube.com/watch?v=k2fX89t4bdc) · [311 Tips and Tricks (JCF)](https://www.youtube.com/watch?v=Zmu6awZAaqM)
