--!strict
--[[
	mark: a callback ref that writes attributes onto the instance React creates, for what
	React props can't express. The UI gate reads them (UI/Gate):
	- mark({ Decor = true }): a shadow or backplate meant to sit behind its siblings;
	- mark({ Overlay = true }): meant to sit on top (badges, tooltips, toasts);
	- mark({ Glyph = "close" }): an icon from the glyph set;
	- mark.composite: one graphic made of overlapping parts, checked as a whole.
	Refs made from the same table are cached, so React doesn't re-run them each render.
]]

local cache: { [any]: (Instance?) -> () } = setmetatable({}, { __mode = "k" }) :: any

local DECOR = { Decor = true }
local BACKDROP = { Decor = true, Backdrop = true }
local OVERLAY = { Overlay = true }
local COMPOSITE = { Composite = true }

local function mark(attributes: { [string]: any }): (Instance?) -> ()
	local cached = cache[attributes]
	if cached then
		return cached
	end
	local function ref(instance: Instance?)
		if instance then
			for name, value in attributes do
				instance:SetAttribute(name, value)
			end
		end
	end
	cache[attributes] = ref
	return ref
end

return {
	attributes = mark,
	decor = mark(DECOR),
	-- A full-screen dim behind a panel, reaching under Roblox's top bar.
	backdrop = mark(BACKDROP),
	overlay = mark(OVERLAY),
	-- One graphic made of overlapping parts (the minimap, an item slot, a round button):
	-- the gate checks it as a single element and skips its insides.
	composite = mark(COMPOSITE),
}
