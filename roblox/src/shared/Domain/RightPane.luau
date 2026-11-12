--!strict
--[[
	RightPane: what the inventory's right pane shows (LDOE_PARITY #13-14). Pure.

	LDoE's inventory is two panes: the bag on the left and, on the right, whatever the
	player opened it with (a Haven stall, a station, a project, a container, a crate) or,
	opened alone, the survivor: the model with the gear slots around it. The item inbox is
	a tab the player opens from the survivor pane (or the shop's inbox button); it never
	stands in for the survivor. 2026-11-12, the developer: "when i press tab all i see is my
	inbox but i cant see my player model or my equipment slots": the inbox tab stuck once
	opened, and the Bag button opened the inbox whenever it held a row.
]]

local RightPane = {}

export type Pane = "haven" | "station" | "project" | "loot" | "storage" | "inbox" | "character"

export type Context = {
	haven: boolean?, -- a Haven stall is open
	station: boolean?, -- a station is open
	project: boolean?, -- a project's parts checklist is open
	loot: boolean?, -- a container or a body is being looted
	crate: boolean?, -- a storage crate is open
	tab: string?, -- the tab the player picked: "inbox", or nil for the survivor
}

function RightPane.choose(context: Context?): Pane
	if context == nil then
		return "character"
	end
	if context.haven then
		return "haven"
	elseif context.station then
		return "station"
	elseif context.project then
		return "project"
	elseif context.loot then
		return "loot"
	elseif context.tab == "inbox" then
		return "inbox"
	elseif context.crate then
		return "storage"
	end
	return "character"
end

return RightPane
