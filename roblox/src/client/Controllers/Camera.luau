--!strict
--[[
	Camera: the fixed angled top-down camera (GAME_DESIGN.md "Camera"): about 55°
	pitch, a fixed 45° yaw, smooth follow, and zoom with the mouse wheel or a
	pinch. Build mode eases out a little for an overview. `shake` adds a short
	decaying jolt for impacts.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require("../State")

local Camera = {}

local PITCH = math.rad(55)
local YAW = math.rad(45)
local FOV = 45
local ZOOM_DEFAULT = 30 -- a room and its surroundings fit; the survivor about 1/7 of the screen (2.2)
local ZOOM_MIN = 18
local ZOOM_MAX = 70
local ZOOM_STEP = 5
local BUILD_EXTRA = 12
local FOLLOW_RATE = 10
local ZOOM_RATE = 9
local SHAKE_DECAY = 7

local zoomTarget = ZOOM_DEFAULT
local zoom = ZOOM_DEFAULT
local focus: Vector3? = nil
local shakeAmount = 0

-- A short camera jolt; `amount` is in studs (0.3 is a firm hit).
local shakeEnabled = true

function Camera.shake(amount: number)
	if shakeEnabled then
		shakeAmount = math.max(shakeAmount, amount)
	end
end

-- The "Camera shake" setting (Controllers/Preferences).
function Camera.setShakeEnabled(enabled: boolean)
	shakeEnabled = enabled
	if not enabled then
		shakeAmount = 0
	end
end

-- The camera's yaw, for camera-relative input (touch build cursor, aiming).
function Camera.yaw(): number
	return YAW
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if camera == nil or root == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FOV

	-- Studio only: a fixed camera for close-up captures (Workspace attribute CaptureCam).
	local capture = if RunService:IsStudio() then workspace:GetAttribute("CaptureCam") else nil
	if typeof(capture) == "CFrame" then
		camera.CFrame = capture
		return
	end

	local target = root.Position
	focus = if focus then (focus :: Vector3):Lerp(target, 1 - math.exp(-FOLLOW_RATE * dt)) else target
	local wanted = zoomTarget + (if State.ui().panel == "build" then BUILD_EXTRA else 0)
	zoom += (wanted - zoom) * (1 - math.exp(-ZOOM_RATE * dt))

	local rotation = CFrame.Angles(0, YAW, 0) * CFrame.Angles(-PITCH, 0, 0)
	local f = focus :: Vector3
	local cframe = CFrame.new(f) * rotation * CFrame.new(0, 0, zoom)

	if shakeAmount > 0.001 then
		local t = os.clock() * 40
		cframe *= CFrame.new(math.noise(t, 0) * shakeAmount, math.noise(0, t) * shakeAmount, 0)
		shakeAmount *= math.exp(-SHAKE_DECAY * dt)
	end
	camera.CFrame = cframe
	camera.Focus = CFrame.new(f)
end

function Camera.start()
	local player = Players.LocalPlayer
	player.CameraMaxZoomDistance = ZOOM_MAX
	player.CameraMinZoomDistance = ZOOM_MIN
	RunService:BindToRenderStep("EmberCamera", Enum.RenderPriority.Camera.Value + 1, step)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			-- The plain wheel cycles the hotbar (Input); Ctrl+wheel zooms.
			if
				UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			then
				zoomTarget = math.clamp(zoomTarget - input.Position.Z * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			end
		end
	end)
	local pinchStart = zoomTarget
	UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, inputState, processed)
		if processed then
			return
		end
		if inputState == Enum.UserInputState.Begin then
			pinchStart = zoomTarget
		end
		zoomTarget = math.clamp(pinchStart / math.max(scale, 0.1), ZOOM_MIN, ZOOM_MAX)
	end)
end

return Camera
