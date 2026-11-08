# LDoE parity: binding rulings (2026-11-08)

This came out of an independent audit of every LDoE recording frame (rec1–rec9) and the LDoE systems research, compared against our design and the slice-1 build. The developer had said: "I shouldn't have to tell you things like this... make the best game you can with the information provided, the source material is good."

**Rule:** every screen, control, HUD element and flow matches what the LDoE recordings show. The only exceptions are the deliberate deviations listed at the end, each of which is also in DECISIONS.md. Before designing any screen, open its rec frame.

**Owners:**
- **S1:** the current slice-1 session; it finishes only what's already in flight.
- **S1b:** a new "LDoE parity: home UX" slice that starts as soon as S1 merges.
- **S2:** Fog Runs.
- **S3:** shop, quests and meta.

## Rulings

### HUD and controls (S1b)
1. **No hotbar.** The bottom-right cluster:
   - a big **active-weapon circle** (about 96 px) that doubles as the attack button, with icon, ammo and a durability ring
   - a **second-weapon circle** (about 64 px) that swaps on click or F
   - a **meds slot** (about 56 px) with a count; H uses it
   - the **context button** (its icon follows the target: hand, axe, gear, speech bubble; greyed when nothing is in range)
   - a **sprint** button (Shift)
   Keys: 1/2 select, LMB attacks, and the plain mouse wheel zooms.
2. **Top-left:** player name and the HP bar with its number only. A buff and status icon row appears beneath it only when something is active. **No hunger or thirst bars:** a pulsing food or water icon with its value appears next to HP at ≤ 20. **Energy moves to the Fog map.** Level lives only on the bottom bar.
3. **Bottom-left:** the AUTO toggle (Q), plus the joystick on touch. **Craft** and **Build** buttons stack under the minimap.
4. **Bottom menu bar:** Social, Crew/Guild, Quests, Pass, Shop, Map (M) and Inventory (Tab), with teal count badges and red NEW badges. Slots are reserved now; each switches on when its screen ships.
5. **Level bar** along the bottom edge reading "Lv N", with the numbers on hover and "+N xp" popping up beside it.
6. **Top-right:** the minimap, then a three-icon strip left of the gear (event, offers, daily gift) with timers; S3 fills it. A small **sun/moon arc** by the minimap replaces the clock pill (a deliberate deviation, since nights matter).
7. **Minimap icons:** crates, stations (with a ready badge), nodes, Hollow, bags (red X), and exits and extraction points (green arc).
8. **Top centre** is reserved for the target bar (enemies red, NPCs green, companions yellow). Toasts sit below it. The DEV badge is hidden outside Studio.
9. **Pickup feedback:** a floating "+N [icon]" at the player that merges repeats. Cards are only for warnings and completions.
10. **Chat:** TextChatService docked as a one-line bar at bottom-left, above the level bar. The Social panel slides in from the right.
11. **Opening any panel** (inventory, storage, station, crafting, quests, shop) hides the HUD, dims the world and docks a vertical CLOSE strip at the right edge.
12. **Zoom:** deliberate deviation (the developer asked for it). The wide range applies at home and in build mode. **In Fog Run lobbies it clamps near LDoE framing** (survivor about 1/8 of screen height) for PvP fairness.

### Inventory and storage (S1b)
13. **Two-pane inventory, as in LDoE:**
    - **Left:** pockets 2×5, a backpack grid 5 wide, the currency balance and "+" in the header, and USE/EQUIP · SPLIT · sort · trash.
    - **Right:** the context (box, station, corpse, vehicle or recycler), or a **character pane** (gear plus HP, food, water and armor values) when opened alone.
    - Drop the inventory CRAFTING tab; the catalogue replaces it. The inbox gets a shop entry and a HUD badge.
14. **Gear slots:** head, body, legs, feet, backpack, **Weapon 1, Weapon 2, Quick slot**. They feed the HUD circles and the meds button.
15. **Stack size 20** (scrap and coupons 50). **Bags add +5, +10 or +15** slots.
16. **Storage header:** icon, name and **level**, a paint brush (label colour or icon), and a green upgrade arrow. The arrow opens a modal with materials have/need, **SLOT CAPACITY 20 » 25**, and CANCEL / BUY (BUY fills the shortfall with premium currency). Hide gear while a container is open. Paint content icons **onto the crate lid**.
17. **Storage ladder:** add Trunk and Rack tiers and rack levels in M2. Specialised storage becomes capacity products.

