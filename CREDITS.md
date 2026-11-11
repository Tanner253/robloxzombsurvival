# Credits

Everything the game's **Credits** panel (Settings, then Credits) shows comes from this file.

To add a credit:
1. Add a row to the right section's table. Add a new `## Section` with the same four columns if none fits.
2. From `roblox/`, run `lune run tools/credits.luau`. It rewrites `src/shared/Data/Credits.luau`.
3. Commit both files. The Lune spec `Credits` fails when they disagree.

What to credit:
- Every CC-BY asset we use, with its author and licence.
- Open-source code we ship.

Our own art (generated for this game) and Roblox's built-in content need no row.

Columns: **Work** is what we use. **By** is the author or owner. **License** is the short licence name. **Source** is where it came from (a URL or a repository path).

## Open-source code

| Work | By | License | Source |
|---|---|---|---|
| React Luau (react, react-roblox and their packages) | Roblox Corporation | MIT | github.com/jsdotlua/react-lua |
| Promise | Eryn L. K. | MIT | github.com/jsdotlua/promise |
| GoodSignal | Mark Langen (stravant) | MIT | github.com/stravant/goodsignal |
| ProfileStore | MAD STUDIO (loleris) | Apache 2.0 | github.com/MadStudioRoblox/ProfileStore |

## Models

| Work | By | License | Source |
|---|---|---|---|
| "sawnoffs Animated" (the Scrap Shotgun) | DJMaesen | CC-BY-4.0 | sketchfab.com/3d-models/sawnoffs-animated-001bec4277414a62bb8ad9b2a1a7abcb |
| "Service Pistol" (the Worn Pistol) | Mateusz Sadek | CC0 | polyhaven.com/a/service_pistol |
| "Machete" (the Machete) | Ulan Cabanilla | CC0 | polyhaven.com/a/machete |
| "Crowbar 01" (the Tire Iron) | Alexander Otterbeck | CC0 | polyhaven.com/a/crowbar_01 |
| "Universal Animation Library" (combat animations: gun aim, shot, reload, hit, fall) | Quaternius | CC0 | quaternius.com |

This work is based on "sawnoffs Animated"
(https://sketchfab.com/3d-models/sawnoffs-animated-001bec4277414a62bb8ad9b2a1a7abcb) by DJMaesen
(https://sketchfab.com/bumstrum) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/).
CC0 assets are listed as a courtesy.

The models came through the developer's Zona repository (`assets-src/models`, see its CREDITS.md),
converted with glTF-Transform. Everything else is original to Ember Outpost (Higgsfield and Roblox
Studio generations on the owner's account) or from Roblox's own audio library.
