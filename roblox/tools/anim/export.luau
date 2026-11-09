--[[
	Exports what the offline animation preview needs (tools/anim/preview.py):
	- the survivor rig from place/kit/StarterCharacter.rbxm: each part's size and each
	  joint's attachments (AnimationConstraint Attachment0 on the parent, Attachment1 on
	  the child), plus the right-hand grip attachment;
	- every move built by Domain/MeleeKeys (both the full-body and the upper-body
	  variant), with the marks from Domain/MeleeTiming.

	Usage (from roblox/): lune run tools/anim/export.luau <out.json>
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local MeleeKeys = require("../../src/shared/Domain/MeleeKeys")
local MeleeTiming = require("../../src/shared/Domain/MeleeTiming")

local out = process.args[1] or "anim_export.json"

local function components(c: any): { number }
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local model = roblox.deserializeModel(fs.readFile("place/kit/StarterCharacter.rbxm"))[1]
local parts = {}
local joints = {}
local grip = nil
local leftGrip = nil
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		parts[d.Name] = { size = { d.Size.X, d.Size.Y, d.Size.Z } }
	elseif d.ClassName == "AnimationConstraint" then
		local a0, a1 = d.Attachment0, d.Attachment1
		if a0 and a1 then
			joints[a1.Parent.Name] = {
				parent = a0.Parent.Name,
				c0 = components(a0.CFrame),
				c1 = components(a1.CFrame),
			}
		end
	elseif d:IsA("Attachment") and d.Name == "RightGripAttachment" then
		grip = components(d.CFrame)
	elseif d:IsA("Attachment") and d.Name == "LeftGripAttachment" then
		leftGrip = components(d.CFrame)
	end
end

local moves = {}
for _, id in MeleeKeys.ids() do
	moves[id] = {
		full = MeleeKeys.build(id, "full"),
		upper = MeleeKeys.build(id, "upper"),
		marks = MeleeTiming.marksOf(id),
	}
end

fs.writeFile(
	out,
	serde.encode("json", {
		rig = { parts = parts, joints = joints, grip = grip, leftGrip = leftGrip },
		moves = moves,
	}, false)
)
print(`wrote {out}`)
