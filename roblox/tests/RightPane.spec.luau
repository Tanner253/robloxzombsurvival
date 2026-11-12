--!strict
-- Domain/RightPane: the inventory's right pane. 2026-11-12, the developer: "when i press tab
-- all i see is my inbox but i cant see my player model or my equipment slots". LDoE's
-- inventory opened alone shows the survivor; the inbox is a tab the player opens.
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local RightPane = require("../src/shared/Domain/RightPane")

return function(test: TestKit.Register)
	test("no context means the survivor", function()
		TestKit.equal(RightPane.choose(nil), "character")
		TestKit.equal(RightPane.choose({}), "character")
		TestKit.equal(RightPane.choose({ tab = "crafting" }), "character", "an unknown tab")
	end)

	test("what the inventory was opened with wins, in order", function()
		TestKit.equal(RightPane.choose({ haven = true, station = true, crate = true }), "haven")
		TestKit.equal(RightPane.choose({ station = true, project = true, loot = true }), "station")
		TestKit.equal(RightPane.choose({ project = true, loot = true }), "project")
		TestKit.equal(RightPane.choose({ loot = true, crate = true, tab = "inbox" }), "loot")
		TestKit.equal(RightPane.choose({ crate = true }), "storage")
	end)

	test("the inbox shows only when its tab is picked", function()
		TestKit.equal(RightPane.choose({ tab = "inbox" }), "inbox")
		TestKit.equal(RightPane.choose({ tab = "inbox", crate = true }), "inbox", "the shop's inbox button at a crate")
	end)

	-- The AutoPlayer's first session: the inbox pane read "DailyGift" under the daily gift.
	test("every inbox row's source reads in words", function()
		local Inbox = require("../src/shared/Domain/Inbox")
		local found = 0
		for _, dir in { "src/server/Services", "src/server/World" } do
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isFile(path) then
					local source = fs.readFile(path)
					for key in string.gmatch(source, 'Inbox%.grant%([^\n]-,%s*"([^"]+)"') do
						found += 1
						TestKit.truthy(Inbox.SOURCE_TEXT[key], `{name}: inbox source "{key}" has words`)
					end
				end
			end
		end
		TestKit.truthy(found >= 15, `{found} inbox sources`)
		TestKit.equal(Inbox.sourceText("DailyGift"), "Daily gift")
		local pane = fs.readFile("src/client/UI/screens/ldoe/ContextPanes.luau")
		TestKit.truthy(string.find(pane, "InboxRules.sourceText(row.source)", 1, true), "the pane shows the words")
	end)

	test("Tab and the Bag button open on the survivor; the inbox is a tab of its pane", function()
		local actions = fs.readFile("src/client/Actions.luau")
		local toggle = string.match(actions, "function Actions%.toggleInventory%(%).-\nend")
		TestKit.truthy(toggle, "Actions.toggleInventory")
		TestKit.truthy(string.find(toggle :: string, 'State.clear("inventoryTab")', 1, true), "opening clears the tab")
		TestKit.truthy(string.find(actions, "function Actions.showSurvivor", 1, true), "the inbox's way back")
		for _, path in { "src/client/UI/screens/ldoe/Hud.luau", "src/client/UI/screens/HUD.luau" } do
			local hud = fs.readFile(path)
			TestKit.truthy(
				not string.find(hud, "then Actions.openInbox", 1, true),
				`{path}: the Bag button never opens the inbox`
			)
		end
		local panels = fs.readFile("src/client/UI/screens/ldoe/Panels.luau")
		TestKit.truthy(string.find(panels, "RightPane.choose(", 1, true), "Panels picks the pane through RightPane")
		TestKit.truthy(string.find(panels, "onInbox = Actions.openInbox", 1, true), "the survivor pane's Inbox tab")
		TestKit.truthy(string.find(panels, "onBack = Actions.showSurvivor", 1, true), "the inbox pane's Survivor tab")
		local pane = fs.readFile("src/client/UI/screens/ldoe/CharacterPane.luau")
		TestKit.truthy(string.find(pane, "e(SurvivorView", 1, true), "the survivor's model stands in the pane")
	end)
end
