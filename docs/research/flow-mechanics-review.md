# Flow and mechanics review: v0.1 before launch (2026-11-08)

A cold, adversarial pass over how the game plays, traced through the data and code rather than the docs' claims. The question for every system: does it make sense to a player, step by step, with what they actually have at that moment?

**What was read:**
- `main` at `b04571a`.
- The Fog Runs branch `origin/claude/m1-slice2b-fog-runs-9a5388` at `fd3e620`: six resource zones, location quests, `Services/LocationQuests`.
- The launch home branch `origin/claude/m1-launch-home-platform` at `b43702a`. Main merged it at `d7688d3`, but the branch has 9 more commits: the Reedweave and Padded sets, the stake, lights, doormat respawn, the Rain Barrel and Smoke Rack, and the Equipment and Building shop tabs.

Line numbers are for `main` unless a row names a branch.

**Owners:**
- **S1b** owns home: quests, items, stations, the shop, Haven and UI.
- **S2B** owns Fog Runs: maps, enemies, loot, travel and combat.

**Not repeated here:** the content gaps in [ldoe-mvp-parity-content.md](ldoe-mvp-parity-content.md) (LB-1 to LB-6, BR-1 to BR-11). Rows below cite them where they decide whether the loop makes sense.

---

## Verdict

**Five blockers.** The loop does not make sense yet, though the design under it does.

- **As shipped:** the flag that turns Fog Runs on is off on every branch. The game is a one-hour home plot that runs out of trees, and its Ember Trail stops after quest 8.
- **If the flag is flipped:** quest 1 can never complete. Nothing in the code reports its "search the body" objective, so the whole trail and every building unlock stay locked.
- **Behind those two:**
  - three holes that remove the risk the loop depends on:
    - crafting on a run draws from your home crates
    - the inbox works mid-run as a death-proof stash
    - dying at home refills food, water and health for free
  - a set of mechanics that undercut the money engine:
    - Energy almost never binds
    - the Trader sells the Scrap-tier bottleneck for coins
    - the death screen and the travel panel show no offers
    - the biggest kits are sold to players who can't use them yet

**What holds up:**
- Station chains: no station needs its own output to be built.
- Purchase receipts are idempotent.
- Bag looting doesn't duplicate items.
- Haven's buy and sell prices can't be looped for profit.
- Ores, ironbark and blueprints are obtainable at the fog tier the quests send you to.

---

## Findings

Ranked BLOCKER (soft-lock, exploit, broken loop), then MAJOR (confusing, or no feedback), then MINOR. A row whose Owner cell says **Fixed** names where the fix landed (HANDOFF §6 has the detail).

### BLOCKER

