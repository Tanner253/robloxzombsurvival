--!strict
--[[
	credits_parse: reads CREDITS.md (the repo root) into sections of credit rows. Shared by
	tools/credits.luau (which writes src/shared/Data/Credits.luau) and the Credits spec
	(which checks the two agree). Pure: text in, tables out.

	Format: "## Section" headings, each followed by a Markdown table whose header is
	| Work | By | License | Source |. Anything else in the file is prose and ignored.
]]

export type Row = { work: string, by: string, license: string, source: string }
export type Section = { title: string, rows: { Row } }

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function cells(line: string): { string }?
	if string.sub(trim(line), 1, 1) ~= "|" then
		return nil
	end
	local result: { string } = {}
	local inner = string.match(trim(line), "^|(.*)|$")
	if inner == nil then
		return nil
	end
	for cell in string.gmatch(inner .. "|", "([^|]*)|") do
		table.insert(result, trim(cell))
	end
	return result
end

return function(text: string): { Section }
	local sections: { Section } = {}
	local current: Section? = nil
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		local heading = string.match(line, "^##%s+(.+)$")
		if heading then
			current = { title = trim(heading), rows = {} }
			table.insert(sections, current :: Section)
			continue
		end
		local row = cells(line)
		if current and row and #row >= 4 then
			local first = row[1]
			local isHeader = first == "Work"
			local isRule = string.match(first, "^:?%-+:?$") ~= nil
			if not isHeader and not isRule and first ~= "" then
				table.insert((current :: Section).rows, { work = row[1], by = row[2], license = row[3], source = row[4] })
			end
		end
	end
	-- Sections without rows (prose under a heading) don't show in the panel.
	local kept: { Section } = {}
	for _, section in sections do
		if #section.rows > 0 then
			table.insert(kept, section)
		end
	end
	return kept
end
