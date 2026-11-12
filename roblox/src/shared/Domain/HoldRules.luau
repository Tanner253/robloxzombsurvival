--!strict
--[[
	HoldRules: which class an item in the hand belongs to and what follows from it
	(2.0 batch 1). Pure; the data is Data/Holds.

	- classOf: the item's hold class (Data/Holds.items, else by its kind, so a new item
	  never ends up with no animation); empty hands are "fists".
	- mountOf: how it sits in the fist ("gun": along the forearm; "fist": ahead of it).
	- strikeDelay: seconds from the start of a swing to its hit frame. The server lands a
	  light swing's damage on it, so the number, the flinch and the impact sound arrive
	  when the blade does, not when the button goes down.
	- consumeAction: the action clip for using a consumable (eat, drink or bandage).
]]

local Holds = require("../Data/Holds")

local HoldRules = {}

type ItemLike = {
	tool: { kind: string }?,
	weapon: { kind: string, bow: any?, firearm: { animClass: string? }? }?,
	throw: any?,
}

function HoldRules.classOf(itemId: string?, def: ItemLike?): string
	if itemId == nil or itemId == "" then
		return "fists"
	end
	local listed = Holds.items[itemId]
	if listed then
		return listed
	end
	if def == nil then
		return "fists"
	end
	if def.tool then
		return if def.tool.kind == "pick" then "pick" else "axe"
	end
	if def.throw then
		return "throw"
	end
	local weapon = def.weapon
	if weapon and weapon.kind == "ranged" then
		if weapon.bow then
			return "bow"
		end
		local firearm = weapon.firearm
		return if firearm and firearm.animClass == "pistol" then "pistol" else "long"
	end
	return if weapon then "blunt" else "fists"
end

function HoldRules.mountOf(itemId: string?, def: ItemLike?): Holds.Mount
	return Holds.classes[HoldRules.classOf(itemId, def)].mount
end

-- The clip a class plays for a use ("carry", "swing", "heavy", "aim", "recoil", "reload").
function HoldRules.clip(class: string, use: string): string?
	local def = Holds.classes[class] :: any
	return def and def[use]
end

function HoldRules.strikeDelay(class: string, heavy: boolean): number
	local name = HoldRules.clip(class, if heavy then "heavy" else "swing")
	local clip = if name then Holds.clips[name] else nil
	return if clip and clip.hit then clip.hit else 0
end

--[[
	The support hand on a long gun (batch 3): at 1.3x gun scale the solved stances left the
	off hand at the magazine well, short of the handguard. Clients pull it there with an
	IKControl toward a "Support" attachment the held model carries this far along the gun
	from the grip: 0.4 of the gun's length (a rifle's handguard, a shotgun's pump), but no
	more than SUPPORT_MAX_STUDS, the farthest the survivor's arm reaches from the bladed
	stance (measured in Studio: shoulder to palm 1.79 studs). Returned as a share of the
	length from the butt. nil for every other class. Off during a reload, when that hand is
	on the magazine.
]]
HoldRules.SUPPORT_REACH = 0.4
HoldRules.SUPPORT_MAX_STUDS = 1.25
-- How far above the grip's drop the palm sits, as a share of the gun's height.
HoldRules.SUPPORT_LIFT = 0.15

function HoldRules.supportAt(class: string, grip: number, length: number): number?
	if class ~= "long" or length <= 0 then
		return nil
	end
	local reach = math.min(HoldRules.SUPPORT_REACH, HoldRules.SUPPORT_MAX_STUDS / length)
	return math.min(grip + reach, 0.9)
end

function HoldRules.supportWeight(reloading: boolean): number
	return if reloading then 0 else 1
end

-- Eat, drink or dress a wound: whichever the item mostly does.
function HoldRules.consumeAction(
	consume: { hunger: number?, thirst: number?, health: number?, energy: number? }?
): string
	if consume == nil then
		return "eat"
	end
	local hunger, thirst, health = consume.hunger or 0, consume.thirst or 0, consume.health or 0
	if health > hunger and health > thirst then
		return "bandage"
	end
	-- Tonics (Energy only) are drunk too.
	return if thirst > hunger or (hunger == 0 and health == 0) then "drink" else "eat"
end

return HoldRules
