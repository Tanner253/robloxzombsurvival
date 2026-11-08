# LDoE systems catalog, part 1: world and content

**Scope:** a data-oriented catalog of *Last Day on Earth: Survival* (Kefir!, current build 1.53.x, Nov 2026). It covers locations, bunkers and dungeons, keys and access chains, loot containers and reward boxes, events and live ops, enemies and bosses, and how the content structure drives the grind. It is reference material for an **original** Roblox game that models the same loops with our own names and art.

**What this is not:** the economy (resources, crafting trees, workstations, farming, mining and extractors) is covered by a separate agent's document, so it appears here only where a location gates it. Broad context such as the FTUE, meters, energy, base building and raiding lives in [`docs/research/ldoe-core-systems.md`](../research/ldoe-core-systems.md). This file adds depth and does not repeat that overview.

**Method**
- **Primary source:** the LDoE Fandom wiki. Its HTML is blocked to fetch tools, so I pulled raw wikitext for about 230 pages through the wiki's MediaWiki API on 2026-11-07. Most pages were last edited 27 Oct – 7 Nov 2026, but many keep text from 2018–2022. Each table notes the stale bits.
- **Supplements:** Kefir's official Helpshift FAQ (bunkers, police armory), a 2020 Gamingonphone Bunker Alfa guide, and the existing overview doc.
- **Labels:**
  - **Inference:** my own reasoning.
  - **(conflict)**: two sources disagree.
  - **(stale)**: the text predates recent reworks.
  - **(unverified)**: one weak source.
  - A number with no label comes from the wiki page linked in that section.
- **Energy/Walk column:** the cost to *run* there (energy) and the free walk time, from Home. Drive times and fuel are listed where the wiki gives them.

---

## 1. World structure

### 1.1 Map halves and regions

The Global Map has two halves. **The Wasteland** is single-player and holds almost all content. **The Crater** is the multiplayer half and uses a separate character. Exiting any location to the map is a safe state: meters don't drain, you can craft and eat, and hostile AI survivors and event-spawned mobs despawn ([Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map)).

The Wasteland is split into a free central area plus four regions, each unlocked by repairing a **watchtower**. Each region adds one travel requirement, one environmental hazard (with a matching armor set), and one region boss behind a daily-task counter.

