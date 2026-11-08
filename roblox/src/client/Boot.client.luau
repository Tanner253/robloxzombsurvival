--!strict
-- Client entry point: init() every controller in Controllers/, then start() them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Lifecycle"))

Lifecycle.boot(script.Parent:WaitForChild("Controllers"), "Client")
