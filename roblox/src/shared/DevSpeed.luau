--!strict
--[[
	DevSpeed: a Studio-only multiplier for pacing (timers, yields, regen and XP), so
	playtests don't wait on the long free grind (DECISIONS 2026-11-08). The value is
	Tuning.devSpeed; on any live server it is forced to 1, whatever the data says.

	Data/init applies it to the content bundle before deep-freezing it, so server and
	client read the same scaled numbers.
]]

local Types = require("./Types")

local DevSpeed = {}

-- The multiplier for this server: Tuning.devSpeed in Studio (at least 1), else 1.
function DevSpeed.resolve(configured: number?, isStudio: boolean): number
	if not isStudio then
		return 1
	end
	return math.max(1, configured or 1)
end

function DevSpeed.factor(content: Types.Content): number
	-- Outside Roblox (Lune specs) there is no `game`: that counts as not Studio.
	local ok, studio = pcall(function(): boolean
		return game:GetService("RunService"):IsStudio()
	end)
	return DevSpeed.resolve(content.Tuning.devSpeed, ok and studio == true)
end

--[[
	Scales the content in place by `factor`: craft and respawn timers and energy regen
	divide by it, gathering yields and XP per hit multiply by it. Runs once per content
	table; a factor of 1 changes nothing.
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
		node.xpPerHit = math.floor(node.xpPerHit * factor)
		for _, yield in node.yields do
			yield.perHit = math.floor(yield.perHit * factor)
		end
	end
	content.Tuning.energy.secondsPerPoint = math.max(1, math.floor(content.Tuning.energy.secondsPerPoint / factor))
end

return DevSpeed
