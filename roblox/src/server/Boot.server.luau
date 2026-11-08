--!strict
--[[
	Server entry point.
	1. Validate all content (a broken reference stops the server here).
	2. Create every declared remote.
	3. init() every service in Services/, then start() them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Content = require(Shared.Data)
local DataValidator = require(Shared.Domain.DataValidator)
local Lifecycle = require(Shared.Util.Lifecycle)
local Net = require(script.Parent.Net)

local errors = DataValidator.validate(Content)
if #errors > 0 then
	error(`Content validation failed ({#errors}):\n` .. table.concat(errors, "\n"), 0)
end

Net.setup()
Lifecycle.boot(script.Parent.Services, "Server")
