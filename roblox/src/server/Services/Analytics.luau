--!strict
--[[
	Analytics: thin wrapper around Roblox AnalyticsService (ARCHITECTURE.md §3).

	Services log economy, progression and funnel events through here so event names
	and parameters stay consistent. Every call is protected: analytics must never
	break gameplay.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

export type Flow = "source" | "sink"
export type ProgressionStatus = "start" | "complete" | "fail"

-- Up to three free-form values, sent as CustomField01..03 for dashboard breakdowns.
export type Fields = { string }

-- Security events are capped per player and remote to keep exploit spam out of analytics.
local SECURITY_LOG_INTERVAL = 60

local lastSecurityLog: { [Player]: { [string]: number } } = {}

local function customFields(fields: Fields?): { [string]: any }?
	if fields == nil then
		return nil
	end
	local result: { [string]: any } = {}
	for index = 1, math.min(#fields, 3) do
		result[`CustomField0{index}`] = fields[index]
	end
	return result
end

local function protected(name: string, fn: () -> ...any)
	local ok, err = pcall(fn)
	if not ok then
		warn(`Analytics.{name} failed: {err}`)
	end
end

--[[
	Economy event. `currency` is a resource or currency name such as "Energy" or
	"item.wood"; `transactionType` is an Enum.AnalyticsEconomyTransactionType name
	(for example "Gameplay", "IAP", "Shop") or a custom string.
]]
function Analytics.economy(
	player: Player,
	flow: Flow,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string?,
	fields: Fields?
)
	protected("economy", function()
		local flowType = if flow == "source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			currency,
			amount,
			endingBalance,
			transactionType,
			itemSku,
			customFields(fields)
		)
	end)
end

-- Progression event, e.g. Analytics.progression(player, "PlayerLevel", "complete", 3).
function Analytics.progression(
	player: Player,
	path: string,
	status: ProgressionStatus,
	level: number,
	levelName: string?,
	fields: Fields?
)
	protected("progression", function()
		local progressionType = if status == "start"
			then Enum.AnalyticsProgressionType.Start
			elseif status == "complete" then Enum.AnalyticsProgressionType.Complete
			else Enum.AnalyticsProgressionType.Fail
		AnalyticsService:LogProgressionEvent(player, path, progressionType, level, levelName, customFields(fields))
	end)
end

-- One step of a funnel (onboarding, shop flow, ...). Steps start at 1.
function Analytics.funnelStep(
	player: Player,
	funnel: string,
	step: number,
	stepName: string?,
	sessionId: string?,
	fields: Fields?
)
	protected("funnelStep", function()
		if funnel == "Onboarding" then
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields(fields))
		else
			AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, stepName, customFields(fields))
		end
	end)
end

-- Any other event worth a chart.
function Analytics.custom(player: Player, eventName: string, value: number?, fields: Fields?)
	protected("custom", function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, customFields(fields))
	end)
end

-- A rejected remote request (rate limit or validation). Logged at most once per
-- player and remote per SECURITY_LOG_INTERVAL seconds.
function Analytics.securityViolation(player: Player, remoteName: string, reason: string)
	local perPlayer = lastSecurityLog[player]
	if perPlayer == nil then
		perPlayer = {}
		lastSecurityLog[player] = perPlayer
	end
	local now = os.clock()
	local last = perPlayer[remoteName]
	if last and now - last < SECURITY_LOG_INTERVAL then
		return
	end
	perPlayer[remoteName] = now

	if RunService:IsStudio() then
		warn(`[Net] rejected {remoteName} from {player.Name}: {reason}`)
	end
	Analytics.custom(player, "SecurityViolation", 1, { remoteName, string.sub(reason, 1, 50) })
end

function Analytics.start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSecurityLog[player] = nil
	end)
end

return Analytics
