--!strict
--[[
	DevSpeed: a Studio-only multiplier that compresses TIMERS (crafting and station jobs,
	node regrowth, energy regen) so automated playtests don't wait on real hours. It never
	touches yields, drops or XP: the economy a playtester sees is the real one
	(the developer, 2026-11-08: "getting way too many resources").

	Off by default (Tuning.devSpeed is 1). A worker turns it on explicitly by setting the
	Workspace attribute "DevSpeed" (a number) in Studio before pressing Play. Live servers
	always run at 1, whatever the data says. Data/init applies it to the content bundle
	before deep-freezing it, so server and client read the same scaled timers.
]]

local Types = require("./Types")

local DevSpeed = {}

-- The multiplier for this server: in Studio the Workspace "DevSpeed" attribute, else
-- Tuning.devSpeed (at least 1); on a live server always 1.
function DevSpeed.resolve(configured: number?, isStudio: boolean, override: number?): number
	if not isStudio then
		return 1
	end
	return math.max(1, override or configured or 1)
end

function DevSpeed.factor(content: Types.Content): number
	-- Outside Roblox (Lune specs) there is no `game`: that counts as not Studio.
	local ok, studio, override = pcall(function(): (boolean, number?)
		local attribute = workspace:GetAttribute("DevSpeed")
		return game:GetService("RunService"):IsStudio(), if type(attribute) == "number" then attribute else nil
	end)
	return DevSpeed.resolve(content.Tuning.devSpeed, ok and studio == true, if ok then override else nil)
end

--[[
	Compresses the content's timers in place by `factor`: craft times, node respawn and
	home regrowth, and energy regen divide by it. Yields, drops and XP never change.
	Runs once per content table; a factor of 1 changes nothing.
]]
function DevSpeed.apply(content: Types.Content, factor: number)
	local marked = content :: any
	if factor <= 1 or marked._devSpeedApplied then
		return
	end
	marked._devSpeedApplied = factor
	for _, recipe in content.Recipes do
		recipe.craftSeconds = math.max(1, math.floor(recipe.craftSeconds / factor))
	end
	for _, node in content.Nodes do
		node.respawnSeconds = math.max(1, math.floor(node.respawnSeconds / factor))
	end
	for _, span in content.Tuning.home.regrowHours do
		span.min /= factor
		span.max /= factor
	end
	content.Tuning.energy.secondsPerPoint = math.max(1, math.floor(content.Tuning.energy.secondsPerPoint / factor))
end

return DevSpeed
