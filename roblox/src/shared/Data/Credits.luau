--!strict
-- Generated from CREDITS.md by tools/credits.luau. Don't edit by hand: edit CREDITS.md
-- and run `lune run tools/credits.luau` from roblox/. The Credits panel reads this.

export type Row = { work: string, by: string, license: string, source: string }
export type Section = { title: string, rows: { Row } }

local Credits: { Section } = {
	{
		title = "Open-source code",
		rows = {
			{
				work = "React Luau (react, react-roblox and their packages)",
				by = "Roblox Corporation",
				license = "MIT",
				source = "github.com/jsdotlua/react-lua",
			},
			{ work = "Promise", by = "Eryn L. K.", license = "MIT", source = "github.com/jsdotlua/promise" },
			{
				work = "GoodSignal",
				by = "Mark Langen (stravant)",
				license = "MIT",
				source = "github.com/stravant/goodsignal",
			},
			{
				work = "ProfileStore",
				by = "MAD STUDIO (loleris)",
				license = "Apache 2.0",
				source = "github.com/MadStudioRoblox/ProfileStore",
			},
		},
	},
	{
		title = "Models",
		rows = {
			{
				work = '"sawnoffs Animated" (the Scrap Shotgun)',
				by = "DJMaesen",
				license = "CC-BY-4.0",
				source = "sketchfab.com/3d-models/sawnoffs-animated-001bec4277414a62bb8ad9b2a1a7abcb",
			},
			{
				work = '"Service Pistol" (the Worn Pistol)',
				by = "Mateusz Sadek",
				license = "CC0",
				source = "polyhaven.com/a/service_pistol",
			},
			{
				work = '"Machete" (the Machete)',
				by = "Ulan Cabanilla",
				license = "CC0",
				source = "polyhaven.com/a/machete",
			},
			{
				work = '"Crowbar 01" (the Tire Iron)',
				by = "Alexander Otterbeck",
				license = "CC0",
				source = "polyhaven.com/a/crowbar_01",
			},
		},
	},
}

return table.freeze(Credits)
