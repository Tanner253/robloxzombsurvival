--!strict
--[[
	Flags: feature switches for work that is built but not yet verified, or that waits on
	another slice (PLAYER_EXPERIENCE_CHECKLIST §0: nothing visible below grade A, so a
	feature whose screens or art haven't passed their Studio check stays hidden).

	`Flags.DEFAULTS` is what live servers run. In Studio a worker can flip any flag for a
	playtest with a Workspace boolean attribute named "Flag_<name>" (for example
	Flag_ldoeHud = true); live servers ignore those attributes.

	S1b (LDoE parity, home):
	- ldoeHud: the LDoE HUD (LDOE_PARITY #1-12) replaces the slice-1 HUD.
	- ldoeInventory: the two-pane inventory and storage screens (#13-17).
	- ldoeStations: the converter station screen (#18-23).
	- ldoeBuild: build mode's tray, per-piece actions and hidden HUD (#25-28).
	- vehicleFrame: the wrecked vehicle frame on new plots and its parts screen (#56);
	  waits on its model passing the lineup gate.
	Other slices:
	- fogRuns: the Fog map, locations and the Hollow (S2). Quest objectives that need them
	  carry this flag and are left out while it is off.
]]

local Flags = {}

export type Name = "ldoeHud" | "ldoeInventory" | "ldoeStations" | "ldoeBuild" | "vehicleFrame" | "fogRuns"

Flags.DEFAULTS = {
	ldoeHud = false,
	ldoeInventory = false,
	-- The converter screen is the only one that matches the converter stations, so it
	-- is on; Phase B verifies it beside rec4_05.
	ldoeStations = true,
	ldoeBuild = false,
	vehicleFrame = false,
	fogRuns = false,
} :: { [string]: boolean }

-- Whether `name` is on, given the Studio state (pure, for Lune).
function Flags.resolve(name: string, isStudio: boolean, override: boolean?): boolean
	if isStudio and override ~= nil then
		return override
	end
	return Flags.DEFAULTS[name] == true
end

-- Whether `name` is on for this server or client.
function Flags.on(name: string): boolean
	-- Outside Roblox (Lune specs) there is no `game`: defaults apply.
	local ok, studio, override = pcall(function(): (boolean, boolean?)
		local attribute = workspace:GetAttribute(`Flag_{name}`)
		return game:GetService("RunService"):IsStudio(), if type(attribute) == "boolean" then attribute else nil
	end)
	return Flags.resolve(name, ok and studio == true, if ok then override else nil)
end

-- A lookup for pure modules that take flags as data (Domain/Quests).
function Flags.snapshot(): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for name in Flags.DEFAULTS do
		result[name] = Flags.on(name)
	end
	return result
end

return Flags