### Crafting and stations (S1b)
18. **Stations are LDoE converters, not job queues:**
    - The inventory sits on the left. The station pane shows "NAME LVL N", an **ALL RECIPES** button, a green upgrade arrow, and **one input slot → one output slot** (20 per stack, +20 per level).
    - Fuelled stations get a fuel slot with a burn bar. Drag a stack in and it converts on the timer.
    - This supersedes the 3/5/7 queue model.
19. **Station roster:** each station is a building goal with its own floor tier.
    - Woodworking Bench: timber → planks
    - Stonecutter: stone → blocks
    - Smelter: scrap → plates and bars
    - Workbench: parts and nails
    - Campfire: cooking
    - Tanning Rack and Sewing Table come later.
20. **Gear is crafted by hand in the catalogue:** weapons, armor, tools, bags, stations and furniture. Stations only refine materials. Remove station recipes from the hand grid, or make the tile say "Made at Workbench" with a locate button.
21. **No early repair.** Worn gear is re-crafted. Repair comes from a late Repair Station or as a VIP perk.
22. **Floor-tier gates:** `floorTierMin` per station, with the ghost saying "Needs a Plank floor".
23. Show **"Installed x/y"** on placeables in the catalogue, and a teal **ready-count badge** over stations.
24. **Notifications (S3):** Roblox experience notifications, opt-in, for "station done" and "Energy full".

