--!strict
--[[
	Loading: the first thing a player sees (PLAYER_EXPERIENCE_CHECKLIST 10.1). Runs from
	ReplicatedFirst before anything else loads, replaces Roblox's default loading
	screen with the game's key art, the title and rotating tips, and a progress bar
	that follows the content queue. It fades away once the world, the survivor and
	the HUD are ready (never into an empty world), or after MAX_SECONDS.

	Self-contained on purpose: Shared modules haven't replicated yet when it runs,
	so the few theme values it needs are repeated here.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local KEY_ART = "rbxassetid://118390976045902" -- dusk at an outpost (docs/milestones/m1-slice1/30-loading-keyart.png)
local MAX_SECONDS = 30
local TIP_SECONDS = 4.5
local HEADER = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold)
local BODY = Font.fromName("BuilderSans", Enum.FontWeight.Medium)
local EMBER = Color3.fromHex("FF8A3D")
local TEXT = Color3.fromHex("F2EBDD")
local PANEL = Color3.fromHex("1C1F24")

local TIPS = {
	"Branches give sticks by hand. Sticks and stone make your first hatchet.",
	"Press Q for AUTO: your survivor walks from node to node and gathers for you.",
	"Keep the campfire fed. Night is short, but it is not kind.",
	"Stations keep converting while you're away. Drop a full stack in before you leave.",
	"Follow the Ember Trail on the left: each quest unlocks the blueprints for the next.",
	"What grows at home doesn't grow back. The Fog is where the real timber is.",
	"A full bag drops the rest on the ground. Come back for it.",
	"Furniture snaps flush against walls. Press R to turn it.",
	"Upgrade walls in place: wood, then scrap, then reinforced.",
}

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "EO_Loading"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 100

local art = Instance.new("ImageLabel")
art.Size = UDim2.fromScale(1, 1)
art.BackgroundColor3 = PANEL
art.Image = KEY_ART
art.ScaleType = Enum.ScaleType.Crop
art.Parent = screen

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BorderSizePixel = 0
local fade = Instance.new("UIGradient")
fade.Rotation = 90
fade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.75),
	NumberSequenceKeypoint.new(0.55, 0.55),
	NumberSequenceKeypoint.new(1, 0.1),
})
fade.Parent = shade
shade.Parent = screen

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 90)
title.Position = UDim2.new(0, 0, 1, -230)
title.BackgroundTransparency = 1
title.FontFace = HEADER
title.Text = "EMBER OUTPOST"
title.TextSize = 72
title.TextColor3 = TEXT
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.TextStrokeTransparency = 0.4
title.Parent = screen

local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(0.7, 0, 0, 30)
tip.Position = UDim2.new(0.15, 0, 1, -130)
tip.BackgroundTransparency = 1
tip.FontFace = BODY
tip.TextSize = 22
tip.TextColor3 = TEXT
tip.TextWrapped = true
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = screen

local track = Instance.new("Frame")
track.Size = UDim2.new(0.4, 0, 0, 8)
track.Position = UDim2.new(0.3, 0, 1, -80)
track.BackgroundColor3 = PANEL
track.BorderSizePixel = 0
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.02, 1)
fill.BackgroundColor3 = EMBER
fill.BorderSizePixel = 0
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill
fill.Parent = track
track.Parent = screen

-- The build in the corner (LDOE_PARITY #58), so a capture or bug report names its version.
local version = Instance.new("TextLabel")
version.Size = UDim2.fromOffset(240, 20)
version.Position = UDim2.new(1, -16, 1, -12)
version.AnchorPoint = Vector2.new(1, 1)
version.BackgroundTransparency = 1
version.FontFace = BODY
version.TextSize = 14
version.TextColor3 = TEXT
version.TextTransparency = 0.35
version.TextXAlignment = Enum.TextXAlignment.Right
version.Text = `M1 build {game.PlaceVersion}`
version.Parent = screen

screen.Parent = playerGui

-- Ready when the game has loaded, the survivor exists and the HUD has mounted.
local function ready(): boolean
	return game:IsLoaded() and player.Character ~= nil and playerGui:FindFirstChild("App") ~= nil
end

local started = os.clock()
local peakQueue = 1
local nextTip = os.clock() + TIP_SECONDS
local shown = 0.02
while not ready() and os.clock() - started < MAX_SECONDS do
	local queue = ContentProvider.RequestQueueSize
	peakQueue = math.max(peakQueue, queue)
	local loaded = 1 - queue / peakQueue
	local target = math.clamp(0.1 + loaded * 0.75 + (if game:IsLoaded() then 0.1 else 0), 0.02, 0.95)
	shown += (target - shown) * 0.2
	fill.Size = UDim2.fromScale(shown, 1)
	if os.clock() >= nextTip then
		nextTip = os.clock() + TIP_SECONDS
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
	task.wait(0.1)
end

fill.Size = UDim2.fromScale(1, 1)
task.wait(0.25)
local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, object in screen:GetDescendants() do
	if object:IsA("TextLabel") then
		TweenService:Create(object, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif object:IsA("ImageLabel") then
		TweenService:Create(object, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
	elseif object:IsA("Frame") then
		TweenService:Create(object, info, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.7)
screen:Destroy()
