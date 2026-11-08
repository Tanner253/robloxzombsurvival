--!strict
--[[
	Stores: opens ProfileStore stores with the environment rule in one place
	(Domain/DataSafety): live servers use the real DataStore names, Studio always uses
	"<name>_Studio", so playtests never touch live saves. Without Studio API access
	ProfileStore falls back to its in-memory mock by itself ("data will not be saved").

	Every store opened is remembered for the startup audit (Stores.opened).
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local DataSafety = require(ReplicatedStorage.Shared.Domain.DataSafety)

local Stores = {}

-- Each store opened: its base name and the DataStore name it opened.
Stores.opened = {} :: { { base: string, opened: string } }

-- Opens the store `name` with `template` as its profile template.
function Stores.open(name: string, template: any): any
	local opened = DataSafety.storeName(name, RunService:IsStudio())
	table.insert(Stores.opened, { base = name, opened = opened })
	return ProfileStore.New(opened, template)
end

return Stores
