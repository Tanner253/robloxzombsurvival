--!strict
--[[
	ModelView: renders a copy of a model in a ViewportFrame, framed from the
	upper left (the icon style's light direction, ART_DIRECTION.md §8). Used for
	rendered 3D item icons and build-menu thumbnails.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Props = {
	model: Model,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	yaw: number?, -- degrees around the model, default 35
	pitch: number?, -- degrees above, default 28
	zIndex: number?,
}

local FOV = 30
local AMBIENT = Color3.fromRGB(150, 140, 128)
local LIGHT = Color3.fromRGB(255, 236, 214)

local function ModelView(props: Props)
	local frameRef = React.useRef(nil :: ViewportFrame?)

	React.useEffect(function()
		local frame = frameRef.current
		if frame == nil then
			return function() end
		end
		local copy = props.model:Clone()
		local cf, size = copy:GetBoundingBox()
		local radius = math.max(size.Magnitude / 2, 0.1)
		local distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
		local yaw, pitch = math.rad(props.yaw or 35), math.rad(props.pitch or 28)
		local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		local camera = Instance.new("Camera")
		camera.FieldOfView = FOV
		camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
		camera.Parent = frame
		frame.CurrentCamera = camera
		copy.Parent = frame
		return function()
			copy:Destroy()
			camera:Destroy()
		end
	end, { props.model })

	return React.createElement("ViewportFrame", {
		ref = frameRef,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Ambient = AMBIENT,
		LightColor = LIGHT,
		LightDirection = Vector3.new(-1, -1.2, -0.6),
		ZIndex = props.zIndex,
	})
end

return ModelView
