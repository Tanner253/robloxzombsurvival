--!strict
local TestKit = require("./TestKit")
local RunTicket = require("../src/shared/Domain/RunTicket")
local TableUtil = require("../src/shared/Util/Table")

local NOW = 1_700_000_000

local function ticket(): any
	return RunTicket.new("a1b2-c3d4", "loc.sunken_quarry", 3, "party_7", false, 123456, NOW)
end

return function(test: TestKit.Register)
	test("a fresh ticket round-trips", function()
		local parsed, reason = RunTicket.parse(ticket(), NOW + 10, 120)
		TestKit.equal(reason, nil)
		TestKit.deepEqual(parsed, ticket())
	end)

	test("tampered or stale join data is refused", function()
		local cases: { { mutate: (any) -> (), reason: string } } = {
			{
				mutate = function(t)
					t.v = 99
				end,
				reason = "wrong version",
			},
			{
				mutate = function(t)
					t.locationId = "item.timber"
				end,
				reason = "bad location",
			},
			{
				mutate = function(t)
					t.lobbyId = string.rep("x", 200)
				end,
				reason = "bad IDs",
			},
			{
				mutate = function(t)
					t.powerBand = 0.5
				end,
				reason = "bad numbers",
			},
			{
				mutate = function(t)
					t.reentry = "yes"
				end,
				reason = "bad reentry",
			},
			{
				mutate = function(t)
					t.partyId = "a b"
				end,
				reason = "bad party",
			},
			{
				mutate = function(t)
					t.issuedAt = NOW - 999
				end,
				reason = "stale",
			},
			{
				mutate = function(t)
					t.issuedAt = NOW + 999
				end,
				reason = "stale",
			},
			{
				mutate = function(t)
					t.godMode = true
				end,
				reason = "unknown field",
			},
		}
		for _, case in cases do
			local data = TableUtil.deepCopy(ticket())
			case.mutate(data)
			local parsed, reason = RunTicket.parse(data, NOW, 120)
			TestKit.equal(parsed, nil, case.reason)
			TestKit.equal(reason, case.reason)
		end
		TestKit.equal(select(2, RunTicket.parse(nil, NOW, 120)), "no ticket")
	end)

	test("a solo ticket has no party", function()
		local solo = RunTicket.new("L1", "loc.pine_hollow", 1, nil, true, 0, NOW)
		local parsed = RunTicket.parse(solo, NOW, 60) :: RunTicket.Ticket
		TestKit.equal(parsed.partyId, nil)
		TestKit.equal(parsed.reentry, true)
	end)
end
