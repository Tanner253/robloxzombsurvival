--!strict
--[[
	FogRegions: the Fog map SCREEN as data (GAME_DESIGN "The Fog map screen: generated
	from data"). The client composes the map from this: terrain zones, rivers, roads,
	trails and rails drawn as paths, landmark pictures, woods and fog, then the location
	pins. Adding a location, road or region means adding data here, with no re-painting.

	Every coordinate is a share of the map canvas (0..1 across, 0..1 down). Sizes are
	shares of the canvas width (so pictures keep their aspect at any screen shape).
	Picture keys name entries in Art.fogMap.sprites.
]]

local FogRegions = {}

local V2 = Vector2.new

export type Zone = {
	kind: "meadow" | "rock" | "water",
	at: Vector2,
	size: Vector2, -- width and height, shares of the canvas width
	rotation: number?,
}

export type Path = {
	kind: "road" | "trail" | "river" | "rail",
	points: { Vector2 },
}

export type Landmark = {
	sprite: string,
	at: Vector2,
	width: number, -- share of the canvas width
	rotation: number?,
}

export type Woods = {
	at: Vector2, -- the patch's centre
	size: Vector2, -- shares of the canvas
	count: number, -- tree clusters scattered in it
}

export type Pin = {
	locationId: string,
	at: Vector2,
	event: boolean?, -- a timed or rotating location: its pin shows a countdown
}

export type Region = {
	id: string,
	name: string,
	home: Vector2, -- the player's outpost
	zones: { Zone },
	paths: { Path },
	landmarks: { Landmark },
	woods: { Woods },
	fog: { Vector2 }, -- drifting fog banks (decoration)
	pins: { Pin },
	-- Where neighbours' outposts sit (M2 raids, Domain/Neighbours): each shown neighbour
	-- takes the same slot every time.
	neighbourSlots: { Vector2 },
}

FogRegions.list = {
	{
		id = "region.emberwood",
		name = "Emberwood Valley",
		home = V2(0.485, 0.74),
		zones = {
			{ kind = "meadow", at = V2(0.17, 0.33), size = V2(0.26, 0.2) },
			{ kind = "meadow", at = V2(0.4, 0.5), size = V2(0.3, 0.2), rotation = 12 },
			{ kind = "meadow", at = V2(0.5, 0.7), size = V2(0.2, 0.13) },
			{ kind = "meadow", at = V2(0.29, 0.43), size = V2(0.18, 0.11) },
			{ kind = "meadow", at = V2(0.63, 0.42), size = V2(0.16, 0.12), rotation = -10 },
			{ kind = "meadow", at = V2(0.12, 0.6), size = V2(0.16, 0.14) },
			{ kind = "meadow", at = V2(0.3, 0.62), size = V2(0.14, 0.1) },
			{ kind = "rock", at = V2(0.85, 0.28), size = V2(0.3, 0.25) },
			{ kind = "rock", at = V2(0.95, 0.62), size = V2(0.12, 0.18) },
			{ kind = "rock", at = V2(0.72, 0.64), size = V2(0.09, 0.08) },
			{ kind = "water", at = V2(0.085, 0.53), size = V2(0.05, 0.04) },
		},
		paths = {
			{
				kind = "river",
				points = {
					V2(0.3, -0.02),
					V2(0.31, 0.12),
					V2(0.39, 0.29),
					V2(0.36, 0.44),
					V2(0.27, 0.56),
					V2(0.14, 0.66),
					V2(0.04, 0.74),
					V2(-0.02, 0.8),
				},
			},
			{
				kind = "road",
				points = {
					V2(-0.02, 0.1),
					V2(0.24, 0.14),
					V2(0.45, 0.22),
					V2(0.62, 0.3),
					V2(0.78, 0.36),
					V2(1.02, 0.42),
				},
			},
			{
				kind = "road",
				points = { V2(0.485, 0.74), V2(0.47, 0.6), V2(0.46, 0.45), V2(0.48, 0.33), V2(0.49, 0.24) },
			},
			{ kind = "trail", points = { V2(0.465, 0.53), V2(0.33, 0.49), V2(0.22, 0.43), V2(0.17, 0.33) } },
			{ kind = "trail", points = { V2(0.47, 0.66), V2(0.38, 0.64), V2(0.29, 0.62) } },
			{ kind = "rail", points = { V2(0.66, 0.6), V2(0.78, 0.53), V2(0.88, 0.48), V2(1.02, 0.41) } },
		},
		landmarks = {
			{ sprite = "farm", at = V2(0.15, 0.25), width = 0.2 },
			{ sprite = "town", at = V2(0.5, 0.15), width = 0.3 },
			{ sprite = "quarry", at = V2(0.85, 0.25), width = 0.28 },
			{ sprite = "railcars", at = V2(0.86, 0.47), width = 0.15, rotation = -12 },
			{ sprite = "outpost", at = V2(0.485, 0.77), width = 0.16 },
			{ sprite = "caravan", at = V2(0.29, 0.585), width = 0.15 },
			{ sprite = "cliff", at = V2(0.94, 0.66), width = 0.1 },
			{ sprite = "cliff", at = V2(0.72, 0.66), width = 0.08 },
		},
		woods = {
			{ at = V2(0.12, 0.85), size = V2(0.26, 0.24), count = 12 },
			{ at = V2(0.35, 0.86), size = V2(0.2, 0.2), count = 9 },
			{ at = V2(0.65, 0.84), size = V2(0.24, 0.24), count = 11 },
			{ at = V2(0.88, 0.86), size = V2(0.24, 0.24), count = 11 },
			{ at = V2(0.6, 0.55), size = V2(0.16, 0.14), count = 6 },
			{ at = V2(0.24, 0.07), size = V2(0.2, 0.12), count = 6 },
			{ at = V2(0.68, 0.12), size = V2(0.14, 0.14), count = 5 },
			{ at = V2(0.04, 0.38), size = V2(0.08, 0.3), count = 6 },
			{ at = V2(0.33, 0.3), size = V2(0.1, 0.12), count = 4 },
			{ at = V2(0.75, 0.47), size = V2(0.08, 0.12), count = 4 },
			{ at = V2(0.2, 0.52), size = V2(0.1, 0.08), count = 3 },
		},
		fog = { V2(0.96, 0.06), V2(0.02, 0.44), V2(0.6, 0.92), V2(0.32, 0.96), V2(0.98, 0.9), V2(0.7, 0.56) },
		pins = {
			{ locationId = "loc.pine_hollow", at = V2(0.17, 0.3) },
			{ locationId = "loc.sunken_quarry", at = V2(0.5, 0.21) },
			{ locationId = "loc.ashfall_depot", at = V2(0.85, 0.33) },
			{ locationId = "loc.stranded_caravan", at = V2(0.29, 0.62), event = true },
		},
		neighbourSlots = {
			V2(0.2, 0.84),
			V2(0.34, 0.92),
			V2(0.63, 0.9),
			V2(0.76, 0.8),
			V2(0.9, 0.9),
			V2(0.1, 0.74),
			V2(0.64, 0.66),
			V2(0.06, 0.92),
		},
	},
} :: { Region }

-- The region a location's pin belongs to, and the pin.
function FogRegions.pinOf(locationId: string): (Region?, Pin?)
	for _, region in FogRegions.list do
		for _, pin in region.pins do
			if pin.locationId == locationId then
				return region, pin
			end
		end
	end
	return nil, nil
end

-- The region shown (one for M1; later regions extend the canvas).
function FogRegions.current(): Region
	return FogRegions.list[1]
end

return FogRegions
