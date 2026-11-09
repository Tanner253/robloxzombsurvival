--!strict
--[[
	Home stakes (the flow review's F-04 and F-05): what is risked on a run stays risked, and
	home is not a free refill.

	The server glue (OnRun, Inbox, Stations) needs Roblox, so these specs read its source for
	the guards that make the rules hold, beside the pure rules themselves.
]]

local fs = require("@lune/fs")
local TestKit = require("./TestKit")

local function source(path: string): string
	return fs.readFile(path)
end

-- The body of `local function <name>(` up to the next top-level `end`.
local function body(text: string, name: string): string
	local start = string.find(text, `local function {name}%(`)
	assert(start, `no local function {name}`)
	local finish = string.find(text, "\nend\n", start, true)
	assert(finish, `{name} has no end`)
	return string.sub(text, start, finish)
end

return function(test: TestKit.Register)
	test("F-04: a run server, or a seat in a simulated lobby, counts as on a run", function()
		local text = source("src/server/OnRun.luau")
		TestKit.truthy(string.find(text, 'Teleport.role() == "run" or OnRun.seated(player)', 1, true), "OnRun.is")
		local lobby = source("src/server/Services/Lobby.luau")
		TestKit.truthy(string.find(lobby, "OnRun.seated = function", 1, true), "Lobby seats count")
		local materials = source("src/server/Services/Materials.luau")
		TestKit.truthy(string.find(materials, "not OnRun.is(player)", 1, true), "crafting on a run uses only the bag")
	end)

	test("F-04: on a run the inbox refuses TAKE, TAKE ALL and USE with a notice", function()
		local text = source("src/server/Services/Inbox.luau")
		local usable = body(text, "usable")
		TestKit.truthy(string.find(usable, "OnRun.is(player)", 1, true), "usable asks OnRun")
		TestKit.truthy(string.find(usable, "Sync.notice(player, OnRun.INBOX_NOTICE", 1, true), "and says why")
		for _, handler in { "take", "takeAll", "use" } do
			TestKit.truthy(string.find(body(text, handler), "usable(player)", 1, true), `{handler} checks usable`)
		end
		-- Grants still land in it: a level-up on a run waits at home.
		TestKit.equal(string.find(text, "function Inbox.grant[^\n]*\n[^\n]*usable"), nil, "grants are never refused")
	end)

	test("F-04: a hand craft that overflows on a run drops on the ground, never in the inbox", function()
		local text = source("src/server/Services/Stations.luau")
		local craft = body(text, "handCraft")
		local runBranch = string.find(craft, "if #leftover > 0 and onRun then", 1, true)
		local inboxBranch = string.find(craft, "Inbox.grant(player, leftover", 1, true)
		TestKit.truthy(runBranch and inboxBranch and runBranch < inboxBranch, "the run branch comes first")
		TestKit.truthy(string.find(craft, "Drops%.spawn%(player, [^\n]*, true%)"), "a ground-only drop")
		local drops = source("src/server/Services/Drops.luau")
		TestKit.truthy(
			string.find(drops, "if keepOnGround then\n\t\t\treturn nil", 1, true),
			"ground drops skip the inbox"
		)
	end)
end
