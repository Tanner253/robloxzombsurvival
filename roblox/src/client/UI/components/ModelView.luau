--!strict
--[[
	ModelView: renders a copy of a real in-game model in a ViewportFrame (checklist
	4.16: UI pictures are rendered from the model the player sees, never painted
	separately). Every rendered picture shares one camera and one light, framed from
	the upper left (the icon style's light direction, ART_DIRECTION.md §8): item
	slots, recipe cards, build cards and station headers. Live, so a changed model
	re-renders by itself.

	A `pose` (a held item's butt-to-head axis and edge, Shared/Art.held) lays tools
	and weapons on the icon diagonal, head up and to the right, flat side to the
	camera. The camera is fitted to the model's box, not its bounding sphere, so long
	thin things fill the frame.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Pose = { axis: Vector3, edge: Vector3 }

export type Props = {
	model: Model,
	pose: Pose?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	margin: number?, -- framing slack, default 1.04
}

-- The one icon camera and light.
local FOV = 30
local YAW = math.rad(35)
local PITCH = math.rad(28)
local AMBIENT = Color3.fromRGB(128, 120, 112)
local LIGHT = Color3.fromRGB(255, 246, 232)

local BACK = Vector3.new(math.sin(YAW) * math.cos(PITCH), math.sin(PITCH), math.cos(YAW) * math.cos(PITCH))
local RIGHT = (-BACK):Cross(Vector3.yAxis).Unit
local UP = RIGHT:Cross(-BACK).Unit
-- Key light from the upper left and in front, as in the painted set.
local LIGHT_DIRECTION = (RIGHT * 0.7 - UP - BACK * 0.6).Unit

-- A posed item is framed by its length (the model box is far fatter than a diagonal
-- handle): about this wide across and deep, as fractions of the length.
local POSED_WIDTH = 0.24
local POSED_DEPTH = 0.2

-- Turns a posed model so its axis runs along the screen diagonal (up-right) and its
-- flat side faces the camera. Returns its length along the axis.
local function posed(model: Model, pose: Pose): number
	local axis = pose.axis.Unit
	local edge = (pose.edge - axis * pose.edge:Dot(axis)).Unit
	local from = CFrame.fromMatrix(Vector3.zero, axis, edge, axis:Cross(edge))
	local along = (RIGHT + UP).Unit
	local across = (UP - RIGHT).Unit
	local to = CFrame.fromMatrix(Vector3.zero, along, across, along:Cross(across))
	model:PivotTo(CFrame.identity)
	local _, size = model:GetBoundingBox()
	model:PivotTo(to * from:Inverse())
	return math.abs(axis.X) * size.X + math.abs(axis.Y) * size.Y + math.abs(axis.Z) * size.Z
end

-- The camera distance for a posed item of `length`: the handle on the diagonal plus
-- its width across, in frame.
local function fitPosed(length: number, aspect: number, margin: number): number
	local tanV = math.tan(math.rad(FOV / 2))
	local half = length / 2 * math.sqrt(0.5) + length * POSED_WIDTH / 2 * math.sqrt(0.5)
	return (length * POSED_DEPTH / 2 + math.max(half / (tanV * aspect), half / tanV)) * margin
end

-- How far back the camera sits so every corner of the box is in frame.
local function fitDistance(model: Model, aspect: number, margin: number): (Vector3, number)
	local box, size = model:GetBoundingBox()
	local centre = box.Position
	local tanV = math.tan(math.rad(FOV / 2))
	local tanH = tanV * aspect
	local need = 0.1
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = box * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2) - centre
				local x, y, z = corner:Dot(RIGHT), corner:Dot(UP), corner:Dot(BACK)
				need = math.max(need, z + math.abs(x) / tanH, z + math.abs(y) / tanV)
			end
		end
	end
	return centre, need * margin
end

-- Poses the copy when asked and returns where the camera looks and how far back it sits.
local function frameFor(copy: Model, pose: Pose?, aspect: number, margin: number): (Vector3, number)
	if pose then
		local length = posed(copy, pose)
		return copy:GetBoundingBox().Position, fitPosed(length, aspect, margin)
	end
	return fitDistance(copy, aspect, margin)
end

local function ModelView(props: Props)
	local frameRef = React.useRef(nil :: ViewportFrame?)

	React.useEffect(function()
		local frame = frameRef.current
		if frame == nil then
			return function() end
		end
		local copy = props.model:Clone()
		local absolute = frame.AbsoluteSize
		local aspect = if absolute.X > 0 and absolute.Y > 0 then absolute.X / absolute.Y else 1
		local margin = props.margin or 1.04
		local centre, distance = frameFor(copy, props.pose, aspect, margin)
		local camera = Instance.new("Camera")
		camera.FieldOfView = FOV
		camera.CFrame = CFrame.lookAt(centre + BACK * distance, centre)
		camera.Parent = frame
		frame.CurrentCamera = camera
		copy.Parent = frame
		-- A texture that isn't cached yet never shows in a ViewportFrame (it doesn't fall back
		-- to the baseline image the world uses: fresh uploads drew grey, batch 4b). Load the
		-- copy's content, then put it back in the frame so it draws with it.
		local live = true
		task.spawn(function()
			local ok = pcall(function()
				ContentProvider:PreloadAsync({ copy })
			end)
			if ok and live and copy.Parent == frame then
				copy.Parent = nil
				copy.Parent = frame
			end
		end)
		return function()
			live = false
			copy:Destroy()
			camera:Destroy()
		end
	end, { props.model, props.pose } :: { any })

	return React.createElement("ViewportFrame", {
		ref = frameRef,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Ambient = AMBIENT,
		LightColor = LIGHT,
		LightDirection = LIGHT_DIRECTION,
		ZIndex = props.zIndex,
	})
end

return ModelView
