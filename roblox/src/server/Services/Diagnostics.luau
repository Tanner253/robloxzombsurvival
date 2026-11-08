--!strict
-- Diagnostics: answers the example Ping remote so clients can check Net end to end.

local Net = require("../Net")

local Diagnostics = {}

function Diagnostics.init()
	Net.onInvoke("Ping", function(_player: Player, nonce: number)
		return nonce, workspace:GetServerTimeNow()
	end)
end

return Diagnostics
