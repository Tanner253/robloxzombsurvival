--!strict
--[[
	StationScreen (E at a Workbench, Campfire or Recycler).
	- left: the station's recipes (or, at the Recycler, what you carry that it
	  breaks down), with lock and missing-input states
	- middle: the chosen recipe: inputs you have / need, run count, Craft [Enter]
	- right: the queue with live timers and progress, Collect all, cancel; the
	  Campfire's fuel gauge with buttons for each fuel you carry
	- header: station level and Upgrade (cost, player level gate)
	Timers are drawn from the synced timestamps (Domain/Crafting.status), so they
	keep counting without server messages.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Crafting = require(ReplicatedStorage.Shared.Domain.Crafting)
local Salvage = require(ReplicatedStorage.Shared.Domain.Salvage)
local Actions = require("../../Actions")
local Net = require("../../Net")
local Theme = require("../theme")
local hooks = require("../hooks")
local format = require("../format")
local Button = require("../components/Button")
local ItemIcon = require("../components/ItemIcon")
local KeyChip = require("../components/KeyChip")
local Label = require("../components/Label")
local ProgressBar = require("../components/ProgressBar")
local Sheet = require("../components/Sheet")

local e = React.createElement

local function iconBox(itemId: string, size: number, rarityStroke: boolean?)
	local def = Content.Items[itemId]
	return e("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = Theme.colors.panelRaised }, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = rarityStroke
			and def
			and e("UIStroke", { Color = Theme.rarity[def.rarity], Thickness = Theme.strokeThickness }),
		Icon = e(ItemIcon, { itemId = itemId }),
	})
end

local function recipesFor(stationId: string): { any }
	local list = {}
	for _, recipe in Content.Recipes do
		if recipe.stationId == stationId then
			table.insert(list, recipe)
		end
	end
	table.sort(list, function(a: any, b: any)
		local la, lb = a.stationLevel or 1, b.stationLevel or 1
		if la ~= lb then
			return la < lb
		end
		return a.craftSeconds < b.craftSeconds
	end)
	return list
end

-- Left: recipe cards ----------------------------------------------------------------------------------

local function RecipeCard(props: {
	recipe: any,
	selected: boolean,
	ok: boolean,
	locked: string?,
	seconds: number,
	onSelect: () -> (),
	layoutOrder: number,
})
	local output = props.recipe.outputs[1]
	return e("TextButton", {
		Size = UDim2.new(1, -8, 0, 56),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if props.selected
			then Theme.colors.panelRaised:Lerp(Theme.colors.accent, 0.15)
			else Theme.colors.panelRaised,
		BackgroundTransparency = if props.locked then 0.45 else 0.05,
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = props.onSelect,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = e("UIStroke", {
			Color = if props.selected then Theme.colors.accent else Theme.colors.strokeWarm,
			Thickness = if props.selected then 2 else 1,
			Transparency = if props.selected then 0 else 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = e(
			"Frame",
			{ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1 },
			{
				Inner = e(ItemIcon, { itemId = output.itemId, size = UDim2.fromScale(1, 1) }),
			}
		),
		Name = e(Label, {
			text = if output.count > 1
				then format.stack(output.itemId, output.count)
				else format.itemName(output.itemId),
			style = "body",
			size = UDim2.new(1, -60, 0, 22),
			position = UDim2.fromOffset(56, 6),
		}),
		Meta = e(Label, {
			text = props.locked or format.duration(props.seconds),
			style = "caption",
			tone = if props.locked then "muted" elseif props.ok then "good" else "muted",
			size = UDim2.new(1, -60, 0, 18),
			position = UDim2.fromOffset(56, 30),
		}),
	})
end

-- Middle: recipe detail -----------------------------------------------------------------------------------

local function InputRow(props: { itemId: string, need: number, have: number, layoutOrder: number })
	local enough = props.have >= props.need
	return e("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = props.layoutOrder }, {
		Icon = iconBox(props.itemId, 40),
		Name = e(Label, {
			text = format.itemName(props.itemId),
			style = "body",
			size = UDim2.new(1, -150, 1, 0),
			position = UDim2.fromOffset(50, 0),
		}),
		Count = e(Label, {
			text = `{props.have} / {props.need}`,
			style = "number",
			tone = if enough then "good" else "accent",
			size = UDim2.new(0, 90, 1, 0),
			position = UDim2.fromScale(1, 0),
			anchorPoint = Vector2.new(1, 0),
			alignX = Enum.TextXAlignment.Right,
		}),
	})
end

-- Right: queue -------------------------------------------------------------------------------------------------

local function JobCard(props: { uid: string, job: any, outputItem: string?, layoutOrder: number })
	local job = props.job
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = if job.done
			then Theme.colors.panelRaised:Lerp(Theme.colors.durability, 0.15)
			else Theme.colors.panelRaised,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Stroke = job.done and e("UIStroke", { Color = Theme.colors.durability, Thickness = 2 }),
		Icon = props.outputItem and e(
			"Frame",
			{ Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1 },
			{
				Inner = e(ItemIcon, { itemId = props.outputItem, size = UDim2.fromScale(1, 1) }),
			}
		),
		Status = e(Label, {
			text = if job.done then "Ready!" elseif job.stalled then "Needs fuel" else format.duration(job.remaining),
			style = "body",
			tone = if job.done then "good" elseif job.stalled then "threat" else "text",
			size = UDim2.new(1, -100, 0, 20),
			position = UDim2.fromOffset(54, 6),
		}),
		Bar = e(ProgressBar, {
			progress = job.progress,
			color = if job.done then Theme.colors.durability else Theme.colors.accent,
			size = UDim2.new(1, -100, 0, 10),
			position = UDim2.fromOffset(54, 32),
		}),
		Cancel = not job.done and e("TextButton", {
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme.colors.track,
			FontFace = Theme.fonts.header,
			Text = "✕",
			TextSize = Theme.textSize.body,
			TextColor3 = Theme.colors.textMuted,
			[React.Event.Activated] = function()
				Net.fire("StationCancel", props.uid, job.index)
			end,
		}, { Corner = e("UICorner", { CornerRadius = Theme.radius }) }),
	})
