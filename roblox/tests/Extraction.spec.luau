--!strict
local TestKit = require("./TestKit")
local Content = require("../src/shared/Data")
local Extraction = require("../src/shared/Domain/Extraction")

local T0 = 1_700_000_000
local CONFIG = Content.Tuning.extraction
local HERE = { x = 0, z = 0 }
local QUARRY = Content.Locations["loc.sunken_quarry"].run.extraction
local DEPOT = Content.Locations["loc.ashfall_depot"].run.extraction
local PINES = Content.Locations["loc.pine_hollow"].run.extraction

return function(test: TestKit.Register)
	test("Light fog leaves from any edge with a short fog-out", function()
		local channel = Extraction.begin(PINES, 1, "edge", 7, HERE, T0, CONFIG) :: Extraction.Channel
		TestKit.equal(channel.kind, "edge")
		TestKit.equal(channel.endsAt, T0 + CONFIG.edgeSeconds)
		local _, reason = Extraction.begin(PINES, 1, "north_ramp", 7, HERE, T0, CONFIG)
		TestKit.equal(reason, "unknown", "Light fog has no points")
		TestKit.deepEqual(Extraction.openPoints(PINES, 1), {})
	end)

	test("Dense fog: one of three points is closed per lobby seed, the same for everyone", function()
		local seen: { [string]: number } = {}
		for seed = 1, 60 do
			local open = Extraction.openPoints(QUARRY :: any, seed)
			TestKit.equal(#open, 2, `seed {seed}`)
			TestKit.deepEqual(Extraction.openPoints(QUARRY :: any, seed), open, "deterministic")
			for _, id in open do
				seen[id] = (seen[id] or 0) + 1
			end
		end
		for _, point in (QUARRY :: any).points do
			local count = seen[point.id] or 0
			TestKit.truthy(count > 20 and count < 60, `{point.id} open in {count} of 60 lobbies`)
		end
	end)

	test("a closed point refuses; an open one channels for 8 s", function()
		local seed = 5
		local open = Extraction.openPoints(QUARRY :: any, seed)
		local closedId: string? = nil
		for _, point in (QUARRY :: any).points do
			if not table.find(open, point.id) then
				closedId = point.id
			end
		end
		local _, reason = Extraction.begin(QUARRY, seed, closedId :: string, 1, HERE, T0, CONFIG)
		TestKit.equal(reason, "closed")
		local channel = Extraction.begin(QUARRY, seed, open[1], 1, HERE, T0, CONFIG) :: Extraction.Channel
		TestKit.equal(channel.kind, "point")
		TestKit.equal(Extraction.isDone(channel, T0 + 7.9), false)
		TestKit.equal(Extraction.isDone(channel, T0 + 8), true)
		TestKit.equal(Extraction.progress(channel, T0 + 4), 0.5)
		TestKit.equal(Extraction.remaining(channel, T0 + 6), 2)
		local _, edge = Extraction.begin(QUARRY, seed, "edge", 1, HERE, T0, CONFIG)
		TestKit.equal(edge, "noEdge", "no walking off the edge in Dense fog")
		local _, nowhere = Extraction.begin(QUARRY, seed, "moon_base", 1, HERE, T0, CONFIG)
		TestKit.equal(nowhere, "unknown")
	end)

	test("damage, death and walking off break a point channel", function()
		local open = Extraction.openPoints(QUARRY :: any, 9)
		local channel = Extraction.begin(QUARRY, 9, open[1], 1, HERE, T0, CONFIG) :: Extraction.Channel
		TestKit.equal(Extraction.breaks(channel, "damage"), true)
		TestKit.equal(Extraction.breaks(channel, "death"), true)
		TestKit.equal(Extraction.outOfRange(channel, { x = CONFIG.radiusStuds, z = 0 }, CONFIG), false)
		TestKit.equal(Extraction.outOfRange(channel, { x = CONFIG.radiusStuds + 0.1, z = 0 }, CONFIG), true)
	end)

	test("Black fog's flare extract: 30 s, and damage doesn't break it", function()
		local channel = Extraction.begin(DEPOT, 3, "flare", 1, HERE, T0, CONFIG) :: Extraction.Channel
		TestKit.equal(channel.kind, "flare")
		TestKit.equal(channel.endsAt, T0 + 30)
		TestKit.equal(Extraction.breaks(channel, "damage"), false, "survive it, don't avoid it")
		TestKit.equal(Extraction.breaks(channel, "death"), true)
		local _, reason = Extraction.begin(QUARRY, 3, "flare", 1, HERE, T0, CONFIG)
		TestKit.equal(reason, "noFlare", "Dense fog has no flare extract")
	end)

	test("results pay XP by tier only for getting out alive", function()
		local stats: Extraction.RunStats = {
			outcome = "extracted",
			fogTier = 3,
			enteredAt = T0,
			endedAt = T0 + 600,
			kills = 7,
			containersSearched = 4,
			carriedOut = { { itemId = "item.trigger_group", count = 1 } },
		}
		local result = Extraction.summarize(stats, CONFIG)
		TestKit.equal(result.xp, CONFIG.xpByTier[3])
		TestKit.equal(result.seconds, 600)
		TestKit.equal(#result.carriedOut, 1)
		stats.outcome = "died"
		local died = Extraction.summarize(stats, CONFIG)
		TestKit.equal(died.xp, 0)
		TestKit.equal(#died.carriedOut, 0, "nothing came home")
	end)
end
