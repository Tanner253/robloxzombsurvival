--!strict
--[[
	Boundary: an error boundary around one screen. If a screen throws while
	rendering, only that screen disappears (and the error is logged once); the
	HUD and every other screen keep working. It tries again after a few seconds,
	so a transient bad state recovers on its own.

	Boundary.failures keeps each screen's last error, so the UI gate fails a screen that
	crashed instead of passing it for drawing nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local RETRY_SECONDS = 3

local Boundary = (React.Component :: any):extend("Boundary")

-- Screen name -> its last error (the UI gate clears and reads it per state), and the
-- screens down right now (waiting to retry; they draw nothing meanwhile).
Boundary.failures = {} :: { [string]: string }
Boundary.down = {} :: { [string]: string }

function Boundary:init()
	self.state = { failed = false }
end

function Boundary.getDerivedStateFromError(_err: any)
	return { failed = true }
end

function Boundary:componentDidCatch(err: any, _info: any)
	warn(`UI screen '{self.props.name or "?"}' failed: {tostring(err)}`)
	local name = self.props.name or "?"
	Boundary.failures[name] = tostring(err)
	Boundary.down[name] = tostring(err)
	task.delay(RETRY_SECONDS, function()
		Boundary.down[name] = nil
		self:setState({ failed = false })
	end)
end

function Boundary:render()
	if self.state.failed then
		return nil
	end
	return React.createElement(React.Fragment, nil, self.props.children)
end

return Boundary
