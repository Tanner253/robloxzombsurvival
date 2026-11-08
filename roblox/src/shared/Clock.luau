--!strict
--[[
	Clock: the world's time of day, worked out from server time so every client
	(and the server) agrees without replicating anything.

	A cycle lasts Tuning.dayNight.cycleSeconds. Day (06:00-19:30) takes
	`dayFraction` of it and night the rest, so nights are short and tense (LDoE
	keeps nights brief too). `daylight` eases 0..1 through dawn (05:00-07:00) and
	dusk (17:30-19:30) for lighting and ambience.
]]

local Content = require("./Data")

local Clock = {}

local DAY_START, DAY_END = 6, 19.5 -- hours
local DAY_HOURS = DAY_END - DAY_START
local NIGHT_HOURS = 24 - DAY_HOURS

-- The hour (0 <= h < 24) at a server time.
function Clock.hoursAt(serverTime: number): number
	local tuning = Content.Tuning.dayNight
	local f = ((serverTime / tuning.cycleSeconds) + tuning.offset) % 1
	local day = tuning.dayFraction
	local hours = if f < day then DAY_START + f / day * DAY_HOURS else DAY_END + (f - day) / (1 - day) * NIGHT_HOURS
	return hours % 24
end

-- 1 in full day, 0 at night, eased through dawn and dusk.
function Clock.daylight(hours: number): number
	local t = hours % 24
	local x: number
	if t >= 7 and t <= 17.5 then
		return 1
	elseif t <= 5 or t >= 19.5 then
		return 0
	elseif t < 12 then
		x = (t - 5) / 2
	else
		x = (19.5 - t) / 2
	end
	return x * x * (3 - 2 * x)
end

-- The sun's ClockTime for an hour. Roblox's sun sets at its own pace, which would
-- darken the world before our dusk begins; this keeps the sun high through the day
-- (08:00-16:00 sun for 07:00-17:30) and lays sunset and sunrise exactly over the
-- eased dusk and dawn, with the moon up all night.
local SUN_KEYS = {
	{ 0, 0 },
	{ 5, 4.5 },
	{ 7, 8 },
	{ 17.5, 16 },
	{ 18.8, 17.4 },
	{ 19.5, 19.6 },
	{ 24, 24 },
}
function Clock.sunTime(hours: number): number
	local t = hours % 24
	for index = 2, #SUN_KEYS do
		local a, b = SUN_KEYS[index - 1], SUN_KEYS[index]
		if t <= b[1] then
			local f = (t - a[1]) / (b[1] - a[1])
			return (a[2] + (b[2] - a[2]) * f) % 24
		end
	end
	return t
end

-- "14:35" for an hour value.
function Clock.label(hours: number): string
	local h = math.floor(hours) % 24
	local m = math.floor((hours % 1) * 60)
	return string.format("%02d:%02d", h, m)
end

return Clock
