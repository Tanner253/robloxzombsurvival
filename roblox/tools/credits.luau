--!strict
--[[
	credits.luau: rewrites src/shared/Data/Credits.luau from CREDITS.md (the repo root), so
	the in-game Credits panel (Settings, then Credits) shows exactly what CREDITS.md lists.

	Usage (from roblox/): lune run tools/credits.luau
	Then commit both files; the Credits spec fails while they disagree.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local parse = require("./credits_parse")

local source = fs.readFile("../CREDITS.md")
local sections = parse(source)

local function quote(text: string): string
	return '"' .. string.gsub(string.gsub(text, "\\", "\\\\"), '"', '\\"') .. '"'
end

local lines = {
	"--!strict",
	"-- Generated from CREDITS.md by tools/credits.luau. Don't edit by hand: edit CREDITS.md",
	"-- and run `lune run tools/credits.luau` from roblox/. The Credits panel reads this.",
	"",
	"export type Row = { work: string, by: string, license: string, source: string }",
	"export type Section = { title: string, rows: { Row } }",
	"",
	"local Credits: { Section } = {",
}
for _, section in sections do
	table.insert(lines, "\t{")
	table.insert(lines, `\t\ttitle = {quote(section.title)},`)
	table.insert(lines, "\t\trows = {")
	for _, row in section.rows do
		table.insert(
			lines,
			`\t\t\t\{ work = {quote(row.work)}, by = {quote(row.by)}, license = {quote(row.license)}, source = {quote(
				row.source
			)} },`
		)
	end
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t},")
end
table.insert(lines, "}")
table.insert(lines, "")
table.insert(lines, "return table.freeze(Credits)")
table.insert(lines, "")

fs.writeFile("src/shared/Data/Credits.luau", table.concat(lines, "\n"))
local count = 0
for _, section in sections do
	count += #section.rows
end
print(`Credits: {#sections} sections, {count} rows -> src/shared/Data/Credits.luau`)
