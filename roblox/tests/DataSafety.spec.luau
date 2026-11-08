--!strict
-- Specs for Domain/DataSafety: live and Studio store names, load retries, the startup audit.
local TestKit = require("./TestKit")
local DataSafety = require("../src/shared/Domain/DataSafety")

return function(test: TestKit.Register)
	test("live servers use the real store names; Studio always uses _Studio", function()
		TestKit.equal(DataSafety.storeName("PlayerData", false), "PlayerData")
		TestKit.equal(DataSafety.storeName("PlayerData", true), "PlayerData_Studio")
		TestKit.equal(DataSafety.storeName("Outposts", true), "Outposts_Studio")
	end)

	test("load retries wait longer each time, up to a cap", function()
		TestKit.equal(DataSafety.retryDelay(2), 2)
		TestKit.equal(DataSafety.retryDelay(3), 4)
		TestKit.equal(DataSafety.retryDelay(4), 8)
		TestKit.equal(DataSafety.retryDelay(10), DataSafety.MAX_RETRY_SECONDS)
		TestKit.truthy(DataSafety.MAX_LOAD_ATTEMPTS >= 2, "at least one retry")
	end)

	test("the audit passes a safe setup and names each problem", function()
		local safe: DataSafety.Facts = {
			isStudio = false,
			stores = { { base = "PlayerData", opened = "PlayerData" } },
			sessionLocked = true,
			shutdownBound = true,
		}
		TestKit.equal(#DataSafety.audit(safe), 0)
		local studioOnLive: DataSafety.Facts = {
			isStudio = true,
			stores = { { base = "PlayerData", opened = "PlayerData" } }, -- Studio touching the live store
			sessionLocked = false,
			shutdownBound = false,
		}
		local problems = DataSafety.audit(studioOnLive)
		TestKit.equal(#problems, 3)
		TestKit.truthy(string.find(problems[1], "PlayerData_Studio", 1, true) ~= nil, "names the expected store")
	end)

	test("a live server never opens a _Studio store", function()
		local problems = DataSafety.audit({
			isStudio = false,
			stores = { { base = "PlayerData", opened = "PlayerData_Studio" } },
			sessionLocked = true,
			shutdownBound = true,
		})
		TestKit.equal(#problems, 1)
	end)
end
