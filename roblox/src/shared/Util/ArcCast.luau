--!strict
--[[
	ArcCast: the one raycast a thrown arc uses, on the server (Services/Throwables, which decides
	where it lands) and on the client (Controllers/Throwing, which previews it), so both stop the
	arc on the same things.

	A cast passes through what doesn't collide (RespectCanCollide: tree crowns) and through
	see-through volumes (Domain/Throw.solid: invisible markers, exit edges, trigger boxes), and
	the caller's params leave out the survivors and the client's Hollow views. Batch 5's
	"lands short" throws stopped on geometry the player couldn't see or didn't expect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Throw = require(ReplicatedStorage.Shared.Domain.Throw)

local ArcCast = {}

local PASSES = 6 -- see-through parts skipped on one segment before giving up

function ArcCast.cast(from: Vector3, to: Vector3, params: RaycastParams): RaycastResult?
	local skipped: { Instance } = {}
	local base = params.FilterDescendantsInstances
	for _ = 1, PASSES do
		local hit = workspace:Raycast(from, to - from, params)
		if hit == nil then
			break
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or Throw.solid(part.Transparency) then
			params.FilterDescendantsInstances = base
			return hit
		end
		table.insert(skipped, part)
		local list = table.clone(base)
		for _, extra in skipped do
			table.insert(list, extra)
		end
		params.FilterDescendantsInstances = list
	end
	params.FilterDescendantsInstances = base
	return nil
end

-- The full name of what a cast hit, for scripted checks.
function ArcCast.describe(hit: RaycastResult?): string?
	return if hit then hit.Instance:GetFullName() else nil
end

return ArcCast
