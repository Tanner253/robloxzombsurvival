--!strict
--[[
	flyIcon: an item's icon pops out of the world where it was gathered and flies
	into the Bag button (LDoE-style yield feedback). Purely visual; drawn in its
	own ScreenGui above the HUD so React never has to know about it.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Content = require(ReplicatedStorage.Shared.Data)

local ICON_SIZE = 44
local FLIGHT_SECONDS = 0.55

local layer: ScreenGui? = nil

local function screen(): ScreenGui?
	if layer and layer.Parent then
		return layer
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local made = Instance.new("ScreenGui")
	made.Name = "EO_FlyLayer"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.DisplayOrder = 50
	made.Parent = playerGui
	layer = made
	return made
end

-- The Bag button's centre on screen, or the bottom right corner if it isn't drawn.
local function bagCentre(): Vector2
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local app = playerGui and playerGui:FindFirstChild("App")
	local bag = app and app:FindFirstChild("Bag", true)
	if bag and bag:IsA("GuiObject") and bag.AbsoluteSize.X > 0 then
		local centre = bag.AbsolutePosition + bag.AbsoluteSize / 2
		if app and app:IsA("ScreenGui") and not app.IgnoreGuiInset then
			centre += GuiService:GetGuiInset() -- this layer ignores the inset; App doesn't
		end
		return centre
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1366, 768)
	return Vector2.new(view.X - 80, view.Y - 80)
end

return function(itemId: string, from: Vector3, delay: number?)
	local def = Content.Items[itemId]
	local camera = workspace.CurrentCamera
	local gui = screen()
	if def == nil or def.icon == "" or camera == nil or gui == nil then
		return
	end
	task.delay(delay or 0, function()
		local point, onScreen = camera:WorldToViewportPoint(from)
		if not onScreen then
			return
		end
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = def.icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromOffset(ICON_SIZE * 0.4, ICON_SIZE * 0.4)
		icon.Position = UDim2.fromOffset(point.X, point.Y)
		icon.Parent = gui
		-- Pop up, then arc into the bag and shrink.
		local up = UDim2.fromOffset(point.X, point.Y - 46)
		TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			Position = up,
		}):Play()
		task.delay(0.22, function()
			local target = bagCentre()
			local flight = TweenService:Create(
				icon,
				TweenInfo.new(FLIGHT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(target.X, target.Y),
					Size = UDim2.fromOffset(ICON_SIZE * 0.5, ICON_SIZE * 0.5),
				}
			)
			flight.Completed:Once(function()
				icon:Destroy()
			end)
			flight:Play()
		end)
	end)
end
