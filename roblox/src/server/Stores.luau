--!strict
--[[
	Stores: opens ProfileStore stores with the Studio rule in one place.

	In Studio, stores use ProfileStore's in-memory mock so playtests never touch
	live saves. To test real save and load across play sessions, set the
	boolean attribute `PersistStudioSaves = true` on Workspace in the place:
	Studio then uses separate "<name>_Studio" DataStores (Studio API access
	must be on), still never the live ones.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)

local Stores = {}

-- Opens (or mocks) the store `name` with `template` as its profile template.
function Stores.open(name: string, template: any): any
	if not RunService:IsStudio() then
		return ProfileStore.New(name, template)
	end
	if workspace:GetAttribute("PersistStudioSaves") == true then
		return ProfileStore.New(`{name}_Studio`, template)
	end
	return ProfileStore.New(name, template).Mock
end

return Stores
