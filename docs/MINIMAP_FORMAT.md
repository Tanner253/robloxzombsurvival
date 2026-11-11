# Minimap map format (MapData v1)

The minimap (checklist 8.11) and the full-screen map draw any map written in this format. It is
defined in `roblox/src/shared/Domain/MapData.luau` (types, `MapData.validate`). The Neighbourhood is
generated from Tuning by `Domain/NeighbourhoodMap.luau`. Each Fog Run location supplies its own.

## Where a location's map goes

1. Write `roblox/src/shared/Data/Maps/<Location>.luau` that returns one `MapData.Map`.
2. List it in `roblox/src/shared/Data/Maps/init.luau`, keyed by location id:
   `["loc.pine_hollow"] = require("@self/PineHollow"),`
3. `lune run tests/run.luau` validates every listed map (spec "every supplied location map is valid").

Keep the paths and footprints in that shared module and have the layout module
(`server/FogRuns/Maps/<Location>`) build from the same tables, so the picture and the ground never
drift apart. Until a location is listed, the client draws it from what it can see of the built map
(terrain colours, roofs with `Interior`, `EO_Canopy` trees and `EO_RunExit` exits).

## Coordinates

- Studs on the ground plane, map-local: **+X east, +Z south** (north is -Z), the same frame as the
  layout modules (`Builder.at(ctx, x, z)`). The client adds the map folder's `Origin` attribute.
- A `yaw` is in degrees, Roblox's: the footprint turned by `CFrame.Angles(0, math.rad(yaw), 0)`.
- The minimap turns the picture so the camera's view is up; write maps north-up as usual.

## The map

| Field | Type | Meaning |
|---|---|---|
| `format` | `1` | `MapData.FORMAT` |
| `id`, `name` | string | the location id and its display name |
| `bounds` | `{x0, z0, x1, z1}` | the drawn area: the playable area plus its surroundings |
| `play` | bounds, optional | the playable area; past it the `edge` kind is painted, fading in |
| `ground` | zone kind | painted under everything (`grass` is the Fog map's forest-floor tile) |
| `edge` | zone kind, optional | what lies past `play` (`forest`, `dry`, `fog`) |
| `zones` | list | ground patches, drawn in order (later on top) |
| `paths` | list | roads, paths, trails, rivers, rails |
| `buildings` | list | footprints (rotated rectangles) |
| `fences` | list | fence and wall polylines |
| `trees` | list of points, optional | single trees (canopy sprites) |
| `points` | list | named points: exits, the spawn, places worth a label |

**Zone**: `{ kind, shape = "rect" | "ellipse" | "poly", x, z, w, d, yaw?, round?, points?, soft? }`.
`x, z` is the centre; `w` the width along X and `d` the depth along Z (an ellipse's diameters).
`round` is a rect's corner radius. `poly` takes `points` (3 or more) instead. `soft = true` paints a
ragged, cloudy edge. Kinds: `grass meadow dry earth mud plaza yard rock sand water forest fog`.
`forest` fills the shape with painted tree clusters; `fog` is a wash with drifting clouds; soft
`water` uses the painted water blob.

**Path**: `{ kind = "road" | "path" | "trail" | "river" | "rail", width, points }`, 2 or more points.

**Building**: `{ kind?, x, z, w, d, yaw?, label? }`. Kinds: `house barn shed stall ruin tent container tower`.

**Fence**: `{ kind = "fence" | "wall" | "palisade" | "rail", points }`.

**Point**: `{ id, kind, x, z, label?, glyph? }`. Kinds: `exit trailhead poi plot fire npc spawn`.
Ids are unique. An `exit` uses the extraction `PointId` as its id. Exits and the Trailhead stay on
the minimap's rim when they're off it. Live things (Hollow, containers, bags, players) are not map
data: the client places them every frame.

## Example

```luau
--!strict
local MapData = require("../../Domain/MapData")

local PineHollow: MapData.Map = {
	format = MapData.FORMAT,
	id = "loc.pine_hollow",
	name = "Pine Hollow",
	bounds = { x0 = -200, z0 = -200, x1 = 200, z1 = 200 },
	play = { x0 = -125, z0 = -125, x1 = 125, z1 = 125 },
	ground = "grass",
	edge = "forest",
	zones = {
		{ kind = "earth", shape = "rect", x = -4, z = -22, w = 70, d = 54, round = 10, soft = true }, -- the yard
		{ kind = "water", shape = "ellipse", x = -74, z = 64, w = 46, d = 34, soft = true }, -- the pond
		{ kind = "forest", shape = "rect", x = 78, z = 72, w = 68, d = 64 }, -- the orchard
	},
	paths = {
		{ kind = "trail", width = 8, points = { { x = 4, z = 190 }, { x = -6, z = 4 }, { x = -24, z = -190 } } },
	},
	buildings = {
		{ kind = "house", x = -30, z = -40, w = 22, d = 16, yaw = 0, label = "Farmhouse" },
		{ kind = "barn", x = 24, z = -30, w = 28, d = 20, yaw = 90 },
	},
	fences = { { kind = "rail", points = { { x = -40, z = 0 }, { x = 30, z = 0 } } } },
	trees = { { x = 60, z = -80 }, { x = 66, z = -92 } },
	points = {
		{ id = "north", kind = "exit", x = -24, z = -125, label = "North trail" },
		{ id = "cottage", kind = "poi", x = -84, z = -82, label = "Burnt cottage" },
	},
}

return PineHollow
```
