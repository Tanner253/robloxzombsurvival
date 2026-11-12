--!strict
--[[
	Trigger: the attack input's press and release, bound to what was in the hand at the press
	(batch 5 follow-up: one real-mouse throw spent all three grenades, and the rifle the hand
	switched to kept firing about 54 rounds on a hold that began with a grenade). Pure; the
	client's Controllers/CombatControl keeps one and tests/Trigger.spec holds it.

	- press(state, kind): a press starts only from up (a second "down" from another input path
	  is the same press). It remembers the weapon kind in hand.
	- release(state, kind): what the release completes: the throw, the bow's loose or the melee
	  swing, once, and only when the hand still holds the kind it was pressed with. A hold that
	  began with a throwable never completes anything else.
	- firing(state, kind): a held gun fires at its cadence only on a hold that began with a gun
	  in hand; a hand that switched to a gun mid-hold (the last grenade thrown) waits for a new
	  press.
	- throwReady(lastAt, now, interval): one throw per interval on the client too, so a press in
	  the server's cool-down draws no phantom throw.
]]

local Trigger = {}

export type Kind = string -- "melee" | "gun" | "bow" | "throw"
export type State = { down: boolean, kind: Kind?, presses: number }

function Trigger.new(): State
	return { down = false, kind = nil, presses = 0 }
end

-- True when this is a new press.
function Trigger.press(state: State, kind: Kind): boolean
	if state.down then
		return false
	end
	state.down = true
	state.kind = kind
	state.presses += 1
	return true
end

-- The action the release completes, or nil.
function Trigger.release(state: State, kind: Kind): Kind?
	if not state.down then
		return nil
	end
	local pressed = state.kind
	state.down = false
	state.kind = nil
	if pressed ~= kind then
		return nil
	end
	return pressed
end

function Trigger.firing(state: State, kind: Kind): boolean
	return state.down and state.kind == "gun" and kind == "gun"
end

-- Drops a hold without completing it (a panel opened, the run ended).
function Trigger.cancel(state: State)
	state.down = false
	state.kind = nil
end

function Trigger.throwReady(lastAt: number?, now: number, interval: number): boolean
	return lastAt == nil or now - lastAt >= interval
end

return Trigger
