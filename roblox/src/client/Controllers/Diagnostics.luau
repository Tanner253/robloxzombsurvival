--!strict
-- Diagnostics: in Studio, pings the server once at start to prove Net works end to end.

local RunService = game:GetService("RunService")

local Net = require("../Net")

local Diagnostics = {}

function Diagnostics.start()
	if not RunService:IsStudio() then
		return
	end
	local nonce = math.random(0, 2 ^ 31 - 1)
	local sentAt = os.clock()
	local echoed, serverTime = Net.invoke("Ping", nonce)
	if echoed == nonce then
		print(`[Net] Ping OK: {math.round((os.clock() - sentAt) * 1000)} ms, server time {serverTime}`)
	else
		warn("[Net] Ping failed: nonce mismatch or request rejected")
	end
end

return Diagnostics