| # | Finding | Evidence | Player impact | Fix | Owner |
|---|---|---|---|---|---|
| F-01 | **Fog Runs are off on every branch, so the launch build is a one-hour home game.** | <ul><li>`Tuning.features.fogRuns = false`: `Data/Tuning.luau:196` on main, `:202` on the Fog Runs branch, `:197` on the launch branch.</li><li>Quest 9 `quest.scavenger` has only fogRuns objectives (`Data/Quests.luau:155-158`), so it's dormant (`Domain/Quests.luau:91-93`) and quests 10-13 never open.</li><li>The only code that reports `travel`, `kill` and `loot` quest events is `Services/LocationQuests.luau`, which exists only on the Fog Runs branch.</li><li>Home nodes never regrow (`Tuning.home`). On main, ironstone exists only at Ashfall Depot (level 15).</li></ul> | <ul><li>After about 60 minutes the plot's 60 timber, 43 stone and 40 scrap are gone.</li><li>The tracker empties after quest 8.</li><li>The Energy Refill, Rations, Scavenger's Kit and "Recover all" sell nothing usable.</li></ul> | <ul><li>Merge the Fog Runs branch and set `fogRuns = true` for the publish build, **together with F-02**: flipping the flag alone soft-locks quest 1.</li><li>Add a launch spec: every quest has at least one live objective, and every objective kind has a server emitter.</li></ul> | S2B (merge, flag); orchestrator (main merge) |
| F-02 | **Quest 1 soft-locks the moment Fog Runs switch on.** | <ul><li>`quest.first_light` objectives 3-4 are `{ kind = "kill", flag = "fogRuns" }` and `{ kind = "lootBody", flag = "fogRuns" }` (`Data/Quests.luau:40-41`).</li><li>Nothing fires `lootBody` on any branch; it appears only in `Types.luau:387` and `UI/questText.luau:42`.</li><li>The Hollow have no body to search: they're bodiless records (Fog Runs branch `Services/Hollow.luau:7`) that turn to ash and drop loot.</li><li>`kill` is reported only on a run server (`LocationQuests.luau:159-162`), and no Hollow spawn at home (`Services/Haven.luau:18`).</li><li>The Guide has no handler for `kill`, `loot`, `lootBody` or `reachLevel` (`Controllers/Guide.luau:130-170`).</li><li>Quest 1 also gates the Timber Foundation and Wall (`Data/BuildPieces.luau:45, 60`).</li></ul> | <ul><li>A new player gathers 6 sticks and 6 stones, then reads "Put down the Hollow" and "Search the body", with nothing to kill and no pointer.</li><li>Even a player who finds Pine Hollow alone never gets the body tick.</li><li>The whole Ember Trail, every quest-gated recipe and piece, and the "Ashes and Embers" chapter reward are unreachable.</li></ul> | <ul><li>Make quest 1 gather-only, plus "craft a Sharpened Stake" once the launch branch lands.</li><li>Move "kill one and take what it drops" to quest 6, and fire `lootBody` when a player picks up a Hollow's loot drop on a run.</li><li>Cover it with the emitter spec from F-01.</li></ul> | S1b (quest data); S2B (emitter) |
| F-03 | **On a Fog Run, crafting draws from home crates and the inbox.** | <ul><li>`Materials.atHome` returns `workspace:GetAttribute("FogRun") ~= true` (`Services/Materials.luau:25-27`), and no code on any branch sets that attribute. Run servers only name a folder `FogRun` (`FogRuns/Maps/init.luau:83`).</li><li>`handCraft` has no home check (`Services/Stations.luau:384-414`) and takes from `Materials.take`, which includes every crate and the inbox.</li><li>Crates live in the player profile, which moves to the run server.</li></ul> | <ul><li>Mid-run, a player makes Field Dressings, arrows, rounds or a fresh Spiked Club from materials sitting at home.</li><li>"You only risk what you carry in" and the bag-space pressure both disappear.</li><li>The Craft button is hidden on runs (`ldoe/Hud.luau:360`), so this takes one remote call: a standard Roblox exploit.</li></ul> | <ul><li>Run servers set `workspace:SetAttribute("FogRun", true)` at boot, where the server role is decided, with a spec.</li><li>Also refuse `HandCraft` on runs, or limit it to carried items.</li></ul> | S2B (run role); S1b (spec) |
| F-04 | **The inbox works mid-run: take, eat and bank loot death-proof.** | <ul><li>`InboxTake`, `InboxTakeAll` and `InboxUse` have no home check (`Services/Inbox.luau:92-140`).</li><li>The Inventory button opens the inbox anywhere (`ldoe/Hud.luau:685`).</li><li>Hand-craft overflow goes to the inbox (`Stations.luau:410`), and death empties only pockets and backpack (`Domain/Death.luau`).</li></ul> | <ul><li>On a run a player pulls dressings, stew or a Scrapblade from the inbox.</li><li>They heal with `InboxUse` from a stash that can never drop.</li><li>With a full bag, they craft loot into cord or arrows that overflow into the inbox, banked even if they die.</li><li>The death drop, the loot-the-bag stakes and re-entry lose their teeth.</li></ul> | <ul><li>On run servers, refuse `InboxTake`, `InboxTakeAll` and `InboxUse`.</li><li>Drop hand-craft overflow on the ground on runs.</li><li>If paid mid-run rescues are wanted, allow only rows with source "Purchase" bought during this run.</li></ul> | S1b |
| F-05 | **Dying at home is a free meal.** | <ul><li>On respawn, hunger and thirst are set to the larger of their current value and 100, and HP to 100 (`Services/Survival.luau:133-141`).</li><li>The home `Died` handler only sets a flag (`:145-150`) and nothing drops; only `Lobby.luau:619` handles run deaths. The launch branch is the same.</li><li>Roblox's Reset Character is enabled: no `ResetButtonCallback` anywhere.</li></ul> | <ul><li>At home, Esc then Reset (or 25 s of starving) refills food, water and HP at no cost.</li><li>Boiled water, cooking, Hearth Stew, the Rain Barrel, dressings at home, and quest 5's lesson all become pointless.</li><li>Players learn to reset before every run so they set out at 100/100.</li></ul> | <ul><li>A home death drops pockets and backpack as a bag at the spot. `Domain/Death.drop` already does this, and LDoE does it too.</li><li>Respawn on the Doormat or at the plot with hunger and thirst at 40 and HP at 50.</li><li>Disable the Reset button, or route it through the same death.</li></ul> | S1b |

### MAJOR

