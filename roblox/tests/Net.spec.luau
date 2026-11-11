--!strict
local TestKit = require("./TestKit")
local Check = require("../src/shared/Net/Check")
local RateLimiter = require("../src/shared/Net/RateLimiter")
local Remotes = require("../src/shared/Net/Remotes")

return function(test: TestKit.Register)
	test("every remote declares a validator and a sane rate limit", function()
		for name, decl in Remotes.list do
			TestKit.truthy(type(decl.validate) == "function", `{name}.validate`)
			TestKit.truthy(decl.rateLimit.count >= 1 and decl.rateLimit.perSeconds > 0, `{name}.rateLimit`)
			TestKit.truthy(decl.kind == "event" or decl.clientCanSend, `{name}: functions are client-to-server`)
		end
	end)

	test("Remotes.get rejects undeclared names", function()
		TestKit.throws(function()
			Remotes.get("Pnig")
		end, "not declared")
	end)

	test("Ping accepts one integer nonce and nothing else", function()
		local validate = Remotes.get("Ping").validate
		TestKit.truthy((validate(42)), "valid nonce")
		TestKit.equal((validate(1.5)), false, "fraction")
		TestKit.equal((validate(0 / 0)), false, "NaN")
		TestKit.equal((validate(math.huge)), false, "infinity")
		TestKit.equal((validate("42")), false, "string")
		TestKit.equal((validate()), false, "missing")
		TestKit.equal((validate(1, 2)), false, "extra argument")
	end)

	test("Gather takes a home plot node key or a Fog Run lobby node key", function()
		local validate = Remotes.get("Gather").validate
		TestKit.truthy((validate("12345:node.pine_tree#3")), "home plot node")
		TestKit.truthy((validate("rsim2:36")), "simulated lobby node")
		TestKit.truthy((validate("r8f3c2a1e-77b0-4d2e-9a51-0c4f6e2b9d13:120")), "run server lobby node")
		TestKit.equal((validate("rsim2:x")), false, "lobby index not a number")
		TestKit.equal((validate("node.pine_tree")), false, "bare node id")
		TestKit.equal((validate(36)), false, "a number")
		TestKit.equal((validate("r" .. string.rep("a", 80) .. ":1")), false, "too long")
	end)

	test("Check.string and Check.contentId bound their input", function()
		TestKit.equal((Check.string(4)("abcde")), false, "too long")
		TestKit.equal((Check.string(8)("\255\254")), false, "invalid UTF-8")
		TestKit.truthy((Check.contentId("item")("item.wood")), "valid ID")
		TestKit.equal((Check.contentId("item")("loot.wood")), false, "wrong prefix")
		TestKit.equal((Check.contentId("item")("item.Wood; drop")), false, "bad characters")
		TestKit.truthy((Check.optional(Check.boolean())(nil)), "optional nil")
	end)

	test("rate limiter allows a burst, then refills over time", function()
		local limiter = RateLimiter.new()
		local limit = { count = 2, perSeconds = 1 }
		TestKit.truthy(limiter:allow(1, "Ping", limit, 0), "1st")
		TestKit.truthy(limiter:allow(1, "Ping", limit, 0), "2nd")
		TestKit.equal(limiter:allow(1, "Ping", limit, 0.1), false, "3rd in burst")
		TestKit.truthy(limiter:allow(2, "Ping", limit, 0.1), "other player unaffected")
		TestKit.truthy(limiter:allow(1, "Ping", limit, 0.6), "refilled after 0.5 s")
	end)
end
