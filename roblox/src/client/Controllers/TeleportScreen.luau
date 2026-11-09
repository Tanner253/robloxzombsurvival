--!strict
--[[
	TeleportScreen: what a live teleport shows instead of Roblox's default screen
	(11.3). A Fog Run trip and the way home are real teleports on a published place, so
	the client hands TeleportService a screen as soon as one may happen: the location's
	art and name when a trip starts, "Heading home" once a run has begun. In Studio no
	teleport happens and this does nothing visible.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Art = require(ReplicatedStorage.Shared.Art)
local Content = require(ReplicatedStorage.Shared.Data)
local Theme = require("../UI/theme")

local TeleportScreen = {}

local current: ScreenGui? = nil

local function label(parent: Instance, text: string, font: Font, size: number, color: Color3, y: number)
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.Size = UDim2.new(1, -96, 0, size + 8)
	made.Position = UDim2.new(0, 48, 0.62, y)
	made.FontFace = font
	made.TextSize = size
	made.TextColor3 = color
	made.TextXAlignment = Enum.TextXAlignment.Left
	made.Text = text
	made.Parent = parent
	return made
end

local function build(locationId: string?): ScreenGui
	local location = if locationId then Content.Locations[locationId] else nil
	local gui = Instance.new("ScreenGui")
	gui.Name = "EO_Teleport"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromHex("1A1D21")
	back.BorderSizePixel = 0
	back.Parent = gui
	local art = location and Art.fogMap.art[location.id]
	if art then
		local picture = Instance.new("ImageLabel")
		picture.Size = UDim2.fromScale(1, 0.55)
		picture.BackgroundTransparency = 1
		picture.Image = art
		picture.ScaleType = Enum.ScaleType.Crop
		picture.ImageTransparency = 0.15
		picture.Parent = back
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		shade.Parent = picture
	end
	if location then
		label(back, "Heading into", Theme.fonts.body, 22, Theme.colors.textMuted, 0)
		label(back, location.name, Theme.fonts.header, 44, Theme.colors.text, 30)
	else
		label(back, "Heading home", Theme.fonts.header, 44, Theme.colors.text, 30)
	end
	return gui
end

-- Sets the screen the next teleport shows: a trip to `locationId`, or home when nil.
function TeleportScreen.prepare(locationId: string?)
	local gui = build(locationId)
	local ok = pcall(function()
		-- The engine takes a ScreenGui here; the API definitions say GuiObject.
		TeleportService:SetTeleportGui(gui :: any)
	end)
	if not ok then
		gui:Destroy()
		return
	end
	if current then
		current:Destroy()
	end
	current = gui
end

return TeleportScreen
