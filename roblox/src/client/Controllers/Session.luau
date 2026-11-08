--!strict
--[[
	Session: feeds the server's synced sections and effects into State.

	Listens to Sync and Fx first, then asks for a full snapshot with
	SyncRequest (retrying while the player's data is still loading), so nothing
	sent before the client was listening is missed. Notices and item rewards
	become toasts and reward pops here; other effects are re-broadcast through
	State.fx for the controllers that draw them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.Shared.Data)
local CraftingMath = require(ReplicatedStorage.Shared.Domain.Crafting)
local Players = game:GetService("Players")
local Net = require("../Net")
local Animations = require("./Animations")
local Sfx = require("../Sfx")
local State = require("../State")

local Session = {}

local SOURCE_SOUND: { [string]: string } = {
	station = "collect",
	craft = "reward",
	refund = "pickup",
}

local function onFx(kind: string, payload: any)
	if kind == "notice" then
		State.notify(payload.text, payload.tone)
		if payload.tone == "warn" then
			Sfx.play("uiError")
		end
	elseif kind == "items" then
		for _, stack in payload.items or {} do
			State.reward(stack.itemId, stack.count)
			State.markNew(stack.itemId)
		end
		Sfx.play(SOURCE_SOUND[payload.source] or "pickup")
	elseif kind == "gather" then
		for _, stack in payload.items or {} do
			State.reward(stack.itemId, stack.count)
			State.markNew(stack.itemId)
		end
	elseif kind == "inbox" then
		-- Something landed in the inbox (overflow, a reward): say so once.
		local names = {}
		for _, item in payload.items or {} do
			local def = Content.Items[item.itemId]
			table.insert(names, `{if def then def.name else item.itemId} x{item.count}`)
		end
		if #names > 0 then
			State.notify(`To your inbox: {table.concat(names, ", ")}`, "info")
		end
	elseif kind == "bagFull" then
		State.patch({ bagFullAt = os.clock() })
	elseif kind == "levelUp" then
		State.patch({ levelUp = { level = payload.level, rewards = payload.rewards or {}, at = os.clock() } })
		Sfx.play("levelUp")
	elseif kind == "consumed" then
		Animations.play(Players.LocalPlayer.Character, "eat")
		local def = Content.Items[payload.itemId]
		local drink = def and def.consume and (def.consume.thirst or 0) > (def.consume.hunger or 0)
		Sfx.play(if drink then "drink" else "eat")
	elseif kind == "fuelled" then
		Sfx.play("fuel")
	elseif kind == "craftStarted" then
		Sfx.play("craftStart")
	elseif kind == "stationUpgraded" then
		State.notify(`Station upgraded to level {payload.level}`, "good")
		Sfx.play("upgrade")
	end
	State.fx:Fire(kind, payload)
end

-- On the first stations sync of a session: say what finished while the player was
-- away (checklist 5.6), e.g. "Ready while you were away: Workbench (2), Campfire".
local announcedAway = false
local function announceAway(stations: any)
	if announcedAway or type(stations) ~= "table" then
		return
	end
	announcedAway = true
	local now = State.now()
	local parts: { string } = {}
	for _, station in stations do
		local def = Content.Stations[station.stationId]
		if def then
			local done = 0
			for _, job in CraftingMath.status(station, def, now) do
				if job.done then
					done += 1
				end
			end
			if done > 0 then
				table.insert(parts, if done > 1 then `{def.name} ({done})` else def.name)
			end
		end
	end
	if #parts > 0 then
		State.notify(`Ready while you were away: {table.concat(parts, ", ")}`, "good")
		Sfx.play("reward")
	end
end

function Session.start()
	Net.on("Sync", function(section: string, value: any)
		State.set(section, value)
		if section == "stations" then
			announceAway(value)
		end
	end)
	Net.on("Fx", onFx)
	task.spawn(function()
		-- The profile may still be loading: retry within SyncRequest's rate limit.
		for _ = 1, 40 do
			local ok, snapshot = pcall(Net.invoke, "SyncRequest")
			if ok and type(snapshot) == "table" and snapshot.inventory then
				for section, value in snapshot do
					State.set(section, value)
				end
				announceAway(snapshot.stations)
				return
			end
			task.wait(5)
		end
	end)
end

return Session
