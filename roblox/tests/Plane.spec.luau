--!strict
local TestKit = require("./TestKit")
local Plane = require("../src/shared/Domain/Plane")

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

local ORIGIN = Plane.point(0, 0)

return function(test: TestKit.Register)
	test("yaw 0 faces +Z and yaw pi/2 faces +X; yawTo inverts direction", function()
		local north = Plane.direction(0)
		near(north.x, 0, "x")
		near(north.z, 1, "z")
		local east = Plane.direction(math.pi / 2)
		near(east.x, 1, "x")
		near(Plane.yawTo(ORIGIN, Plane.point(5, 0)), math.pi / 2, "yawTo east")
		near(Plane.yawTo(ORIGIN, ORIGIN), 0, "same point")
	end)

	test("angleDiff wraps to [-pi, pi]", function()
		near(Plane.angleDiff(math.rad(170), math.rad(-170)), math.rad(20), "across the seam")
		near(Plane.angleDiff(0, math.rad(-30)), math.rad(-30), "negative")
	end)

	test("moveToward steps and lands exactly", function()
		local step = Plane.moveToward(ORIGIN, Plane.point(10, 0), 4)
		near(step.x, 4, "partial")
		local landed = Plane.moveToward(ORIGIN, Plane.point(3, 0), 4)
		near(landed.x, 3, "lands")
		near(Plane.distance(ORIGIN, Plane.offset(ORIGIN, 1.2, 7)), 7, "offset distance")
	end)

	test("inArc honours range, arc width and the target's radius", function()
		local ahead = Plane.point(0, 5)
		TestKit.truthy(Plane.inArc(ORIGIN, 0, ahead, 6, 90), "straight ahead")
		TestKit.equal(Plane.inArc(ORIGIN, 0, Plane.point(0, 7), 6, 90), false, "out of range")
		TestKit.truthy(Plane.inArc(ORIGIN, 0, Plane.point(0, 7), 6, 90, 1.5), "its radius reaches")
		TestKit.equal(Plane.inArc(ORIGIN, 0, Plane.point(5, 0), 6, 90), false, "90 degrees off a 90-degree arc")
		TestKit.truthy(Plane.inArc(ORIGIN, 0, Plane.point(5, 0), 6, 200), "a wide arc")
		TestKit.truthy(Plane.inArc(ORIGIN, math.pi, Plane.point(0.2, 0), 6, 10, 1), "standing inside it")
	end)

	test("rayCircle finds the first hit, or nil", function()
		local hit = Plane.rayCircle(ORIGIN, 0, 50, Plane.point(0, 20), 2)
		near(hit :: number, 18, "front of the circle")
		TestKit.equal(Plane.rayCircle(ORIGIN, math.pi, 50, Plane.point(0, 20), 2), nil, "facing away")
		TestKit.equal(Plane.rayCircle(ORIGIN, 0, 10, Plane.point(0, 20), 2), nil, "beyond range")
		TestKit.equal(Plane.rayCircle(ORIGIN, 0, 50, Plane.point(5, 20), 2), nil, "passes beside")
		TestKit.equal(Plane.rayCircle(ORIGIN, 0, 50, Plane.point(0.5, 0), 2), 0, "starts inside")
	end)
end
