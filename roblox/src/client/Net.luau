--!strict
--[[
	Net (client): sends intents to the server and listens for server events.
	Only names declared in Shared/Net/Remotes are accepted. Everything sent is a
	request; the server validates and decides (ARCHITECTURE.md §8).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Net = {}

local folder = ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME)

local function remote(name: string, kind: Remotes.RemoteKind): Instance
	local decl = Remotes.get(name)
	assert(decl.kind == kind, `Remote '{name}' is a {decl.kind}, not a {kind}`)
	return folder:WaitForChild(name)
end

-- Sends a client-to-server event.
function Net.fire(name: string, ...: any)
	assert(Remotes.get(name).clientCanSend, `Remote '{name}' is server-to-client only`)
	local event = remote(name, "event") :: RemoteEvent
	event:FireServer(...)
end

-- Calls a client-to-server function and yields for the reply.
function Net.invoke(name: string, ...: any): ...any
	return (remote(name, "function") :: RemoteFunction):InvokeServer(...)
end

-- Listens to a server-to-client event. Returns the connection.
function Net.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	return (remote(name, "event") :: RemoteEvent).OnClientEvent:Connect(handler)
end

return Net
