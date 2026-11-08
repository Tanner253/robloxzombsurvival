--!strict
--[[
	conform_pivots: authored pivots for placeable kit models (checklist 6.12). Every
	placeable's pivot sits at the centre of its base with up = +Y, and its LookVector
	points out of its working side (the side you stand at), because placement puts a
	piece's back (+Z of its pivot) against the wall behind it.

	FRONT lists, per kit model, the model-space direction its working side faces, read
	from close captures (the workbench's vice handle sticks out on -X). The pivot keeps
	its place and orientation (LookVector -Z, up +Y at the base centre); the script turns
	the model's parts about that base centre so the working side ends up facing -Z, and
	writes place/kit/EO_Kit.rbxm. A model already facing -Z is left alone.

	Usage (from roblox/): lune run tools/conform_pivots.luau
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local FRONT: { [string]: any } = {
	-- Workbench: its vice handle and tool shelf were on the -X long side; turned 2026-11-08.
	Workbench = Vector3.new(0, 0, -1),
	-- After a run, set an entry to Vector3.new(0, 0, -1): the model now faces -Z.
}

local PATH = "place/kit/EO_Kit.rbxm"
local roots = roblox.deserializeModel(fs.readFile(PATH))
local kit = roots[1]

local changed = 0
for name, front in FRONT do
	local model = kit:FindFirstChild(name, true)
	if model == nil then
		print(`missing {name}`)
		continue
	end
	if (front - Vector3.new(0, 0, -1)).Magnitude < 1e-3 then
		print(`{name}: already faces -Z`)
		continue
	end
	-- The base centre: bottom of the parts' bounds, centred in X and Z (the kit pivots
	-- sit there; Studio showed the box centre straight above the pivot).
	local lo, hi
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			local p = part.CFrame.Position
			local extent = Vector3.new(
				math.abs(part.CFrame.RightVector.X) * half.X + math.abs(part.CFrame.UpVector.X) * half.Y + math.abs(part.CFrame.LookVector.X) * half.Z,
				math.abs(part.CFrame.RightVector.Y) * half.X + math.abs(part.CFrame.UpVector.Y) * half.Y + math.abs(part.CFrame.LookVector.Y) * half.Z,
				math.abs(part.CFrame.RightVector.Z) * half.X + math.abs(part.CFrame.UpVector.Z) * half.Y + math.abs(part.CFrame.LookVector.Z) * half.Z
			)
			lo = if lo then lo:Min(p - extent) else p - extent
			hi = if hi then hi:Max(p + extent) else p + extent
		end
	end
	local base = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	-- Turn about +Y so `front` maps onto -Z.
	local angle = math.atan2(front.X, front.Z) - math.atan2(0, -1)
	local turn = CFrame.new(base) * CFrame.Angles(0, -angle, 0) * CFrame.new(-base)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = turn * part.CFrame
		end
	end
	changed += 1
	print(`{name}: turned so its working side ({front}) faces -Z`)
end
if changed > 0 then
	fs.writeFile(PATH, roblox.serializeModel(roots))
end
print(`{changed} pivots changed`)
