--!strict
--[[
	hooks: React hooks for screens.
	- useSection(name): a synced section from State, re-rendering on change
	- usePooled(): the carried inventory plus the home pool, for have/need counts
	- useUi(): the UI state
	- useClock(seconds): server time, re-rendering every `seconds`
	- useAnimated(target, speed): a binding that eases toward `target` each frame
	  (springy panels, bars and pops without re-rendering)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Pool = require("../Pool")
local State = require("../State")

local hooks = {}

-- The carried inventory plus every home crate and the inbox (checklist 5.13), for
-- have/need counts only: never render its slots.
function hooks.usePooled(): any
	local inventory = hooks.useSection("inventory")
	hooks.useSection("pool")
	hooks.useSection("inbox")
	return Pool.inventory(inventory)
end

function hooks.useSection(name: string): any
	local value, setValue = React.useState(State.get(name))
	React.useEffect(function()
		setValue(State.get(name))
		local connection = State.changed:Connect(function(key: any)
			if key == name then
				setValue(State.get(name))
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { name })
	return value
end

function hooks.useUi(): State.Ui
	local value, setValue = React.useState(State.ui())
	React.useEffect(function()
		local connection = State.changed:Connect(function(key: any)
			if key == "ui" then
				setValue(State.ui())
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return value
end

function hooks.useClock(seconds: number): number
	local now, setNow = React.useState(State.now())
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(seconds)
				if running then
					setNow(State.now())
				end
			end
		end)
		return function()
			running = false
		end
	end, { seconds })
	return now
end

--[[
	A binding that follows `target` with exponential easing (`speed` per second,
	higher is snappier). Starts at `from` (default: the target) so a component
	can pop in on mount.
]]
function hooks.useAnimated(target: number, speed: number?, from: number?): any
	local binding, setBinding = React.useBinding(from or target)
	local current = React.useRef(from or target)
	React.useEffect(function()
		local rate = speed or 14
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function(dt: number)
			local value = current.current :: number
			local diff = target - value
			if math.abs(diff) < 1e-3 then
				current.current = target
				setBinding(target)
				connection:Disconnect()
				return
			end
			value += diff * (1 - math.exp(-rate * dt))
			current.current = value
			setBinding(value)
		end)
		return function()
			connection:Disconnect()
		end
	end, { target })
	return binding
end

return hooks
