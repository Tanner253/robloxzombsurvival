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
				work = '"animated pistol" (the Duty Pistol)',
				by = "DJMaesen",
				license = "CC-BY-4.0",
				source = "sketchfab.com/3d-models/animated-pistol-bd896167e7ca44f19597d3afe6a8d83f",
			},
			{
				work = '"Benelli M3 Tactical" (the Pump Shotgun)',
				by = "Amapsis",
				license = "CC-BY-4.0",
				source = "sketchfab.com/3d-models/benelli-m3-tactical-1eaea0239fdf43ad92eb276fbf9c60dd",
			},
			{
				work = '"Bolt Action Rifle 7.62" (the Hunting Rifle)',
				by = "Mateusz Sadek",
				license = "CC0",
				source = "polyhaven.com/a/bolt_action_rifle_7_62",
			},
			{
				work = '"FPS AK-74m animations" (the Assault Rifle)',
				by = "Cransh",
				license = "CC-BY-4.0",
				source = "sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14",
			},
			{
				work = '"Barrett-M82 (Optimized)" (the Anti-Materiel Rifle)',
				by = "Gintoki1234",
				license = "CC-BY-4.0",
				source = "sketchfab.com/3d-models/barrett-m82-optimized-af16e974a47e463989311bcda6f51f87",
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
			{
				work = '"Universal Animation Library" (combat animations: reload, hit, fall)',
				by = "Quaternius",
				license = "CC0",
				source = "quaternius.com",
			},
		},
	},
}

return table.freeze(Credits)
