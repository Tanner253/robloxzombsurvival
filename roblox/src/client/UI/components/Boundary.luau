--!strict
--[[
	Boundary: an error boundary around one screen. If a screen throws while
	rendering, only that screen disappears (and the error is logged once); the
	HUD and every other screen keep working. It tries again after a few seconds,
	so a transient bad state recovers on its own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local RETRY_SECONDS = 3

local Boundary = (React.Component :: any):extend("Boundary")

function Boundary:init()
	self.state = { failed = false }
end

function Boundary.getDerivedStateFromError(_err: any)
	return { failed = true }
end

function Boundary:componentDidCatch(err: any, _info: any)
	warn(`UI screen '{self.props.name or "?"}' failed: {tostring(err)}`)
	task.delay(RETRY_SECONDS, function()
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
