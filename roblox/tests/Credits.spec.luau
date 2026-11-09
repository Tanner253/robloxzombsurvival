--!strict
-- Specs for the Credits panel's data: Data/Credits must match CREDITS.md (tools/credits.luau).
local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local parse = require("../tools/credits_parse")
local Credits = require("../src/shared/Data/Credits")

return function(test: TestKit.Register)
	test("Data/Credits matches CREDITS.md (run tools/credits.luau after editing it)", function()
		local sections = parse(fs.readFile("../CREDITS.md"))
		TestKit.equal(#Credits, #sections, "sections")
		for index, section in sections do
			local generated = Credits[index]
			TestKit.equal(generated.title, section.title, `section {index} title`)
			TestKit.equal(#generated.rows, #section.rows, `{section.title}: rows`)
			for rowIndex, row in section.rows do
				local other = generated.rows[rowIndex]
				TestKit.equal(other.work, row.work, `{section.title} row {rowIndex}`)
				TestKit.equal(other.by, row.by, `{section.title} row {rowIndex}`)
				TestKit.equal(other.license, row.license, `{section.title} row {rowIndex}`)
				TestKit.equal(other.source, row.source, `{section.title} row {rowIndex}`)
			end
		end
	end)

	test("the parser reads sections and table rows and skips prose, headers and rules", function()
		local sections = parse(table.concat({
			"# Credits",
			"Some prose with | a pipe.",
			"## Weapons",
			"| Work | By | License | Source |",
			"|---|---|---|---|",
			"| AK model | Jane Doe | CC-BY 4.0 | sketchfab.com/x |",
			"## Empty",
			"Nothing here yet.",
		}, "\n"))
		TestKit.equal(#sections, 1, "empty sections are dropped")
		TestKit.equal(sections[1].title, "Weapons")
		TestKit.equal(#sections[1].rows, 1)
		TestKit.equal(sections[1].rows[1].license, "CC-BY 4.0")
	end)

	test("every credit names its author, licence and source", function()
		for _, section in Credits do
			for _, row in section.rows do
				TestKit.truthy(row.work ~= "" and row.by ~= "" and row.license ~= "" and row.source ~= "", row.work)
			end
		end
	end)
end
