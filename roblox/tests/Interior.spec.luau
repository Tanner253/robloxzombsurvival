--!strict
local TestKit = require("./TestKit")
local Interior = require("../src/shared/Domain/Interior")

local function near(actual: number, expected: number, label: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{label}: expected {expected}, got {actual}`, 2)
	end
end

-- A 12 x 8 room, floor top at y = 5, roof 10 above it, unturned.
local ROOM = Interior.footprint(0, 5, 0, 0, 12, 8, 10)
-- A long 20 x 6 shed turned 90°: its width now runs along world Z.
local SHED = Interior.footprint(100, 0, 50, math.rad(90), 20, 6, 6)
local ROOT = 3 -- a standing survivor's root sits about this far above the floor

return function(test: TestKit.Register)
	test("toLocal turns a world point into the building's frame (as CFrame.Angles)", function()
		local lx, lz = Interior.toLocal(ROOM, 4, -2)
		near(lx, 4, "unturned x")
		near(lz, -2, "unturned z")
		-- Turned 90°, the shed's own +X points along world -Z.
		local sx, sz = Interior.toLocal(SHED, 100, 50 - 7)
		near(sx, 7, "turned x")
		near(sz, 0, "turned z")
	end)

	test("inside the footprint and under the roof counts; outside or above does not", function()
		TestKit.truthy(Interior.isInside(ROOM, 0, 5 + ROOT, 0, false), "room centre")
		TestKit.truthy(Interior.isInside(ROOM, 5.5, 5 + ROOT, 3.5, false), "near a corner")
		TestKit.equal(Interior.isInside(ROOM, 7, 5 + ROOT, 0, false), false, "past the east wall")
		TestKit.equal(Interior.isInside(ROOM, 0, 5 + ROOT, -4.5, false), false, "past the north wall")
		TestKit.equal(Interior.isInside(ROOM, 0, 5 + 10.5, 0, false), false, "up on the roof")
		TestKit.equal(Interior.isInside(ROOM, 0, 5 - 2.5, 0, false), false, "in a cellar below")
	end)

	test("a turned building tests in its own frame", function()
		-- 9 studs along world Z is inside its 20-long width; 9 along world X is outside
		-- its 6-deep depth.
		TestKit.truthy(Interior.isInside(SHED, 100, ROOT, 50 + 9, false), "along the turned width")
		TestKit.equal(Interior.isInside(SHED, 100 + 9, ROOT, 50, false), false, "across the depth")
		TestKit.truthy(Interior.isInside(SHED, 100 + 2.5, ROOT, 50 - 9, false), "far corner, inside")
	end)

	test("hysteresis: enter a little inside the edge, leave only well past it", function()
		local y = 5 + ROOT
		-- On the wall line (x = 6): not in yet when walking in...
		TestKit.equal(Interior.isInside(ROOM, 6, y, 0, false), false, "doorway, walking in")
		TestKit.equal(Interior.isInside(ROOM, 5.8, y, 0, false), false, "inside the inset")
		TestKit.truthy(Interior.isInside(ROOM, 5.6, y, 0, false), "past the inset")
		-- ...and still in when walking out, until EXIT_PAD beyond it.
		TestKit.truthy(Interior.isInside(ROOM, 6, y, 0, true), "doorway, walking out")
		TestKit.truthy(Interior.isInside(ROOM, 7.4, y, 0, true), "a step outside")
		TestKit.equal(Interior.isInside(ROOM, 7.6, y, 0, true), false, "clear of the door")
		-- Jitter across the doorway never flips it either way.
		local inside = false
		local flips = 0
		for step = 0, 40 do
			local x = 6 + math.sin(step) * 0.25
			local now = Interior.isInside(ROOM, x, y, 0, inside)
			if now ~= inside then
				flips += 1
			end
			inside = now
		end
		TestKit.equal(flips, 0, "jitter at the doorway")
	end)

	test("pick keeps the current building, else the smallest one entered", function()
		local yard = Interior.footprint(0, 5, 0, 0, 40, 40, 14)
		local list = { yard, ROOM }
		TestKit.equal(Interior.pick(list, 0, 5 + ROOT, 0, nil), 2, "the room inside the yard")
		TestKit.equal(Interior.pick(list, 15, 5 + ROOT, 15, nil), 1, "the yard alone")
		TestKit.equal(Interior.pick(list, 0, 5 + ROOT, 0, 1), 1, "still in the current one")
		TestKit.equal(Interior.pick(list, 60, 5 + ROOT, 0, 1), nil, "outside everything")
		TestKit.equal(Interior.pick({}, 0, 0, 0, nil), nil, "no buildings")
	end)

	test("near culls by distance plus the building's own size", function()
		TestKit.truthy(Interior.near(ROOM, 70, 0, 70), "at the radius")
		TestKit.truthy(Interior.near(ROOM, 76, 0, 70), "the half-diagonal counts")
		TestKit.equal(Interior.near(ROOM, 80, 0, 70), false, "too far")
	end)

	test("facesCamera: the walls on the camera's side, not the far or end walls", function()
		-- The play camera looks along (-1, -1): it sits to the +X +Z side.
		TestKit.truthy(Interior.facesCamera(1, 0, -1, -1), "east wall")
		TestKit.truthy(Interior.facesCamera(0, 1, -1, -1), "south wall")
		TestKit.truthy(Interior.facesCamera(1, 1, -1, -1), "the corner between them")
		TestKit.equal(Interior.facesCamera(-1, 0, -1, -1), false, "west wall")
		TestKit.equal(Interior.facesCamera(1, -1, -1, -1), false, "an end corner")
		TestKit.equal(Interior.facesCamera(0, 0, -1, -1), false, "no normal")
	end)

	test("targets: inside lifts the roof and ghosts the walls; shading ghosts the roof", function()
		local roof, walls = Interior.targets(true, false)
		TestKit.truthy(roof >= 0.9 and roof < 1, "roof nearly gone, still shading")
		near(walls, Interior.WALL_ALPHA, "walls")
		roof, walls = Interior.targets(false, true)
		near(roof, Interior.SHADE_ALPHA, "a roof that hides you")
		near(walls, 0, "its walls stay")
		roof, walls = Interior.targets(false, false)
		near(roof + walls, 0, "untouched")
		roof = Interior.targets(true, true)
		near(roof, Interior.ROOF_ALPHA, "inside wins")
	end)

	test("step eases over FADE_SECONDS and lands exactly, both ways", function()
		local now, frames = 0, 0
		while now ~= Interior.ROOF_ALPHA and frames < 100 do
			now = Interior.step(now, Interior.ROOF_ALPHA, 1 / 60)
			frames += 1
		end
		near(now, Interior.ROOF_ALPHA, "lands")
		TestKit.truthy(frames >= 13 and frames <= 16, `about a quarter second ({frames} frames)`)
		near(Interior.step(0.5, 0, 1), 0, "a long frame lands")
		near(Interior.step(0.3, 0.3, 1 / 60), 0.3, "at rest")
		near(Interior.step(0.4, 0, -1), 0.4, "a negative dt never moves")
	end)
end