### Building (S1b)
25. Build mode **hides the HUD** but keeps the tracker. Add a top-left **"hide upper walls"** toggle.
26. **Tray:** icon tabs (Building, Stations, Storage, Furniture & decor, Defense, ★) with NEW ribbons.
27. **Per-piece actions:** clicking a placed piece puts three floating buttons on it: move/rotate, demolish (red), and upgrade (green, with the next tier's have/need). The R/U/X keys stay.
28. Furniture shows as **translucent cyan ghosts** in build mode. Costs are **icon chips** with have/need and a Fill-up slot.
29. **Plot size** matches LDoE's buildable area in survivor lengths (about 13×13 of our 8-stud cells). Debris clearing is a later sink.

### Gathering, survival, economy (S1 now; S1b for UI)
30. **Home nodes are finite and never respawn** (LDoE). Seed each plot with an LDoE-size set (about 20 pines, 7 stone, 5 scrap, 7 berry, 20 fiber/reed, plus branches and loose stones). Repeat farming happens on Fog Runs. This **supersedes** the slow-regrow instruction.
31. **AUTO (Q) is free everywhere** and also auto-attacks (in S2). The **paid AUTO** is on the location panel: AUTO via ad (13+, 10 a day) and AUTO via Rations or premium, which **clear the location into the inbox without entering it** (S2).
32. **Night readability:** blue moonlight ambient, a survivor rim light, and warm lantern pools. Side by side with rec6_04 (S1 now).
33. **Survival:** −1 every 10 s for both meters, 2 HP/s at 0, a warning at 20. **Food never restores Energy** (one rare Energy drink remains). Death resets every meter to full.
34. **Tools can sit in weapon slots** as weak melee.
35. **Wildlife:** a fleeing deer and an aggressive wolf in Light fog, giving meat and hide → leather (S2).
36. **Garden Bed and Rain Catcher** (S3).
37. **Fog-exposure meter** in Dense and Black, with a gear resistance stat, so armor sets gate the tiers (S2).

### Map and travel (S2)
38. **Energy:** cap 200, +1 every 5 min. Run costs 15/22/33 by tier; Walk takes 12/19/29 min. Energy shows **on the map**, with a regen countdown and a Rations "+" counter.
39. **Location panel:**
    - art, name, skulls, the rule line, a Main loot row, and a Possible loot grid with rarity frames
    - **AUTO buttons**
    - an **ENTER** bracket on the current location
    - **round Run/Walk buttons on the map** next to the pin
    - timed pins with countdowns
40. **Travel bonus:** TAKE costs one item per rewarded ad; TAKE ALL costs Rations or premium. Free players see the grid.
41. **Rations:** a consumable earned from quests and the pass, sold in Currency, and shown on the map. It pays for AUTO and bonus loot, and refills Energy.
42. **Exit zones:** a green ground overlay plus a green minimap arc. **Travel state:** a "CURRENT LOCATION / DESTINATION" bar.
43. **Map pop-ups** with event cards ("Show me" pans to the pin) and one offer card during the Run load. **Airdrops** spawn as Energy falls below 140, 80 and 20 (a guarded crate). A **"Hurry"** button on Walk spends Energy. **Region gates:** repair the tower with a parts checklist before Dense and Black. An **arrival title card**.

### Locations, combat, death (S2)
44. **Sneak (Ctrl):** slower and quieter, a 3× melee backstab, and a smaller detection radius. It breaks on loot or harvest.
45. Corpses and containers **reuse the two-pane storage screen**. On a weapon break, **auto-switch** to the other slot, or fists, with a toast. **Location quests** pin to the top of the tracker in teal.
46. **Death recovery** on the death screen: "Recover all" (rewarded ad, once a day) and "Recover all" (premium), delivered to the inbox. A **Reanimator** item auto-revives and is sold in the shop. A craftable **Doormat** sets the respawn point. **Death-milestone gifts** go to the inbox.
47. **Haven NPC hub** with traders and a contract board, scheduled for M2.

### Quests and meta (S1b for the tracker; S3 for screens)
48. **Rename "Survivor's Path"**, which is LDoE's own name, to **"Ember Trail"** everywhere: UI, data IDs and docs.
49. **Blueprints unlock through quests, not levels.** Only the hatchet, pick, satchel and small crate start unlocked. Level gates only locations. Lock text names the quest.
50. **Tracker:** completes a quest automatically on its last objective (reward pop → inbox → next quest), and shows 3 quests with their next step. Clicking opens the quest screen.
51. **Quest screen (S3):** rec5 layout, with chapter cards, numbered quests, free (blue) and premium (gold) rewards, TAKE ALL and BUY ULTRA.
52. **Skills (S3):** level-up offers "pick 1 of 3", with a paid reroll; about 12 passives to start. Plus **achievements** with toasts, a **daily contract board**, and one **event track**.

### Shop and social (S3)
53. **Shop:** rec8 layout, with a banner carousel and countdown, scrolling cards, the bottom tab icons with badges, INBOX and VIP at bottom-left, and balances at bottom-right. Cards carry a **VIP-points** badge.
54. **VIP is a points ladder:** every purchase adds points across 10 levels plus Prestige. Perks include travel-Energy discounts, faster benches, more XP and automatic corpse loot. A Roblox subscription grants points monthly.
55. **Social screen** from the HUD bar: Friends (online, invite to party or crew), Crew, and Guild (list, filter, Open/Request, members x/50).

### Onboarding (S1b)
56. **Every new plot starts with a damaged starter shelter:** a floor, a few walls, a cold Hearth and a crate. It also gets a **wrecked vehicle frame** with a parts checklist screen (have/need, FILL UP, FINALIZE) as the visible long-term goal, using the LDoE pattern.
57. **Quest 1 includes a Hollow kill and looting its body.** Quest 6 sends you to a one-time **crash site**.
58. **Loading screen:** painted key art plus a version string. A **daily food and water gift** goes to the inbox until level 10.

## Deliberate deviations kept (each in DECISIONS.md)
- shared multiplayer lobbies with PvP by fog tier
- raids, crews and guilds
- the Neighbourhood
- the light and Fog theme, with night tower defense
- jumping without climbing
- zoom (clamped in lobbies)
- three build tiers
- drag-to-paint building
- crafting draws from home storage and the inbox
- the locked stash
- Vaults in M4
- companions in M3
- leaving home by walking off the edge
- death-drop rules set by fog tier
- offline outposts are never attacked by night assaults

## The audit table

The audit's full evidence table (with frame citations) is at `docs/research/ldoe-parity-audit-2026-11-08.md`.
