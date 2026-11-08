--!strict
-- Specs for Domain/UiAudit, the rules of the UI overlap gate (checklist 4.19, 4.18).
local TestKit = require("./TestKit")
local UiAudit = require("../src/shared/Domain/UiAudit")

local SAFE = { x = 0, y = 58, w = 1366, h = 710 }

local function node(id: number, x: number, y: number, w: number, h: number, extra: { [string]: any }?): UiAudit.Node
	local result: any = {
		id = id,
		path = `n{id}`,
		rect = { x = x, y = y, w = w, h = h },
		ancestors = {},
		draws = true,
	}
	for key, value in extra or {} do
		result[key] = value
	end
	return result
end

local function kinds(flags: { UiAudit.Flag }): { [string]: number }
	local result: { [string]: number } = {}
	for _, flag in flags do
		result[flag.kind] = (result[flag.kind] or 0) + 1
	end
	return result
end

return function(test: TestKit.Register)
	test("two drawn siblings that intersect are flagged; touching edges are not", function()
		local flags = UiAudit.audit({
			node(1, 100, 100, 50, 50),
			node(2, 140, 120, 50, 50),
			node(3, 150, 100, 50, 50), -- touches 1's right edge, overlaps 2
		}, SAFE, {})
		TestKit.equal(kinds(flags).overlap, 2)
		for _, flag in flags do
			TestKit.truthy(not (flag.path == "n1" and flag.other == "n3"), "touching edges pass")
		end
	end)

	test("an element over its own ancestor, a badge or a shadow is fine", function()
		local flags = UiAudit.audit({
			node(1, 100, 100, 100, 100),
			node(2, 110, 110, 20, 20, { ancestors = { [1] = true } }),
			node(3, 180, 90, 30, 30, { overlay = true }),
			node(4, 104, 104, 100, 100, { decor = true }),
		}, SAFE, {})
		TestKit.equal(#flags, 0)
	end)

	test("undrawn layout containers never count as overlapping", function()
		local flags = UiAudit.audit({
			node(1, 100, 100, 300, 300, { draws = false }),
			node(2, 150, 150, 300, 300, { draws = false }),
		}, SAFE, {})
		TestKit.equal(#flags, 0)
	end)

	test("text that doesn't fit and elements cut off by a clipping parent are clipped", function()
		local flags = UiAudit.audit({
			node(1, 100, 100, 60, 20, { textFits = false }),
			node(2, 300, 300, 80, 40, { clip = { x = 300, y = 300, w = 60, h = 60 } }),
			node(3, 400, 400, 40, 40, { clip = { x = 380, y = 380, w = 100, h = 100 } }),
		}, SAFE, {})
		TestKit.equal(kinds(flags).clipped, 2)
	end)

	test("anything outside the safe area or on a reserved zone is flagged", function()
		local zones = UiAudit.touchZones(844, 390)
		local flags = UiAudit.audit({
			node(1, 10, 20, 40, 40), -- under the top bar
			node(2, 770, 310, 40, 40), -- on the jump button
			node(3, 20, 330, 40, 40), -- on the thumbstick
			node(4, 400, 100, 40, 40),
		}, SAFE, zones)
		local found = kinds(flags)
		TestKit.equal(found.outside, 1)
		TestKit.equal(found.zone, 2)
	end)

	test("a full-screen backdrop may run under the top bar and the reserved zones", function()
		local zones = UiAudit.touchZones(844, 390)
		local flags = UiAudit.audit({
			node(1, 0, -60, 844, 450, { decor = true, backdrop = true }),
			node(2, 0, -60, 844, 450, { decor = true }), -- a plain decor frame is still checked
		}, SAFE, zones)
		local found = kinds(flags)
		TestKit.equal(found.outside, 1)
		TestKit.equal(found.zone, 2)
	end)

	test("an icon with no image is flagged as a missing glyph", function()
		local flags = UiAudit.audit({ node(1, 100, 100, 20, 20, { missingGlyph = true, draws = false }) }, SAFE, {})
		TestKit.equal(kinds(flags).missingGlyph, 1)
	end)

	test("touch zones follow Roblox's small and large screen layouts", function()
		local small = UiAudit.touchZones(844, 390)
		TestKit.equal(small[1].rect.w, 70, "small jump button")
		local large = UiAudit.touchZones(1366, 1024)
		TestKit.equal(large[1].rect.w, 120, "large jump button")
	end)

	test("describe reads as one line", function()
		TestKit.equal(UiAudit.describe({ kind = "overlap", path = "App.A", other = "App.B" }), "overlap: App.A x App.B")
	end)
end
