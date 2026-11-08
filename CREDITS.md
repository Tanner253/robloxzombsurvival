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