| # | Finding | Evidence | Player impact | Fix | Owner |
|---|---|---|---|---|---|
| F-06 | **Quests count only what you do after they open, but their targets are available earlier.** | <ul><li>`Domain/Quests.record` counts events for active quests only (`:142-160`).</li><li>`craft` and `build` are events, not states, unlike `equip` and `reachLevel` (`observe`, `:163-179`).</li><li>The hatchet, pick, satchel, cord and Timber Crate are unlocked from the start (`Recipes.luau:32-68`, `BuildPieces.luau:400-416`), but quests 2, 6 and 7 ask for them.</li><li>The Doorway and Door unlock at quest 3 (`BuildPieces.luau:92, 107`) and are asked for in quest 7, which opens after quest 4. Foundations and walls unlock at quest 1 and are asked for in quest 3.</li></ul> | <ul><li>The natural order is gather 3 sticks and 3 stones, craft a hatchet, carry on. That leaves quest 2 at 0/1, because the hatchet was made while quest 1 was open.</li><li>The same goes for a satchel made early, a crate placed on day 1, or a door hung during quest 4.</li><li>The player has to make a second one, with no explanation.</li></ul> | <ul><li>Count tools, bags, weapons and placed pieces as "have" when the quest opens, the way `equip` already works.</li><li>Or keep a ledger of events from the start of play.</li></ul> | S1b · **Fixed** (main (holdings count)) |
| F-07 | **The home plot can't pay for chapter 1, and nothing tells the player.** | <ul><li>Home timber: 20 pines × 3 = 60 (`Tuning.luau:113`), never regrown, plus 10 from quest 3.</li><li>Quests 3, 4 and 7 cost 36 + 12 + 19 = 67 of those 70, before any campfire fuel.</li><li>The fire line's Stonecutter (8) and Workbench (6 planks = 12) push the total to about 87, and the launch branch's Rain Barrel adds 8.</li><li>`Quests.luau:15` claims quests 1-7 are "playable on the home plot alone".</li></ul> | <ul><li>Around quests 5-7 the last pine falls with no message, and the build line stalls.</li><li>The Fog map, the only other timber, is introduced by quest 6 on the other branch of the trail.</li></ul> | <ul><li>Either add 8 home pines and raise quest 3's reward from 10 to 20 timber, or toast on the last home tree: "Your plot's trees are gone for good. The Fog has more." Point the Guide at the Trailhead.</li><li>Correct the code comment.</li></ul> | S1b · **Fixed** (main (84 home timber, last-tree toast)) |
| F-08 | **No moment-of-need offer on the death screen or for Energy.** | <ul><li>The death screen has only "Go back in" and "Continue" (`UI/screens/RunHud.luau:594-682`, the same on both branches).</li><li>`offers.gear` and `offers.buyEnergy` are set (`Controllers/Shop.luau:66-75`) but no screen calls them.</li><li>The server sends `energyShort` when a Run can't be paid (Fog Runs branch `Travel.luau`), but no client handles it; the Run button just greys out.</li><li>"Go back in" is disabled when Energy is short, with no refill offered.</li><li>MVP_LAUNCH requires both offers.</li></ul> | The two highest-intent buying moments (you just died; you can't pay for the Run) show nothing. | <ul><li>Death screen: a Scavenger's Kit chip, and the Energy Refill when "Go back in" is short.</li><li>Fog map: a Refill slot beside a greyed Run, showing the shortfall.</li></ul> | S2B (screens); S1b (offer hooks) |
| F-09 | **"Recover all" can't be reached.** | <ul><li>`recoverAll` searches `hostedLobbies` (`Lobby.luau:870`), which exist only on the run server.</li><li>The player sees the death screen there for 4 s (`DEATH_LINGER_SECONDS`, `:67`), then at home, where the handler finds nothing.</li><li>No client sends `RecoverAll`.</li><li>`Payments.verify` accepts only premium "Recover all" and refuses every ad (`Shop.luau:298-307`, `FogRuns/Payments.luau:23-25`). LDOE_PARITY #46.</li></ul> | <ul><li>A designed Ember sink (100 Embers) and the recover-by-ad hook don't exist.</li><li>The Ember Pouch card still advertises "Recover all".</li></ul> | <ul><li>Put "Recover all (100 Embers)" on the home death screen. The home server messages the run server (MessagingService, keyed by lobby id) to release the bag to the inbox.</li><li>Hide the ad option until ads ship.</li><li>Or cut "Recover all" from v0.1 copy.</li></ul> | S2B |
| F-10 | **Build mode has no Fill Up.** | <ul><li>The build tray's cost chips (`ldoe/Build.luau:111` for placing, `:253` for upgrades) show have and need but no Fill Up, on both branches.</li><li>Fill Up exists only in the crafting, inventory, crate and station panes (`CraftingScreen.luau:505`, `InventoryScreen.luau:635`, `ContextPanes.luau:255`, `StationPane.luau:245`). LDOE_PARITY #28.</li></ul> | The commonest shortfall, a wall short of timber or an upgrade short of plates, has no buy button. | Add the Fill Up slot to the placement card and the per-piece upgrade button. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-11 | **The Firestarter Kit's 48-hour window opens silently.** | <ul><li>The first win is the first extraction, or the first dawn after 2 minutes online (`Services/Shop.luau:373-397`), often 10-25 minutes into the first session.</li><li>The offers strip is reserved but empty (`ldoe/Hud.luau:332`). The kit shows only on the shop's Best tab, with no toast, badge or pop-up on either branch.</li></ul> | <ul><li>The best-value SKU, 10-20× by the playbook, expires unseen for most players.</li><li>A "first night" with no threat barely reads as a win.</li></ul> | <ul><li>On the first win, show a one-time card with the countdown, then a pulsing offers-strip icon until it expires.</li><li>Count the first extraction as the first win.</li></ul> | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-12 | **Packs are sold before their tier unlocks, with no warning.** | <ul><li>**Reinforced Room Kit, 1,699:** every reinforced piece needs the Reinforcement Plans (`BuildPieces.luau:32`), a random drop from the Black-fog Depot strongbox or the rotating Dense Caravan. The kit is about 32 of the 145 grind-hours a room takes (`Products.luau:135`).</li><li>**Firestarter Kit:** its Scrap room waits for quest 8.</li><li>**Launch branch:** Gunrunner (249), Raider Arms (499) and Heavy Equipment (2,499) sell guns whose ammo recipes and Ammo Press unlock at quest 10 (`Recipes.luau:410-453`, `BuildPieces.luau:436-455`). The packs contain no ammo.</li><li>**Weapon Parts (149)** feeds recipes that are also locked until quest 10.</li><li>No shop card shows a lock.</li></ul> | A level-3 player can pay 1,699 for pieces they can't place, or 2,499 for guns that can't fire. That's a refund and trust risk. | <ul><li>Give products an unlock gate, and grey the card with its lock line ("Needs the Reinforcement Plans", "Unlocks with The Dense Fog").</li><li>Or put the Plans in the Reinforced kit and ammo in the gun packs.</li><li>Size the 1,699 kit to a full room, or rename it.</li></ul> | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-13 | **"No ammo" is decided but not built.** | <ul><li>DECISIONS and MVP_LAUNCH (2026-11-08) remove ammo, ammo recipes and the Ammo Press from v0.1.</li><li>All three branches still have Light Rounds, Shells, Flares, Blackpowder, their recipes, `station.ammo_press`, and guns and the bow with `ammoItemId` (`Items.luau:390, 709, 739, 771`; `Recipes.luau:407-453`).</li></ul> | <ul><li>The shop and docs say guns run on durability, but the game needs ammo.</li><li>Checklist 13.6 (ammo counter) and 13.12 (Ammo Press) contradict the decision.</li></ul> | <ul><li>Build the decision: drop `ammoItemId`, remove the Ammo Press and the ammo recipes, convert ammo already held to scrap.</li><li>Set the shot counts per F-14, and update checklist 13.6 and 13.12.</li></ul> | S2B |
| F-14 | **Guns cost a free player more than they give back.** | <ul><li>Durability is shots (`gunDurabilityPerShot = 1`): Worn Pistol 50, Scrap Shotgun 30, Flare Pistol 24 (`Items.luau:701, 731, 763`).</li><li>Re-crafting needs Trigger Groups (pistol 1, shotgun 2, flare 1), at weight 3 in `loot.quarry_band2` with a pity drop every 15 band-2 Dense containers: about 4-6 Dense runs each.</li><li>Broken guns are destroyed, and the Recycler has no gun line.</li><li>A Dense run has 12-17 Hollow. The pistol needs 2-3 shots each, so it lasts about 20 kills; the shotgun lasts about one run.</li></ul> | A free player farms about 5 runs for one Trigger Group and burns the gun in 1-2. "First firearm, days 3-5" lands, but the gun is useless to them. | <ul><li>When ammo goes (F-13), raise durability to Pistol 150, Shotgun 90, Flare Pistol 72.</li><li>Or give the Recycler gun lines that return the Trigger Group at 60-100%.</li><li>Rerun Pacing.spec.</li></ul> | S2B |
| F-15 | **Fog exposure is live, and it puts late-run loot out of reach.** | <ul><li>Exposure runs every run with no flag (`Lobby.luau:733-746`), though MVP_LAUNCH lists it for M4.</li><li>Unprotected, Black fills in 240 s and Dense in 600 s (`Tuning.fogExposure`).</li><li>The best resist is 0.25 on main (hood and vest), or 0.45 with the launch branch's full Padded set.</li><li>Meter bands start at 6 and 11.25 minutes (`Tuning.lobby.bands`). A full meter does 2 HP/s.</li></ul> | <ul><li>In Black with the full Padded set, the meter fills at about 7.3 minutes. Band 3, where `loot.depot_band3` and its "a whole gun in every 10" pity live, then costs about 470 HP of fog to reach.</li><li>"Stay late for better loot" and "leave before the fog gets you" contradict each other.</li><li>Quest 13 sends players into Black, which also drops equipped gear, without a word about it.</li></ul> | <ul><li>Put exposure behind a flag for v0.1, as MVP_LAUNCH says.</li><li>Or slow it (Dense 100/1200, Black 100/720) so a full Padded set reaches band 3.</li><li>Warn in quest 13's text.</li></ul> | S2B · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-16 | **Energy almost never binds, so the Energy products sell little.** | <ul><li>Players start at 200 (`PlayerSchema.luau:213`), regenerate 288 a day and get 20 per level-up.</li><li>Location dailies pay up to 5 Rations a day, which is 300 Energy (BR-9).</li><li>Walking is free and doesn't stop home play: checklist 11.4 says so, and Travel checks the Trailhead only when you set out.</li><li>VIP's +40 cap (`Data/Haven.luau:120`) only matters after more than 16.7 h away.</li></ul> | <ul><li>A 2.5 h-a-day player never runs dry, and anyone short just walks and keeps crafting.</li><li>The Energy Refill and the "Time" lever of the money engine sit idle.</li></ul> | <ul><li>No Rations from location dailies (BR-9).</li><li>Make walking cost something: lock stations and crafting while on the road (as in LDoE), or seat walkers in a lobby already at band 2.</li><li>Give VIP a travel discount instead (LDOE_PARITY #54).</li></ul> | S2B (travel); S1b (VIP) · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-17 | **The Haven Trader undercuts Fill Up and the Scrap-tier bottleneck.** | <ul><li>She sells Rivets for 18 coins, Planks 12, Cloth 15 and Cord 20, with no stock limit (`Data/Haven.luau:66-75`, `Services/Haven.luau:125-150`), and buys Scrap at 4 (`:82`).</li><li>Fill Up prices a Rivet at 8 Embers, about 21-24 Robux (`Tuning.luau:431`).</li><li>Crafting a Rivet costs 2.5 scrap plus about 12 minutes of the Workbench, the binding throttle (BR-7).</li></ul> | <ul><li>4.5 scrap buys a Rivet instantly, which beats both crafting and Fill Up.</li><li>The "Rivets for the Scrap tier" bottleneck (GAME_DESIGN) and the Builder's Crate ("heavy on Rivets") lose their pull.</li></ul> | <ul><li>Take Rivets off her list; keep the basics (water, tins, dressings, cord, cloth, fatwood).</li><li>Give everything a daily stock, for example 10 per item.</li></ul> | S1b · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-18 | **Forged tools are burned on ordinary nodes.** | `Gathering.pickTool` picks the highest-tier tool in the bag (`Domain/Gathering.luau:77-109`). So the Forged Hatchet (75 durability; 5 ingots, 2 rivets, 2 glue) chops pines, and the Forged Pick breaks boulders, heaps and ironstone, even with stone tools in the bag. | Players wear out their costliest tools on cheap nodes before they reach Ironbark or Malachite, and can't choose otherwise. | Pick the lowest tier that can harvest the node. | S1b · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-19 | **The Hollow don't scale with lobby size, so kill objectives are contested.** | <ul><li>Spawns are a fixed count per band, with no scaling by player count and no respawn within a lobby (Fog Runs branch `Services/Hollow.luau:205-210, 660-667`).</li><li>Pine Hollow has 6-9 Shamblers and 0-2 Runners for up to 12 players.</li><li>Quest 8 needs 5 kills and the Pine Hollow daily needs 3. Light loot is per player; kills aren't.</li></ul> | In a full launch-day lobby, most new players can't finish quest 8 in one run, and kill XP is scarce. | <ul><li>Scale band spawns by seated players (base plus 1 Shambler per player above 2), or trickle-respawn Shamblers in Light fog.</li><li>Credit assists within 5 s.</li></ul> | S2B · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-20 | **The AUTO button shows the wrong price.** | <ul><li>Fog Runs branch `UI/screens/FogMap.luau:855` always reads "AUTO: clear it for 1 Ration".</li><li>Dense actually costs 2 and Black 3 (`Tuning.autoClear.rationsByTier`), plus the Run's Energy (`Travel.autoClear`).</li><li>A refusal just says "You can't pay for that".</li></ul> | The player taps expecting to pay 1 Ration and gets a vague refusal, or pays Energy they didn't see. | Build the label from data ("AUTO: 2 Rations + 22 Energy"), and name the shortfall in the refusal. | S2B · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-21 | **Items and stations that do nothing.** | <ul><li>**Smoke Rack** (launch branch: 5 planks, 10 cord, 10 stone) and the Campfire's venison line (`Recipes.luau:456`) need Raw Venison, which only wildlife drops, and wildlife is deferred (Fog Runs branch, `Enemies` `deferred`).</li><li>**Ember Heart** comes only from the 20-death milestone, but `DeathRecovery.milestoneGifts` is never called, and no product sells it.</li><li>**Rain Barrel** (launch branch) still needs Murky Water put in, so it's a slow boiler, not a rain catcher.</li><li>**Doormat and Tanned Leather** are dead ends on main, fixed on the launch branch.</li></ul> | Players spend materials on dead ends, and trust drops. | <ul><li>Hide the Smoke Rack and the venison lines until wildlife ships.</li><li>Call `milestoneGifts` on run and home deaths. Sell the Ember Heart or drop it from loot.</li><li>Make the Rain Barrel fill itself (1 Boiled Water every 15 minutes, up to 5).</li><li>Merge the launch branch.</li></ul> | S1b; S2B (wildlife, Ember Heart drops) · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-22 | **Quest lines don't say where, and some steps have no pointer.** | <ul><li>Station recipes read "Make Hewn Plank" with no station named (`UI/questText.luau:26-30`).</li><li>`loot` reads "Search containers", though quest 9 counts Pine Hollow only.</li><li>`reachLevel 8` has no Guide and no hint.</li><li>Quest 4's plank counts only when taken out of the bench (`Stations.luau:315-323`).</li><li>Drinking from the inbox fires no `consume` (`Inbox.luau:126-140`), so it doesn't count for quest 5.</li></ul> | <ul><li>Players do the right thing in the wrong place, or wait at a bench that already made the plank.</li><li>Quest 10 is a silent wall several hours long.</li></ul> | <ul><li>Name the place: "Saw a Hewn Plank at the Saw Bench and take it", "Search 3 containers in Pine Hollow".</li><li>Hint `reachLevel` ("XP comes from gathering, fighting and extracting").</li><li>Fire `consume` from `InboxUse`.</li></ul> | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-23 | **Ad caps reset on every server hop.** Latent today; a blocker the day ads ship. | <ul><li>The daily caps for "Recover all" by ad (`Lobby.luau:133`, cleared at `:1252`) and AUTO by ad (Fog Runs branch `Travel.luau:72`) live in server memory.</li><li>So do airdrop days and signal-tower progress (`Travel.luau:66-72`).</li><li>Every run is a new server.</li></ul> | Once ads are wired, one free recovery a day and ten ad clears a day become unlimited, and tower parts vanish on rejoin. | Store these in the profile before ads switch on. | S2B · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-24 | **Nothing to build for past the Scrap tier, and nothing after quest 13.** (Detail in BR-2, BR-3 and BR-8.) | <ul><li>Walls face no threat in v0.1: no night assault, and raids come in M2.</li><li>Black fog has no new enemy, weapon or armor.</li><li>The trail ends at quest 13, about day 7, and levels 16-20 gate nothing.</li></ul> | The 30-hour Reinforced grind protects nothing, so the loop has no reason to continue at home. | Follow the parity doc: Night Drift (SH-2), a Black-only threat, and chapter 3. | Orchestrator (scope); S1b; S2B |

### MINOR

| # | Finding | Evidence | Player impact | Fix | Owner |
|---|---|---|---|---|---|
| F-25 | **Ember prices don't line up.** | <ul><li>Speeding up one 20-minute Scrap Plate costs 18 Embers (`Offers.speedUpPrice`, `Tuning.luau:409`), but filling one up costs 13 (`:432`). A 60-minute Copper Ingot: 31 against 20.</li><li>The 1-Ember floor on raw materials is about 3-4× the plate rate.</li><li>At Fill Up rates the Supply Bundle (99 Robux) is worth about 196 Embers and the Builder's Crate (399) about 289, so the small pack is 2.7× better per Robux.</li></ul> | Players who compare find that skipping a timer costs more than buying the item outright, and that the bigger pack is worse value. | <ul><li>Cap a speed-up at the Fill Up value of what it makes.</li><li>Charge raw materials at 1 Ember per 3 units.</li><li>Re-step the bundles.</li></ul> | S1b · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-26 | **The Scout's Kit is strictly worse than the Scavenger's Kit at the same price.** | <ul><li>Launch branch, both 79 Robux.</li><li>Scout's Kit: Tire Iron (18 DPS), 5 dressings, 3 tins, 3 water.</li><li>Scavenger's Kit: Scrapblade (31 DPS), Padded Vest, 5 dressings, 5 stew, 5 water.</li></ul> | One of the two cards reads as a trap. | Give the Scout's Kit its own job, for example the Reedweave set, a stake and food for fresh players. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-27 | **"+1 Smelter" and "+1 Recycler" are offered before you can place the first one.** | <ul><li>Launch branch, 399 Robux each.</li><li>The Smelter unlocks at quest 6; the Recycler at quest 9 and needs a Scrap floor.</li></ul> | Players pay for capacity they can't use yet. | Show each only when the plot is at its limit ("Placed 2/2"). | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-28 | **The broken-weapon offer also fires for tools and armor.** | `Controllers/Shop.luau:87` matches any " broke" toast, including "Your Stone Hatchet broke" and "Your armor broke". | A combat kit is offered for a broken hatchet. | Match weapons only; for tools, offer Fill Up of the recipe. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-29 | **A tool in a weapon slot is weaker than bare fists.** | Tool: 8 damage × 1.1/s = 8.8 DPS, plus durability wear (`Tuning.melee`). Fists: 6 × 1.8/s = 10.8. LDOE_PARITY #34 calls a tool "a weak club". | Equipping a hatchet to fight is worse than punching. | 10 damage at 1.2/s. | S2B |
| F-30 | **Demolishing the starter shelter refunds more timber than the whole home forest.** | `Shelter.build` stamps every piece as placed now (`Domain/Shelter.luau:43-57`, `Plots.luau:331`). So for 30 s the refund is 100% (about 138 timber), then 50% (about 65). | It undercuts quest 3 ("patch the shelter") and the finite-home design. | Starter pieces refund nothing. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-31 | **Stack sizes break LDOE_PARITY #15 (20 for everything, 50 for scrap).** | Niter 40, Blackpowder 50, Light Rounds 60, Shells 30, Flare 10, Steel Pipe 10, Trigger Group 5, venison 10, leather 30 (`Items.luau`). | Inventory reads inconsistently. | Set them to 20, or list the exceptions in the parity doc. | S2B · **Fixed** (2.0 economy batch, `economy-balance`) |
| F-32 | **Three different bag lifetimes.** | `Tuning.death.despawnSeconds` is 2 h and `Tuning.drops.lifetimeSeconds` 10 minutes, but a death bag really lasts until the lobby closes (the death screen says so). | Future work could wire the wrong rule. | Delete the dead numbers. | S2B · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-33 | **The daily gift is off with a false reason.** | `dailyGift = false -- cut from v0.1 (docs/MVP_LAUNCH.md)` (`Tuning.luau:198`), but MVP_LAUNCH doesn't cut it and LDOE_PARITY #58 requires it. | A new player loses the food and water cushion that F-05's fix makes matter. | Switch it on (it's built and tested), or record the cut. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-34 | **The fire line depends on the build line without saying so.** | The Workbench (quest 5) and Smelter (quest 6) cost Stone Blocks, whose Stonecutter unlocks at quest 4 on the other branch. | The Workbench card reads "unlocked" but can't be built. | The Stone Block chip says "Stonecutter: Ember Trail 4". | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-35 | **Contracts and the Trader take from the bag only.** | `Haven.luau:165, 190` take from the bag, while building and crafting draw on the whole home pool. Contracts can also ask for Planks or Cloth before the player can make them. | Players walk crates' contents to Haven by hand, or get a contract they can't do. | Draw on the home pool, and roll contracts only from unlocked items. | S1b · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-36 | **A Walk ends if you leave the game.** | Fog Runs branch `Travel.luau:18`. Checklist 11.4 and `Domain/Travel` say a walk carries on while you're offline. | A long Walk is lost on disconnect. | Save trips in the profile. | S2B · **Fixed** (2.0 batch 2, `qol-flow-review`) |
| F-37 | **One craftable bag until a rare blueprint.** | <ul><li>The Reed Satchel (+5) is the only bag you can craft.</li><li>The Pack Frame (+10) needs a Black strongbox, the Caravan, or a 2% Gloaming crate roll.</li><li>A Light clear fills about 20 stacks against 15 slots.</li></ul> | It's the intended pressure, but LDoE has two craftable bags before that point. | Add a mid bag (+8, leather and cord, quest 9). | S1b |
| F-38 | **No reward for the "Into the Fog" chapter.** | `Data/Haven.luau:107` has a reward for chapter 1 only, though Old Hale promises chapter rewards. | Players who finish chapter 2 get nothing from him. | Add a chapter 2 reward. | S1b · **Fixed** (already on main; spec added in batch 2) |

---

## Trace 1: a new player's first hour

With `fogRuns` on and the Fog Runs branch merged, which is the intended launch state.

| Step | Quest | What it needs | Source at that moment | Verdict |
|---|---|---|---|---|
| 0 | Spawn | Shelter (3×3 floor, 5 walls, cold Campfire, Crate), 2 tins, 2 boiled water, 200 Energy | — | OK |
| 1 | 1 First Light | 6 sticks, 6 stone, kill 1, search a body | Branches and loose stones by hand; a kill only on a run; nothing ever reports the body search | **Soft-lock (F-02)** |
| 2 | 2 Tools of Survival | Hatchet and pick (3 sticks and 3 stone each) | Unlocked from the start | Crafts made during quest 1 don't count (F-06) |
| 3 | 3 Claim the Ground | 2 foundations (20 timber), 2 walls (16 timber, 2 cord) | Pines (hatchet); quest 2's 6 fiber makes 3 cord | OK; 36 of 70 home timber used |
| 4 | 4 A Place to Work | Saw Bench (10 timber, 6 stone, 2 cord), take 1 plank (2 timber, 4 min) | Home | OK; counts only when taken out (F-22) |
| 5 | 5 Keep the Fire | Boil and drink 1 water at the starter Campfire | Spring pool, sticks or timber as fuel | OK; but F-05 makes drinking optional |
| 6 | 6 Into the Fog | Craft and equip the satchel, reach Pine Hollow | Trailhead | Satchel made earlier doesn't count (F-06) |
| 7 | 7 Hold the Door | Doorway (6 timber, 1 cord), door (5, 2), crate (8, 4) | Home timber nearly gone: 67 of 70 | Tight (F-07) |
| 8 | 8 Stand Your Ground | Spiked Club (4 planks, 2 cord, 3 scrap), equip, kill 5 | Quest 7's 6 planks, quest 6's 6 scrap | 5 kills contested in a full lobby (F-19) |
| 9 | 9 Scavenger | Search 3 containers in Pine Hollow, gather 4 ashroot | 3-5 packs and 6 mounds per run | OK |
| 10 | 10 The Dense Fog | Level 8 (16,000 XP), reach Rustwater | After quest 9, about 4,400 XP (2,350 from quests, about 2,050 from home nodes); Light clears give 1,400-2,500 XP each | A bare grind with no pointer (F-22) |
| 11-12 | Heartwood, The Green Vein | Forged Hatchet or Pick (5 ingots, 3 planks, 2 rivets, 2 glue), 10 Ironbark logs, 6 Malachite | Smelter (6), Rivets (7), glue (5); Ironbark Stand and Greenvein, both Dense | OK, only on the Fog Runs branch |
| 13 | Into the Black | Level 15 (57,000 XP), enter Black | — | OK, then the trail ends (F-24) |

**No circular station dependency:**
- Every station's build cost uses lower-tier output (Saw Bench and Stonecutter first, then Workbench and Smelter).
- Every level-2 upgrade uses its own level-1 output or earlier materials.
- The cross-line dependency in F-34 is a signposting issue, not a soft-lock.

**Without `fogRuns`:** quests 1-8 complete. Quest 9 then sits dormant, quests 10-13 never open, and home nodes run out (F-01).

## Trace 2: the core loop in numbers

**Energy:**

| Item | Value |
|---|---|
| Start | 200 |
| Cap | 200, or 240 with VIP |
| Regeneration | 12 an hour, 288 a day |
| Run | 15 / 22 / 33 (Light / Dense / Black) |
| Re-entry | 8 / 11 / 17 |
| AUTO | The Run's Energy plus 1 / 2 / 3 Rations |
| Hurry | 2 a minute |
| Walk | Free; 12 / 19 / 29 min; you keep playing at home |
| Other sources | Level-up +20, Ration +60, Ember Tonic +25, Energy Refill +100 |

At 2.5 h a day, about 10 lobbies cost 150-330 Energy, which the cap, regeneration and up to 300 from dailies cover. Energy binds only on Black-heavy days, and Walk removes even that (F-16).

**Carrying capacity:**
- 10 pockets plus the Satchel's 5 (plus 5 with the Pack Expansion) is 15-20 slots, at 20 a stack (50 for scrap).
- One Bracken Edge clear is about 90 timber (5 slots), 24 sticks (2), 24 stone (2), 40 fiber (2), 30 berries (2), 12 fatwood and 6 ashroot (2), plus containers: about 16-20 stacks before food and dressings.
- The bag binds on every run. That's intended, but there's no mid-size bag (F-37).

**Durability against crafting supply:**

| Item | Durability | Re-craft cost | Lasts |
|---|---|---|---|
| Stone Hatchet | 40 | 3 sticks, 3 stone | 13 pines |
| Forged Hatchet | 75 | 5 ingots, 3 planks, 2 rivets, 2 glue | 18 Ironbark (37 logs, about 7 Ironbark Planks, one reinforced wall), but spent on pines (F-18) |
| Spiked Club | 80 | 4 planks, 2 cord, 3 scrap | About 25 Light Shamblers |
| Worn Pistol | 50 shots | 1 Trigger Group and parts | About 20 kills, against about 5 Dense runs to find the Trigger Group (F-14) |
| Scrap Shotgun | 30 shells | 2 Trigger Groups and parts | About 1 Dense run |

**Closing the loop at home:**
- Refining and building close, with no dead end in the chains.
- Home has no stakes. Night brings no threat, and death is free (F-05).

## Trace 3: combat by tier

Hollow HP is the Thin band, then Closing (×1.45), with the Fog Runs branch's tier scale (×1, ×1.2, ×1.4):

| Hollow | Light | Dense | Black |
|---|---|---|---|
| Shambler | 40 → 58 | 48 → 70 | 56 → 81 |
| Runner | 70 → 102 | 84 → 122 | 98 → 142 |

**Damage taken:**
- Shambler: 3.1 HP/s in Light, up to 5.9 in Black at Closing.
- Runner: 6 HP/s, up to 11.3.
- A Field Dressing heals 40.

**Weapon DPS:**

| Weapon | DPS |
|---|---|
| Fists | 10.8 |
| Tool | 8.8 (F-29) |
| Stake (launch branch) | 11 |
| Spiked Club | 14 |
| Reed Shortbow | 14.4 (silent) |
| Tire Iron (launch branch) | 18 |
| Rail Mallet (launch branch) | 21 |
| Worn Pistol | 24 |
| Scrapblade | 31 |
| Fire Axe | 32 |
| Machete | 35, crit 12% |
| Scrap Shotgun | 36 at point blank |

**Each gate has a weapon that clears it in 3-5 hits:**
- The club for Light fog.
- The Scrapblade, recommended for Dense, unlocks at quest 9, before level 8.
- Guns and the Fire Axe for Black.

The ladder is sound. What breaks it is gun upkeep (F-14), fog exposure (F-15) and a Black tier with nothing new (F-24).

**Noise:**
- Guns carry 90-120 studs, and Runners hear 1.25× farther.
- Melee is 10 and searching 8.
- It reads as intended: guns trade quiet for damage.

## Trace 4: every shop product at the moment it's offered

| Product | Robux | When it's first seen | Usable then? |
|---|---|---|---|
| Firestarter Kit | 99 | First dawn or first extraction, shop tab only | Partly: blade, armor, meds, Pack Frame and Embers yes; the Scrap room waits for quest 8 (F-11, F-12) |
| Scavenger's Kit | 79 | Always; the death-screen chip isn't wired (F-08) | Yes |
| Supply Bundle | 99 | Always | Yes; ironstone once the Smelter is built (quest 6) |
| Builder's Crate | 399 | Always | Station upgrades; Scrap walls after quest 8 |
| Reinforced Room Kit | 1,699 | Always | **No:** needs the Reinforcement Plans (F-12) |
| Energy Refill | 99 | Always; not on the travel panel (F-08) | Rarely needed (F-16) |
| Ember Pouch / Ember Chest | 149 / 799 | Always | Fill Up and speed-ups; "Recover all" is unreachable (F-09) |
| Pack Expansion | 199 | Bag-full toast | Yes |
| VIP Lounge | 399 | Always; any purchase gives a week | The daily crate yes; the +40 cap is low value |
| Scout's Kit (launch branch) | 79 | Always | Yes; dominated by the Scavenger's Kit (F-26) |
| Weapon Parts (launch branch) | 149 | Always | Not before quest 10 |
| Padded Armor (launch branch) | 199 | Always | Yes |
| Gunrunner Pack, Raider Arms, Heavy Equipment (launch branch) | 249 / 499 / 2,499 | Always | Guns with no ammo before quest 10 (F-12, F-13) |
| +1 Smelter, +1 Recycler (launch branch) | 399 each | Always | Not until the first one is placed (F-27) |

**Inbox flow:**
- Purchases, quest and level rewards land in the inbox.
- At home, crafting and building draw from it automatically, which is clear and works.
- The problem is that it also works on runs (F-04).

## Trace 5: Haven Square

**Trader:**
- No loop exists. Every sell price is below the matching buy price (Planks buy 12, sell 5), and Embers can't be turned into coins at a profit.
- The problem is what she sells: Rivets (F-17).

**Contracts:**
- Three a day, 30-80 coins and 80-200 XP each.
- Buying cloth to deliver turns 30 coins into 150 XP, capped at 3 a day. That's acceptable.

**VIP:**
- The daily crate is a stew, a water and a dressing, plus a Ration every 7th day in a row.
- It's handed out once a UTC day even across server hops (`vipCrateDay` is saved).
- The +40 Energy cap rarely matters (F-16).

## Trace 6: death and recovery

| Where | What drops | Who can take it | How long it stays | Re-entry |
|---|---|---|---|---|
| Light run | Pockets and backpack | You and your party | Until the lobby closes | Half the Run's Energy, until 60 s before close |
| Dense run | Pockets and backpack | Anyone | Until the lobby closes | Same |
| Black run | Everything, equipment included | Anyone | Until the lobby closes | Same |
| Leaving mid-run | Counts as a death, so quitting can't carry loot out | — | — | — |
| Home | **Nothing**; meters reset to full (F-05) | — | — | — |

**Duplication:**
- Bag looting returns any leftover to the same record (`Lobby.luau:820-828`, `Domain/Lobby.returnToDrop`) with no copy.
- Receipts are logged in the same change that grants the goods.
- The remaining leaks are home stock reaching runs (F-03, F-04), not duplication.