end

-- Screen ------------------------------------------------------------------------------------------------------

local function StationScreen()
	local ui = hooks.useUi()
	local stations = hooks.useSection("stations")
	local inventory = hooks.useSection("inventory")
	local progression = hooks.useSection("progression")
	local unlocks = hooks.useSection("unlocks")
	local now = hooks.useClock(0.25)
	local selectedId, setSelected = React.useState(nil :: string?)
	local count, setCount = React.useState(1)

	local uid = ui.stationUid
	local station = if ui.panel == "station" and uid and stations then stations[uid] else nil
	local def = if station then Content.Stations[station.stationId] else nil
	local open = station ~= nil and def ~= nil

	local progress = {
		level = if progression then progression.level else 1,
		unlocks = if unlocks then unlocks else { recipes = {}, blueprints = {} },
	}
	local view = if inventory then { pockets = inventory.pockets, backpack = inventory.backpack } else nil

	-- The chosen recipe (or, at the Recycler, the chosen carried item).
	local recipes: { any } = if def and not def.salvage then recipesFor(def.id) else {}
	local selectedRecipe = nil
	for _, recipe in recipes do
		if recipe.id == selectedId then
			selectedRecipe = recipe
		end
	end
	if selectedRecipe == nil and #recipes > 0 then
		selectedRecipe = recipes[1]
	end

	-- Enter crafts the chosen recipe.
	React.useEffect(function()
		if not open then
			return function() end
		end
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.Return and selectedRecipe and uid then
				Net.fire("StationCraft", uid, selectedRecipe.id, count)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { open, selectedRecipe and selectedRecipe.id, count, uid } :: { any })

	local body: any = nil
	if station and def and uid and view then
		local status = Crafting.status(station, def, now)
		local level = def.levels[station.level]
		local nextLevel = def.levels[station.level + 1]
		local anyDone = false
		for _, job in status do
			anyDone = anyDone or job.done
		end

		-- Left list.
		local list: { [string]: any } = {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		local middle: { [string]: any } = {}
		if def.salvage then
			local seen: { [string]: boolean } = {}
			local order = 0
			for _, refName in { "pockets", "backpack" } do
				for index, slot in (inventory :: any)[refName] do
					if slot.count > 0 and Salvage.find(def, slot.itemId) and not seen[slot.itemId] then
						seen[slot.itemId] = true
						order += 1
						local salvage = Salvage.find(def, slot.itemId) :: any
						list[`{refName}{index}`] = e(RecipeCard, {
							recipe = { outputs = { { itemId = slot.itemId, count = 1 } } },
							selected = selectedId == slot.itemId,
							ok = true,
							seconds = Salvage.jobSeconds(salvage, def, station.level),
							layoutOrder = order,
							onSelect = function()
								setSelected(slot.itemId)
							end,
						})
						if selectedId == slot.itemId then
							local rows: { [string]: any } = {
								Layout = e(
									"UIListLayout",
									{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
								),
								Title = e(Label, {
									text = `Breaks down {format.itemName(slot.itemId)} into`,
									style = "body",
									tone = "muted",
									layoutOrder = 0,
								}),
							}
							for outputIndex, output in salvage.outputs do
								local chance = math.floor(output.chance * 100 + 0.5)
								rows[`O{outputIndex}`] = e("Frame", {
									Size = UDim2.new(1, 0, 0, 44),
									BackgroundTransparency = 1,
									LayoutOrder = outputIndex,
								}, {
									Icon = iconBox(output.itemId, 40),
									Name = e(Label, {
										text = `{format.itemName(output.itemId)}  {output.min}-{output.max}`,
										style = "body",
										size = UDim2.new(1, -120, 1, 0),
										position = UDim2.fromOffset(50, 0),
									}),
									Chance = e(Label, {
										text = if chance >= 100 then "Always" else `{chance}%`,
										style = "number",
										tone = if chance >= 100 then "good" else "warn",
										size = UDim2.new(0, 70, 1, 0),
										position = UDim2.fromScale(1, 0),
										anchorPoint = Vector2.new(1, 0),
										alignX = Enum.TextXAlignment.Right,
									}),
								})
							end
							middle.Outputs =
								e("Frame", { Size = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1 }, rows)
							middle.Recycle = e(Button, {
								text = "Recycle",
								size = UDim2.new(1, 0, 0, 48),
								position = UDim2.new(0, 0, 1, -48),
								onActivated = function()
									Net.fire("StationSalvage", uid, refName, index)
								end,
							})
						end
					end
				end
			end
			if order == 0 then
				list.Empty = e(Label, {
					text = "Carry broken gear and junk (lanterns, wire, motors, worn weapons) to break it down.",
					style = "caption",
					tone = "muted",
					wrap = true,
					size = UDim2.new(1, -8, 0, 60),
				})
			end
		else
			for index, recipe in recipes do
				local locked: string? = nil
				if not Crafting.isUnlocked(recipe, progress) then
					locked = if recipe.unlock.kind == "level"
						then `Unlocks at level {recipe.unlock.level}`
						else "Needs a blueprint"
				elseif station.level < (recipe.stationLevel or 1) then
					locked = `Station level {recipe.stationLevel}`
				end
				local ok = locked == nil and (Crafting.check(recipe, view, progress, station, def, 1))
				list[recipe.id] = e(RecipeCard, {
					recipe = recipe,
					selected = selectedRecipe ~= nil and selectedRecipe.id == recipe.id,
					ok = ok,
					locked = locked,
					seconds = Crafting.jobSeconds(recipe, def, station.level),
					layoutOrder = index,
					onSelect = function()
						setSelected(recipe.id)
						setCount(1)
					end,
				})
			end

			if selectedRecipe then
				local recipe = selectedRecipe
				local output = recipe.outputs[1]
				local rows: { [string]: any } = {
					Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
				}
				for index, stack in recipe.inputs do
					rows[`I{index}`] = e(InputRow, {
						itemId = stack.itemId,
						need = stack.count * count,
						have = format.count(inventory, stack.itemId),
						layoutOrder = index,
					})
				end
				local can, reason = Crafting.check(recipe, view, progress, station, def, count)
				local maxRuns = 0
				for runs = 1, level.queueSlots do
					if Crafting.check(recipe, view, progress, station, def, runs) then
						maxRuns = runs
					end
				end
				middle.Header = e("Frame", { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1 }, {
					Icon = iconBox(output.itemId, 72, true),
					Name = e(Label, {
						text = if output.count > 1
							then format.stack(output.itemId, output.count)
							else format.itemName(output.itemId),
						style = "title",
						size = UDim2.new(1, -84, 0, 28),
						position = UDim2.fromOffset(84, 6),
					}),
					Time = e(Label, {
						text = `{format.duration(Crafting.jobSeconds(recipe, def, station.level))} per run`,
						style = "caption",
						tone = "muted",
						size = UDim2.new(1, -84, 0, 20),
						position = UDim2.fromOffset(84, 38),
					}),
				})
				middle.Inputs = e("Frame", {
					Size = UDim2.new(1, 0, 0, 150),
					Position = UDim2.fromOffset(0, 84),
					BackgroundTransparency = 1,
				}, rows)
				middle.Stepper = e("Frame", {
					Size = UDim2.new(1, 0, 0, 44),
					Position = UDim2.new(0, 0, 1, -104),
					BackgroundTransparency = 1,
				}, {
					Minus = e(Button, {
						text = "−",
						variant = "secondary",
						size = UDim2.fromOffset(52, 44),
						onActivated = function()
							setCount(math.max(1, count - 1))
						end,
					}),
					Count = e(Label, {
						text = `{count} run{if count > 1 then "s" else ""}`,
						style = "title",
						size = UDim2.new(1, -230, 1, 0),
						position = UDim2.fromOffset(60, 0),
						alignX = Enum.TextXAlignment.Center,
					}),
					Plus = e(Button, {
						text = "+",
						variant = "secondary",
						size = UDim2.fromOffset(52, 44),
						position = UDim2.new(1, -112, 0, 0),
						anchorPoint = Vector2.new(1, 0),
						onActivated = function()
							setCount(math.min(level.queueSlots, count + 1))
						end,
					}),
					Max = e(Button, {
						text = "Max",
						variant = "secondary",
						size = UDim2.fromOffset(104, 44),
						position = UDim2.fromScale(1, 0),
						anchorPoint = Vector2.new(1, 0),
						disabled = maxRuns < 1,
						onActivated = function()
							setCount(math.max(1, maxRuns))
						end,
					}),
				})
				middle.Craft = e(Button, {
					text = if can
						then "Craft"
						elseif reason == "queueFull" then "Queue full"
						elseif reason == "missingInputs" then "Missing materials"
						else "Locked",
					disabled = not can,
					size = UDim2.new(1, 0, 0, 48),
					position = UDim2.new(0, 0, 1, -48),
					onActivated = function()
						Net.fire("StationCraft", uid, recipe.id, count)
					end,
				})
				middle.CraftKey = can
					and e(KeyChip, {
						text = "Enter",
						accent = true,
						position = UDim2.new(1, -8, 1, -40),
						anchorPoint = Vector2.new(1, 0),
					})
			end
		end

		-- Right: queue and fuel.
		local queue: { [string]: any } = {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		for _, job in status do
			local outputItem: string? = nil
			if def.salvage then
				outputItem = (Salvage.parse(job.recipeId))
			else
				local recipe = Content.Recipes[job.recipeId]
				outputItem = if recipe then recipe.outputs[1].itemId else nil
			end
			queue[`J{job.index}`] =
				e(JobCard, { uid = uid, job = job, outputItem = outputItem, layoutOrder = job.index })
		end
		for index = #status + 1, level.queueSlots do
			queue[`Free{index}`] = e("Frame", {
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = Theme.colors.track,
				BackgroundTransparency = 0.4,
				LayoutOrder = index,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.radius }),
				Stroke = e("UIStroke", { Color = Theme.colors.strokeWarm, Thickness = 1, Transparency = 0.6 }),
				Text = e(Label, {
					text = "Empty slot",
					style = "caption",
					tone = "muted",
					alignX = Enum.TextXAlignment.Center,
					size = UDim2.fromScale(1, 1),
				}),
			})
		end

		local fuel: any = nil
		if def.fuel then
			local remaining = Crafting.fuelRemaining(station, def, now)
			local capacity = def.fuel.maxUnits * def.fuel.secondsPerUnit
			local buttons: { [string]: any } = {
				Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
			}
			for index, itemId in def.fuel.itemIds do
				local have = format.count(inventory, itemId)
				buttons[itemId] = e("TextButton", {
					Size = UDim2.fromOffset(92, 52),
					BackgroundColor3 = Theme.colors.panelRaised,
					BackgroundTransparency = if have > 0 then 0 else 0.5,
					AutoButtonColor = have > 0,
					Text = "",
					LayoutOrder = index,
					[React.Event.Activated] = function()
						if have > 0 then
							Net.fire("StationFuel", uid, itemId, 1)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = Theme.radius }),
					Icon = e("Frame", {
						Size = UDim2.fromOffset(36, 36),
						Position = UDim2.fromOffset(4, 8),
						BackgroundTransparency = 1,
					}, {
						Inner = e(ItemIcon, { itemId = itemId, size = UDim2.fromScale(1, 1) }),
					}),
					Burn = e(Label, {
						text = `+{format.duration(Crafting.burnSeconds(def, itemId))}`,
						style = "caption",
						tone = if have > 0 then "highlight" else "muted",
						size = UDim2.new(1, -42, 0, 18),
						position = UDim2.fromOffset(42, 8),
					}),
					Have = e(Label, {
						text = `×{have}`,
						style = "caption",
						tone = "muted",
						size = UDim2.new(1, -42, 0, 18),
						position = UDim2.fromOffset(42, 26),
					}),
				})
			end
			fuel = e(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 112), Position = UDim2.new(0, 0, 1, -112), BackgroundTransparency = 1 },
				{
					Title = e(Label, {
						text = if remaining > 0 then `FIRE · burns {format.duration(remaining)}` else "FIRE · out",
						style = "caption",
						tone = if remaining > 0 then "accent" else "threat",
					}),
					Gauge = e(ProgressBar, {
						progress = remaining / capacity,
						color = Theme.colors.accent,
						size = UDim2.new(1, 0, 0, 12),
						position = UDim2.fromOffset(0, 26),
					}),
					Buttons = e("Frame", {
						Size = UDim2.new(1, 0, 0, 52),
						Position = UDim2.fromOffset(0, 50),
						BackgroundTransparency = 1,
					}, buttons),
				}
			)
		end

		local upgradeText = if nextLevel == nil
			then "Max level"
			elseif (nextLevel.requiredLevel or 1) > progress.level then `Upgrade at level {nextLevel.requiredLevel}`
			else "Upgrade"
		local upgradeCost = {}
		if nextLevel then
			for _, stack in nextLevel.upgradeCost do
				table.insert(upgradeCost, `{stack.count} {format.itemName(stack.itemId)}`)
			end
		end

		body = {
			Upgrade = e("Frame", {
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
			}, {
				Level = e(Label, {
					text = `Level {station.level} · {level.queueSlots} queue slots · speed ×{level.speedMultiplier}`,
					style = "caption",
					tone = "muted",
					size = UDim2.fromScale(0.5, 1),
				}),
				Cost = nextLevel and e(Label, {
					text = table.concat(upgradeCost, " · "),
					style = "caption",
					tone = "muted",
					size = UDim2.new(0.5, -200, 1, 0),
					position = UDim2.fromScale(0.5, 0),
					alignX = Enum.TextXAlignment.Right,
				}),
				Button = e(Button, {
					text = upgradeText,
					variant = "secondary",
					disabled = nextLevel == nil
						or (nextLevel.requiredLevel or 1) > progress.level
						or #station.queue > 0,
					size = UDim2.fromOffset(190, 44),
					position = UDim2.fromScale(1, 0),
					anchorPoint = Vector2.new(1, 0),
					onActivated = function()
						Net.fire("StationUpgrade", uid)
					end,
				}),
			}),
			List = e("ScrollingFrame", {
				Size = UDim2.new(0, 290, 1, -60),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.colors.strokeWarm,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
			}, list),
			Middle = e("Frame", {
				Size = UDim2.new(0, 360, 1, -60),
				Position = UDim2.fromOffset(310, 56),
				BackgroundTransparency = 1,
			}, middle),
			Right = e("Frame", {
				Size = UDim2.new(1, -690, 1, -60),
				Position = UDim2.new(1, 0, 0, 56),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
			}, {
				Title = e(
					Label,
					{ text = "QUEUE", style = "caption", tone = "accent", size = UDim2.new(0.5, 0, 0, 22) }
				),
				Collect = anyDone and e(Button, {
					text = "Collect all",
					size = UDim2.fromOffset(140, 36),
					position = UDim2.new(1, 0, 0, -6),
					anchorPoint = Vector2.new(1, 0),
					onActivated = function()
						Net.fire("StationCollect", uid)
					end,
				}),
				Jobs = e("ScrollingFrame", {
					Size = UDim2.new(1, 0, 1, if fuel then -150 else -36),
					Position = UDim2.fromOffset(0, 34),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
				}, queue),
				Fuel = fuel,
			}),
		}
	end

	return e(Sheet, {
		open = open,
		title = if def then def.name else "Station",
		subtitle = if station then `Level {station.level}` else nil,
		closeKey = "E",
		onClose = Actions.closePanel,
		size = UDim2.fromOffset(1080, 580),
	}, body)
end

return StationScreen
