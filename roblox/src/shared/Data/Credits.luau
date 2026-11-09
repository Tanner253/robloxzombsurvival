--!strict
--[[
	Credits: the third-party assets in the game, shown in Settings → Credits (a launch
	requirement for CC-BY; CC0 listed as a courtesy). Mirrors CREDITS.md at the repo root.
]]

export type Credit = {
	usedAs: string, -- our item or prop
	title: string,
	author: string,
	licence: string,
	source: string, -- where it came from (short, no URL scheme needed)
}

local Credits: { Credit } = {
	{
		usedAs = "Scrap Shotgun",
		title = "sawnoffs Animated",
		author = "DJMaesen",
		licence = "CC-BY-4.0",
		source = "sketchfab.com/bumstrum",
	},
	{
		usedAs = "Worn Pistol",
		title = "Service Pistol",
		author = "Mateusz Sadek",
		licence = "CC0",
		source = "polyhaven.com",
	},
	{
		usedAs = "Machete",
		title = "Machete",
		author = "Ulan Cabanilla",
		licence = "CC0",
		source = "polyhaven.com",
	},
}

return Credits
