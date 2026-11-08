--!strict
local TestKit = require("./TestKit")
local Rng = require("../src/shared/Domain/Rng")

return function(test: TestKit.Register)
	test("the same seed gives the same sequence", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 50 do
			TestKit.equal(a:NextNumber(), b:NextNumber())
		end
	end)

	test("different seeds diverge, including 0 and negative seeds", function()
		local first = { Rng.new(0):NextNumber(), Rng.new(1):NextNumber(), Rng.new(-7):NextNumber() }
		TestKit.truthy(first[1] ~= first[2] and first[2] ~= first[3], "distinct first draws")
	end)

	test("NextNumber stays in [0, 1) and NextInteger in [min, max]", function()
		local rng = Rng.new(123)
		local seen: { [number]: boolean } = {}
		for _ = 1, 5000 do
			local n = rng:NextNumber()
			TestKit.truthy(n >= 0 and n < 1, "NextNumber range")
			local i = rng:NextInteger(3, 6)
			TestKit.truthy(i >= 3 and i <= 6 and i % 1 == 0, "NextInteger range")
			seen[i] = true
		end
		TestKit.truthy(seen[3] and seen[4] and seen[5] and seen[6], "every value appears")
		TestKit.equal(rng:NextInteger(9, 9), 9, "single-value range")
	end)

	test("NextInteger rejects a reversed range", function()
		TestKit.throws(function()
			Rng.new(1):NextInteger(5, 4)
		end, "min <= max")
	end)
end
