--!strict
--[[
	Payments: how a Fog Run action is paid for (LDOE_PARITY #31, #40, #46).

	- "rations": Trail Rations from the bag, taken here.
	- "ad" and "premium": S3 wires the rewarded-ad and shop flows by replacing
	  `Payments.verify`. Until then both are refused, so nothing is ever free by
	  accident.

	Purposes: "autoClear", "bonusItem" (TAKE), "bonusAll" (TAKE ALL), "recoverAll".
]]

local Inventory = require("../Services/Inventory")

local Payments = {}

export type Method = "ad" | "rations" | "premium"
export type Purpose = "autoClear" | "bonusItem" | "bonusAll" | "recoverAll"

Payments.RATIONS = "item.rations"

-- S3 replaces this: whether the player just completed the ad or paid premium for `purpose`.
Payments.verify = function(_player: Player, _purpose: Purpose, _method: Method): boolean
	return false
end

-- Pays `rations` Rations, or the S3 hook for ads and premium. True when paid.
function Payments.pay(player: Player, purpose: Purpose, method: Method, rations: number): boolean
	if method == "rations" then
		return rations <= 0 or Inventory.take(player, { { itemId = Payments.RATIONS, count = rations } }, purpose)
	end
	return Payments.verify(player, purpose, method)
end

return Payments
