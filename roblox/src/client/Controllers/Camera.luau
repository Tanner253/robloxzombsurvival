--!strict
--[[
	Camera: the fixed angled top-down camera (GAME_DESIGN.md "Camera"): about 55°
	pitch, a fixed 45° yaw and smooth follow. Zoom (checklist 2.2): the mouse wheel,
	a touch pinch or holding + / -, eased, from close (the survivor about a quarter of
	the screen tall) out to far (a large part of the map). Build mode has its own range
	and zoom. Both zooms are remembered for the session (respawns keep them).
	`shake` adds a short decaying jolt for impacts.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local State = require("../State")

local Camera = {}

local PITCH = math.rad(55)
local YAW = math.rad(45)
local FOV = 45
-- Zoom ranges (camera distance in studs). At 31 the survivor stands about 1/7 of the
-- screen; the on-screen size goes as 1/distance, so 16 puts them at about a quarter.
local PLAY_RANGE = { min = 16, max = 150, default = 31 }
local BUILD_RANGE = { min = 28, max = 170, default = 52 } -- an overview of the plot
-- In Fog Run lobbies the zoom clamps near LDoE framing, the survivor about 1/8 of the
-- screen (LDOE_PARITY #12: fair sight lines once PvP arrives).
local LOBBY_RANGE = { min = 26, max = 44, default = 34 }
local lobbyClamp = false
local WHEEL_STEP = 0.14 -- one wheel notch changes the distance by 14% (even steps near and far)
local KEY_RATE = 1.1 -- holding + / - changes it by about 110% a second
local FOLLOW_RATE = 10
local ZOOM_RATE = 9
local SHAKE_DECAY = 7

-- The wanted distance per mode, kept for the session.
local targets: { [string]: number } = { play = PLAY_RANGE.default, build = BUILD_RANGE.default }
local zoom = PLAY_RANGE.default
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

type Range = { min: number, max: number, default: number }

local function mode(): string -- "play" or "build"
	if State.ui().panel == "build" then
		return "build"
	end
	return "play"
end

local function rangeFor(which: string): Range
	if which == "build" then
		return BUILD_RANGE
	end
	return if lobbyClamp then LOBBY_RANGE else PLAY_RANGE
end

-- On a Fog Run the play zoom is clamped (FogRun turns it on at arrival and off at home).
function Camera.setLobbyClamp(on: boolean)
	lobbyClamp = on
	local range = rangeFor("play")
	targets.play = math.clamp(if on then LOBBY_RANGE.default else targets.play, range.min, range.max)
end

-- Multiplies the current mode's wanted distance (below 1 zooms in), within its range.
function Camera.zoomBy(factor: number)
	local which = mode()
	local range = rangeFor(which)
	targets[which] = math.clamp(targets[which] * factor, range.min, range.max)
end

-- The current mode's wanted distance and range (for tests and the Studio capture hooks).
function Camera.zoomState(): (number, number, number)
	local range = rangeFor(mode())
	return targets[mode()], range.min, range.max
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
	-- Holding + / - (or the keypad's) zooms smoothly.
	local held = 0
	if not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.Equals) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadPlus) then
			held -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Minus) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadMinus) then
			held += 1
		end
	end
	if held ~= 0 then
		Camera.zoomBy(math.exp(held * KEY_RATE * dt))
	end
	local wanted = targets[mode()]
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
	-- The camera is scripted, but keep Roblox's own limits out of the way of our range.
	player.CameraMaxZoomDistance = math.max(PLAY_RANGE.max, BUILD_RANGE.max)
	player.CameraMinZoomDistance = math.min(PLAY_RANGE.min, BUILD_RANGE.min)
	RunService:BindToRenderStep("EmberCamera", Enum.RenderPriority.Camera.Value + 1, step)

	-- The wheel zooms anywhere in the world; a scrolling list under the mouse keeps it
	-- (the event arrives processed then).
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			Camera.zoomBy(1 - input.Position.Z * WHEEL_STEP)
		end
	end)
	local pinchStart = targets[mode()]
	UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, inputState, processed)
		if processed then
			return
		end
		if inputState == Enum.UserInputState.Begin then
			pinchStart = targets[mode()]
		end
		local range = rangeFor(mode())
		targets[mode()] = math.clamp(pinchStart / math.max(scale, 0.1), range.min, range.max)
	end)
end

return Camera
