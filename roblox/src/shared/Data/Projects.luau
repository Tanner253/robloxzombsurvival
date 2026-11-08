--!strict
--[[
	Long-term build goals shown on the plot (LDOE_PARITY #56), keyed by permanent ID.

	The wrecked hauler sits at the edge of every new plot, LDoE's broken-chopper pattern:
	a visible goal from minute one. Its parts checklist (have/need per part, FILL UP,
	FINALIZE) takes parts from the home pool; Fog Runs are where most of them come from.
	Driving it arrives with vehicles (M2); finalizing restores it.
]]

local Types = require("../Types")

local Projects: { [string]: Types.ProjectDef } = {
	["project.hauler"] = {
		id = "project.hauler",
		name = "Wrecked Hauler",
		description = "A rusted cargo hauler, stripped to its frame. Bring it the parts and it runs again.",
		parts = {
			{ itemId = "item.scrap_plate", count = 20 },
			{ itemId = "item.rivets", count = 16 },
			{ itemId = "item.coil_spring", count = 6 },
			{ itemId = "item.brass_gear", count = 4 },
			{ itemId = "item.seized_motor", count = 1 },
			{ itemId = "item.rope", count = 10 },
		},
		rewards = { { itemId = "item.ember_tonic", count = 2 } },
	},
}

return Projects
