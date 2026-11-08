--!strict
--[[
	Gifts: the daily food and water gift (LDOE_PARITY #58). Pure.

	Below Tuning.dailyGift.untilLevel, the first time a player is online on a UTC day the
	gift goes into their inbox. Days are whole UTC days since the epoch; a clock that
	reads earlier than the last gift never grants twice.
]]

local Gifts = {}

local DAY = 24 * 60 * 60

function Gifts.day(now: number): number
	return now // DAY
end

-- Whether the gift is due now, and the day to record if it is.
function Gifts.due(lastDay: number, level: number, untilLevel: number, now: number): (boolean, number)
	local today = Gifts.day(now)
	return level < untilLevel and today > lastDay, today
end

return Gifts
