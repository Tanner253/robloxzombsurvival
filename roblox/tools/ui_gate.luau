--[[
	ui_gate.luau: runs the automated UI overlap gate (PLAYER_EXPERIENCE_CHECKLIST 4.19) in a
	Studio playtest. A hard blocker: every report shows its result, and the pass is zero
	flags.

	How (Roblox Studio MCP):
	1. start_stop_play (start), wait for the player to spawn.
	2. execute_luau with this file's body (it runs on the server and replicates the trigger).
	3. get_console_output and read the line that starts with "UIGATE ". It is JSON:
	   { pass, flagCount, elements, flags = { "<profile> | <state> | <kind>: <path> x <other>" },
	     counts = { ["<profile> | <state>"] = n } }.
	The client (Controllers/UiGate) renders every screen and state from fixtures at
	1920x1080, 1366x768, 2560x1440 and 844x390 (touch), audits each with Domain/UiAudit
	and restores the real state afterwards. It takes about 30 seconds.

	Fix every flag, then run it again: layout objects and tokens (UI/components/Layout,
	UI/theme) rather than nudged positions.
]]

workspace:SetAttribute("UIGate", os.clock())
return "UI gate started; read the UIGATE line from the console in about 30 s"
