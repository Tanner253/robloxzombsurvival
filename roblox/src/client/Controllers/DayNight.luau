--!strict
--[[
	DayNight: runs the day/night cycle on the client from Shared/Clock (server time,
	so every player sees the same hour) and keeps exposure stable through it
	(PLAYER_EXPERIENCE_CHECKLIST 9.5): every lighting value eases between a day
	and a night keyframe with the clock's smooth `daylight`, with a warm tint
	around dawn and dusk. Nothing jumps.

	- Night is dark but readable, like LDoE's (rec6_04, LDOE_PARITY #32): a cool blue
	  moonlight wash, a desaturated grade so the ground reads blue-grey instead of murky
	  olive, and a cool rim light on your own survivor. Warm light at night comes only from
	  fires and torches, so their pools stand out (1.7).
	- "Night is coming" at 18:30 and "Dawn breaks" at 06:00 (8.5).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Sfx = require("../Sfx")
local State = require("../State")

local DayNight = {}

local player = Players.LocalPlayer

type Key = {
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoor: Color3,
	tint: Color3,
	saturation: number,
	contrast: number,
	shift: Color3, -- Lighting.ColorShift_Top: the sun's or the moon's colour
	haze: Color3,
	decay: Color3,
}

local DAY: Key = {
	brightness = 2.6,
	exposure = 0.3, -- QA2: midday read murky next to LDoE's bright, warm noon
	ambient = Color3.fromRGB(66, 70, 80),
	outdoor = Color3.fromRGB(118, 124, 134),
	tint = Color3.fromRGB(244, 246, 250),
	saturation = -0.2,
	contrast = 0.12,
	shift = Color3.fromRGB(240, 236, 228),
	haze = Color3.fromRGB(182, 188, 194),
	decay = Color3.fromRGB(104, 118, 134),
}
local NIGHT: Key = {
	brightness = 1.7,
	exposure = 1.1,
	-- Blue moonlight fill: trees, nodes and the base stay readable at night (rec6_04).
	ambient = Color3.fromRGB(96, 106, 170),
	outdoor = Color3.fromRGB(140, 154, 240),
	tint = Color3.fromRGB(146, 164, 255),
	saturation = -0.7,
	contrast = 0.06,
	shift = Color3.fromRGB(150, 172, 240),
	haze = Color3.fromRGB(46, 54, 72),
	decay = Color3.fromRGB(34, 40, 58),
}
local DUSK_TINT = Color3.fromRGB(255, 212, 172) -- golden hour, strongest mid-transition
-- A soft light on your own survivor: by night a cool moonlit rim keeps you readable in the
-- dark (LDoE lights the survivor blue, not with a warm pool); by day a smaller, warm one
-- lifts the shadowed side so you never sink into the ground (2.2).
local READ_LIGHT = {
	color = Color3.fromRGB(176, 198, 255),
	range = 16,
	brightness = 1.1,
	dayColor = Color3.fromRGB(255, 214, 170),
	dayRange = 7,
	dayBrightness = 0.45,
}

local cues = {
	{ hour = 18.5, text = "Night is coming. Keep your fire fed.", tone = "warn" },
	{ hour = 6, text = "Dawn breaks.", tone = "good" },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function find(className: string): Instance?
	return Lighting:FindFirstChildOfClass(className)
end

local readLight: PointLight? = nil

local function readabilityLight(): PointLight?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil
	end
	if readLight and readLight.Parent == root then
		return readLight
	end
	local light = Instance.new("PointLight")
	light.Name = "EO_ReadLight"
	light.Color = READ_LIGHT.color
	light.Range = READ_LIGHT.range
	light.Shadows = false
	light.Brightness = 0
	light.Parent = root
	readLight = light
	return light
end

local function apply(hours: number)
	local day = Clock.daylight(hours)
	local t = 1 - day -- 0 day, 1 night
	local golden = math.sin(day * math.pi) * 0.5 -- peaks at the middle of dawn and dusk
	Lighting.ClockTime = Clock.sunTime(hours)
	Lighting.Brightness = lerp(DAY.brightness, NIGHT.brightness, t)
	Lighting.ExposureCompensation = lerp(DAY.exposure, NIGHT.exposure, t)
	Lighting.Ambient = DAY.ambient:Lerp(NIGHT.ambient, t)
	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(NIGHT.outdoor, t)
	Lighting.ColorShift_Top = DAY.shift:Lerp(NIGHT.shift, t):Lerp(DUSK_TINT, golden * 0.5)
	local grade = find("ColorCorrectionEffect") :: ColorCorrectionEffect?
	if grade then
		grade.TintColor = DAY.tint:Lerp(NIGHT.tint, t):Lerp(DUSK_TINT, golden * 0.35)
		grade.Saturation = lerp(DAY.saturation, NIGHT.saturation, t)
		grade.Contrast = lerp(DAY.contrast, NIGHT.contrast, t)
	end
	local atmosphere = find("Atmosphere") :: Atmosphere?
	if atmosphere then
		atmosphere.Color = DAY.haze:Lerp(NIGHT.haze, t):Lerp(DUSK_TINT, golden * 0.25)
		atmosphere.Decay = DAY.decay:Lerp(NIGHT.decay, t)
	end
	local light = readabilityLight()
	if light then
		light.Brightness = READ_LIGHT.dayBrightness + (READ_LIGHT.brightness - READ_LIGHT.dayBrightness) * t
		light.Range = READ_LIGHT.dayRange + (READ_LIGHT.range - READ_LIGHT.dayRange) * t
		light.Color = READ_LIGHT.dayColor:Lerp(READ_LIGHT.color, t)
		light.Enabled = t > 0.01
	end
end

function DayNight.start()
	local lastHours = Clock.hoursAt(State.now())
	local studio = RunService:IsStudio()
	RunService.RenderStepped:Connect(function()
		local hours = Clock.hoursAt(State.now())
		-- Studio only: Workspace attribute ClockOverride (hours) pins the time for captures.
		local override = if studio then workspace:GetAttribute("ClockOverride") else nil
		if type(override) == "number" then
			hours = override % 24
			apply(hours)
			lastHours = hours
			return -- a pinned clock fires no dusk/dawn cues
		end
		apply(hours)
		for _, cue in cues do
			local crossed = if hours >= lastHours
				then lastHours < cue.hour and hours >= cue.hour
				else lastHours < cue.hour or hours >= cue.hour
			if crossed then
				State.notify(cue.text, cue.tone :: any)
				Sfx.play(if cue.tone == "warn" then "uiError" else "reward", nil, 0.6)
			end
		end
		lastHours = hours
	end)
end

return DayNight
