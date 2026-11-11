--!strict
local TestKit = require("./TestKit")
local Remotes = require("../src/shared/Net/Remotes")

local function get(name: string): any
	local decl = Remotes.fogRuns[name]
	assert(decl, `no Fog Run remote '{name}'`)
	return decl.validate
end

return function(test: TestKit.Register)
	test("every Fog Run remote has a validator and a sane rate limit", function()
		local count = 0
		for name, decl in Remotes.fogRuns do
			count += 1
			TestKit.truthy(type(decl.validate) == "function", `{name}.validate`)
			TestKit.truthy(decl.rateLimit.count >= 1 and decl.rateLimit.perSeconds > 0, `{name}.rateLimit`)
			TestKit.truthy(#decl.description > 0, `{name}.description`)
			if not decl.clientCanSend then
				TestKit.equal((decl.validate("anything")), false, `{name}: server-only`)
			end
		end
		TestKit.truthy(count >= 20, "the whole feature is declared")
	end)

	test("with Fog Runs on (F-01), every one of them is a live remote", function()
		for name, decl in Remotes.fogRuns do
			TestKit.equal(Remotes.list[name], decl, name)
		end
	end)

	test("travel and re-entry take a location ID and a mode", function()
		TestKit.truthy((get("TravelStart")("loc.sunken_quarry", "run")), "valid")
		TestKit.equal((get("TravelStart")("loc.sunken_quarry", "fly")), false, "bad mode")
		TestKit.equal((get("TravelStart")("item.timber", "walk")), false, "not a location")
		TestKit.truthy((get("LobbyReenter")("loc.pine_hollow")), "re-entry")
		TestKit.equal((get("TravelBonusTake")(17)), false, "bonus rows are few")
	end)

	test("bags, containers and exits use their wire IDs", function()
		TestKit.truthy((get("BagTake")("b3", "equipment", 2)), "valid")
		TestKit.equal((get("BagTake")("b3", "pouch", 2)), false, "the secure pouch never drops")
		TestKit.equal((get("BagTake")("d3", "backpack", 1)), false, "a ground drop is not a death drop")
		TestKit.truthy((get("ContainerTake")("c12", 1)), "valid")
		TestKit.equal((get("ContainerSearch")("c12; drop")), false, "bad characters")
		TestKit.truthy((get("ExtractStart")("north_ramp")), "a point")
		TestKit.truthy((get("ExtractStart")("edge")), "the edge")
		TestKit.equal((get("ExtractStart")("North Ramp")), false, "IDs, not names")
	end)

	test("combat sends aim headings and an optional soft-lock target", function()
		TestKit.truthy((get("CombatMelee")(true, 1.2)), "no lock")
		TestKit.truthy((get("CombatMelee")(false, -3, "h7")), "locked on")
		TestKit.equal((get("CombatMelee")(false, 0 / 0)), false, "NaN aim")
		TestKit.equal((get("CombatFire")(1, "u7")), false, "players aren't targets in M1")
		TestKit.truthy((get("CombatDodge")(0.5)), "dodge")
		TestKit.equal((get("CombatDodge")()), false, "a dodge needs a heading")
	end)

	test("two weapon slots: 1 and 2 select, F swaps, H uses meds (home remotes, shared with runs)", function()
		for _, name in { "WeaponSelect", "WeaponSwap", "UseMeds" } do
			TestKit.equal(Remotes.fogRuns[name], nil, `{name} is not redeclared for Fog Runs`)
		end
		local select = Remotes.list.WeaponSelect.validate
		TestKit.truthy((select(1)), "slot 1")
		TestKit.truthy((select(2)), "slot 2")
		TestKit.equal((select(3)), false, "there is no third slot (no hotbar)")
		TestKit.truthy((Remotes.list.WeaponSwap.validate()), "swap")
		TestKit.equal((Remotes.list.WeaponSwap.validate(1)), false, "swap takes nothing")
		TestKit.truthy((Remotes.list.UseMeds.validate()), "meds")
	end)
end
