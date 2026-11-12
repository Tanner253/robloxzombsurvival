--!strict
--[[
	Interiors: marks the buildings you can stand inside, where they're built, so the
	client's roof fade (Controllers/RoofFade, Domain/Interior) knows what to lift without
	guessing.

	- `mark` writes the footprint (floor centre and yaw, width, roof height, depth) on the
	  building and tags it; call it once the building is complete.
	- `roof` tags a holder or part as roof: hidden while you're inside, ghosted when it
	  hides you from the camera.
	- `wall` tags a wall side with its outward normal: ghosted while you're inside when it
	  faces the camera.

	Users: FogRuns/Maps/Builder (every enterable building and porch), ZoneDress (lookout
	towers), Rustwater (the gas station canopy), World/Haven (market stalls and sheds).
	Player-built bases have no roof piece yet (Data/BuildPieces has no roof kind); Grid's
	"roof" layer would call `roof` from Services/Building when one is added.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interior = require(ReplicatedStorage.Shared.Domain.Interior)

local Interiors = {}

-- `floor`: the floor's centre (its top) with the building's yaw; any tilt is dropped.
function Interiors.mark(building: Instance, floor: CFrame, width: number, depth: number, height: number)
	local _, yaw = floor:ToEulerAnglesYXZ()
	building:SetAttribute(Interior.FLOOR_ATTR, CFrame.new(floor.Position) * CFrame.Angles(0, yaw, 0))
	building:SetAttribute(Interior.SIZE_ATTR, Vector3.new(width, height, depth))
	CollectionService:AddTag(building, Interior.TAG)
end

function Interiors.roof(instance: Instance)
	CollectionService:AddTag(instance, Interior.ROOF_TAG)
end

-- `outward`: the wall's outward normal in world space (only its flat part is used).
function Interiors.wall(instance: Instance, outward: Vector3)
	local flat = Vector3.new(outward.X, 0, outward.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	instance:SetAttribute(Interior.FACING_ATTR, flat.Unit)
	CollectionService:AddTag(instance, Interior.WALL_TAG)
end

return Interiors
