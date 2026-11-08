# LDoE screen recordings: notes

These are the developer's own recordings of Last Day on Earth (v1.53, Halloween season, player level 115). The frames come from five recordings: `rec1_*` through `rec5_*`, plus a `*_sheet.jpg` overview grid for each recording.
**Use them for mechanics, UX flow and monetization patterns only.** Never copy their art, names or exact UI look.

## What each recording shows

| Rec | Content |
|---|---|
| 1 | Base at night from the angled top-down camera, HUD layout, inventory and Recycler, the "Unknown Box" random reward, an event popup (fishing spot), world map location panels (loot preview, Run/Walk), Bunker panel with refresh rule |
| 2 | Loading screen (season art), inventory and storage box, the **shop** (Chopper Parts Pack $19.99, Rack storage $19.99 at -85%, Storages $5.99), the Season / Settlement store (Substation $9.99, Water Pump $14.99), **build mode** (grid, ghost walls, Foundations/Walls/Doors/Windows tabs, cost shown, "can be improved") |
| 3 | Map travel route (red arrow path), the **Pine Bushes** location panel ("items left here are lost when you exit"), **AUTO (watch an ad, 10/10) / AUTO 2 (coins)** auto-gather, a travel popup offer with a 22h timer, a **travel BONUS loot** panel ("TAKE" with an ad icon 10/10, "TAKE ALL (2)"), night forest gathering (+XP popups, a context action button that switches hand/axe), wolf fight and loot |
| 4 | Settlement hub with NPCs and a speech bubble, base edit mode (rotate arrows, floor-layer toggle), **Chopper** (luggage, fuel 4/200), **ATV blueprint** (part counts like /250, /200, **"FILL UP" with coins**, FINALIZE), Stonecutter's Table and Workbench recipes (single input → output), a trunk full of food |
| 5 | **Survivor's Path**: chapter quest chains (Laboratory, Heavy Machinery, Radiation Protection, Expeditions, New Home, Engineering Networks, Air Support), each with item rewards, plus **"TAKE ALL (52)" and "BUY ULTRA"** (a premium reward track on the questline) |

## How the game works (confirmed by the footage)

- **Map loop:** choose a location, see its main and possible loot, then pay Energy to Run or spend real time to Walk. Resource locations **reset when you leave**, and anything left behind is lost, which creates carry-capacity pressure.
- **Inventory pressure everywhere:** a small set of pockets plus a backpack. Storage boxes, trunks and racks at home. The vehicle has its own luggage.
- **Stations are simple converters:** one input produces one output, with a station level and an "All recipes" list. The upgrade arrow is always visible.
- **Long goals are visible part checklists:** vehicles need hundreds of parts each. Progress stays visible and slow.
- **The questline is the spine:** chapters unlock systems and hand out rewards, and a premium row sits next to every free row.
- **Constant small rewards:** XP popups, loot panels, NEW badges on every menu icon.

## How it gets you to spend (the conversion levers)

1. **Energy** (200 cap, with a "+" always next to it): Running is fast but costs Energy; Walking is free but slow.
2. **Auto-gather:** for an ad (limited per day) or for coins. The tedium becomes the product.
3. **Travel bonus loot:** take it by watching an ad, or take all of it.
4. **"FILL UP" on blueprints:** pay coins to complete the missing parts on a vehicle checklist.
5. **Premium questline row ("BUY ULTRA"):** next to every free reward you see the premium one you're missing.
6. **Storage scarcity, then storage packs:** discounted racks and boxes in the shop.
7. **Part packs for long goals** (e.g. a chopper parts pack).
8. **Season store of settlement buildings** at "-50% / -85%" anchored prices.
9. **Timed popup offers** with countdowns (22h) triggered during travel.
10. **The coin balance with "+" is visible in every inventory screen.**
11. **Rewarded ads as a soft currency** for players who don't pay (10 per day caps).

## Our adaptation (feeds GAME_DESIGN.md)

**Adopt the levers and price them fairly:**
- Energy with Run/Walk
- auto-gather (rewarded ad on Roblox for 13+, or a pass/product)
- bonus travel loot through a rewarded ad
- "fill up" parts with premium currency
- a premium track on the questline
- storage and part packs
- timed offers (sparingly)

**Do better than LDoE:**
- more generous caps
- honest discount anchors (no fake "-85%")
- never sell shields or raid immunity
- purchases land in the locked stash
- no paid random boxes