| Region | Unlock gate | Travel | Hazard (min protection) | Main locations | Region boss and loop |
|---|---|---|---|---|---|
| **Central (Home)** | none | walk / run / drive | none | Pine and Limestone zones, Bunker Alfa and Bravo, Crooked Creek Farm, Motel, Abandoned Factory, Gas Station, Port, Pier | none. Dungeons on 24–72 h timers |
| **East** | Southeastern (Eastern) Watchtower: **L10**, finish its generator (10 Wiring, 12 Rubber Parts, 15 Bolts). Guards: 1 Floater Bloater, 2 Hungry Chompers, 2 Zombie Officers | walk / run / drive | none | Blackport PD, Transport Hub, Greenwood Camping Park | none |
| **North** | Northern Watchtower: **L15**. You must bring an Electric Generator by Chopper or ATV (it can't be assembled on site), which triggers a **Screech** fight | walk / run / drive; scouting zones need a vehicle | **Cold.** Fur armor; per-location minimums 10 / 18 / 23 cold protection | Oak Bushes, Wooded Foothills, Frosty Backwoods, Quarantine Zone, Frozen Training Ground, Ice-Trapped Ship, Icy Outskirts (daily), Rest Stop (Northern) | **Borealis** (1,500 HP) gives **300 Infected Genome**. Access costs 3 Northern Region Points (3 free daily tasks) or is paid |
| **Islands** | Island Watchtower: reached by **Motorboat** via Survivor's Path. Fix the generator and fight the **Lighthouse Keeper** | Motorboat only | **Spores.** Anti-Spore set; Dead Island needs 18, Landfill needs the Enhanced set (4/8/7/4) | Sand Quarry, Old Mine, Dead Island, Landfill; Oil Rig is visible but unreachable | **Consilium** (4,000 HP) gives **450 Genome**. Needs 3 Island Points |
| **Boggy (West)** | Western Watchtower: **ATV only**. A Crowbar opens the gate; generator needs 40 Wiring, 5 Wrench, 50 Bolts. Bosses: **Butcher** (1,200 HP) on the old page; **Alpha Irradiator** (2,000 HP) must be killed to fix it | ATV only on the way out (walk/run are allowed back) | **Radiation.** Hazmat minimum; Swamp Forest 25, Wild Bogs 35 | Swamp Forest, Wild Bogs, Bogside Outskirts, Leviathan's Lair | **Leviathan** (4,000 HP) gives **600 Genome**. Needs 3 Boggy Region Points, then a 3-day access window |
| **The Crater** (MP) | Abandoned convoy event (page: L30). Level gate **(conflict)**: the Kefir FAQ says L100 plus a quest; the wiki says the gate moved 150 → 15 → 60 | separate character | none | Crater hub, 5 Chopper locations | tournaments, PvP from Business Level 15 (overview doc) |

Sources: [Regions on Global Maps](https://last-day-on-earth-survival.fandom.com/wiki/Regions_on_Global_Maps), [Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Watchtower), [Island Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Island_Watchtower), [Leviathan's Lair](https://last-day-on-earth-survival.fandom.com/wiki/Leviathan%27s_Lair), [Ice-Trapped Ship](https://last-day-on-earth-survival.fandom.com/wiki/Ice-Trapped_Ship), [Landfill](https://last-day-on-earth-survival.fandom.com/wiki/Landfill), [The Crater](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater).

### 1.2 Location lifecycle types

Every location in LDoE fits one of these lifecycles. This is the single most useful field for our `LocationDef`.

| Lifecycle | Behaviour | LDoE examples |
|---|---|---|
| **Home plot** | Persistent. Its nodes never respawn | Home |
| **Farm zone** | Fully regenerates when you exit (and when you die). Rations can auto-clear it | Pine Bushes/Grove, Limestone Ridge/Cliffs/Spires, Oak zones, Wooded Foothills, Frosty Backwoods, island resource zones |
| **Timed dungeon** | A per-player instance whose reset timer starts on first entry. Kills, opened containers and your last corpse persist until the timer ends. Since 1.44 you must also **exit** after the timer ends for Bunker Alfa to reset | Bunker Alfa (48 h), Farm (48 h), Blackport PD (3 d), Motel (36 h), Factory (24 h), Transport Hub (48 h), Port, Sewer and Lab (48 h or 3 d, a conflict), Gas Station and Highway (48 h), Pier (48 h) |
| **Never-reset storage inside a dungeon** | Loot once, then it works as remote storage | Bunker Alfa ground floor (7 lockers × 20 slots = 140), Bunker Bravo main level (6 lockers), PD arena staging lockers (2 × 20) |
| **One-time story** | Spawns once and is gone 15 min after you leave | Crash Site |
| **Rotating pop-up** | Spawns on a schedule or trigger and has a short lifetime | Airdrop (up to 3/day, triggered by energy spend), Destroyed convoy (1 h, every 4 days), Oak Clearing (1 h 30 m, every 5 days), Junkyard (48–72 h after the last one), Fishing Spot (12 h), Rest Stop |
| **Player-spawned** | Created by an item or radio call | N 50.01061, E −110.1134 (Floppy with coordinates, 12 h); Dealer Joe (CB Radio) |
| **Daily-task location** | Refreshes at 00:00 UTC and feeds a region-point counter (max 3) | Icy Outskirts, watchtower tasks, Swamp Forest tasks, Sand Quarry and Dead Island tasks |
| **Boss lair** | Locked behind a region-point counter, with a cooldown or access window | Ice-Trapped Ship, Landfill, Leviathan's Lair |
| **Event-only** | Exists or is accessible only during an event | Infected Forest (since 1.41), Mysterious Forest, Cult's Shelter, Hunting Grounds, Climate Anomaly, Uncharted Territories |
| **Season-only (retired)** | Shipped for one season and later removed | Fort Moss, Prison, Bikers' base, Maze, Fair, Infected Base, Strange factory |
| **Teaser / unreleased** | Shown on the map but unreachable. Its card drops already exist | Bunker Charlie (needs the uncraftable Mi-24), Oil Rig, Suburb, Bunkers Delta, Foxtrot, Romeo and Zulu |
| **Multiplayer** | Separate economy and character | The Crater and its Chopper locations; Sector 7 (removed) |

---

## 2. Location catalog

### 2.1 Resource zones (Farm zones)

All reset on exit. The economy doc covers the node economics; listed here is what each zone puts *in containers*, and its enemies.

| Location | Gate | Energy / Walk | Reset | Enemies | Main loot | Possible loot | Notes |
|---|---|---|---|---|---|---|---|
| **Pine Bushes** (green) | none (Inference: starter zone) | 15 / 12 m | on exit | Roaming Zombie, Grey Wolf, Fast Biter, AI Survivor, rare Floater Bloater, very rare Diseased Wolf | 27 pine + 3 dead trees, 19 loose logs, 21 loose limestone, 20 fiber, 10 berry bushes | 1–3 storages with a couple of items each: canned food, water, bandages, bolts, duct tape, bearings, transistors, lock and key, adhesive, scrap, wiring; melee (hockey stick, paddle, hammer, bat, golf club); **CAC A** | About 2,050 XP for a full clear. The wiki says 27 trees give 51 logs, but its other pages count 3 logs per tree **(conflict)**. Can roll a ruined base with a basement trapdoor. Dead Soldier corpse with the Alfa code |
| **Pine Grove** (yellow) | L10 (Inference: the page lists L10 and L15 notes without saying which tier gets which) | 22 / 19 m 25 s | on exit | More Fast Biters, 1–2 Floater Bloaters, 1–2 Toxic Spitters, Rabid Wolves | logs | 3–4 bags; vehicle parts drop more often | Deer, Wild Turkey |
| *Pine Wood* (red, **removed in 1.19.4**) | — | 26 / 22 m 19 s | — | Toxic Abomination, very rare The Big One, AI with VSS | — | — | Its map slot became the Abandoned Factory |
| **Limestone Ridge** (green) | none | 15 / 12 m 30 s | on exit | Roaming, Grey Wolf, 1–2 Fast Biters | 25 limestone rocks (75), 5 iron rocks (15 ore), 7 pine trees, 20 loose limestone | 1–3 bags, up to 5 items each: beans, water, low-tier parts, bat, paddle | About 2,500 XP |
| **Limestone Cliffs** (yellow) | L10 (Inference) | 22 / 19 m 35 s | on exit | As Grove; rare **Timmy the Bloat** | Iron-rich: 30 iron rocks ≈ 90 ore (overview doc) | 3–4 bags; more vehicle parts | Timmy explodes at 50 HP into 2 Parasites (+300 XP) |
| **Limestone Spires** (red) | L15 (Inference) | 33 / 29 m 5 s | on exit | Red-zone mix | iron, limestone | — | Basement odds were reduced in an unknown patch |
| **Oak Bushes / Oak Grove** (North) | Northern Watchtower plus a Chopper | n/a (stale page, 2024) | on exit | — | oak logs (Iron Hatchet) | — | **(stale)** |
| **Wooded Foothills** (yellow, North) | Northern Watchtower | 62 / 1 h 8 m | on exit | Frozen Bloater, Frozen Fast Biter, Frozen Phantom; Northern Deer, Boar | 50 pine trees (150 logs), aluminium ore, Thermite (dig) | 3–4 storages × 20 slots | Cold 10. AI survivors here **don't despawn** on exit. Has a daily task |
| **Frosty Backwoods** (red, North) | Northern Watchtower | 70 / 1 h 5 m | on exit | Frozen Fast Biter, Frozen Phantom, Frozen Bloater, Dire Wolf, **Wendigo** | 90 pine trees, 10 copper rocks (1–3 ore each), Northern Berry | Chance of a **ruined tank**: at least 1 random gun plus wrench, cog, engine part, wiring, spring, tactical armor, iron plate | Cold 18. One of the few copper sources |
| **Sand Quarry** (yellow, Island) | Island Watchtower; boat | — / 41 fuel | on exit | Toxic Spitter, Fast Biter, Floater Bloater, 5 Spore Deer; daily-task spore mobs | sand (Shovel) | preset crates (§4.1) | Daily tasks pay 1 and 10 Genome. Spore mobs take 40% of normal damage from non-spore weapons |
| **Old Mine** (Island) | boat; Manual Earth Drill for ore | — | on exit | Spore runner, wolf, spitter, bloater, Miasma; Spore Bear (task) | Quartz, Halite, 9–20 seaweed | — | Anti-Spore 3/5/4/2 recommended |
| **Dead Island** (red, Island) | boat; drill for cave ore | 24 / — (30 fuel) | on exit | Spore family, 2 Spore Bears, 3 Cocoons, Parasites; Spore Hybrid or 2 Spore Giants (tasks) | cave ore | — | Spore 18. Spore armor cuts about 60% of non-spore damage. Its 3 daily tasks unlock Consilium |
| **Swamp Forest** (yellow, Bogs) | Western Watchtower; ATV | — / 101 fuel | 00:00 GMT | Roaming, Rotten Zombie, Radioactive Spitter, Leaper, Alligator | Antimony Extractor, Sawmill (Heavy Ash Log), corn | chests behind crowbar doors and ATV-hinged doors | Radiation 25. Starting an extractor triggers a defence wave |
| **Wild Bogs** (red, Bogs) | Western Watchtower; ATV | ATV only (the infobox still lists 60 run energy, drive 20 s) | 00:00 GMT | Radioactive zombies; legacy page lists Carrion 100, Tainter 120, Screaker 200, Swamp Bloater 300 | Lead and Sulfur extractors, peat, Alligator Skin | chests | Radiation 35 |

Sources: [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood), [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires), [Oak Bushes and Grove](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Bushes_and_Grove), [Wooded Foothills](https://last-day-on-earth-survival.fandom.com/wiki/Wooded_Foothills), [Frosty Backwoods](https://last-day-on-earth-survival.fandom.com/wiki/Frosty_Backwoods), [Sand Quarry](https://last-day-on-earth-survival.fandom.com/wiki/Sand_Quarry), [Old Mine (Island)](https://last-day-on-earth-survival.fandom.com/wiki/Old_Mine_(Island)), [Dead Island](https://last-day-on-earth-survival.fandom.com/wiki/Dead_Island), [Swamp Forest](https://last-day-on-earth-survival.fandom.com/wiki/Swamp_Forest), [Wild Bogs](https://last-day-on-earth-survival.fandom.com/wiki/Wild_Bogs), [Timmy the Bloat](https://last-day-on-earth-survival.fandom.com/wiki/Timmy_the_Bloat).

### 2.2 Permanent dungeons and hubs

| Location | Gate | Energy / Walk | Reset | Enemies | Main loot | Possible loot | Notes |
|---|---|---|---|---|---|---|---|
| **Bunker Alfa** (red) | **L40**; **CAC A** once; a 5-digit code per reset | 31 / 27 m 26 s (drive 10 s) | Sublevels: **48 h** from activation. Ground floor: never | See §3.1 | Coupon-exchange boxes; Specialist reputation rewards | Modded guns, Minigun, SWAT/Tactical sets, chopper parts, paint patterns, C-4 | Full breakdown in §3.1 |
| **Bunker Bravo** (red) | **L75**; an Electric Generator in the elevator machine. A CAC B gate is likely but the page doesn't state it **(unverified)** | 40 / 35 m 10 s (20 fuel on a max-efficiency Chopper) | **not documented** | See §3.2 | Floor cargo lifted to the lobby | Hi-Tech Components, Grenades, ATV Wheel, Turret parts | Dungeon crawl with 3 boss floors and radiation |
| **Blackport PD** (red) | Eastern Watchtower (L10) | 51 / 46 m 16 s (drive 17 s) | **3 days** | Zombie Officer (incl. SWAT), Hungry Chomper, Explosive Zombie, Riot Zombie, Jailbird, Brawler | Police-card crates (3 per reset, 5 when upgraded) | Extremely-rare mod blueprints, SWAT set, modded firearms | 99-wave arena; Police Bike skin at wave 99. See §3.3 |
| **Crooked Creek Farm** (red) | **L15**. The old bridge build (20 iron bars, 40 planks, 20 bricks, 20 rope, 40 scrap, 1 hammer) was removed | 33 / 28 m 47 s (drive 11 s) | **48 h** after entry | Rotten Yokel 80 HP/2 armor, Savage Giant 200/5, Infected Bull 300/10, **Ravager** 500, Fast Biter 80, Diseased Wolf 100, Raiders 100 (armor 12–24) | **Farm chest** (18–21 items, 60 slots) | Puppy (house, plots or barn); chopper parts plus gas from the barn Chopper; a melee blueprint in the house | Map 850 × 500 units. See §3.4 |
| **Motel** (yellow) | none; Kefir calls it a beginner area | 24 / 21 m 33 s | **36 h** | 16 Roaming, 11 Fast Biter, 2 Floater Bloater, **Weeper** (mini-boss) | 13 storages × 20 (bins, wardrobes, TV stands, a pool car trunk) | Grill turkey, phones, cigarettes, bandages, coupons; a grenade behind a Burglar-1 door; rare Glock; extremely rare Shotgun in the trunk | **Basement** (Burglar 3): 5–6 Fast Rotters, Crawlers, Spitters, a Bloater or Abomination; its far chest can hold **6 Screws** (needed for the Transport Hub bridge) |
| **Abandoned Factory** (red) | Survivor's Path ("Helping Chris"), then **6 Transistors** for the power boxes (6 more for the forklift box) | 26 / 21 m 4 s (drive 9 s) | **24 h** (infobox says 48 h, the 1.19.4 value; **conflict**) | Toxic Spitter, Fast Biter, Floater Bloater; basement Exploders and Parasites; The Big One (quest) | Pipes, bolts, bearings, rubber parts, wiring, wrench, vinyl record | Super rare M16 or Shotgun, very rare Glock, Grenade, Katana, Shepherd puppy, possible mod blueprint | You must break boxes with an **Iron Hatchet** every visit. Gas does 15 dmg every 0.5 s and needs valves; electrified puddles need switches |
| **Transport Hub** (red) | Eastern Watchtower; the **Drone** opens the gate | 51 / 43 m 9 s | **48 h** | Fast Rotter, Floater Bloater, Zombie Officer and Chomper (armored, heal on hit), Acid Melter, Carrion, Toxic Darter, Riot and Explosive (armored), Groaner, Parasite; **Butcher** or **Miner** boss | 4 shelf crates, chosen by drone scan plus the CAC Card Key | Red crate: reagents, sulfur, lead plate, drone battery, gun oil, acid, hydraulic part, land mine, AntiRad | See §3.5 |
| **Port** | **L15**; no watchtower | 33 / 29 m 10 s | **48 h after entering the Sewer or Lab** (entering the Port alone doesn't start it) | 4 Sailors (80) and 1 Midshipman (240), first visit only | **Motorboat blueprint** (hangar door); Big Tuna factory benches; delivery terminal | Jake's delivery reputation; Terrain maps (Sewer) | Hub. The delivery terminal offers 6 random contracts and resets 24 h after use, on its own timer |
| **Port Sewer** | Electric Generator, first time only | via Port | shares the Port timer | Swamp Zombies, Carrion, Berserker (mini-boss), Exploder; spore mobs in quest basements | — | Rubber, plastic, spring, sporicide, spore blocker | Poison goo does 20 dmg per 1.5 s until the waterpumps are fixed (1 Pump, 20 Rubber Parts, 10 Cement, 5 Wrench, 20 Bolts, 10 Al Wire) |
| **Port Laboratory** | Survivor's Path, a level gate, and Eva's infiltration mission (one time) | via Port | **3 d** per the Lab page; the Port page says 48 h **(conflict)**. The timer is shared with the Sewer | 4 themed sectors and 4 bosses (§3.6) | Key cards A/B (A+/B+ on hard), Infection Samples, Employee badges, Data disks, Hard drives | Card-box weapons (Neutralizer, Protector, Resonator, Ultimatum), CBRN and Kevlar sets | Roguelite perks and threats. See §3.6 |
| **Gas Station** | **L15** | 30 / 26 m 7 s (free with VIP) | 48 h | none since 1.14 (safe biker hub) | Jane (Chopper upgrade reputation), Lenny (limited skins), **Slot Machine** | Tokens → bike models | Entrance to the Highway |
| **The Highway** (Gas Station sublocation) | Settlement "Minivan" act | via Gas Station | **48 h** | 120 HP armored Fast Biter variant, Zombie Officer, Hungry Chomper, Raiders, Fast Biter, Spitter, Bloater, Rabid Wolf; **Smasher** (story) | **Air Filters** (best farm), **Spark Plugs** (red sedan), Rusty or Intact Engine | Iron ore, bauxite, leather, fabric, alcohol, USB drive, first aid, lock and key | 5 sections, each with its own variants (a raider ambush, a survivor on a truck). Car alarms summon Crawlers. A rare "easy" variant covers the whole map |
| **Pier** | — | 17 / 14 m 51 s | **48 h** (12 h before, and originally a Saturday-only 1 h event) | none | Fish: carp, catfish, perch, pike, trout; sturgeon needs a food buff | Fisherman NPC trades (Professional rod, or 75 coins) | Burley restocks fish. Explosives kill fish but give only low quality |
| **Infected Forest** (red) | **L35**. Since 1.41 it is only accessible during **On the Witch's Trail**, after 4 Greyhound tasks | 37 / 31 m 40 s | 20 h | **Witch**, Leshen, Explosive Zombie, Gut-Mucher, Rotting Spawn, Bloater and Behemoth | 33 dead trees | The Witch's head (horde totem) | Sends **The Horde** to your base every 24 h. Spiked thorns hurt on contact |
| **NPC Survivor Base** (red roof) | about L10 | varies | 1 h after a visit (overview) | none (rare roaming) | Chests behind walls | — | Practice target for wall breaching |

Sources: [Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa), [Bunker Bravo](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Bravo), [Blackport PD](https://last-day-on-earth-survival.fandom.com/wiki/Blackport_PD), [Crooked Creek Farm](https://last-day-on-earth-survival.fandom.com/wiki/Crooked_Creek_Farm), [Motel](https://last-day-on-earth-survival.fandom.com/wiki/Motel), [Abandoned Factory](https://last-day-on-earth-survival.fandom.com/wiki/Abandoned_Factory), [Transport Hub](https://last-day-on-earth-survival.fandom.com/wiki/Transport_Hub), [Port](https://last-day-on-earth-survival.fandom.com/wiki/Port), [Port/Sewer](https://last-day-on-earth-survival.fandom.com/wiki/Port/Sewer), [Port/Laboratory](https://last-day-on-earth-survival.fandom.com/wiki/Port/Laboratory), [Gas Station](https://last-day-on-earth-survival.fandom.com/wiki/Gas_Station), [Gas Station/The Highway](https://last-day-on-earth-survival.fandom.com/wiki/Gas_Station/The_Highway), [Pier](https://last-day-on-earth-survival.fandom.com/wiki/Pier), [Infected Forest](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Forest), [NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base).

### 2.3 Rotating and pop-up locations

| Location | Gate / trigger | Energy / Walk | Lifetime | Enemies | Main loot | Possible loot | Notes |
|---|---|---|---|---|---|---|---|
| **Airdrop** (green) | Energy spend. The 1st spawns below 140 energy, the 2nd below 80, the 3rd below 20, for **max 3 per 24 h** (181 energy spent to see all three) | varies | Until it despawns. Re-entering does **not** re-roll the loot | 1 Floater Bloater and at least 2 Toxic Spitters. At 5 min: a Roaming Zombie, 2 Grey Wolves and the 1st AI Survivor; at 10 min a 2nd AI Survivor | **1 Aid Box (20 slots).** At least one half-durability weapon: Glock 17, Machete, Saw Blade Mace, Skull Crusher or Metal Pipe | 10 planks, 10 iron bars, 10 bricks, 1–2 transistors and bolts, 5/10/15 wiring, bearings, rubber parts, iron plate, paint, wrench, truck wheel, a Ration or Survival Kit coupon, 5–14 caps, a mod blueprint. Rare: engine part, gasoline, lens, CAC card | Also has 15 pine trees, 10 logs, 1–3 deer. The wiki frames it as low-energy bait to push coin use |
| **Crash Site** (green; was "Crashed Plane") | Triggers **once** after you mine 2 limestone at Home | 10 / 27 m 50 s (or 36 m 6 s) | Gone **15 min** after you leave | Roaming Zombie, Grey Wolf | **14 Baggage × 12 slots** (was 20; another line on the page says 22–44 luggage, **conflict**) | **CAC Card Romeo**, tactical pieces, a Glock with mods, 5 Gold Bars, scrap, cloth, rope, duct tape, phones, watches, food, water, bandages | 20 dead trees (60 logs), 30 loose logs, 10 limestone. FTUE puppy |
| **Destroyed convoy** (green) | Spawns **every 4 days** (since 1.9.8) | 30 / 25 m 12 s | **1 h** | Alternates. **Raider** version: 4 Raiders (Glock, Machete, Shotgun, Winchester). **Zombie** version: 7 Roaming, 4 Fast Biter, 2 Spitter, 1 Bloater, 1 Abomination, 1 Frenzied Giant | 3 military boxes and 4 storages (20 slots each), a Soldier corpse (20 slots) | **Cut Finger** (opens the Bunker Alfa lobby's secret door), a Ration and a Survival Kit coupon, tactical pieces. First visit: a **Minigun** on a broken Power Armor, and taking it spawns a 20–30 zombie horde | 21 pine and 3 dead trees |
| **Rest Stop** (yellow) | Needs a **Chopper** | — | event | 4 variants. **Ambush**: 3 hostile survivors. **Rescue**: 3 survivors vs 20+ Roaming per wave. **Camp**: 3 armed survivors, 10 deer. **Standoff**: 4 survivors with AK, Glock, Shotgun and M16, the best loot | 60-slot storage, 2 Choppers, Baggage | Very rare gas mask, modded M16, 1–2 weapons or a Weapon Crate, 0–4 medkits, a SWAT or Tactical piece, 12–20 alcohol, **guaranteed paint** | A Northern variant exists for quests |
| **Junkyard** (yellow) | Chopper built; page says "upgraded to level 40" (ambiguous) | 33 / — | Appears **48–72 h** after the last one | Savage Giant 250, Raider 100, Fast Biter 80/120, Bloater 240, Zombie Officer 120, Hungry Chomper 240 | Reward chest | Rubber, car battery, **Biker Magazine**, cog, scrap, transistors, rubber parts, bearings | 3 variants: protect a looting survivor; deliver a Rusty or Intact Engine (3 waves); free a hostage from raiders |
| **Oak Clearing** (yellow) | Iron Hatchet | 40 / 35 m 11 s | **1 h 30 m, every 5 days** | 6 versions: raiders, animals, lumberjacks, hunters' camp and others | about 10 oak trees (8 hits for 2 logs; an Iron Hatchet lasts 75 hits) | — | Exists to supply oak to players without a Chopper |
| **Fishing Spot** | Fisherman skill | Grasslands 13 / 10 m 56 s; Snowbound and Oak Pond are farther (up to 62 / 56 m) | **12 h** | none | fish | — | 3 piers. Snowbound needs fur |
| **Dealer Joe** | CB Radio plus level | — | while active | Joe himself: 1,000 armor, can't die (HP stops at 1) | **Weapon Crate** or **Puppy in a Box** for requested goods | — | Trades include 1 Gold Bar + 1 Expensive Watch → Weapon Crate |
| **N 50.01061, E −110.1134** (red) | Insert a **Floppy with coordinates** at the Tactical Terminal in Alfa's Overseer room | 30 / 25 m 43 s | **12 h** | red-zone mobs | One valuable crate. The first floppy crate is fixed for everyone: Electronic Circuit, Air Filter, Engine Part, 10 copper ore, 2 copper bars, iron plates… | Uncommonly an **Infected Box** replaces the crate | §4.2 |
| **Basements** | Random: a resource zone rolls a ruined base whose trapdoor is wooden (open), **locked** (Burglar), or **hi-tech** (Hacker skill) | — | with the zone | Fast Rotter 120, Roaming 40, Crawler 80, Fast Biter, Spitter, Raiders, Survivors, Floater Bloater 240, Savage Giant 250, Abomination 300, Fetid Corpse 400, Toxic Spewer 500, Lurker 800, reduced-HP The Big One | Carrot stew, jerky, iron plate, scrap, plastic, spring, batteries, wristwatch, bulb, wiring, oak log, iron ore | **Copper ore deposit** | 6 layouts. Introduced 1.12.2 |
| **Wrecked ship** (yellow) | Recurring 8-day event | 9 / 14 m 25 s (15 fuel) | event | 4 Roaming, 9 Fast Biter | **Container:** 1 free opening per reset, then 3 more for 150 (the currency icon was stripped; Inference: coins) | Rarity floors are published (§4.3) | |
| **Pine Bushes event / Limestone Ridge event** (Season 1, historical) | — | 15 / about 13 m | **3 h** | Charlie Jr. (leaves at <800 HP), Diseased Wolves, Petty Officer, Midshipman, Captain; Limestone version has thorns (10 dmg) | 2 soldier corpses (5 slots) | — | An early story-driven pop-up |

Sources: [Airdrop](https://last-day-on-earth-survival.fandom.com/wiki/Airdrop), [Crash Site](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site), [Destroyed convoy](https://last-day-on-earth-survival.fandom.com/wiki/Destroyed_convoy), [Rest Stop](https://last-day-on-earth-survival.fandom.com/wiki/Rest_Stop), [Junkyard](https://last-day-on-earth-survival.fandom.com/wiki/Junkyard), [Oak Clearing](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Clearing), [Fishing Spot](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Spot), [Dealer Joe](https://last-day-on-earth-survival.fandom.com/wiki/Dealer_Joe), [N 50.01061, E -110.1134](https://last-day-on-earth-survival.fandom.com/wiki/N_50.01061,_E_-110.1134), [Basements](https://last-day-on-earth-survival.fandom.com/wiki/Basements), [Wrecked ship](https://last-day-on-earth-survival.fandom.com/wiki/Wrecked_ship), [Gold Bar](https://last-day-on-earth-survival.fandom.com/wiki/Gold_Bar), [Event](https://last-day-on-earth-survival.fandom.com/wiki/Event).

### 2.4 Uncharted Territories (large vehicle-only scouting maps)

The wiki counts 5 permanent "Uncharted Territories" (v1.51.1): Greenwood Camping Park, Quarantine Zone, Frozen Training Ground, Swamp Forest and Wild Bogs. They are very large, need a Chopper or ATV, and have road types (asphalt, dirt…) that change vehicle speed and turning. Enemies give up the chase once you are far from their spawn ([The Uncharted Territories](https://last-day-on-earth-survival.fandom.com/wiki/The_Uncharted_Territories)).

| Location | Gate | Cost | Enemies | Sublocations / landmarks | Loot focus | Notes |
|---|---|---|---|---|---|---|
| **Greenwood Camping Park** (yellow) | Eastern Watchtower; Chopper or ATV | 60 fuel | Roaming, Fast Biter, Spitter, Bloater, Crawler, Raiders, **Siren** (supermarket); deer, grey wolves | Farm, Mini Camp, Trailer Park, Supermarket, Parking Lot | **Food** (Scouting) | Searching the farm's garden beds gives 8–12 carrots |
| **Quarantine Zone** (North) | Chopper or ATV; full clothing against cold | — | Roaming, Fast Biter, Spitter, Bloater, Frenzied Giant, Crawler, Nurse, Medic; **Leshen** (Ritual Zone); **Screech** (Army Base) | Traffic Jam, EMS Station, Army Base, FENA Outpost, Crash Site, Ritual Zone, Fishing Spot | **Medical supplies** (Scouting) | |
| **Frozen Training Ground** (North) | Chopper or ATV; fur | — | Frozen Fast Biter, Phantom, Bloater, **Frozen Giant**, **Wendigo**; boar, deer | Gas Station, Radio Tower, Vehicle Park Junkyard, Military Outpost, Helicopter crash, Broken tank, Fishing Spot | **Tools Crates** (carry in the bike trunk) | Radio Tower: power a generator and survive a horde, and the radio then spawns **airdrops** at sublocations. Gas Station: repair your bike and refuel after a generator defence |
| *Uncharted Territories* (event version, 1.40.1) | Chopper; Scouting event | 60 fuel | Roaming, FB, Spitter, Crawler, Bloater, Nurse, Medic, Raiders | — | Tools Crate, Medical Supplies crate, Food crate | Vanishes when the Scouting event ends. Replaced by the permanent maps |

Sources: [Greenwood Camping Park](https://last-day-on-earth-survival.fandom.com/wiki/Greenwood_Camping_Park), [Quarantine Zone](https://last-day-on-earth-survival.fandom.com/wiki/Quarantine_Zone), [Frozen Training Ground](https://last-day-on-earth-survival.fandom.com/wiki/Frozen_Training_Ground), [Uncharted Territories](https://last-day-on-earth-survival.fandom.com/wiki/Uncharted_Territories), [Scouting](https://last-day-on-earth-survival.fandom.com/wiki/Scouting).

### 2.5 Watchtowers, region bosses and daily-task locations

| Location | Gate | Cost | Timer | Enemies | Main loot | Possible loot | Notes |
|---|---|---|---|---|---|---|---|
| **Northern Watchtower** | L15 plus an Electric Generator delivered by vehicle | 48 / 43 m 13 s | permanent unlock | Fast Biter, Floater Bloater, Toxic Abomination; **Screech** (700 HP, previously 2,000; 48 armor) | 4 oak and 10 pine trees | — | A Drone upgrade quest is also here |
| **Southeastern Watchtower** | L10; finish its generator | — | permanent unlock | 1 Floater Bloater, 2 Hungry Chompers, 2 Zombie Officers | 7 pine and 5 dead trees | — | Players from before 1.11.8 already have the East unlocked |
| **Western Watchtower** | ATV; a Crowbar for the gate (a half-durability one sits in a car trunk) | ATV fuel | permanent unlock; daily tasks | 4 Swamp Zombies, **Butcher** (1,200 HP, 100 dmg, 2 stun screams, the large one summons 4 Swamp Zombies, full heal on exit); **Alpha Irradiator** (2,000 HP) to finish | — | — | Daily tasks: "Dog Eat Dog World" (Genesis Camp defence), "Valuable Equipment" (cargo fetch), madman, raiders, sentry defence |
| **Island Watchtower** | Motorboat; Survivor's Path | 15 / — | permanent; daily "Threat in the Watchtower" | **Lighthouse Keeper** (1,250 HP, 14–18 armor, 20 dmg; gains spore armor in the daily task), spore mobs, Raiders | — | — | Since 1.35 the lighthouse is removed and a daily task added |
| **Ice-Trapped Ship** (red) | "Maximum Warming" quest, then **3 Northern Region Points** (3 free daily tasks) or a purchase | 75 / — (72 fuel) | **60 min cooldown**; daily refresh 00:00 GMT; 24 h if undefeated | 7 trapped Frozen Fast Biters; **Borealis** (1,500 HP, armor 40 → 15) | Container: 1 (rarely 2) fur armor pieces; a food or drink item; rubber or carbon composite; more slot-rolls | **300 Infected Genome**, Big Bones, **CAC Card Z** | Cold 23. 3 explosive barrels do 100 dmg to the player and 350 to the boss and biters |
| **Landfill** (Island) | "Infection Epicenter" quest, then **3 Island Points** | boat | daily | **Consilium** (4,000 HP, about 85% spore-armor reduction, 80 dmg), fast parasites | **450 Genome**, inhaler, sporicide; rare Gas Cylinder | Anti-Spore Pistol, Spore Blocker, gasoline, lens, cog, rubber, air filter, factory parts, carbon composite; rare ATV Wheel or Car Battery | Spore goop stays on the floor until the valves open after the fight |
| **Leviathan's Lair** (Bogs) | Western Watchtower (permanent), then **3 Boggy Region Points** or a purchase. The counter holds 0–3 indefinitely | ATV | A **3-day access timer** starts when the counter hits 3 | **Leviathan** (4,000 HP). Dives at 2,800 and 1,600 HP and only resurfaces after you set up another generator; Radioactive Roaming Zombies spawn meanwhile | **600 Genome**; the lair's storage | — | Daily tasks are spread across the Western Watchtower and Swamp Forest |
| **Icy Outskirts** (North) | daily task | — | **24 h**, then re-rolls | Frozen Fast Biter, Boar, Frozen Phantom, Frozen Bloater, **The Frozen Big One**; the "Winter of Despair" variant has 3 Infected Wolves and a Wendigo | — | Copper rocks | |
| **Bogside Outskirts** (Bogs) | ATV | 14 s drive / 75 fuel | 00:00 UTC | Berserker (1,000 HP here) slowly marches on the Gamma rig | Genesis Engineer (ATV modules), Janitor, ATV repairs; Drilling Rigs (**1 free start per day**) | Gate Beta (150 Parts for Sophisticated Equipment plus basics) and Gate Gamma (300 plus basics) | Hosts a 25-level **Genesis Expedition reputation** track paid in Genesis cards, with an infinite tier. Rewards include a Drone Module blueprint (L19), Box with a Kitten (L20), a Saint Bernard puppy (L22), a Broken Down ATV engine (L23) and 400 Genome (L25) |

Sources: [Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Watchtower), [Western Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Western_Watchtower), [Screech](https://last-day-on-earth-survival.fandom.com/wiki/Screech), [Borealis](https://last-day-on-earth-survival.fandom.com/wiki/Borealis), [Consilium](https://last-day-on-earth-survival.fandom.com/wiki/Consilium), [Leviathan](https://last-day-on-earth-survival.fandom.com/wiki/Leviathan), [Icy Outskirts](https://last-day-on-earth-survival.fandom.com/wiki/Icy_Outskirts), [Bogside Outskirts](https://last-day-on-earth-survival.fandom.com/wiki/Bogside_Outskirts), [Lighthouse Keeper](https://last-day-on-earth-survival.fandom.com/wiki/Lighthouse_Keeper), [Alpha Irradiator](https://last-day-on-earth-survival.fandom.com/wiki/Alpha_Irradiator).

### 2.6 Multiplayer zones and "settlements"

| Zone | Gate | Contents | Enemies / boss | Notes |
|---|---|---|---|---|
| **Abandoned convoy** | Page says **L30** | Entry event for the Crater. In Season 9 a scripted scene with Hazmat soldiers introduced a sibling character | none | Introduced 1.16.3 |
| **The Crater** hub | see §1.1 (conflict) | **Workshop** (bench slots grow with Business Level). **Shop**: sell for Counterfoils, a listing is locked for 1 h after posting, extra slots at Business Level 16 and 29. **Garage** (BL13, same time as the Chopper). **Apartment** (upgradable, other players can visit). Mailbox, Shower | — | A separate character and economy |
| Crater Chopper location: **Red Forest** | Crater Chopper | 2 chests: logs, oak (12), mushrooms (11), hide, meat, duct tape, scrap, plastic, bolts, air filter, flare, road sign, Katana, Old Revolver | Ashy Spitter, Ashy Runner, Ashy Bloater, Oozer, Guard | |
| **Bauxite Quarry** (2 skulls) | Crater Chopper | 2 chests: quartz, sulfur, iron ore, bauxite, parts | — | |
| **Crossroads** (2 skulls) | Crater Chopper | 5 cars (3 alarmed): lens, iodine, rubber, glass, electronics, Al plate and wire, Golf Club, Katana, Old Revolver | — | Alarmed cars are a risk/reward choice |
| **Container** (3 skulls) | Crater Chopper | Iron wire, springs, plates, the Scout's armor set, Old Revolver, handmade guns | **Devourer** | |
| **Old Mines** (3 skulls) | Crater Chopper | Acid, saltpeter, iodine, the Combat armor set, Halberd, MP5K, HK416 | **The Miner** (5,000 HP); the wiki calls him impractical solo | |
| *Sector 7* (Wall, Camp, Bunker, Cluster of anomalies), **removed** | Gateway Door repair (15 Al plates, 1 Electronic Circuit, 50 Wiring, 3 Steel Plates, 5 Wrenches, 40 Transistors); **Power Armor** to enter the Cluster | Daily scientific mission (study anomalies; reward a 1 h firearm-crit buff); clan storage; up to 3-player groups | Ashy Giant, Ashy Zombie | The first MP zone (1.8), removed 1.11.2–1.14.1 |
| **Settlement** (Act II) | Survivor's Path | A second *single-player* base with rooms, power and water (overview doc). It also gates story locations such as the Highway | — | No shared or MP "settlement" exists in the Wasteland. "Cult's Settlement" is a 1.53 event camp (§2.7) |

Sources: [Abandoned convoy](https://last-day-on-earth-survival.fandom.com/wiki/Abandoned_convoy), [The Crater](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater), [Crater's Chopper Locations](https://last-day-on-earth-survival.fandom.com/wiki/Crater%27s_Chopper_Locations), [Camp. Sector 7](https://last-day-on-earth-survival.fandom.com/wiki/Camp._Sector_7), [Wall. Sector 7](https://last-day-on-earth-survival.fandom.com/wiki/Wall._Sector_7), [Gateway Door](https://last-day-on-earth-survival.fandom.com/wiki/Gateway_Door), [Cluster of anomalies](https://last-day-on-earth-survival.fandom.com/wiki/Cluster_of_anomalies), [The Miner](https://last-day-on-earth-survival.fandom.com/wiki/The_Miner).

### 2.7 Season and event locations (current and retired)

These show the *template* Kefir reuses: a temporary map node, a task giver, an event currency, a reputation track and a shop.

| Location | When | Lifetime / reset | Mechanic | Rewards / currency |
|---|---|---|---|---|
| **Cult's Shelter** | Cult Hunting, Halloween 2026 (1.53) | On the map 24 h, refreshing at 00:00 UTC. A **2 h timer** starts on entry | Cultist enemies (Unarmed, Cultist, Arsonist, Shooter, Thug, Preacher). Lockpicks for locks | Small and Medium Occult Crates, opened at home in the **Buzzsaw** |
| **Cult's Camp / Cult's Settlement** | Cult Hunting | event | Raid tiered walls with breach consumables (overview doc) | Occult crates (Large ×1 each) |
| **Mysterious Forest** | On the Witch's Trail (Halloween 2025) | Run 8–12; resets almost instantly | Rotating tasks: kill Halloween zombies, examine tracks, kill 8 Poachers, deliver 5 Bandages, kill escaped beasts (Zombie Bear stuns), kill 5 Lurkers, kill the **Leshen** (1,600 HP), steal data from 8 Soldiers | 4 completed tasks open the Infected Forest |
| **Hunting Grounds** | Hunter's Instinct (18 days) | event | Fish or drill for Abrasive, upgrade the event weapons, and kill animals **only with the recommended weapon** for bonus samples | Ecologist reputation, Hunter's Token |
| **Climate Anomaly** | Anomaly Season (11 days) | event | Daily contracts to kill weather zombies with recommended weapons | Common/Rare Keys, Cutthroat's reputation |
| **Forlorn Fair** | occasional | **22 h** reset | 3 stages (Restoration, Preparation, Grand Opening), mini-games, an arena, William and Nigel | **Fair Coupon** (kept between events); see the odds in §4.3 |
| **Maze** | Season 16 | 24 h reset | Find the keeper's key: relight 2 fires (3 logs each), clear tool-gated obstacles (hatchet, pickaxe, basement door). 4 loot spots, one needing a Shovel | Family reputation items; weekly tool unlocks (Hacksaw and Nipper in week 1, Emergency lamp and Signal Amplifier in week 2…) |
| **Fort Moss** | Season 3 (until 8 Dec 2019) | event | Rebuild-the-fort quest chain (clear waves, deliver supplies, build 4 foundations) | Transistors, Iron Hatchet… |
| **Prison, Bikers' base, Convoy Stop, Roadside Junkyard** | Season 7, plus a seasonless rerun in May 2021 | event | 3 daily biker tasks at easy/medium/hard. Prison robbery by **Assault** or stealth. Assault spawns Convoy Stop (steal the bomb, optional sabotage) | Bike/Skull/Cross patches buy Club Member's, Treasurer's and Road Captain's boxes (10 patches each) |
| **Fair** | Season 8 | event | Piñatas, fighter betting (3 tries per 24 h, or a 50-coin reset), Zombie Corrida | Tickets, Travis reputation |
| **Infected Base** | Season 2 | **1 h** after entry | Cocoons (320), Tainted Zombies and Bloaters | Story notes |
| **Genesis outpost** | Season 14 | 12 h after entry | Story | — |
| **Strange factory** | Seasons 13, 18, 84–85 | 24 h; walk or run only | Odd keys, **Robo-Nick** (2 × 300), Greg (800 HP) | Christmas-tree decoration rewards |
| **Hidden Garden** | Lunar New Year | event; 13 / 10 m 22 s | Jiangshi, Terracotta Zombies; tasks | Secret Compartment Boxes (Nian treats) |
| **Hidden Ridge Farm** | winter holiday | event | Nomad at Home; elder and storekeeper reputation; cold | Decoration trades |
| **Smugglers' Camp** | Halloween 2017 (daily for 15 days, 24 h windows) | event | Capture numb zombies: 1 for the Chest, 2 for the Trunk, more for the Military Box (easy, medium, hard) | Tiered containers. An early "difficulty → container tier" pattern |
| **Mercenaries' camp** | 26 Apr – 13 May 2019 | event | Buy mercenary contracts with points (Terrain map 10, Field Ration 15, First Aid Kit 20). Rank 1 = 100 pts (1 perk, possibly negative), Rank 2 = 200 pts… Contracts last 30 min | — |
| **Snowy Race Track / Infected Junkyard / Greg's Barn** | Christmas 2018 | 8 h daily / 12 h after Claus | Races, trades; **Kramp** (1,000 HP) and Crawler hordes | Holiday items |
| **Arena (event)** | old, replaced by **Headhunting** (1.27.0) | event | Pick 1 of 3 bosses (Gnarly Billy, Feral Jesse, Lucy Luck) to duel | Blood samples |

Sources: [Cult's Shelter](https://last-day-on-earth-survival.fandom.com/wiki/Cult%27s_Shelter), [Mysterious Forest](https://last-day-on-earth-survival.fandom.com/wiki/Mysterious_Forest), [Hunter's Instinct](https://last-day-on-earth-survival.fandom.com/wiki/Hunter%27s_Instinct), [Anomaly Season](https://last-day-on-earth-survival.fandom.com/wiki/Anomaly_Season), [Forlorn Fair](https://last-day-on-earth-survival.fandom.com/wiki/Forlorn_Fair), [Maze](https://last-day-on-earth-survival.fandom.com/wiki/Maze), [Fort Moss](https://last-day-on-earth-survival.fandom.com/wiki/Fort_Moss), [Bikers' base](https://last-day-on-earth-survival.fandom.com/wiki/Bikers%27_base), [Convoy Stop](https://last-day-on-earth-survival.fandom.com/wiki/Convoy_Stop), [Fair](https://last-day-on-earth-survival.fandom.com/wiki/Fair), [Infected Base](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Base), [Strange factory](https://last-day-on-earth-survival.fandom.com/wiki/Strange_factory), [Smugglers' Camp](https://last-day-on-earth-survival.fandom.com/wiki/Smugglers%27_Camp), [Mercenaries' camp](https://last-day-on-earth-survival.fandom.com/wiki/Mercenaries%27_camp), [Infected Junkyard](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Junkyard), [Arena (Event)](https://last-day-on-earth-survival.fandom.com/wiki/Arena_(Event)).

---

## 3. Bunkers and dungeons

### 3.1 Bunker Alfa

**Access chain**
1. **Level 40** ([Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa)).
2. **CAC Card A**, used **once**, permanently unlocks the ground floor. Since 1.6 the corpse outside no longer carries one (it holds a half-used Glock). The overview doc notes an ad-based unlock from 1.27.
3. **A 5-digit code** at the ground-floor terminal opens the sublevels and creates a **48 h instance**:
   - The code rotates every 2 days and is shared per OS: Android and iOS differ.
   - Sources: the CB Radio, a Dead Soldier corpse (red X on the minimap in resource zones), or the official Discord.
   - **Since 1.44 the bunker resets only once the 48 h is up *and* you exit.**
4. **Rank IV "True Friend" dog**: opens the outside Minigun cage and 2 doggy doors on Floor 4.
5. **Cut Finger** (Destroyed convoy, Fishing Tournament chests) opens a locked lobby door (since 1.9.8).
6. **Burglar skill 1–3**: some sublevel lockers.

**Ground floor:** no enemies; 17 pine trees outside; **7 military lockers × 20 slots = 140 slots that never reset**. Players use it as a remote vault, including against NPC raids at L150+.

**Sublevel rules**
- Each floor loads as a separate zone. **Damaged zombies regenerate to full when you change floors.**
- Bunker zombies have no special attacks, shorter sight, and aggro as a group.
- Their stats differ from the outside: small zombies deal 10 dmg (Hard Mode: 15 dmg, +15 armor); big zombies deal 20 (Hard: 30, +20 armor).
- Since 1.18.7, corpses and drops stay where they fell, enemies keep their facing after you leave, and enemies in closed rooms are hidden on the minimap.

| Floor | Hazards / features | Enemies (normal) | Enemies (Hard Mode) | Loot and special |
|---|---|---|---|---|
| **F1 Lobby** | Coupon terminals, locked door (Cut Finger), Overseer room (after the rescue) | 5 Fast Biters, 1 Floater Bloater | unchanged; neither crates nor creatures reset when Hard Mode starts | 3 coupon terminals (table below). Quest-only safe for **27 red coupons** (beginner's guide) |
| **F2** | Pipe gas (some valves), gore (−50% move speed; wall arms do 3 dmg), a terminal door, 1 turret, The Big One caged in a lab (can't attack). A weapon-mod spot (since 1.9). **Specialist** caged near the terminal, guarded by Abominations | 8 Roaming, 13 Fast Biter, 5 Spitter, 8 Floater Bloater, 5 Abomination, 7 Frenzied Giant, 1 Turret | 2 Abominations and **3 Exploders** instead of 5 Abominations; fast Frenzied Giants | Coupons from corpses and lockers |
| **F3** | Electrified fence (5 dmg at a very high tick rate), **gas chamber** (needs a Gas Mask, Hazmat or CBRN helmet), pipe gas, gore, terminal doors, **laser tripwire alarms** (terminal off), 1 turret. Acid Bath blueprint table removed in 1.49 | 4 Fast Biter, **25 Spitter**, 1 Bloater, 16 Abomination, 10 Frenzied Giant, 1 Turret | 4 Abominations and **12 Exploders**, plus **The Blind One** behind an antechamber terminal (the door locks behind you, since 1.10) | The 2020 guide says most yellow and red coupons come from here |
| **F4** | 3 cold rooms, **8 indestructible spike mines**, 2 terminals, a generator (nonfunctional), 2 doggy doors | 7 Fast Biter, 6 Spitter, 1 Bloater, 5 Abomination, 3 Frenzied Giant, **3 Turrets, 3 Heavy Turrets**, 7 Numb Zombies, 3 Frozen Bloaters | **All Abominations become Exploders** (since 1.18.7) | Copper ore and bars, steel, turret parts |

**Security devices:**
- **Turret:** 250 HP, 15 armor (takes about 53% damage), 360° arc, roughly Glock range, which grows once it is firing at you. Ignores zombies; deals 20 dmg (30 on hard).
- **Heavy turret:** 500 HP, 45 armor (takes about 27% damage), also lobs grenades.

**Coupon exchange (F1).** Coupons drop from creature corpses and bunker lockers, and rarely outside (red zones, airdrops, convoys).

| Terminal | Price | Item rolls per box | Content classes (each roll may be empty) |
|---|---|---|---|
| **Rationing** | **20 green** (Ration Coupon) | 16 | Food stacks (5–10 beans or jerky), basic guns (AK, Glock, M16, Uzi) or melee, casual clothes, small parts, 1–2 gasoline, paint, alcohol, iron bars, nails, fabric, lens, mod blueprints |
| **Survival Kit** | **25 yellow** (Survival Kit Coupon) | 17–20 | Guns including the Shotgun, **Chopper Fork, Wheel or Gas Tank**, engine part, paint patterns ("Bloater", "Captain", "Harvey", "Nuclear"), the **Tactical set**, 2–3 First Aid Kits, 2–4 gasoline, bulk materials |
| **Combat Gear** | **30 red** (Combat Gear Coupon) | 26–29 | **Modified** AK, Glock, M16 and Uzi, the **Minigun**, chopper parts, patterns, a Signal Amplifier (removed 1.16.3), truck parts, **Tactical/SWAT sets**, steel, Al bars, 3–6 gasoline, 2–4 air filters, Gas Mask, **C-4**, a rare mod blueprint |

**Overseer room and Specialist** (unlocked by rescuing him on F2)
- **Hard Mode toggle.**
  - Irreversible until the 48 h instance ends.
  - Resets F2–F4 with buffed and new enemies.
  - Creatures drop **Identification tags / Chevrons / Military Notebooks** (1 / 2 / 3 rep points) instead of green / yellow / red coupons, at similar frequencies.
- **Reputation per level:**
  - **(conflict)**: the Specialist page says **115 points per level**; the Bunker Alfa page says 140.
  - A player estimate on the Specialist page: about 35 tags + 16 chevrons + 16 notebooks per level, which is exactly 115.
- **Level rewards:**
  - L3 **Colt Python**, L6 Glock Extended Magazine mod, L9 **FN SCAR**, L12 AK-47 Handmade Silencer mod, L15 **Milkor MGL**.
  - Every other level gives a **Floppy with coordinates**, and they keep coming after L15. The level display stops at 15.
- **Floppy → N 50.01061, E −110.1134**: a red location that lasts 12 h with one valuable crate, sometimes an **Infected Box** (§4.2). Floppy loot doesn't scale with reputation.
- **Blueprint exchange:**
  - Common mod blueprint = 10%, Rare = 50%, Extremely rare = 200%.
  - Each 100% buys 1 blueprint; the excess carries over.
  - It never pays out Extremely rare.
- Weapon modification at his bench.

**Hard-mode enemies:**
- **Exploder:** 300 HP, 20 armor, 45 dmg. At 50 HP it explodes and spawns 3 Parasites (40 HP each).
- **The Blind One:** 1,000 HP; armor 150 (about 90% DR) in its normal stance and 30 when stunned; heals at 700 and 400 HP; 50 dmg. Alarms in its room stun it.

Sources: [Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa), [Specialist](https://last-day-on-earth-survival.fandom.com/wiki/Specialist), [Overseer Keycard](https://last-day-on-earth-survival.fandom.com/wiki/Overseer_Keycard), [Coupons](https://last-day-on-earth-survival.fandom.com/wiki/Coupons), [Identification tags](https://last-day-on-earth-survival.fandom.com/wiki/Identification_tags), [Chevron](https://last-day-on-earth-survival.fandom.com/wiki/Chevron), [Military Notebook](https://last-day-on-earth-survival.fandom.com/wiki/Military_Notebook), [Floppy with coordinates](https://last-day-on-earth-survival.fandom.com/wiki/Floppy_with_coordinates), [Dead Soldier](https://last-day-on-earth-survival.fandom.com/wiki/Dead_Soldier), [CB Radio](https://last-day-on-earth-survival.fandom.com/wiki/CB_Radio), [The Blind One](https://last-day-on-earth-survival.fandom.com/wiki/The_Blind_One), [Exploder](https://last-day-on-earth-survival.fandom.com/wiki/Exploder), [Gamingonphone guide (2020)](https://gamingonphone.com/guides/last-day-on-earth-bunker-alfa-guide).

### 3.2 Bunker Bravo

**Gate:** **L75**. An **Electric Generator** must be placed in the machine that drives the elevator. On the first visit a scripted fight between Army Soldiers and Raiders breaks out, and you must kill the soldiers.

**Main level:** 22 dead trees outside; **6 lockers** inside that can be looted and then used as storage. Whether they reset is undocumented (Inference: they work like Alfa's).

**Rules:** Rank IV dogs can't enter the sub-floors. **Radiation** throughout (raised in 1.51): Hazmat is the minimum, CBRN is best. The recurring **"Bunker Bravo" event** cuts the HP of all enemies, bosses included, by **50%** and reduces radiation.

**Design difference from Alfa:** no coupons. You clear a floor and its boss, and the floor's **cargo** is lifted to the lobby, where you collect it with a button press.

| Floor | Theme / warehouse | Threats | Boss | Cargo (lifted to the lobby) |
|---|---|---|---|---|
| **F1 Lobby** | Cargo bay, elevator, **6 security terminals** | — | — | — |
| **F2** | Laboratory; carbon materials | Toxic Spewer, Acid Melter, Toxic Darter, Riot Zombie, Explosive Zombie, Stormtrooper, Exploder, Screamer; Fetid Corpse (boss room) | **Liquidator** (2,000 HP, 24 armor, 50 dmg, 5,000 XP) | Carbon Composite 4–6, Factory Parts 1–2, AntiRad 1, Cog 1–2, Gun Oil 4–5, Engine Part 1–3, Air Filter 1, 20 caps, plus 1 of: Light Bulb, USB Drive, Wrench |
| **F3** | Reactor zone; batteries and electronics | as F2 plus Slasher | **Doctor Dread** (5,000 XP; HP not stated; releases adds at 800/600/400/200 HP: 3 Riot Zombies, a Fetid Corpse, a Toxic Spewer, a Slasher) | Car Battery 3–4, Electronic Circuit 1, Hi-Tech 1–3, Anti-rad Pills 1, Factory Parts 1–7, Cog 3–5, Rubber 3–5, Spring 5, 30 caps, plus 1 of: bulb, flashlight, camera, USB |
| **F4** | Cooling systems; gas cylinders | as F3 plus **Juggernaut** (200 HP, 30 armor, heals 30 on hit); Parasites (boss room) | **Cocoon** (1,000 HP, 36 armor, spawns parasites) | Gas Cylinder 1, Explosive Material 1–3, Rubber 7–12, Cog 5–7, Factory Parts 8–10, Carbon 2, Lens 1, Hi-Tech 3–4, Gun Oil 1–3, Acid 3–5, **Grenade 3–5**, Spring 5–10, Steel Plate 2–4, Anti-rad Pills, Gasoline 2–4, Al Wire 2–4, Turret parts 1, **ATV Wheel 1**, Gunpowder 1, 50 caps, plus 1–2 of: watch, USB, B-Complex, camera |

**Security terminals.** Each is a one-time repair that unlocks a per-floor "security measure" option.

| Terminal | Effect | Repair cost |
|---|---|---|
| Deactivation of Turrets | Turrets inactive | 15 USB, 60 Transistor, 5 Hi-Tech, 60 Bolts, 60 Duct Tape, 10 Wrench, 10 Al Wire, 20 Iron Plate, 15 Spring, 3 Electronic Circuit |
| Opening Locks | Opens a small stash room | 20 Lead Plate, 95 Transistor, 95 Wiring, 5 Circuit, 80 Al Wire, 15 Wrench, 85 Duct Tape, 90 Bolts, 20 USB, 15 Hi-Tech |
| Patrol Cancel | Seals the patrol room | 95 Transistor, 80 Spring, 90 Wiring, 15 Wrench, 30 Al Wire, 10 Circuit, 80 Duct Tape, 100 Bolts, 20 USB, 15 Hi-Tech |
| Surface Rad Clearing | Removes radioactive puddles | 10 Steel Plate, 20 Rubber, 3 Hammer, 3 Cog, 15 Al Wire, 40 Duct Tape, 10 Al Plate, 10 Wrench, 80 Ball Bearing, 10 Air Filter |
| Ventilation Clearance | Clears vents full of enemies | 30 Spring, 15 Al Wire, 25 Air Filter, 80 Wiring, 70 Duct Tape, 15 Wrench, 10 Hi-Tech, 80 Transistor, 5 Circuit, 15 USB |
| Waterpumps | Drains flooded rooms | 20 Rubber, 5 Cog, 3 Hammer, 20 Al Plate, 5 Steel Plate, 5 Wrench, 10 Air Filter, 40 Duct Tape, 60 Bolts, 10 Al Wire |
| **All six** | — | 265 Wiring, 160 Al Wire, 310 Bolts, 330 Transistor, 375 Duct Tape, 23 Circuit, 45 Hi-Tech, **70 USB**, 70 Wrench, 80 Bearing, 125 Spring, 6 Hammer, 20 Iron Plate, 30 Al Plate, 15 Steel Plate, 20 Lead Plate, 8 Cog, 40 Rubber, 45 Air Filter |

The wiki's recommended terminals: F2 turrets plus patrol or vents; F3 turrets and patrol; F4 patrol and vents. **Inference:** the terminals are a permanent sink that turns the dungeon from a gear-burner into a farm. Since F2/F3 cargo pays at most 1 USB Drive per clear, the 70 USB drives alone imply dozens of clears or other sources. That is a built-in long-term goal.

Source: [Bunker Bravo](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Bravo), [Liquidator](https://last-day-on-earth-survival.fandom.com/wiki/Liquidator), [Doctor Dread](https://last-day-on-earth-survival.fandom.com/wiki/Doctor_Dread), [Cocoon (Bunker Bravo)](https://last-day-on-earth-survival.fandom.com/wiki/Cocoon_(Bunker_Bravo)), [Juggernaut](https://last-day-on-earth-survival.fandom.com/wiki/Juggernaut).

### 3.3 Blackport PD (the Police Station)

**Gate:** the Eastern Watchtower. **Reset:** 3 days.

**Rooms and enemies**

| Room | Enemies | Containers |
|---|---|---|
| Lobby | none | Vending machine, Police Card storage terminal, Raider card exchange |
| Main Hall | 3 Zombie Officers (1 dormant), 1 SWAT Officer (dormant) | — |
| Security / Camera room | 1 Hungry Chomper | 2 lockers (1 needs Burglar 1–3) |
| Office halls | 3–4 Officers, 1 SWAT Officer, 1 Chomper | 3 lockers |
| Lower meeting room | 3–4 Officers, 1 SWAT Officer, 1 Chomper | — |
| Higher meeting room | 1 Officer, 1 SWAT Officer, 1 Explosive Zombie | 1 locker: a **guaranteed Captain Card on the first visit** |
| Sheriff's office | 1 Riot Zombie | 2 lockers; the door needs **Burglar 3** |
| Jail hall / cells | 2 Jailbirds, 1 Chomper; 2 cells hold Jailbirds | **6 cells, each opened by a Cell Key** (drops from the Chomper and Officer in the briefing room). Each cell chest: tank top, carrot stew, jerky, about 4 scrap, iron plate |
| Holding cells | 4 Jailbirds, 1 Brawler, 1 Riot Zombie | — |
| Interrogation / observation | 1 dormant Officer | 1 chest with an Antenna; a drawer (Burglar) |
| Jail Yard arena | waves | 2 empty 20-slot lockers for staging |

**Police card chain**
- Cards: **Sergeant → Lieutenant → Captain → Inspector**. The Raider trades **10 lower cards for 1 higher**, so 1 Inspector = 10 Captain = 100 Lieutenant = 1,000 Sergeant.
- **(conflict):** Kefir's FAQ lists the grades as "sergeant, captain, lieutenant, inspector". The wiki's exchange chain and crate contents both put Lieutenant below Captain.
- **Sources:**
  - PD zombies; Captain is "very rare".
  - **Arena waves:** both drop rate and rarity rise with the wave number.
  - **Fishing Tournament:** chests hooked while fishing.
  - The Transport Hub's **BPD** crate.
  - **Supply** event: extremely-valuable cargo.
  - **Commune Trials** shop: Inspector.
- **Usage cap:** 3 terminal uses per reset by default. Terminals 4 and 5 are permanent repairs; each costs 60 Bolts, 20–25 Wiring, 30 Transistors, 3 Hi-Tech, 3 Wrench and 2 Circuits. **Terminal 6 needs 5 Tungsten Bars, which can't be obtained**, so the real cap is **5 crates per 3 days**.

| Crate | Item rolls | Contents (one of each listed group per roll) |
|---|---|---|
| **Sergeant** | 6 | Low melee (bat, cleaver, crowbar, golf club, hammer, pipe); 2–3 bandages or 1–2 FAK; drink or food; 3 rolls of common parts (bolts, wiring, duct tape, adhesive, plastic, lock and key, transistors, bearings, rubber parts) |
| **Lieutenant** | 12 | **Weapon Crate (guaranteed)**; a strong melee or Glock or Winchester; a **Common mod blueprint**; 1 Tactical or SWAT piece; Al or steel plate; medkit; an electronics valuable; wire or plastic; 3 adhesive; 3 springs; 2–3 small parts; 5 caps |
| **Captain** | 14 | 2 firearms (AK, flare gun, Glock, M16, Uzi, Shotgun, Winchester); **full Tactical set**; a **Rare mod blueprint**; plate; wire or plastic; paint; 5 bandages or 2 FAK; electronics; 5 adhesive; 10 caps |
| **Inspector** | 16 | **1 modified firearm** (AK, Glock, M16, Uzi, Shotgun or VSS); 3 more firearms; **full SWAT set**; an **Extremely Rare mod blueprint**; 2–3 Al or 1–2 steel plates; paint; wire or plastic; 3 FAK; electronics; 5 adhesive; 15 caps |

Since 1.15, carbon, factory parts, gun oil, hi-tech and springs were removed from the Captain and Inspector crates.

**Jail Yard arena (99 waves)**
- Start it at the arena terminal; the door locks behind you.
- After each cleared wave you choose to surrender or continue. Surrendering breaks the terminal, and **1 Electronic Circuit** restarts it.
- Wave sizes:
  - Waves 1–10 are scripted, from 2 Officers up to mixes of Explosive, Brawler, Chomper and Riot zombies.
  - Waves 11–20: 5 random enemies. Waves 20–40: 6. Waves 41–98: 7. Wave 99: 10.
  - The pool is Officer, SWAT Officer, Chomper, Explosive, Riot, Jailbird and Brawler.
- The last zombie of wave 99 drops the **Police Bike** Chopper skin.
- Community tactics are land mines and grenades.
- **Blackport PD event** (4 days, recurring each season):
  - +20% explosion protection; waves can be **paused** without losing progress or circuits.
  - Tasks: 35 / 200 / 560 arena kills; 6,500 / 35,000 / 95,000 damage; survive 10 / 45 / 90 waves.

**Police-family enemies:**
- **Zombie Officer:** 120 HP, 6 dmg. The Transport Hub version deals 15 and heals 15 per hit.
- **Hungry Chomper:** 240 HP, 15–30 dmg. Below 59 HP it slows but heals 30 per hit.
- **Jailbird:** 80 HP, 15 dmg, no drops.
- **Brawler:** 240 HP, 30 dmg, a scream that stuns for 5 s.
- **Riot Zombie:** 150 HP, 24 armor, raises a shield.
- **Explosive Zombie:** 100 HP, 24 armor, explodes below 25 HP.
- All grant 100 XP.

Sources: [Blackport PD](https://last-day-on-earth-survival.fandom.com/wiki/Blackport_PD), [Sergeant Card](https://last-day-on-earth-survival.fandom.com/wiki/Sergeant_Card), [Lieutenant Card](https://last-day-on-earth-survival.fandom.com/wiki/Lieutenant_Card), [Captain Card](https://last-day-on-earth-survival.fandom.com/wiki/Captain_Card), [Inspector Card](https://last-day-on-earth-survival.fandom.com/wiki/Inspector_Card), [Cell Key](https://last-day-on-earth-survival.fandom.com/wiki/Cell_Key), [Kefir FAQ – police armory](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/175-how-do-we-obtain-chests-from-the-police-armory), enemy pages.

### 3.4 Crooked Creek Farm

**Layout:** a crossing, 4 fenced plots, a house and a barn, on an 850 × 500 unit map. **Reset:** 48 h after entry.

**Plots.** Each of the 4 fenced plots rolls a random set-piece, and a plot can be empty:
- idle zombies (2 Yokels, 2 Giants);
- biters fighting farm zombies;
- wolves fighting farm zombies;
- raiders guarding a sack.

Haystacks in the left plots can release 3 Yokels; they despawn if the game is closed before they're fully out. Infected Bulls patrol 3 plots, and the **Ravager** patrols between the top two.

**Alertness model**
- **Idle** zombies have a vision cone and can be sneak-attacked for 3×.
- **Alert** zombies (about half the farm, including every "fighting" set-piece) can't be sneak-attacked. They stay alert after you exit, and a group joins in if you hit one.
- Non-boss zombies **keep their damage and facing** across exits; the **Ravager fully heals**.
- A spot behind the car near the bridge loses slow pursuers. Giants and Bulls give up and walk back.

**Barn key chain**
1. A key sits in one of the plot sacks (up to 3 sacks per reset).
2. The key opens the barn: the locked **Farm chest**, a partly built Chopper (10 slots; parts and gas), and maybe a puppy.
3. Carry the chest to the **table saw**. The noise pulls every surviving zombie plus 2 Yokels and 1 Giant from off-screen, but not the Bulls or the haystack Yokels.

**Farm chest** (60 slots; 18–21 items): Hammer or Shovel; a Common, Rare or Extremely rare mod blueprint; 2 Engine Parts, 5 Springs, 1 Steel Plate; paint; 5 bandages and 3 FAK; Al bars, Al wire, iron plate; 2 electronics rolls; Survivor's Notes or a Valuable Survivor's Diary; food; copper bars; adhesive, nails, leather, fabric; small parts; a reinforced or tactical piece for each armor slot; modded melee (Cleaver, Machete, Pipe, Skull Crusher) or a Scythe; and a gun (AK, Colt Python, Flare Gun, Glock, M16, Uzi, Shotgun).

**Other storage:** car trunk 5, mailbox 5, 3 burlap bags (60 total), living-room cabinet 20, 2 bedroom cabinets (40 total, Burglar since 1.11.6), barn Chopper 10. **Puppy chances:** the house, 1–2 plots, and the barn. **Magazines / Bunker Documents** (Exploration XP) also drop from Farm storages.

Sources: [Crooked Creek Farm](https://last-day-on-earth-survival.fandom.com/wiki/Crooked_Creek_Farm), [Ravager](https://last-day-on-earth-survival.fandom.com/wiki/Ravager), [Magazines/Bunker Documents](https://last-day-on-earth-survival.fandom.com/wiki/Magazines/Bunker_Documents).

### 3.5 Transport Hub

**Entry:** the Drone opens the front gate.

**Warehouse floors**
- **Lobby:** 4 armored, self-healing Officers or Chompers; a vending machine; the **CAC Card terminal**.
- **Lower shelving 1:** 4 Groaners (bleed 20/s × 6) and an Acid Melter, all aggroing together.
- **Lower shelving 3:** 3 armored, healing Carrion; 1 Darter; 4 Parasites.
- **Catwalks:** 4–5 Toxic Darters.

**One-time builds**
- **Forklift:** 5 Rotors, 40 Al Cables, 20 Motor Oil, 10 Titanium Bars, 40 Rubber Parts, 10 Hydraulic Parts. It unlocks the 4th crate slot.
- **Bridge:** 40 Screws, 20 Light Parts, 20 Light Frames, 40 Duct Tape, 20 Iron Wire, 10 Iron Sheets. It unlocks the **Police Barracks**: armored Riot/Explosive rooms, an electrified puddle, and a shelf chest with 3 Drone Parts plus a chance at a drone blueprint (possibly no longer obtainable).

**Crate selection:** 4 shelf positions, each with a **50/50 roll between two crates** per reset ([CAC Card Key](https://last-day-on-earth-survival.fandom.com/wiki/CAC_Card_Key)).

| Slot | Possible crates | Contents |
|---|---|---|
| 1 | AID#837983 / UNKNOWN SHIPPER | First aid and herbs / unknown |
| 2 | GM#4593 / CYF#554309 | Garage and vehicle items / building and Settlement materials |
| 3 | ARM#1122_01 / BPD#3782 | Weapons, modded weapons, armor, weapon blueprints / **Police cards**, weapons, modded weapons, armor, blueprints |
| 4 (needs the Forklift) | CLASSIFIED / GENESIS | Genesis-exclusive items, drone mods and drone blueprints |

**Keys:**
1. Each chosen crate must first be **scanned by the Drone**, which spends a charge.
2. The **CAC Card Key** that powers the terminal comes from the boss container in the Hub's own dockside **Port Area** (part of the Transport Hub, not the Port location). A 40-foot container dropped on debris opens that area.
3. Each reset, one of three shipping containers holds either the **Butcher** or the **Miner**.
   - **Butcher:** 2,500 HP, 20 armor; 80 punch / 45 slam / 30 cone.
   - **Miner:** 3,000 HP, armor 30 → 40 below 1,500 HP, doesn't heal.
   - Opening the container **locks all exits until the boss dies**.
   - The CAC Card Key page names only the Miner as the dropper; the Hub page says either boss drops it.

**Other two containers per reset**
- **ECHO container:**
  - 2 "Pale Zombies" (armored, cause bleed, heal on hit).
  - A chest with 10 rolls: a melee weapon (Saw Blade Mace, Machete or Katana) and a sidearm or ranged weapon (Glock, Uzi, Harpoon or Crossbow).
  - Materials: fiberglass, glass, carbon, factory parts, gun oil, rubber, circuit, hi-tech, FAK, bandages, anti-rad pills, titanium armor fragments, air filter.
  - Rare **Neutralizer**.
- **Random event container**, one of six outcomes:
  - empty, with a note (the items are in the ship);
  - a lab with 2 Scientists;
  - a Cocoon with 2 zombies and a crawler that guards a chest;
  - a car;
  - an escaping **Pest** that drops Eva reputation items if you kill it in time;
  - a frozen container with 2 numb Fast Biters and food plus strong alcohol.

Sources: [Transport Hub](https://last-day-on-earth-survival.fandom.com/wiki/Transport_Hub), [Butcher (Boss)](https://last-day-on-earth-survival.fandom.com/wiki/Butcher_(Boss)), [Miner (Wasteland)](https://last-day-on-earth-survival.fandom.com/wiki/Miner_(Wasteland)), [Groaner](https://last-day-on-earth-survival.fandom.com/wiki/Groaner).

### 3.6 Port Laboratory (Genesis Lab), a roguelite dungeon

**Access:** Survivor's Path plus a level gate, then a one-time Eva mission to clear the main floor. **Reset:** 3 d per the Lab page, shared with the Sewer **(conflict with the Port page's 48 h)**. Third floor: an abandoned subway with the **Janitor** and a **Trolley** that can't be finished yet (its Processor isn't in the game).

**Floor 1 (hub)**
- **Repository:** turn in cards and data for Genesis Scientists' Reputation (**Eva**).
- **Genesis Storages:** buy items with **Infection Samples**, each item once per reset.
- **Bioreactor:** feed it organic resources to charge sector entry.
- **Protocol terminal:** Hard Mode, unlocked through Lab reputation.
- **Perks & Threats console.**
- **Seaweed Farm and Janitor** in the Covered Dock.

**Floor 2 run structure**
- 4 sectors, played strictly in order **A1 → A2 → B1 → B2**. Each costs 1 Bioreactor charge.
- At each sector terminal you **pick 1 of 3 random perks**. The perk then applies to every remaining sector, and that sector's **threat** stays active for the rest of the run.
- **4 threats are rolled per run**, for example *Frenzy*: +100% damage below 30% HP; *Lethality*: +15% damage. One activates in each sector. Some can be avoided via the console.
- Perks come in Common, Rare and Very Rare rarities and grow with Lab reputation. Very Rare perks appear only if you enable them at the console. Most perks don't affect bosses.
- The Hologram reward: beat Necrotic Hybrid on your first run without dying or using a Reanimator **(unverified for the current version)**.

| Sector | Theme / hazard (requirement) | Enemies | Boss (normal / hard HP) |
|---|---|---|---|
| **A1** | Greenhouse; spores (**10 spore protection**) | 24 Infected Lab Assistants, 5 Toxic Darters, 12 Spore Runners, 5 Spore Spitters, 4 Spore Bloaters, 7 Spore Giants, 2 Shamblers | **Necrotic Hybrid** 2,000 / 3,000; spore-armored; 55–120 dmg |
| **A2** | Technical bay; electric traps; spores | about 24 Assistants, about 10 Darters, about 18 Spore Runners, 4 Spitters, 5 Bloaters, 6 Giants, 2 Shamblers | **Carrion MK VII** 2,000 / 3,000; a Power-Armor zombie; 60–100 dmg |
| **B1** | Cryo lab; **cold** (resistance or heat sources) | 28 Frozen Lab Assistants, 15 Numb Fast Biters, 3 Frozen Fast Biters, 9 Frozen Bloaters, 1 Frozen Giant, 1 **Wendigo** | **Icebreaker** 2,000 / 3,000; ice armor that must be chipped off |
| **B2** | Weapons factory; laser traps; **every enemy needs armor-piercing (AP) weapons** | 24 Groaners, 23 Scientists, 13 Acid Melters, 3 Toxic Spewers, 4 Screamers, 3 Exploders, 2 Juggernauts | **Blight MK VIII** (stats not captured) |

**Inference:** the Lab is LDoE's cross-region capstone. Its four sectors check the spore, cold and AP gear chains in a single run.

**Drops and storages.** Normal mode drops A/B cards; **hard mode drops A+/B+** instead.

| Source | Key card A / A+ | Key card B / B+ | Other |
|---|---|---|---|
| Sector A1/A2 enemies | 0–2 | — | 0–1 Employee badge or Data disk |
| Sector B1/B2 enemies | — | 0–2 | 0–1 Employee badge or Data disk |
| A1/A2 bosses | 2–5 | — | 2–8 Hard drives, 0–5 Data disks, 1–6 Employee badges; Carrion also 0–1 ATV Transmission and 2–4 Wiring; Hybrid 0–3 Thick Hide; 5–7 Spore Samples |
| B1/B2 bosses | — | 2–5 | Hard drives, disks, badges; Blight 0–3 Thermite |
| Sector storages (2 open + 1 behind the "Pass" perk per sector) | 3–6 cards of the run's type (5–9 in senior staff rooms with the Rare Pass perk) | same | 1–2 Data disks (or 0–1 if a Hard drive is present), 0–1 Hard drive, 1–3 Pipes, 1–2 Reagent boxes, Rubber Hose (0 or 3, max 15), 1–3 badges (hard only) |

**Infection Samples per kill.** For non-boss A1 enemies the wiki's formula is roughly HP ÷ 32.

| Enemy | Normal | Hard |
|---|---|---|
| Lab Assistant | 1 | 2 |
| Toxic Darter | 2 | 3 |
| Spore Runner / Spitter | 5 | 8 |
| Spore Floater Bloater | 10 | 15 |
| Spore Giant | 14 | 21 |
| Shambler | 20 | 30 |
| Necrotic Hybrid / Carrion MK VII | 100 | 150 |
| Frozen Assistant | 2 | 3 |
| Numb FB | 4 | 6 |
| Frozen FB | 6 | 9 |
| Frozen Bloater | 9 | 14 |
| Frozen Giant | 25 | 38 |
| Wendigo | 40 | 60 |
| Icebreaker | 150 | 225 |
| Groaner | 1 | 2 |
| Scientist | 3 | 5 |
| Acid Melter / Toxic Spewer | 6 | 9 |
| Screamer / Exploder | 12 | 18 |
| Juggernaut | 28 | 42 |
| Blight MK VIII | 180 | 270 |

**Repository turn-ins (Eva reputation).** Per-item value, with a turn-in limit per reset:

| Item | Rep each | Limit per reset |
|---|---|---|
| Key card A | +10 | 100 |
| Key card B | +15 | 100 |
| Key card A+ | +15 | 100 |
| Key card B+ | +25 | 100 |
| Employee badge | +20 | 100 |
| Data disk | +40 | 50 |
| Hard drive | +60 | 50 |

**Eva's track:**
- Per-level XP starts 60, 110, 170, 220, 280, 330, 390, 440, 500, 550…
- Rewards: 100 Samples, 20 FAK, 15 Protective Fabric, 300 Samples, 60 Gasoline, 20 Processed Quartz, 20 Inhalers, 14 Copper Bars, 5 Drone Batteries…
- Premium rows sit at levels 4, 8, 12, 16, 20 and 24, plus the infinite tier.
- Higher Eva levels also add Genesis Storage slots.

**Key card boxes.** Card-specific boxes on the Lab's first floor are opened by spending the card. Higher Lab reputation raises the chance of an **armor-piercing** weapon from the A+/B+ boxes.

| Card | Weapon roll groups | Armor | Consumables and materials | Caps |
|---|---|---|---|---|
| **A** | Glock, Uzi, Neutralizer / AK-47, Shotgun, Equalizer / Neutralizer, Equalizer | Hazmat, Tactical or SWAT piece per slot | 1–2 Inhaler, 2–3 FAK, 4–6 Bandage, Energy cells, Air Filter, Reagent box, 3–5 Catalyst, 3–5 Acid, 1–2 Gasoline; rare **Reanimator** | 50 |
| **A+** | adds M16, **Ultimatum, Resonator, Protector** | **CBRN set** | 3–6 FAK, AntiRad, anti-rad pills, hi-tech, USB, rubber, catalysts, acid, paints; sometimes a Reanimator | 150 |
| **B** | Modded Glock, Neutralizer, Protector, Ultimatum, Resonator, Equalizer, AK | **SWAT set** | Inhalers, FAK, AntiRad, 2–3 Grenades, Explosive Material or Land Mines, Energy cells, springs, catalysts, plastic, USB; rare Turret parts or Heat sensor; rare Reanimator | 50 |
| **B+** | adds M16, Shotgun, **Milkor MGL, FN SCAR** | **Kevlar set** | 3–6 FAK, 3–6 Grenades, mines or explosives, factory parts, gun oil, steel, carbon, cog, springs, gunpowder, USB; possible Reanimator | 150 |

**Lab event** (4 days, recurring): AK-47 and M16 +50% damage in the Lab, Equalizer +25%, +25% event currency. Tasks: 3,250 / 17,000 damage; 30 / 60 / 90 kills; pass 2 sectors; kill Carrion MK VII.

Sources: [Port/Laboratory](https://last-day-on-earth-survival.fandom.com/wiki/Port/Laboratory), [Key card A](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_A), [Key card A+](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_A%2B), [Key card B](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_B), [Key card B+](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_B%2B), [Necrotic Hybrid](https://last-day-on-earth-survival.fandom.com/wiki/Necrotic_Hybrid), [Carrion MK VII](https://last-day-on-earth-survival.fandom.com/wiki/Carrion_MK_VII), [Icebreaker](https://last-day-on-earth-survival.fandom.com/wiki/Icebreaker), [Corrupted CEO](https://last-day-on-earth-survival.fandom.com/wiki/Corrupted_CEO).

### 3.7 Unreleased bunkers: cards that drop for content that doesn't exist

| Bunker | Card | Where the card drops | Status |
|---|---|---|---|
| Charlie | CAC C | Random loot (Farm, Oak Bushes, Motel, pine and limestone zones) | Visible on an island in the south. It needs the **uncraftable Mi-24**, so it is unreachable |
| Delta | CAC D | Random loot | Not in the game |
| Foxtrot | CAC F | Random loot | Datamined model only |
| Romeo | CAC R | Crash Site baggage, random loot | Not in the game. The wiki says a release is "highly unlikely" |
| Zulu | CAC Z | **Borealis** (since 1.30.1) and **The Big One** | Not in the game |

- **Card drops:** any **Toxic Abomination or Swamp Bloater** may drop one CAC card of any type except Z, and AI Survivors may also drop cards. Per the wiki, CAC A drops from green- and yellow-zone zombies *after* you have invited the Raiders. No drop percentages are published anywhere I found.
- **Recycling:** every CAC card recycles into **Plastic** in about 10 min. **Inference:** this gives junk cards a value floor so that hoarding them isn't pure dead weight.

Sources: [CAC Cards (A-Z)](https://last-day-on-earth-survival.fandom.com/wiki/CAC_Cards_(A-Z)), [Bunker Charlie](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Charlie), [Bunker Delta](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Delta), [Bunker Foxtrot](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Foxtrot), [Bunker Romeo](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Romeo), [Bunker Zulu](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Zulu).

### 3.8 Key and access chains (master table)

| Key / requirement | Kind | Opens | Where it comes from | Consumed? |
|---|---|---|---|---|
| Player level 10 / 15 / 35 / 40 / 75 | level gate | East / North, Farm, Port, Gas Station / Infected Forest / Alfa / Bravo | XP | — |
| Watchtower repair | quest plus build plus boss | a region's map nodes | parts, generator, vehicle | permanent |
| Vehicle (Chopper / Motorboat / ATV / Mi-24) | travel gate | Rest Stop, Junkyard, Oak and Uncharted zones / Islands / Bogs / Bunker Charlie | two-phase builds (economy doc) | — |
| **CAC Card A** | item key | Alfa ground floor | zone zombies, Abominations, AI survivors, Airdrop (rare), Pine Bushes storages | once, permanent |
| **Alfa code** | time-rotated secret | Alfa sublevels for 48 h | CB Radio, Dead Soldier corpse, Discord | per reset |
| Specialist rescue | quest flag | Overseer room, Hard Mode, Floppies, blueprint exchange | Alfa F2 | permanent |
| **Coupons G/Y/R** | currency | Ration / Survival / Combat boxes (20/25/30) | Alfa corpses and lockers; rare outside | yes |
| **ID tags / Chevrons / Notebooks** | currency | Specialist reputation (1/2/3 pts) | Alfa Hard Mode kills; ID tags also from fishing; Fishing Tournament chests | yes |
| **Floppy with coordinates** | spawn item | N 50 location (12 h) | Specialist levels | yes |
| **Cut Finger** | item key | Alfa lobby secret door | Destroyed convoy soldier; Fishing Tournament chest | (unverified) |
| Rank IV True Friend dog | companion gate | Alfa Minigun cage, Alfa F4 doggy doors | dog breeding | — |
| Burglar skill L1–3 | skill gate | locked lockers and doors (Motel, PD, Farm bedroom, Alfa sublevels, basements) | skill picks | — |
| Hacker skill | skill gate | hi-tech basement doors | skill (Exploration XP from Magazines) | — |
| Tools (Iron Hatchet, Crowbar, Shovel, Manual Earth Drill, Lockpick, Bolt Cutter) | tool gate | Factory boxes, Bog doors and Western gate, Maze, sand and dig spots, island ores, cult caches | crafting / event shop | durability |
| Electric Generator | placed object | Bravo elevator, Port Sewer, Northern Watchtower | crafted | yes |
| **Police cards S/L/C/I** | currency | PD crates (3–5 per 3 days) | PD kills and waves, fishing, Transport Hub BPD, Supply cargo, Commune shop | yes; 10:1 up-trade |
| Cell Key | item key | 1 PD jail cell | Chomper or Officer in the briefing room | yes |
| Drone (with a charge) | tool gate | Transport Hub gate; crate scans | built (economy doc) | charge |
| **CAC Card Key** | item key | Transport Hub crate terminal | Butcher or Miner in a container in the Hub's own dockside "Port Area" (not the Port location) | per use (Inference) |
| Forklift / Bridge | one-time build | Hub crate slot 4 / Police Barracks | parts lists (§3.5) | permanent |
| Survivor's Path progress plus Eva mission | quest gate | Port Laboratory | story | permanent |
| Bioreactor charge | consumable gate | each Lab sector | organic resources | yes |
| **Key cards A/B/A+/B+** | currency | Lab card boxes; Eva reputation | Lab kills, bosses, storages | yes |
| Region Points (0–3) | daily counter | Ice-Trapped Ship / Landfill / Leviathan's Lair | 3 daily tasks per region (reset 00:00 UTC), or a purchase | spent on entry |
| Greyhound tasks (4) | event counter | Infected Forest | Mysterious Forest tasks | per event |
| Abandoned convoy plus level | quest gate | The Crater | event | permanent |

---

## 4. Loot containers and loot boxes

### 4.1 Containers in the world

| Container | Where | Capacity | Access | Typical contents | Reset |
|---|---|---|---|---|---|
| Loot bag / box / chest | Resource zones | Up to 5 items. 1–3 per green zone, 3–4 per yellow | none | Food, water, low-tier parts, melee; rare CAC A, vehicle parts | on exit |
| Ruined-base chests and basement trapdoor | Resource zones (random roll) | varies | Wooden / Burglar / Hacker | Iron plate, scrap, plastic, spring, batteries, copper ore deposit | on exit |
| Baggage / suitcase | Crash Site (14), Rest Stop | 12 | none | Clothes, scrap, gold bars, CAC Romeo, Glock | one-time / event |
| Aid Box | Airdrop | 20 | guarded | 1 half-durability weapon plus parts, coupons, caps | while spawned |
| Military box / storage | Destroyed convoy (3 boxes + 4 storages) | 20 | guarded | Military gear | 1 h event |
| Soldier corpse | Destroyed convoy; Dead Soldier in zones | 20 / none | — | Coupons, Cut Finger, tactical pieces / the bunker code only | with the location |
| Military lockers | Alfa ground floor (7), Bravo main level (6) | 20 each | CAC A / generator | One-time loot, then **permanent storage** | never |
| Sublevel lockers | Alfa F2–F4 | — | some need Burglar 1–3 | Coupons (normal) / tags (hard) | 48 h |
| Sacks, mailbox, car trunk, cabinets | Farm | 5–60 | Burglar (bedroom) | Barn key, parts, documents | 48 h |
| **Locked Farm chest** | Farm barn | 60 | Barn key plus the table saw (spawns a horde) | 18–21 rolls (§3.4) | 48 h |
| Police lockers / cell chests | PD | — / small | Burglar 1–3 / Cell Key | Cards, small items | 3 d |
| Card terminals / conveyors | Alfa (coupons), PD (police cards), Hub (CAC Card Key), Bravo (cargo elevator) | — | currency or key | Box per use | per reset |
| Lab sector storages | Port Lab | — | 2 open, the 3rd needs the **Pass perk** | Key cards, data, pipes, reagents | 3 d |
| Rusty Vehicle | Resource zones, Junkyard | — | none | Sometimes a **Rusty Engine**, a heavy object that only travels by vehicle and is recycled at Home | on exit |
| Ruined tank | Frosty Backwoods (chance) | — | none | At least 1 random gun plus parts and tactical armor | on exit |
| Extractor / landmark chests | Bogs | — | Crowbar doors, ATV-hinged doors | Parts | 00:00 UTC |
| Preset crates (#1–#5) | Spore Islands | — | none | **The same fixed table on every island.** #1 medicine plus sporicide and iodine; #2 rubber, wiring, thick leather… | on exit |
| Heavy objects (Infected Box, Sunken Box, Crates of Lead/Sulfur/Antimony, Heavy Ash Log, Tools Crate, Occult crates) | Various | 1 carry | Carried by hand or in a vehicle trunk; processed at Home (Buzzsaw) | See §4.2 | — |
| Fishing chests | Fishing Tournament (hooked) | — | Fishing rod | Full-durability weapon or armor, Chopper parts, **Cut Finger**, **Sergeant/Lieutenant/Captain cards**, Chevron, ID tags, Military Notebook | 1 d |
| Cult caches | Cult event camps | — | Lockpick / Bolt Cutter | Event loot | event |
| Container (Wrecked ship) | Wrecked ship event | — | 1 free per reset, then paid | Rarity-tiered pack | per reset |

Sources: [Baggage](https://last-day-on-earth-survival.fandom.com/wiki/Baggage), [Rusty Vehicle](https://last-day-on-earth-survival.fandom.com/wiki/Rusty_Vehicle), [Loot crates in the Spore Island](https://last-day-on-earth-survival.fandom.com/wiki/Loot_crates_in_the_Spore_Island), [Fishing Tournament](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Tournament), plus the location pages above.

### 4.2 Reward boxes and chests

There is **no "gold chest"** in current LDoE that I could find. "Gold" appears only as the **Gold Bar** loot item (Motel, Factory, Basements, Crash Site; trade 1 Gold Bar + 1 Expensive Watch to Dealer Joe for a Weapon Crate) and as the **Gold Rush** coin-spend event. The season-pass "chests" are the **Infinite Packs**.

| Box | Source | Cost / trigger | Contents | Published odds / rules |
|---|---|---|---|---|
| **Unknown Box** | Free ad box | Watch 1 video ad; **next available 1 h later**; reward goes to the Inbox | The current fixed pool is Reinforced beanie, jacket, jeans and boots, Glock 17, 5 First Aid Kits, Machete, Military Backpack and AK-47. The older list (coins, logs, carrots, katanas, engine parts…) is **(stale)** | No odds. The wiki says the Military Backpack and AK-47 are the rarest and the Machete slightly rare. 50 Coins were added as a reward in 1.14.3 (whether that's still in the pool is unclear) |
| **Weapon Crate** | Dealer Joe, Lieutenant crate (guaranteed), Rest Stop, AI survivors, Settlement Old Train Station daily reward (level 40) | — | 1 of 8: Glock, Katana, M16, Machete, Metal Pipe, Saw Blade Mace, Shotgun, Skull Crusher | Community sample (§4.3) |
| **Ration Box / Survival Kit / Combat Gear Box** | Alfa F1 terminals | 20 green / 25 yellow / 30 red coupons | 16 / 17–20 / 26–29 rolls | Each roll can come up empty |
| **Police crates (Sergeant / Lieutenant / Captain / Inspector)** | PD terminal | 1 card each | 6 / 12 / 14 / 16 slot-rolls (§3.3) | 3–5 per 3-day reset |
| **Bravo cargo (F2/F3/F4)** | Bravo lobby | clear the floor and boss | §3.2 | some items "by chance" |
| **Key card A / A+ / B / B+ boxes** | Port Lab | 1 card | §3.6 | AP-weapon chance rises with Lab reputation |
| **Farm chest** | Farm barn | key plus a horde defence | 18–21 rolls | — |
| **Floppy crate** | N 50 location | 1 Floppy | The first crate is fixed for every player; later crates are random military cargo | Uncommonly replaced by an Infected Box. Loot doesn't scale with reputation |
| **Infected Box** | N 50 location | — | Opened only in the **Buzzsaw** (since 1.47.1; previously an Acid Bath) | Deals 3 dmg/s while carried. On the ground at Home it attracts zombies (Crowd, Fast Biter, Spitter, Bloater, Abomination) and decays to scrap in 15–25 min. A vehicle trunk prevents both |
| **Sunken Box** | Source page not captured (Inference: Port deliveries or fishing, since contents scale with Genesis delivery reputation) | Buzzsaw + 5 Air Filter + 5 Acid + 5 Steel Bar, **1 h** (or 21 coins) | 4–10 Glass, 1–5 Fiberglass, 1–4 Carbon, 1–4 Factory Parts… | **Quantity scales with Genesis delivery reputation.** Max 2 at Home. Needs a vehicle to bring home |
| **Mechanic's Box** | Gas Station | — | Custom Bike blueprint (common), Military Motorcycle (rare), **Police Bike (extremely rare)**, Repair Kit (rare) | **Pool narrowing:** once a bike reaches level 3 its blueprint leaves the pool and the others become more likely |
| **Infinite Pack** (season pass) | Season levels | — | Guaranteed one of: a Tactical piece, 3 FAK or a Glock 17; a chance at backpack or character skins | Rare, Very Rare and Extremely Rare tiers exist (Season 99 L1 premium gives an Extremely Rare pack), but their wiki pages are empty |
| **Armorer's crate / Gunsmith's crate** | Shop / events | — | Armor (Reinforced → SWAT, Ghillie, Raider) / weapons (melee → AK, a modded Glock) plus 1 equipment item | Each opening gives 1 common item plus chances at rare, very rare, extremely rare or guaranteed. **Pity: at least very rare on every 5th crate** |
| **Scavenger's crate → Collector's crate** | Big Hunt event | 25 Scavenger's Keys → 1 random item + 1 **Collector's Key**; 5 Collector's Keys → Collector's crate | Basics, tools, Shepherd puppy, skins | Every 5th Scavenger crate is at least very rare. **A two-stage key ladder** |
| **Cutthroat's Common / Premium crate** | Anomaly Season | Common: 40 per crate or 400 for 10, with a **Rare Key** inside. Premium: 5, or 50 for 10 | 1 random item per opening | The cost currency's icon was stripped from the wiki text **(unverified)**. Rare Keys also come from premium contracts and the shop |
| **Club Member's / Club Treasurer's / Road Captain's Box** | Season 7 | 10 Bike / Skull / Cross patches | Biker gear and basics / explosives and parts / Motorcycle set, M16, Repair Kit, 50 caps | Unlock week by week (weeks 1, 2, 3) |
| **Researcher's box / case / chest** | Season 10 research | low / mid / high difficulty | 1 item from tiered pools (from bandages up to Scientist's helmet and UV lamp) | Difficulty tier → container tier |
| **Halloween container (2020)** | Event coupons | — | Minigun, FN SCAR, Elite Shepherd puppy, 250 caps, 2 C-4, 10 FAK, Gravestone, skins | Limited to 8 Nov 2020 |
| **Small / Medium / Large Occult Crate** | Cult Hunting 2026 | Opened in the Buzzsaw | Event loot | Count by camp tier: Shelter gives S×2 + M×1; Camp S×1 + M×1 + L×1; Settlement M×2 + L×1 |
| **Fair Coupon prize** | Forlorn Fair | 1 coupon (kept across events) | **5 random items per coupon** at the maxed prize stand (maxes at Restoration level 27) | Community sample (§4.3) |
| **Supply cargo** | Supply event | Kills give Control Points; a delivery arrives **every 6 h** (skippable with coins) | Tier: Common 0, Worthwhile 250, High-value 750, Extremely valuable 1,500 CP | At least 1 item is revealed in advance. An unclaimed delivery blocks the next one and is **lost if the event ends**. The 9-slot storage persists |
| **Slot Machine** | Gas Station | 10–50 Caps per spin | Caps back, Tokens on jackpot; 100 Tokens → a bike model at Lenny | The jackpot box never resets. During **Pursuit of Luck**, wins also pay Clovers toward milestone rewards, and the track can be reset for free and run again |

Sources: [Unknown Box](https://last-day-on-earth-survival.fandom.com/wiki/Unknown_Box), [Weapon Crate](https://last-day-on-earth-survival.fandom.com/wiki/Weapon_Crate), [Infected Box](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Box), [Sunken Box](https://last-day-on-earth-survival.fandom.com/wiki/Sunken_Box), [Mechanic's Box](https://last-day-on-earth-survival.fandom.com/wiki/Mechanic%27s_Box), [Infinite pack](https://last-day-on-earth-survival.fandom.com/wiki/Infinite_pack), [Armorer's crate](https://last-day-on-earth-survival.fandom.com/wiki/Armorer%27s_crate), [Gunsmith's crate](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith%27s_crate), [Scavenger's crate](https://last-day-on-earth-survival.fandom.com/wiki/Scavenger%27s_crate), [Big Hunt](https://last-day-on-earth-survival.fandom.com/wiki/Big_Hunt), [Common Cutthroat's Crate](https://last-day-on-earth-survival.fandom.com/wiki/Common_Cutthroat%27s_Crate), [Premium Cutthroat's Crate](https://last-day-on-earth-survival.fandom.com/wiki/Premium_Cutthroat%27s_Crate), [Rare Key](https://last-day-on-earth-survival.fandom.com/wiki/Rare_Key), [Club Member's Box](https://last-day-on-earth-survival.fandom.com/wiki/Club_Member%27s_Box), [Researcher's chest](https://last-day-on-earth-survival.fandom.com/wiki/Researcher%27s_chest), [Halloween container](https://last-day-on-earth-survival.fandom.com/wiki/Halloween_container), [Small Occult Crate](https://last-day-on-earth-survival.fandom.com/wiki/Small_Occult_Crate), [Fair Coupon](https://last-day-on-earth-survival.fandom.com/wiki/Fair_Coupon), [Supply](https://last-day-on-earth-survival.fandom.com/wiki/Supply), [Slot Machine](https://last-day-on-earth-survival.fandom.com/wiki/Slot_Machine), [Token](https://last-day-on-earth-survival.fandom.com/wiki/Token), [Pursuit of Luck](https://last-day-on-earth-survival.fandom.com/wiki/Pursuit_of_Luck), [Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99).

### 4.3 Published and community odds

Kefir doesn't publish drop tables. The only "official" odds are the **rarity floors** printed in pack descriptions. Everything else is a community sample.

**Rarity floors** (Wrecked ship container and generic packs): rare from 20%, very rare from 10%, extremely rare from 5%, guaranteed 100%. Each opening gives 1 common item, and repeat openings give *different* commons (Inference: sampling without replacement) ([Wrecked ship](https://last-day-on-earth-survival.fandom.com/wiki/Wrecked_ship)).

**Pity rule:** Armorer's, Gunsmith's and Scavenger's crates guarantee at least *very rare* on every 5th opening.

**Weapon Crate**, 200 rolls in v1.15.1. Expected if uniform: 12.5%.

| Item | % |
|---|---|
| Skull Crusher | 15.5 |
| M16 | 13.5 |
| Glock 17 | 13.5 |
| Metal Pipe | 13.5 |
| Machete | 13.0 |
| Katana | 12.0 |
| Shotgun | 9.5 |
| Saw Blade Mace | 9.5 |

A second sample (100 rolls, v1.18.11) had Skull Crusher at 19% and Katana at 17%. **Inference:** the table is about uniform, with sampling noise.

**Fair Coupon**, 50 coupons at max level, v1.48.5. Each value is the expected count per coupon, and each coupon gives 5 items.

| Item | Per coupon |
|---|---|
| Minigun | 24% |
| FN SCAR | 20% |
| M16 | 14% |
| AK-47 / Equalizer | 12% each |
| Mini Uzi | 10% |
| Milkor MGL / Colt Python / Shotgun / Glock | 8% each |
| VSS / Katana | 6% each |
| Neutralizer | 4% |
| Protector | 2% |
| Steel Bar / Titanium Bar | 84% each |
| Ash Plank | 72% |
| Lead Plate | 66% |
| Steel Plate / Al Plate / Carbon | 48% each |
| Acid | 42% |
| Copper Bar | 30% |
| Air Filter | 28% |
| Oak Plank / Lens | 24% each |
| Al Bar / Electronic Circuit | 18% each |
| Heat sensor | 16% |
| Iron Plate / Gunpowder / Engine Part / AntiRad | 12% each |

95% confidence intervals are wide: Minigun 14–37%.

**Supply Control Points per kill:**

| Enemy | Outside | In Bunker Alfa | Highway |
|---|---|---|---|
| Roaming Zombie | 2 | 4 | — |
| Fast Biter | 4 | 7 | 10 (120 HP variant) |
| Toxic Spitter | 6 | — | — |
| The Blind One | — | 200 | — |

Summons, arena mobs, the Horde, humans, machines and animals give **0**.

### 4.4 How random rewards are layered (Inference)

LDoE stacks six reward layers, each with a different randomness profile, so every run feeds at least one meter:

1. **World containers.** Cheap, high-variance, reset on exit. They feed the basics and occasionally drop a *key* (a CAC card, coupons, a Cut Finger), which turns trash runs into lottery tickets for the next layer.
2. **Kill-drop currencies.** Coupons, tags, police cards, key cards, Infection Samples, Control Points. These are near-deterministic in aggregate: roughly a fixed amount per clear.
3. **Exchange terminals.** A **fixed price for a random box** (20/25/30 coupons; 1 police card). The price is predictable; the contents are slot-rolls of the "one item from list N" kind. That format guarantees a floor (you always get N items) while hiding the jackpot inside one slot (a modded gun, the Minigun, an extremely-rare blueprint).
4. **Tier-up exchanges.** 10:1 police cards and blueprint-exchange percentages (10/50/200%). Bad luck converts into progress, which works as a soft pity.
5. **Reputation tracks with fixed milestones.** The Specialist, Eva, Jake, event NPCs. Deterministic guns at set levels, with **random spawn items** (Floppy → a location → a crate → sometimes an Infected Box → the Buzzsaw) between them. The random part recurses into new runs.
6. **Premium and event crates with pity and keys.** Every-5th-crate floors, key ladders (25 Scavenger → 1 Collector), paid re-opens (Wrecked ship), and coin-skippable timers.

**The structural trick:** almost every layer's output is an input to another layer's gate. A random gun lets you clear a harder floor, which gives a better currency, which buys a better box. Timers (48 h, 3 d, 6 h, 1 h) cap how often each layer can be pulled, so players spread their play across many layers every day.

---

## 5. Events and live ops

### 5.1 Cadence

All events share a **single 00:00 UTC daily reset** (overview doc). Durations come from each event's infobox. Where "recurring" is marked "no", the wiki's frequency flag is unset; these are seasonal holiday events.

| Event | Duration | Recurrence | Where | Currency / token | Reputation / progression | Headline rewards |
|---|---|---|---|---|---|---|
| **Season** (pass) | **21 days** (S98: 22 Sep – 12 Oct 2026; S99: 13 Oct – 2 Nov 2026) | continuous. Inference: S100 started about 3 Nov 2026, unconfirmed | all | Season XP | 80 levels plus an infinite tier (S89); free and premium tracks | S99: premium L1 is a modded VSS plus an Extremely Rare Infinite Pack; free levels give Infinite Packs, Tactical set, puppy, Crossbow… |
| **Commune Trials** | 6 d | every 5-day gap (since 1.25.0) | Commune | Trophy currency | Ritual boosts (Marcus, Sophia, Otis); battles with tiered rewards | Trophy Market (one-time and daily stock), including an Inspector Card |
| **Headhunting** | 6 d | every 5-day gap (since 1.27.0) | Headhunting Arena | — | — | Outfit "Rotting Flesh", backpack "Limbs", an **extremely rare mod blueprint** |
| **Pursuit of Luck** | 8 d | recurring | Gas Station; raiders' camps in pine and limestone zones | Caps → Clovers | A milestone track that can be reset and repeated | — |
| **VIP Marathon** | 8 d | recurring | — | VIP points (real money) | Spend thresholds | — |
| **Gold Rush** | n/a | recurring | — | Coins spent | Spend thresholds, claimed manually | — |
| **Supply** | 8 d | recurring | Global | Control Points | 4 cargo tiers every 6 h | Tactical Backpack, FN SCAR, VSS, Ultimatum; Inspector Card |
| **Anomaly Season** | 11 d | recurring | Home, Climate Anomaly | Common and Rare Keys | Cutthroat's reputation; **3 free daily contracts, +2 premium** | Cutthroat's crates |
| **Big Hunt** | n/a | starts **7 days after each season begins** | — | Scavenger's and Collector's Keys | 3 bounties, each on a 24 h cooldown (coin refresh) | Crate ladder |
| **Hunter's Instinct** | 18 d | flag "no" | Hunting Grounds | Abrasive, Hunter's Token | Ecologist reputation | — |
| **Operation "Purge"** | 11 d | flag "no" | Factory, PD, Alfa, Farm, Motel, Transport Hub (marked by Genesis drones) | Stripes (also from dead operatives in forests and hills) | **Operative's Reputation per kill-location:** Farm 284, Factory 256, Motel 182–213 per clear (needs verification); PD arena kills give 0 | Box with a Kitten, vinyl record, Storage for Explosives |
| **Scouting** | 11 d | flag "no" | Gas Station, Greenwood, Quarantine, Frozen Training Ground | Scout supplies | Scout's Reputation; exchange refreshes at 00:00 UTC | Tabletop Food Pantry, outfit, Box with a Kitten |
| **On the Witch's Trail** | 11 d | Halloween 2025 | Home, Mysterious Forest, Infected Forest | Greyhound's Tags | Genesis Greyhound reputation | Witch kill: reputation plus tags |
| **Cult Hunting** | 11 d | Halloween 2026 | Home, Cult's Shelter, camps | Pendants (or coins) | Eradicators' reputation (**an ad gives +125 once per day**); refreshable and fixed markets | Breach tools, Occult crates |
| **Delivery Service** | 3 d | the **last week of each season** | Home | — | Contracts with route events and optional insurance | — |
| **Dog Breeder** | 5 d | recurring (since 1.19) | Home | — | Tasks; needs a Dog Crate | — |
| **Fishing Tournament** | 4 d | recurring | Fishing location (26 energy / 24 fuel), reset 1 d | Fish | Tasks | Hooked chests with cards, chevrons, tags, Cut Finger, Chopper parts |
| **Wrecked ship** | 8 d | recurring | Wrecked ship | — | — | Container packs |
| **Blackport PD event** | 4 d | once per season | PD | — | Tiered tasks (§3.3) | Pausable waves |
| **Port Lab event** | 4 d | recurring | Lab | Samples +25% | Tiered tasks | Weapon damage buffs |
| **Bunker Bravo event** | n/a | recurring | Bravo | — | — | −50% enemy HP, less radiation |
| **Forlorn Fair** | occasional | — | Forlorn Fair (22 h reset) | Regular / Uncommon / Rare Coupons → Fair Coupon | 3 stages; the prize stand maxes at level 27 | 5-item coupon rolls |

**Event task pattern.** Tasks come in three escalating tiers on the same verb, for example 35 / 200 / 560 kills and 10 / 45 / 90 waves. **Inference:** tier 1 is a 1-session task, tier 2 a 2–3-day one, and tier 3 needs the whole event.

**Reward-track pattern** (Eva, Bogside, events): a per-level XP curve, premium rows every 4th level (Eva) or on a separate row, then an **infinite tier** that repeats a supply box (for example "Genesis Expedition's Supplies"). It also folds in season XP, so events feed the pass.

**Genome on events:** the wiki gallery notes about **75 Infected Genome** "at the end of most events". It is also paid by cats, seasons and regional bosses, with an account cap of 5,000.

Sources: [Event Calendar](https://last-day-on-earth-survival.fandom.com/wiki/Event_Calendar), [Commune Trials](https://last-day-on-earth-survival.fandom.com/wiki/Commune_Trials), [Commune](https://last-day-on-earth-survival.fandom.com/wiki/Commune), [Headhunting](https://last-day-on-earth-survival.fandom.com/wiki/Headhunting), [Pursuit of Luck](https://last-day-on-earth-survival.fandom.com/wiki/Pursuit_of_Luck), [VIP Marathon](https://last-day-on-earth-survival.fandom.com/wiki/VIP_Marathon), [Gold Rush](https://last-day-on-earth-survival.fandom.com/wiki/Gold_Rush), [Supply](https://last-day-on-earth-survival.fandom.com/wiki/Supply), [Anomaly Season](https://last-day-on-earth-survival.fandom.com/wiki/Anomaly_Season), [Big Hunt](https://last-day-on-earth-survival.fandom.com/wiki/Big_Hunt), [Hunter's Instinct](https://last-day-on-earth-survival.fandom.com/wiki/Hunter%27s_Instinct), [Operation "Purge"](https://last-day-on-earth-survival.fandom.com/wiki/Operation_%22Purge%22), [Scouting](https://last-day-on-earth-survival.fandom.com/wiki/Scouting), [On the Witch's Trail](https://last-day-on-earth-survival.fandom.com/wiki/On_the_Witch%27s_Trail), [Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting), [Delivery Service](https://last-day-on-earth-survival.fandom.com/wiki/Delivery_Service), [Dog Breeder](https://last-day-on-earth-survival.fandom.com/wiki/Dog_Breeder), [Fishing Tournament](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Tournament), [Season 98](https://last-day-on-earth-survival.fandom.com/wiki/Season_98), [Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99), [Infected Genome](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Genome).

### 5.2 Timed pop-ups and their rotation (summary)

| Pop-up | Spawn rule | Lifetime |
|---|---|---|
| Airdrop | Energy below 140 / 80 / 20; max 3 per 24 h | until it despawns |
| Destroyed convoy | Every 4 days; alternates raider and zombie versions | 1 h |
| Oak Clearing | Every 5 days; 6 variants | 1 h 30 m |
| Junkyard | 48–72 h after the previous one; 3 variants | event |
| Fishing Spot | Needs the Fisherman skill; 3 spot types | 12 h |
| Rest Stop | Random; 4 variants | event |
| Dealer Joe | CB Radio call | while active |
| N 50 coordinates | Player inserts a Floppy | 12 h |
| Crash Site | Once, in the FTUE | 15 min after leaving |
| Cult's Shelter | Daily at 00:00 UTC during the event | 24 h; 2 h once entered |
| Icy Outskirts and daily tasks | 00:00 UTC | 24 h |
| Season 1 pine/limestone events | Season week 2 | 3 h |

---

## 6. Enemies

### 6.1 Core roster (outside dungeons unless noted)

| Enemy | HP | Armor | Dmg | Behaviour / special | Where |
|---|---|---|---|---|---|
| Roaming Zombie | 40 | 0 | — (Alfa 10) | slow; outrunnable | everywhere |
| Fast Biter | 80 | 0 | 6 | speed 43 ≈ player speed | everywhere |
| Fast Biter (Highway variant) | 120 | high | high | bald, blue overcoat | Highway |
| Fast Rotter | 120 | — | — | basement and Hub variant | basements, Motel basement, Hub |
| Crawler | 80 (100 at the Infected Junkyard) | — | 6 | speed 41; spawns from gore pools and car alarms | Infected Forest, basements, Motel, Highway |
| Toxic Spitter | 80 (Alfa 100) | 0 | 6 / spit 15 | cone spit raises stink; no spit in Alfa | yellow and red zones |
| Floater Bloater | 240 | 0 | 10 / slam 30 | red-circle jump slam | widespread |
| Toxic Abomination | 300 | 0 (Alfa hard 20) | 20 (Alfa) / 30 (hard) | bigger sense radius; **may drop any CAC card except Z**; 250–300 XP | red zones, Northern Watchtower, Alfa |
| Frenzied Giant | 500 | 0 (hard 10) | **200** | one-shots under-armored players; 400 XP | Alfa, red events |
| The Big One | 1,000 | 300 | 50 | very fast; summoned by noise; drops **CAC Z** | red zones (rare), Alfa F2 (caged), raids |
| Exploder | 300 | 20 | 45 | explodes at 50 HP into 3 Parasites | Alfa hard, Bravo, Sewer, Lab B2 |
| Parasite | 40 | 0 | 4 | erratic; dies soon after a hit | Exploder spawns, Cocoon, Hub |
| Rotten Yokel | 80 | 2 | — | idle or alert states | Farm |
| Savage Giant | 200 (Farm) / 250 (Junkyard, basements) | 5 | heavy | slow; can be shaken off | Farm, Junkyard, basements |
| Infected Bull | 300 | 10 | heavy | patrols | Farm |
| Diseased Wolf | 100 | — | — | — | Farm, rare in zones |
| Weeper | 240 | 2 | 6 | stun scream | Motel mini-boss |
| Zombie Officer | 120 | 0 | 6 (Hub 15 + heals 15 per hit) | 100 XP | PD, Gas Station, Hub, Highway |
| Hungry Chomper | 240 | 0 | 15–30 | below 59 HP slows and heals 30 per hit | PD, Hub, expeditions |
| Jailbird | 80 | 0 | 15 | hard hitter, no drops | PD |
| Brawler | 240 | 0 | 30 | 5 s stun scream | PD |
| Riot Zombie | 150 | 24 | 20–30 | shield block | PD, Bravo, Hub |
| Explosive Zombie | 100 | 24 | 6 (Bravo 30) | explodes below 25 HP | PD, Bravo, Hub |
| Juggernaut | 200 | 30 | 30 | heals 30 per hit (Lab: attacks twice as fast below 100 HP instead) | Bravo, Lab |
| Groaner | 150 (Hub) / 50 (Lab) | 10 / armored | 30 | bleed 20/s × 6 | Hub, Lab |
| Swamp Zombie | 100 | 0 | 6 | swampy Fast Biter | Bogs, Sewer |
| Spore family (runner, spitter, bloater, giant, wolf, deer, bear, miasma, hybrid) | varies | **spore armor** | varies | −40% (Sand Quarry) to about −60% (Dead Island) damage from non-spore weapons; leave spore goop | Islands, Lab A1/A2 |
| Frozen family (Frozen FB, Phantom, Bloater, Giant, Numb Zombie, Dire Wolf) | varies | — | — | cold zones | North, Alfa F4, Lab B1 |
| Wendigo | 900 | 0 | 10–30 | heals 15 per hit; very fast | Frosty Backwoods, Frozen Training Ground, Lab B1 |
| Radioactive family (spitter, leaper, alligator, roaming) | — | — | — | inflict radiation | Bogs, Leviathan's Lair |
| Turret / Heavy Turret | 250 / 500 | 15 / 45 | 20 (hard 30) / plus grenades | shoots only the player | Alfa |
| Spike mine | indestructible | — | — | trap | Alfa F4 |

**AI humans**
- **AI Survivor (100 HP).** Gathers, hunts zombies, flees when hurt, and heals from its own pack. Drops what it carries: a Basic Backpack and Hammer in green zones; Glock, AK, Shotgun or M16 in red zones. It can drop a Weapon Crate or CAC cards ([AI Survivor](https://last-day-on-earth-survival.fandom.com/wiki/AI_Survivor)).
- **Raiders (100 HP, armor 12–24).** Melee, a Zip Gun, a rare Glock, a very rare M16. Found at the Farm, Oak Clearing, Destroyed convoy and Highway ([Raiders](https://last-day-on-earth-survival.fandom.com/wiki/Raiders)).
- **Soldiers, Poachers, Cultists:** event humans.

### 6.2 Bosses and mini-bosses

| Boss | Location | HP (hard) | Armor | Dmg | Access gate | Reward | Notable mechanics |
|---|---|---|---|---|---|---|---|
| Ravager | Farm | 500 | 0 | 20 | Farm (L15) | — | Easiest boss; full heal on exit |
| Weeper | Motel | 240 | 2 | 6 | — | — | Stun scream |
| Colonel | Factory (quest / raid task) | 500 | 0 | 30 | quest | drops | Wakes 3 Fast Biters; stun scream |
| Smasher | Highway (story) | high | — | — | Minivan act | — | Story fight |
| Screech | Northern Watchtower; Quarantine Army Base | 700 (was 2,000) | 48 | 20 | L15 tower | unlock | Leaps at you; the gates lock |
| Butcher (tower) | Western Watchtower | 1,200 | — | 100 | ATV | unlock | 2 stun screams; summons 4 Swamp Zombies; heals on exit |
| Alpha Irradiator | Western Watchtower | 2,000 | 0 | ? | ATV | unlock; achievement | Must die to fix the tower |
| Lighthouse Keeper | Island Watchtower | 1,250 | 14–18 | 20 | Motorboat | unlock | Spore armor in the daily version |
| **Witch** | Infected Forest | 2,000 | 10 | 30 (rises when an arm is lost) | Event, 4 tasks | 1,000 XP; head totem pauses the Horde | Crawlers from gore pools heal her; C-4 the pools |
| Leshen | Quarantine Ritual Zone; Mysterious Forest | 1,600 | 0 | 40 | — / event | event reputation | Very fast; no special attack |
| **Borealis** | Ice-Trapped Ship | 1,500 | 40 → 15 | 15 | 3 Northern points | **300 Genome**, CAC Z, Big Bones | Explosive barrels; cold 23 |
| **Consilium** | Landfill | 4,000 | ~85% DR | 80 | 3 Island points | **450 Genome** | Instant full spore infection on hit; persistent goop |
| **Leviathan** | Leviathan's Lair | 4,000 | armored | 25 (specials 40–50) | 3 Boggy points, 3-day window | **600 Genome**, lair storage | Dives at 2,800 and 1,600 HP and returns after a generator is set up; Tail Sweep stops below 1,600 |
| The Blind One | Alfa F3 (hard) | 1,000 | 150 / 30 when stunned | 50 | Hard Mode | 1,000 XP; 200 Supply CP | Heals at 700 and 400; stunned by alarms |
| Liquidator | Bravo F2 | 2,000 | 24 | 50 | L75 | 5,000 XP; F2 cargo | — |
| Doctor Dread | Bravo F3 | n/a | — | — | F2 cleared | 5,000 XP; F3 cargo | Releases adds at 800/600/400/200 HP |
| Cocoon | Bravo F4 | 1,000 | 36 | none | F3 cleared | F4 cargo | Stationary; constant parasite eggs |
| Butcher (boss) | Transport Hub | 2,500 | 20 | 80 / 45 / 30 | random container | CAC Card Key (per Hub page) | Heals (per the Miner page's comparison) |
| Miner (Wasteland) | Transport Hub | 3,000 | 30 → 40 below 1,500 | 80 punch; drill 6×8 cone, 65 circle | random container | **CAC Card Key** | Can't be outrun; doesn't heal |
| Necrotic Hybrid | Lab A1 | 2,000 (3,000) | spore | 55–120 | Lab | cards, drives, Spore Samples | — |
| Carrion MK VII | Lab A2 | 2,000 (3,000) | spore | 60–100 | Lab | cards, drives, ATV Transmission | Electric-arc activation |
| Icebreaker | Lab B1 | 2,000 (3,000) | ice armor | 46–50 | Lab | cards, drives | Ice blocks hold Frozen FBs |
| Blight MK VIII | Lab B2 | n/a | AP needed | n/a | Lab | cards, drives, Thermite | — |
| Corrupted CEO | Lab ("Uninvited" threat) | 1,000 | ? | 50 | threat roll | — | Damage rises at low HP |
| Berserker | Port Sewer; Bogside (1,000 HP) | 500 | 0 | 200 | — | — | Swampy Frenzied Giant |
| Wendigo | North, Lab | 900 | 0 | 10–30 | — | — | Heals on hit |
| The Miner | Crater Old Mines | 5,000 | 0 | — | Crater Chopper | Combat set, MP5K, HK416 | 5 attacks; "practically impossible" solo |
| Devourer | Crater Container | — | — | — | Crater Chopper | Scout set | — |
| Greg / Kramp / Claus / Robo-Nick | Christmas events | 800–1,000 / 1,000 / — / 2 × 300 | — | — | event | holiday items | Greg's spit heals him |
| Awakener | Infected village cave (S14) | 200 | — | — | Eva quest | 100 XP | Revives nearby zombies while alive |
| Timmy the Bloat | Limestone Cliffs (rare) | — | — | — | — | 300 XP | Explodes at 50 HP into 2 Parasites |

Sources: [Category:Bosses](https://last-day-on-earth-survival.fandom.com/wiki/Category:Bosses) and each boss page linked above, plus [Witch](https://last-day-on-earth-survival.fandom.com/wiki/Witch), [Leshen](https://last-day-on-earth-survival.fandom.com/wiki/Leshen), [Wendigo](https://last-day-on-earth-survival.fandom.com/wiki/Wendigo), [Berserker](https://last-day-on-earth-survival.fandom.com/wiki/Berserker), [Greg](https://last-day-on-earth-survival.fandom.com/wiki/Greg), [Robo-Nick](https://last-day-on-earth-survival.fandom.com/wiki/Robo-Nick), [Awakener](https://last-day-on-earth-survival.fandom.com/wiki/Awakener), [Colonel](https://last-day-on-earth-survival.fandom.com/wiki/Colonel), [Weeper](https://last-day-on-earth-survival.fandom.com/wiki/Weeper), [Brawler](https://last-day-on-earth-survival.fandom.com/wiki/Brawler), [Hungry Chomper](https://last-day-on-earth-survival.fandom.com/wiki/Hungry_Chomper), [Riot Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Riot_Zombie), [Explosive Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Explosive_Zombie), [Jailbird](https://last-day-on-earth-survival.fandom.com/wiki/Jailbird), [Crawler](https://last-day-on-earth-survival.fandom.com/wiki/Crawler), [Swamp Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Swamp_Zombie), [Toxic Abomination](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Abomination), [Frenzied Giant](https://last-day-on-earth-survival.fandom.com/wiki/Frenzied_Giant), [Fast Biter/Zombie Officer](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter/Zombie_Officer).

### 6.3 Enemy design patterns worth copying (Inference)

- **One family per region or dungeon**, each with a gear check: spore armor needs spore-penetrating weapons, ice armor must be chipped off, B2 needs AP, police zombies heal on hit. Every family turns into a weapon-or-armor craft goal.
- **Self-healing enemies punish slow DPS:** Chomper, Juggernaut, Wendigo, Hub officers, and bosses that heal on exit. They push players to upgrade instead of kiting forever.
- **Explode-on-low-HP enemies** (Exploder, Explosive Zombie, Timmy) teach ranged finishing and burn ammo.
- **Stun screamers** (Brawler, Weeper, Colonel, Butcher) punish melee face-tanking.
- **Location stat overrides.** The same Fast Biter has different HP, damage and Control Points in Alfa than outside. Our `EnemyDef` needs per-location override rows.

---

## 7. How content structure drives the grind

### 7.1 Chain gates: what sits behind what

| Unlock or item | Chain | Hard bottleneck |
|---|---|---|
| Modded guns, Minigun, SWAT set (early) | Pine/Limestone runs → CAC A → Alfa code (radio or soldier) → F2–F4 clears → coupons → Combat Gear Box (30 red) | 48 h instance; red coupons |
| Colt Python, FN SCAR, Milkor MGL; mod blueprints | Alfa → rescue the Specialist → Hard Mode → tags/chevrons/notebooks → 115 (or 140) rep per level → milestone weapons at L3/6/9/12/15 | 48 h instance; hard-mode survivability |
| Infected Box rewards | Specialist level → Floppy → N 50 location (12 h) → rare Infected Box → carry home by vehicle → **Buzzsaw** | RNG plus a bench |
| Extremely rare mod blueprints, SWAT set (reliable) | Eastern Watchtower → PD clears and arena waves → cards → 10:1 up-trades → Inspector crate | 3–5 crates per 3 days; Terminal 6 permanently blocked |
| Police Bike skin | PD arena wave 99 | consumables, time |
| Drone mods, Genesis items | Drone → Transport Hub → boss container → CAC Card Key → scan crates → **Forklift** (10 titanium bars and more) for slot 4 | 48 h; Forklift parts |
| Police Barracks loot | Motel basement (Burglar 3) → Screws → Transport Hub **Bridge** (40 screws) | Motel 36 h × 6 screws per clear |
| Motorboat → Islands | Port (L15) → hangar blueprint → build → Island Watchtower → Lighthouse Keeper | the boat build |
| CBRN / Kevlar sets, AP weapons (Neutralizer, Protector, Resonator, Ultimatum) | Survivor's Path → Port → Eva mission → Lab runs (needing spore, cold and AP gear from the other regions) → A/B cards → hard mode → A+/B+ | 3 d reset; cross-region gear |
| Repair Station, bench upgrades, Site Plans | Regional daily tasks (3 per region) → region points → Borealis/Consilium/Leviathan → Genome (300/450/600) → Genesis Collection | 1 boss pass per day per region; 5,000 Genome cap |
| Bunker Bravo efficiency | L75 → generator → clears → 6 permanent terminal repairs (§3.2 totals) | USB drives, transistors |
| Witch head / horde pause | Halloween event → 4 Mysterious Forest tasks → Infected Forest → Witch (2,000 HP) | event window |

### 7.2 Numbers per milestone (from sourced values)

- **Specialist track to the MGL (L15):** 15 × 115 = **1,725 rep** (2,100 at the 140 figure). That is about 15 × (35 tags + 16 chevrons + 16 notebooks) ≈ **1,000 hard-mode drops**.
  - Hard-mode enemy counts per full clear: F2 46, F3 57 (plus The Blind One), F4 32 zombies, about **135 kills per run**.
  - **Inference:** if each kill yields about one item, a full clear is roughly 2 levels, so L15 takes **about 7–8 full hard clears ≈ 2–3 weeks** at the 48 h cadence. That is unverified, because per-kill drop rates aren't published.
- **Combat Gear Box:** 30 red coupons each. Red is the rarest coupon, mostly from F3 (2020 guide). No per-clear yield was found.
- **Police Inspector by up-trade:** 1 Inspector = 10 Captains = 100 Lieutenants = 1,000 Sergeants. With 3–5 terminal uses per 3 days, **a player can open at most about 35–58 crates a month**. **Inference:** the binding limit is terminal uses, not card supply, for anyone who farms waves.
- **Lab reputation per reset (cap):** 100 A cards × 10 + 100 B × 15 + 100 A+ × 15 + 100 B+ × 25 + 100 badges × 20 + 50 disks × 40 + 50 drives × 60. If the limits count items (the unit is ambiguous), that is at most **13,500 rep per 3-day reset**. **Inference:** in practice, drops per run (2–5 cards per boss, 3–6 per storage) are the real limit.
- **Regional Genome:** up to **1,350 per day** if all three bosses are killed daily (Inference: assumes every region's daily tasks get done). Repair Station = 3,600 Genome + 10 Borealis kills (overview doc), so it takes **at least 10 days**. Site Plans cost 100 Genome each, and expanding fully means 66 debris patches for new accounts (overview doc), on the order of **thousands of Genome**.
- **Bunker Bravo terminals:** 70 USB drives, 330 transistors and 375 duct tape in total. The F2/F3 cargo pays at most 1 USB per clear, so the USBs must mostly come from other sources: Inference, a weeks-long sink.
- **Transport Hub Bridge:** 40 Screws at up to 6 per Motel basement clear (36 h) is **at least 7 Motel clears ≈ 10+ days**. Inference: assumes 6 Screws per clear, which the wiki says the far chest "may" contain.
- **Specialist blueprint exchange:** 10 common or 2 rare blueprints = 1 new blueprint.
- **Airdrops:** 181 energy spent per day to see all 3.

### 7.3 Timers that force players back

| Timer | Value | Effect on behaviour (Inference) |
|---|---|---|
| Energy | +1 per 5 min, cap 200 (16 h 40 m to full) | 2–3 sessions per day |
| Region daily tasks | 00:00 UTC; counter max 3 | A daily habit; the boss gate fills in one day |
| Ice-Trapped Ship | 60 min cooldown; daily refresh | Borealis can be farmed more than once a day once points allow |
| Leviathan's Lair | 3-day access window | Pushes a kill inside each window |
| Bunker Alfa | 48 h instance; code every 2 days; exit needed after 1.44 | Every other day |
| Bunker Bravo | not documented | — |
| Blackport PD | 3 d; 3–5 card uses | Twice a week |
| Farm / Transport Hub / Gas Station / Highway / Pier | 48 h | Every other day |
| Motel | 36 h | — |
| Factory | 24 h | Daily |
| Port Sewer and Lab | 48 h or 3 d (conflict); shared timer | Once or twice a week |
| Port delivery terminal | 24 h after use | Daily |
| Infected Forest | 20 h; Horde every 24 h | Daily base defence |
| Maze / Forlorn Fair | 24 h / 22 h | Daily during the event |
| NPC Survivor Base | 1 h after visit | Repeatable |
| Unknown Box | 1 h (ad) | Ad cadence |
| Supply deliveries | 6 h | 4 check-ins per day during the event |
| Big Hunt bounties | 24 h cooldown | Daily |
| Airdrops | ≤3 per 24 h, energy-gated | Rewards spending energy |
| Destroyed convoy / Oak Clearing / Junkyard | every 4 d / 5 d / 48–72 h | "Check the map" habit |
| Fishing Spot / Floppy location | 12 h | Half-day windows |
| Events | 3–18 d; 6-on, 5-off cycles | Always something live |
| Season | 21 d | The macro cycle |

**Inference, the shape of the grind:** LDoE never gives one big wall. It gives **about 15 parallel timers of different lengths** (1 h to 21 d), each tied to a distinct currency, so a login almost always finds something "ready". Each dungeon pays mainly in its own **closed currency** (coupons, tags, police cards, key cards, samples, Genome), and only that dungeon's terminal spends it. That stops players from converting one farm into everything, and forces breadth.

---

## 8. Conflicts, stale data and gaps

| Topic | Conflict / gap |
|---|---|
| Specialist reputation per level | 115 (Specialist page plus a matching player estimate) vs 140 (Bunker Alfa page) |
| Police card order | Wiki: Sergeant < Lieutenant < Captain < Inspector. Kefir FAQ lists Sergeant, Captain, Lieutenant, Inspector |
| Port / Lab reset | Port page: 48 h after entering the Sewer or Lab. Lab page: 3 d |
| Abandoned Factory reset | Text: 24 h. Infobox: 48 h (the 1.19.4 value) |
| Crash Site baggage | 14 baggage (was 20) vs "22–44 luggage" on the same page |
| Crater level gate | Kefir FAQ: L100 plus a quest (overview). Wiki: moved 150 → 15 → 60 |
| Pine Bushes logs | 27 trees "= 51 logs" vs the 3-logs-per-tree convention |
| Junkyard gate | "Chopper upgraded to level 40": a chopper level or player level 40 is unclear |
| Bunker Bravo | No documented reset timer or CAC B usage; locker reset behaviour unknown |
| Drop rates | No published rates for CAC cards, coupons, police cards per wave, Specialist items, or Lab cards (ranges only) |
| Boss stats | Blight MK VIII and Doctor Dread HP not captured; Alpha Irradiator damage "?" |
| Infinite packs | Rare, Very Rare and Extremely Rare tier contents are undocumented (empty wiki pages) |
| Cutthroat crate cost currency | Icon stripped; unverified |
| Unknown Box | Current pool listed, but no odds |
| Season 100 | Not confirmed; inferred from Season 99 ending 2 Nov 2026 |
| Event recurrence | Hunter's Instinct, Scouting and Purge are flagged non-recurring, but Scouting maps became permanent in 1.47 (overview) |
| Wiki staleness | Many location pages carry 2018–2021 text (Farm developer notes, Alfa generator notes, Oak zones last edited 2024) |

---

## Data model implications

The catalog suggests these data tables for our game. Field names are suggestions; the LDoE example values show the range each field must cover. Store **definitions** in ModuleScript data tables and **per-player state** in DataStore. Store every timer as an absolute UTC timestamp, so that offline time counts the way LDoE's does.

### Definitions (static content)

| Entity | Key fields | LDoE examples |
|---|---|---|
| **RegionDef** | `id`, `unlock: AccessRequirement[]`, `travelModes` (walk, run, vehicle types), `hazard {type, damagePerTick}`, `dailyTaskPool`, `regionPoints {max=3, resetUtcHour=0, purchasable}`, `bossLocationId` | North: L15 plus Generator and Screech; cold; Borealis behind 3 points |
| **LocationDef** | `id`, `regionId`, `threatTier (1–3)`, `lifecycle` (enum, §1.2), `access: AccessRequirement[]`, `travel {energy, walkSec, runSec, driveSec, fuel, vehicleRequired}`, `reset: ResetPolicy`, `hazardMin {cold/spore/rad: number}`, `encounterSets: EncounterVariant[]`, `nodeSpawns`, `containers: ContainerPlacement[]`, `subLocations`, `npcIds`, `persistentStorage {slots, neverResets}` | Alfa: 31 energy, 27 m 26 s walk, L40, CAC A, 140 never-reset slots |
| **ResetPolicy** | `kind` (OnExit, TimerFromFirstEntry, DailyUtc, FixedWindow, Never), `durationSec`, `requiresExitAfterExpiry`, `sharedTimerGroup`, `resets {enemies, containers, corpse, bossHp, terminals=false}`, `bossHealsOnExit`, `enemiesKeepDamageOnExit` | Farm: 48 h from entry; zombies keep damage, the Ravager heals. Port, Sewer and Lab share a group |
| **PopUpSchedule** | `trigger` (interval, energyThresholds, radioCall, itemUse, oneTimeFlag), `maxPerDay`, `lifetimeSec`, `lifetimeAfterEntrySec`, `despawnAfterLeaveSec`, `variantPool` (weighted or alternating), `rerollOnReentry=false` | Airdrop: thresholds [140, 80, 20], max 3. Convoy: every 4 d, 1 h, alternating variants |
| **AccessRequirement** | `type` (level, questFlag, item, itemConsumed, skillLevel, companionRank, vehicle, tool, placedObject, regionPoints, secretCode, eventActive), `params`, `scope` (permanent, perReset, perUse) | CAC A: item, consumed, permanent. Alfa code: secretCode, perReset. Burglar 3: skillLevel |
| **SecretCodeDef** | `rotationSec`, `platformSalt`, `revealSources` (radio, corpse) | 5 digits, 48 h, per OS. For us: a deterministic hash of the date |
| **KeyItemDef / CurrencyDef** | `id`, `stackSize`, `cap`, `persistsAfterEvent`, `recycleInto`, `tier`, `upTradeTo {itemId, ratio}` | Police cards 10:1. Genome cap 5,000. Fair Coupon persists. CAC cards recycle to plastic |
| **ExchangeRecipe** | `vendorId`, `inputs[]`, `output` (item or `lootTableId`), `limitPerReset`, `limitPerDay`, `coinPrice?` | 30 red coupons → Combat Gear box. 10 Sergeant → 1 Lieutenant. Lab turn-in limits of 100 or 50 |
| **DungeonDef** | `locationId`, `floors: DungeonFloor[]` (ordered, each its own zone), `hardMode {unlockFlag, irreversibleUntilReset, statOverrides, replacements, dropSwap}`, `lobby {terminals, vendors, storage}`, `petRestrictions` | Alfa hard: small zombies +5 dmg and +15 armor; Abominations → Exploders; coupons → tags |
| **DungeonFloor** | `index`, `theme`, `spawns: {enemyId, countNormal, countHard}[]`, `hazards: HazardDef[]`, `terminals: TerminalDef[]`, `containers`, `bossId?`, `regenEnemiesOnLeave`, `completionReward` (cargo `lootTableId`), `requiredGear` | Alfa F3: 25 Spitters, 16 Abominations, 10 Giants, gas chamber, lasers. Bravo F4: Cocoon plus a cargo table |
| **HazardDef** | `type` (gas, electricFence, laserAlarm, gore, spikeMine, radiationPuddle, flood, cold, sporeGoop, turret), `damage`, `tickSec`, `mitigation` (item, valve, terminal), `alertsEnemies` | Factory gas: 15 dmg per 0.5 s, valves. Gore: −50% speed |
| **TerminalDef** | `effect`, `repairCost[]`, `persistent`, `usesPerReset`, `unlocksOption` | Bravo "Patrol Cancel": 95 transistors… PD terminals 4–6 |
| **EnemyDef** | `id`, `family`, `hp`, `armor`, `armorType` (none, spore, ice, power), `requiredDamageType`, `damage`, `attackSpeed`, `moveSpeed`, `senseRadius`, `specials[]`, `healOnHit`, `onLowHp {threshold, action: explode/spawn/slow}`, `xp`, `controlPoints`, `dropTableId`, `locationOverrides[]` | Hungry Chomper: 240 HP; below 59 slows and heals 30 per hit. Exploder: 50 HP → 3 Parasites |
| **BossDef** (extends EnemyDef) | `phases: {hpThreshold, action}[]` (heal, summon adds, dive, armor change), `arena {lockDoors, props}`, `access: AccessRequirement[]`, `rewards {currency, items, achievement}`, `healsOnExit`, `cooldownSec` | Leviathan: dives at 2,800 and 1,600. Blind One: heals at 700 and 400. Borealis: 300 Genome, 60 min cooldown |
| **EncounterVariant** | `weight`, `setPieces[]`, `alertState` (idle, alert, fighting), `npcScript?` | Farm plot: idle, biters-vs-zombies, wolves-vs-zombies, raiders. Rest Stop: ambush, rescue, camp, standoff |
| **LootTable** | `mode` (SlotRolls, Weighted, Fixed, Independent), `slots: {pickOne: Entry[], chanceEmpty, qtyMin, qtyMax}[]`, `scaling {byReputation, byWave, byLevel}`, `conditions {hardModeOnly, normalOnly, firstVisitOnly}` | Inspector crate: 16 slot-rolls. Captain card guaranteed on the first PD visit. Sunken Box scales with reputation |
| **LootEntry** | `itemId`, `qty`, `weight`, `rarity`, `modsPreset?`, `durabilityRange` | Airdrop weapons arrive at about half durability. A modded Glock with preset mods |
| **ContainerDef** | `capacitySlots`, `access` (none, burglarLevel, hackerSkill, tool, keyItem, perk, horde trigger), `lootTableId`, `resetPolicy`, `actsAsStorage`, `heavyObject? {vehicleOnly, carryDps, decaySec, attractsEnemies, processAt {bench, inputs, timeSec, coinSkip}}` | Farm chest: saw-triggered horde. Infected Box: 3 dps, 15–25 min decay, Buzzsaw |
| **RewardBoxDef** | `cost` ({currency, amount} or a keyItem), `lootTableId`, `rarityFloors {rare=0.20, veryRare=0.10, extremelyRare=0.05}`, `pity {everyN=5, minRarity}`, `noRepeatCommons`, `poolNarrowing` (remove an entry after a condition), `paidReopen {count, price}`, `deliverTo` (inventory, inbox) | Gunsmith's crate pity. Mechanic's Box pool narrowing. Wrecked ship: 1 free + 3 paid |
| **ReputationTrackDef** | `npcId`, `xpPerLevel[]` or `flatPerLevel`, `turnIns {itemId: points}`, `turnInLimitPerReset`, `levelRewards {level, free, premium}[]`, `infiniteReward`, `levelCapDisplay` | Specialist: 115 per level, rewards at 3/6/9/12/15, a Floppy otherwise. Eva: 60, 110, 170… |
| **ArenaDef / WaveDef** | `waves[]` (fixed composition for 1–10, then `{fromWave, toWave, count, pool}`), `pauseAllowed` (event flag), `restartCost`, `dropBiasByWave`, `finalReward` | PD: 99 waves; 5/6/7/10 enemies per band; 1 Electronic Circuit to restart |
| **RogueliteRunDef** (Lab) | `sectors[]` (ordered), `entryCost` (bioreactor charge), `perkOffer {count=3, pick=1, persistsForRun}`, `threatPool {rollPerRun=4, activatePerSector=1}`, `perkRarities`, `unlockByReputation` | Lab A1 → A2 → B1 → B2 |
| **EventDef** | `id`, `durationDays`, `recurrence` (intervalDays, or an anchor such as seasonStart+7d or lastWeekOfSeason), `locations[]`, `tasks: EventTaskDef[]`, `currencies[]`, `reputationTrackId`, `shops {refreshable, fixed, dailyLimitResetUtc}`, `buffs[]`, `adRewards {amount, perDay}`, `premiumTrack` | Commune Trials: 6 on / 5 off. Cult Hunting: 11 d, +125 rep from an ad once a day. Lab event: AK +50% damage |
| **EventTaskDef** | `verb` (kill, damage, waves, deliver, examine), `targetFilter` (enemy, location, weapon), `tiers [35, 200, 560]`, `rewardPerTier`, `requiredWeapon?` | Hunter's Instinct: only recommended weapons count toward bonus samples |
| **SeasonDef** | `id`, `start`, `end` (21 d), `levels`, `infiniteTier`, `freeRewards`, `premiumRewards` | S99: 13 Oct – 2 Nov 2026 |
| **DailyTaskDef** | `regionId`, `locationId`, `pool[]`, `pointsAwarded=1`, `skippableWith` (Rations) | Western Watchtower: "Valuable Equipment", sentry defence… |

### Per-player state

| Entity | Key fields |
|---|---|
| **PlayerLocationState** | `locationId`, `instanceSeed`, `firstEnteredAtUtc`, `resetsAtUtc`, `killedSpawnIds`, `enemyHp {spawnId: hp}` (Farm-style persistence), `containerContents`, `corpse`, `hardModeActive`, `chosenVariant`, `bossDefeated` |
| **PlayerUnlocks** | `flags` (watchtowers, Specialist rescued, Eva mission, CAC A used, terminals repaired, Forklift and Bridge built), `regionPoints {regionId: 0..3, updatedUtc}`, `bossAccessWindowEndsUtc` |
| **PlayerCurrencies** | All closed currencies (coupons ×3, tags ×3, police cards ×4, key cards ×4, samples, Genome, event tokens), with caps |
| **PlayerReputation** | `trackId → {xp, level, claimedFree[], claimedPremium[]}` |
| **PlayerPopUps** | Active pop-ups with `expiresAtUtc`, daily counters (airdrops spawned today), Floppy-spawned locations |
| **PlayerBoxState** | `pityCounters {boxId: opensSinceFloor}`, `seenCommons {boxId: []}`, `narrowedPools` |

**Roblox-specific notes (Inference)**
- LDoE's per-player instancing maps cleanly onto **reserved servers or per-player places for dungeons**. Shared open-world zones are a design choice from the overview doc, so `LocationDef.instancing` should be one of {perPlayer, perParty, sharedServer}.
- Make `ResetPolicy` evaluation server-authoritative and lazy: compute on entry from `firstEnteredAtUtc`; don't run a cron.
- Keep loot tables as data with a `version`, so balance passes don't invalidate saved container states mid-reset.

---

## Sources

**Primary: LDoE Fandom wiki** (raw wikitext via the MediaWiki API, accessed 2026-11-07)
- Map and regions: [Global Map](https://last-day-on-earth-survival.fandom.com/wiki/Global_Map) · [Regions on Global Maps](https://last-day-on-earth-survival.fandom.com/wiki/Regions_on_Global_Maps) · [Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Watchtower) · [Western Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Western_Watchtower) · [Island Watchtower](https://last-day-on-earth-survival.fandom.com/wiki/Island_Watchtower) · [The Uncharted Territories](https://last-day-on-earth-survival.fandom.com/wiki/The_Uncharted_Territories) · [Event](https://last-day-on-earth-survival.fandom.com/wiki/Event) · [Category:Location](https://last-day-on-earth-survival.fandom.com/wiki/Category:Location)
- Resource zones: [Pine Bushes, Grove and Wood](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes,_Grove_and_Wood) · [Limestone Ridge, Cliffs and Spires](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge,_Cliffs_and_Spires) · [Oak Bushes and Grove](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Bushes_and_Grove) · [Wooded Foothills](https://last-day-on-earth-survival.fandom.com/wiki/Wooded_Foothills) · [Frosty Backwoods](https://last-day-on-earth-survival.fandom.com/wiki/Frosty_Backwoods) · [Sand Quarry](https://last-day-on-earth-survival.fandom.com/wiki/Sand_Quarry) · [Old Mine (Island)](https://last-day-on-earth-survival.fandom.com/wiki/Old_Mine_(Island)) · [Dead Island](https://last-day-on-earth-survival.fandom.com/wiki/Dead_Island) · [Landfill](https://last-day-on-earth-survival.fandom.com/wiki/Landfill) · [Swamp Forest](https://last-day-on-earth-survival.fandom.com/wiki/Swamp_Forest) · [Wild Bogs](https://last-day-on-earth-survival.fandom.com/wiki/Wild_Bogs) · [Bogside Outskirts](https://last-day-on-earth-survival.fandom.com/wiki/Bogside_Outskirts) · [Basements](https://last-day-on-earth-survival.fandom.com/wiki/Basements)
- Dungeons and hubs: [Bunker Alfa](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Alfa) · [Bunker Bravo](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Bravo) · [Bunker Charlie](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Charlie) · [Bunker Delta](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Delta) · [Bunker Foxtrot](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Foxtrot) · [Bunker Romeo](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Romeo) · [Bunker Zulu](https://last-day-on-earth-survival.fandom.com/wiki/Bunker_Zulu) · [Blackport PD](https://last-day-on-earth-survival.fandom.com/wiki/Blackport_PD) · [Crooked Creek Farm](https://last-day-on-earth-survival.fandom.com/wiki/Crooked_Creek_Farm) · [Motel](https://last-day-on-earth-survival.fandom.com/wiki/Motel) · [Abandoned Factory](https://last-day-on-earth-survival.fandom.com/wiki/Abandoned_Factory) · [Transport Hub](https://last-day-on-earth-survival.fandom.com/wiki/Transport_Hub) · [Port](https://last-day-on-earth-survival.fandom.com/wiki/Port) · [Port/Sewer](https://last-day-on-earth-survival.fandom.com/wiki/Port/Sewer) · [Port/Laboratory](https://last-day-on-earth-survival.fandom.com/wiki/Port/Laboratory) · [Gas Station](https://last-day-on-earth-survival.fandom.com/wiki/Gas_Station) · [Gas Station/The Highway](https://last-day-on-earth-survival.fandom.com/wiki/Gas_Station/The_Highway) · [Pier](https://last-day-on-earth-survival.fandom.com/wiki/Pier) · [Infected Forest](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Forest) · [Ice-Trapped Ship](https://last-day-on-earth-survival.fandom.com/wiki/Ice-Trapped_Ship) · [Leviathan's Lair](https://last-day-on-earth-survival.fandom.com/wiki/Leviathan%27s_Lair) · [Icy Outskirts](https://last-day-on-earth-survival.fandom.com/wiki/Icy_Outskirts) · [NPC Survivor Base](https://last-day-on-earth-survival.fandom.com/wiki/NPC_Survivor_Base)
- Pop-ups and uncharted maps: [Airdrop](https://last-day-on-earth-survival.fandom.com/wiki/Airdrop) · [Crash Site](https://last-day-on-earth-survival.fandom.com/wiki/Crash_Site) · [Destroyed convoy](https://last-day-on-earth-survival.fandom.com/wiki/Destroyed_convoy) · [Abandoned convoy](https://last-day-on-earth-survival.fandom.com/wiki/Abandoned_convoy) · [Convoy Stop](https://last-day-on-earth-survival.fandom.com/wiki/Convoy_Stop) · [Rest Stop](https://last-day-on-earth-survival.fandom.com/wiki/Rest_Stop) · [Junkyard](https://last-day-on-earth-survival.fandom.com/wiki/Junkyard) · [Oak Clearing](https://last-day-on-earth-survival.fandom.com/wiki/Oak_Clearing) · [Fishing Spot](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Spot) · [Fishing event](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_event) · [Wrecked ship](https://last-day-on-earth-survival.fandom.com/wiki/Wrecked_ship) · [N 50.01061, E -110.1134](https://last-day-on-earth-survival.fandom.com/wiki/N_50.01061,_E_-110.1134) · [Greenwood Camping Park](https://last-day-on-earth-survival.fandom.com/wiki/Greenwood_Camping_Park) · [Quarantine Zone](https://last-day-on-earth-survival.fandom.com/wiki/Quarantine_Zone) · [Frozen Training Ground](https://last-day-on-earth-survival.fandom.com/wiki/Frozen_Training_Ground) · [Uncharted Territories](https://last-day-on-earth-survival.fandom.com/wiki/Uncharted_Territories) · [Dealer Joe](https://last-day-on-earth-survival.fandom.com/wiki/Dealer_Joe)
- Multiplayer: [The Crater](https://last-day-on-earth-survival.fandom.com/wiki/The_Crater) · [Crater's Chopper Locations](https://last-day-on-earth-survival.fandom.com/wiki/Crater%27s_Chopper_Locations) · [Camp. Sector 7](https://last-day-on-earth-survival.fandom.com/wiki/Camp._Sector_7) · [Wall. Sector 7](https://last-day-on-earth-survival.fandom.com/wiki/Wall._Sector_7) · [Gateway Door](https://last-day-on-earth-survival.fandom.com/wiki/Gateway_Door) · [Cluster of anomalies](https://last-day-on-earth-survival.fandom.com/wiki/Cluster_of_anomalies)
- Season and event locations: [Cult's Shelter](https://last-day-on-earth-survival.fandom.com/wiki/Cult%27s_Shelter) · [Mysterious Forest](https://last-day-on-earth-survival.fandom.com/wiki/Mysterious_Forest) · [Forlorn Fair](https://last-day-on-earth-survival.fandom.com/wiki/Forlorn_Fair) · [Maze](https://last-day-on-earth-survival.fandom.com/wiki/Maze) · [Fort Moss](https://last-day-on-earth-survival.fandom.com/wiki/Fort_Moss) · [Bikers' base](https://last-day-on-earth-survival.fandom.com/wiki/Bikers%27_base) · [Prison](https://last-day-on-earth-survival.fandom.com/wiki/Prison) · [Fair](https://last-day-on-earth-survival.fandom.com/wiki/Fair) · [Infected Base](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Base) · [Genesis outpost](https://last-day-on-earth-survival.fandom.com/wiki/Genesis_outpost) · [Strange factory](https://last-day-on-earth-survival.fandom.com/wiki/Strange_factory) · [Hidden Garden](https://last-day-on-earth-survival.fandom.com/wiki/Hidden_Garden) · [Hidden Ridge Farm](https://last-day-on-earth-survival.fandom.com/wiki/Hidden_Ridge_Farm) · [Smugglers' Camp](https://last-day-on-earth-survival.fandom.com/wiki/Smugglers%27_Camp) · [Mercenaries' camp](https://last-day-on-earth-survival.fandom.com/wiki/Mercenaries%27_camp) · [Hunters' Camp](https://last-day-on-earth-survival.fandom.com/wiki/Hunters%27_Camp) · [Snowy Race Track](https://last-day-on-earth-survival.fandom.com/wiki/Snowy_Race_Track) · [Infected Junkyard](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Junkyard) · [Arena (Event)](https://last-day-on-earth-survival.fandom.com/wiki/Arena_(Event)) · [Pine Bushes event](https://last-day-on-earth-survival.fandom.com/wiki/Pine_Bushes_event) · [Limestone Ridge event](https://last-day-on-earth-survival.fandom.com/wiki/Limestone_Ridge_event)
- Keys, cards and currencies: [CAC Cards (A-Z)](https://last-day-on-earth-survival.fandom.com/wiki/CAC_Cards_(A-Z)) · [CAC Card Key](https://last-day-on-earth-survival.fandom.com/wiki/CAC_Card_Key) · [Coupons](https://last-day-on-earth-survival.fandom.com/wiki/Coupons) · [Key card A](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_A) · [Key card A+](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_A%2B) · [Key card B](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_B) · [Key card B+](https://last-day-on-earth-survival.fandom.com/wiki/Key_card_B%2B) · [Sergeant Card](https://last-day-on-earth-survival.fandom.com/wiki/Sergeant_Card) · [Lieutenant Card](https://last-day-on-earth-survival.fandom.com/wiki/Lieutenant_Card) · [Captain Card](https://last-day-on-earth-survival.fandom.com/wiki/Captain_Card) · [Inspector Card](https://last-day-on-earth-survival.fandom.com/wiki/Inspector_Card) · [Cell Key](https://last-day-on-earth-survival.fandom.com/wiki/Cell_Key) · [Identification tags](https://last-day-on-earth-survival.fandom.com/wiki/Identification_tags) · [Chevron](https://last-day-on-earth-survival.fandom.com/wiki/Chevron) · [Military Notebook](https://last-day-on-earth-survival.fandom.com/wiki/Military_Notebook) · [Floppy with coordinates](https://last-day-on-earth-survival.fandom.com/wiki/Floppy_with_coordinates) · [Overseer Keycard](https://last-day-on-earth-survival.fandom.com/wiki/Overseer_Keycard) · [Specialist](https://last-day-on-earth-survival.fandom.com/wiki/Specialist) · [Reputation](https://last-day-on-earth-survival.fandom.com/wiki/Reputation) · [Dead Soldier](https://last-day-on-earth-survival.fandom.com/wiki/Dead_Soldier) · [CB Radio](https://last-day-on-earth-survival.fandom.com/wiki/CB_Radio) · [Magazines/Bunker Documents](https://last-day-on-earth-survival.fandom.com/wiki/Magazines/Bunker_Documents) · [Common Key](https://last-day-on-earth-survival.fandom.com/wiki/Common_Key) · [Rare Key](https://last-day-on-earth-survival.fandom.com/wiki/Rare_Key) · [Token](https://last-day-on-earth-survival.fandom.com/wiki/Token) · [Infected Genome](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Genome) · [Gold Bar](https://last-day-on-earth-survival.fandom.com/wiki/Gold_Bar)
- Containers and boxes: [Baggage](https://last-day-on-earth-survival.fandom.com/wiki/Baggage) · [Rusty Vehicle](https://last-day-on-earth-survival.fandom.com/wiki/Rusty_Vehicle) · [Loot crates in the Spore Island](https://last-day-on-earth-survival.fandom.com/wiki/Loot_crates_in_the_Spore_Island) · [Unknown Box](https://last-day-on-earth-survival.fandom.com/wiki/Unknown_Box) · [Weapon Crate](https://last-day-on-earth-survival.fandom.com/wiki/Weapon_Crate) · [Infected Box](https://last-day-on-earth-survival.fandom.com/wiki/Infected_Box) · [Sunken Box](https://last-day-on-earth-survival.fandom.com/wiki/Sunken_Box) · [Mechanic's Box](https://last-day-on-earth-survival.fandom.com/wiki/Mechanic%27s_Box) · [Infinite pack](https://last-day-on-earth-survival.fandom.com/wiki/Infinite_pack) · [Armorer's crate](https://last-day-on-earth-survival.fandom.com/wiki/Armorer%27s_crate) · [Gunsmith's crate](https://last-day-on-earth-survival.fandom.com/wiki/Gunsmith%27s_crate) · [Scavenger's crate](https://last-day-on-earth-survival.fandom.com/wiki/Scavenger%27s_crate) · [Collector's crate](https://last-day-on-earth-survival.fandom.com/wiki/Collector%27s_crate) · [Common Cutthroat's Crate](https://last-day-on-earth-survival.fandom.com/wiki/Common_Cutthroat%27s_Crate) · [Premium Cutthroat's Crate](https://last-day-on-earth-survival.fandom.com/wiki/Premium_Cutthroat%27s_Crate) · [Club Member's Box](https://last-day-on-earth-survival.fandom.com/wiki/Club_Member%27s_Box) · [Club Treasurer's Box](https://last-day-on-earth-survival.fandom.com/wiki/Club_Treasurer%27s_Box) · [Road Captain's Box](https://last-day-on-earth-survival.fandom.com/wiki/Road_Captain%27s_Box) · [Researcher's box](https://last-day-on-earth-survival.fandom.com/wiki/Researcher%27s_box) · [Researcher's case](https://last-day-on-earth-survival.fandom.com/wiki/Researcher%27s_case) · [Researcher's chest](https://last-day-on-earth-survival.fandom.com/wiki/Researcher%27s_chest) · [Halloween container](https://last-day-on-earth-survival.fandom.com/wiki/Halloween_container) · [Small Occult Crate](https://last-day-on-earth-survival.fandom.com/wiki/Small_Occult_Crate) · [Medium Occult Crate](https://last-day-on-earth-survival.fandom.com/wiki/Medium_Occult_Crate) · [Large Occult Crate](https://last-day-on-earth-survival.fandom.com/wiki/Large_Occult_Crate) · [Fair Coupon](https://last-day-on-earth-survival.fandom.com/wiki/Fair_Coupon) · [Slot Machine](https://last-day-on-earth-survival.fandom.com/wiki/Slot_Machine) · [Military Box](https://last-day-on-earth-survival.fandom.com/wiki/Military_Box)
- Events: [Event Calendar](https://last-day-on-earth-survival.fandom.com/wiki/Event_Calendar) · [Commune](https://last-day-on-earth-survival.fandom.com/wiki/Commune) · [Commune Trials](https://last-day-on-earth-survival.fandom.com/wiki/Commune_Trials) · [Headhunting](https://last-day-on-earth-survival.fandom.com/wiki/Headhunting) · [Pursuit of Luck](https://last-day-on-earth-survival.fandom.com/wiki/Pursuit_of_Luck) · [VIP Marathon](https://last-day-on-earth-survival.fandom.com/wiki/VIP_Marathon) · [Gold Rush](https://last-day-on-earth-survival.fandom.com/wiki/Gold_Rush) · [Supply](https://last-day-on-earth-survival.fandom.com/wiki/Supply) · [Anomaly Season](https://last-day-on-earth-survival.fandom.com/wiki/Anomaly_Season) · [Big Hunt](https://last-day-on-earth-survival.fandom.com/wiki/Big_Hunt) · [Hunter's Instinct](https://last-day-on-earth-survival.fandom.com/wiki/Hunter%27s_Instinct) · [Operation "Purge"](https://last-day-on-earth-survival.fandom.com/wiki/Operation_%22Purge%22) · [Scouting](https://last-day-on-earth-survival.fandom.com/wiki/Scouting) · [On the Witch's Trail](https://last-day-on-earth-survival.fandom.com/wiki/On_the_Witch%27s_Trail) · [Cult Hunting](https://last-day-on-earth-survival.fandom.com/wiki/Cult_Hunting) · [Delivery Service](https://last-day-on-earth-survival.fandom.com/wiki/Delivery_Service) · [Dog Breeder](https://last-day-on-earth-survival.fandom.com/wiki/Dog_Breeder) · [Fishing Tournament](https://last-day-on-earth-survival.fandom.com/wiki/Fishing_Tournament) · [Season 98](https://last-day-on-earth-survival.fandom.com/wiki/Season_98) · [Season 99](https://last-day-on-earth-survival.fandom.com/wiki/Season_99) · [Rations](https://last-day-on-earth-survival.fandom.com/wiki/Rations)
- Enemies and bosses: [Category:Bosses](https://last-day-on-earth-survival.fandom.com/wiki/Category:Bosses) · [Category:Creatures](https://last-day-on-earth-survival.fandom.com/wiki/Category:Creatures) · [Ravager](https://last-day-on-earth-survival.fandom.com/wiki/Ravager) · [Witch](https://last-day-on-earth-survival.fandom.com/wiki/Witch) · [Leshen](https://last-day-on-earth-survival.fandom.com/wiki/Leshen) · [Screech](https://last-day-on-earth-survival.fandom.com/wiki/Screech) · [Alpha Irradiator](https://last-day-on-earth-survival.fandom.com/wiki/Alpha_Irradiator) · [Lighthouse Keeper](https://last-day-on-earth-survival.fandom.com/wiki/Lighthouse_Keeper) · [Borealis](https://last-day-on-earth-survival.fandom.com/wiki/Borealis) · [Consilium](https://last-day-on-earth-survival.fandom.com/wiki/Consilium) · [Leviathan](https://last-day-on-earth-survival.fandom.com/wiki/Leviathan) · [The Blind One](https://last-day-on-earth-survival.fandom.com/wiki/The_Blind_One) · [Liquidator](https://last-day-on-earth-survival.fandom.com/wiki/Liquidator) · [Doctor Dread](https://last-day-on-earth-survival.fandom.com/wiki/Doctor_Dread) · [Cocoon (Bunker Bravo)](https://last-day-on-earth-survival.fandom.com/wiki/Cocoon_(Bunker_Bravo)) · [Butcher (Boss)](https://last-day-on-earth-survival.fandom.com/wiki/Butcher_(Boss)) · [Miner (Wasteland)](https://last-day-on-earth-survival.fandom.com/wiki/Miner_(Wasteland)) · [The Miner](https://last-day-on-earth-survival.fandom.com/wiki/The_Miner) · [Necrotic Hybrid](https://last-day-on-earth-survival.fandom.com/wiki/Necrotic_Hybrid) · [Carrion MK VII](https://last-day-on-earth-survival.fandom.com/wiki/Carrion_MK_VII) · [Icebreaker](https://last-day-on-earth-survival.fandom.com/wiki/Icebreaker) · [Corrupted CEO](https://last-day-on-earth-survival.fandom.com/wiki/Corrupted_CEO) · [Wendigo](https://last-day-on-earth-survival.fandom.com/wiki/Wendigo) · [Berserker](https://last-day-on-earth-survival.fandom.com/wiki/Berserker) · [Colonel](https://last-day-on-earth-survival.fandom.com/wiki/Colonel) · [Greg](https://last-day-on-earth-survival.fandom.com/wiki/Greg) · [Robo-Nick](https://last-day-on-earth-survival.fandom.com/wiki/Robo-Nick) · [Awakener](https://last-day-on-earth-survival.fandom.com/wiki/Awakener) · [Weeper](https://last-day-on-earth-survival.fandom.com/wiki/Weeper) · [Brawler](https://last-day-on-earth-survival.fandom.com/wiki/Brawler) · [Hungry Chomper](https://last-day-on-earth-survival.fandom.com/wiki/Hungry_Chomper) · [Jailbird](https://last-day-on-earth-survival.fandom.com/wiki/Jailbird) · [Riot Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Riot_Zombie) · [Explosive Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Explosive_Zombie) · [Exploder](https://last-day-on-earth-survival.fandom.com/wiki/Exploder) · [Juggernaut](https://last-day-on-earth-survival.fandom.com/wiki/Juggernaut) · [Groaner](https://last-day-on-earth-survival.fandom.com/wiki/Groaner) · [Crawler](https://last-day-on-earth-survival.fandom.com/wiki/Crawler) · [Swamp Zombie](https://last-day-on-earth-survival.fandom.com/wiki/Swamp_Zombie) · [Fast Biter/Zombie Officer](https://last-day-on-earth-survival.fandom.com/wiki/Fast_Biter/Zombie_Officer) · [Toxic Abomination](https://last-day-on-earth-survival.fandom.com/wiki/Toxic_Abomination) · [Frenzied Giant](https://last-day-on-earth-survival.fandom.com/wiki/Frenzied_Giant) · [Timmy the Bloat](https://last-day-on-earth-survival.fandom.com/wiki/Timmy_the_Bloat) · [AI Survivor](https://last-day-on-earth-survival.fandom.com/wiki/AI_Survivor) · [Raiders](https://last-day-on-earth-survival.fandom.com/wiki/Raiders)

**Official (Kefir)**
- [Kefir Helpshift FAQ – How do we obtain chests from the police armory](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/175-how-do-we-obtain-chests-from-the-police-armory) (four card grades; tries per day are limited, with no number given)
- [Kefir Helpshift FAQ – What is a bunker](https://kefirgames.helpshift.com/hc/en/5-last-day-on-earth/faq/13-what-is-a-bunker/) (needs an access card plus a password; harder zone)
- Kefir dev blog ([Northern Region post](https://kefirgames.com/dev-blog/last-day-on-earth?id=northern-region), cited by the wiki's Infected Genome page). The page rendered empty for the fetch tool.

**Guides and secondary**
- [Gamingonphone – Last Day on Earth Bunker Alfa guide](https://gamingonphone.com/guides/last-day-on-earth-bunker-alfa-guide) (April 2020; used only for corroboration and flagged as old)
- Internal: [`docs/research/ldoe-core-systems.md`](../research/ldoe-core-systems.md) (energy, Crater gate, Genome uses, Site Plans, breach tools, version history)
