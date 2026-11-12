--!strict
--[[
	StationPane: an LDoE converter station (LDOE_PARITY #18-23, rec4_05, rec1_02):
	- header: the station glyph, "WOODWORKING BENCH LVL 1" on the teal chip and the green
	  upgrade arrow (its modal shows have/need and SLOT CAPACITY 20 » 40);
	- ALL RECIPES: what this station converts, with lock text naming the quest;
	- the converter: the input slot, an arrow with the batch bar, and the output slot (the
	  Recycler shows its four outputs); fuelled stations add the fuel slot and burn bar;
	- a status line: time left, how many batches the input holds, or why it waits.
	A passive station (the Rain Barrel, F-21) has no input slot and no recipe list: the arrow
	fills its output by itself, and the line says how long until the next and how much room.

	Drag a stack onto the input or fuel slot (or select it and press PUT IN / ADD FUEL);
	click the input to take it back, the output to take it into the bag. The client draws
	the converter advanced to now with Domain/Converter (the server is authoritative and
	re-syncs as batches finish).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Converter = require(ReplicatedStorage.Shared.Domain.Converter)
local Offers = require(ReplicatedStorage.Shared.Domain.Offers)
local Unlocks = require(ReplicatedStorage.Shared.Domain.Unlocks)
local Net = require("../../../Net")
local Theme = require("../../theme")
local format = require("../../format")
local offers = require("../../offers")
local Glyph = require("../../components/Glyph")
local ItemSlot = require("../../components/ItemSlot")
local Layout = require("../../components/Layout")
local CostChip = require("../../components/CostChip")
local Modal = require("../../components/Modal")
local Parts = require("./Parts")

local e = React.createElement

local BIG = 104 -- the converter's input and output slots
local HINT_HEIGHT = 34 -- two caption lines under the input slot

export type Props = {
	uid: string,
	station: any, -- the synced converter state
	progress: Unlocks.Progress,
	now: number,
	onUpgrade: () -> (), -- opens the upgrade modal (Panels draws it over the whole screen)
}

local function context(def: any): Converter.Context
	return { def = def, recipes = Content.Recipes, items = Content.Items :: any }
end

-- A big converter slot that is also a drop target (DropTarget = "stationInput"...).
local function DropSlot(props: {
	target: string,
	slot: any,
	hint: string,
	layoutOrder: number,
	onActivated: () -> (),
})
	local slot = props.slot
	local filled = slot ~= nil and slot.count > 0
	local def = if filled then Content.Items[slot.itemId] else nil
	return e("Frame", {
		Size = UDim2.fromOffset(BIG, BIG + HINT_HEIGHT + 4),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Column = e(Layout.Stack, {
			gap = 4,
			alignX = Enum.HorizontalAlignment.Center,
			children = {
				Slot = e(ItemSlot, {
					itemId = if filled then slot.itemId else nil,
					count = if filled then slot.count else 0,
					durability = if def
							and def.durability
							and slot.durability
						then slot.durability / def.durability
						else nil,
					size = BIG,
					slotRef = props.target,
					slotIndex = 1,
					layoutOrder = 1,
					onActivated = props.onActivated,
				}),
				Hint = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
					BackgroundTransparency = 1,
					FontFace = Theme.fonts.body,
					Text = props.hint,
					TextWrapped = true, -- two lines for a long input name
					TextYAlignment = Enum.TextYAlignment.Top,
					TextSize = Theme.textSize.caption,
					TextColor3 = Theme.colors.textMuted,
					LayoutOrder = 2,
				}),
			},
		}),
	})
end

-- The arrow between input and output, with the batch bar under it.
local function Flow(props: { fraction: number, working: boolean, layoutOrder: number })
	return e(Layout.Stack, {
		gap = 6,
		alignX = Enum.HorizontalAlignment.Center,
		alignY = Enum.VerticalAlignment.Center,
		size = UDim2.fromOffset(72, BIG),
		layoutOrder = props.layoutOrder,
		children = {
			Arrow = e(Glyph, {
				name = "chevron",
				size = UDim2.fromOffset(28, 28),
				rotation = 180,
				color = if props.working then Theme.colors.accent else Theme.colors.textMuted,
				layoutOrder = 1,
			}),
			Track = e("Frame", {
				Size = UDim2.fromOffset(64, 6),
				BackgroundColor3 = Theme.colors.track,
				BorderSizePixel = 0,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = e("Frame", {
					Size = UDim2.fromScale(math.clamp(props.fraction, 0, 1), 1),
					BackgroundColor3 = Theme.colors.accent,
					BorderSizePixel = 0,
				}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
		},
	})
end

-- ALL RECIPES: every line the station converts.
local function Recipes(props: { def: any, progress: Unlocks.Progress, level: number, onBack: () -> () })
	local rows: { [string]: any } = {}
	for index, line in Converter.lines(props.def, Content.Recipes, Content.Items) do
		local locked = not Unlocks.isMet(line.unlock, props.progress)
		local lowLevel = props.level < line.stationLevel
		local note = if locked
			then Unlocks.text(line.unlock, { items = Content.Items :: any, quests = Content.Quests :: any }) or ""
			elseif lowLevel then `Station level {line.stationLevel}`
			else format.duration(Converter.batchSeconds(line, props.def, props.level))
		rows[`R{index}`] = e(Layout.Stack, {
			direction = "row",
			gap = Theme.spacing.sm,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.new(1, 0, 0, 48),
			layoutOrder = index,
			children = {
				In = e(CostChip, {
					itemId = line.inputItemId,
					have = line.inputCount,
					need = line.inputCount,
					size = 36,
					layoutOrder = 1,
				}),
				Arrow = e(Glyph, {
					name = "chevron",
					size = UDim2.fromOffset(18, 18),
					rotation = 180,
					color = Theme.colors.textMuted,
					layoutOrder = 2,
				}),
				Out = e(Layout.Stack, {
					direction = "row",
					gap = 4,
					size = UDim2.fromOffset(0, 36),
					autoSize = Enum.AutomaticSize.X,
					layoutOrder = 3,
					children = (function()
						local outs: { [string]: any } = {}
						for outIndex, stack in line.outputs do
							outs[`O{outIndex}`] = e(CostChip, {
								itemId = stack.itemId,
								have = stack.count,
								need = stack.count,
								size = 36,
								layoutOrder = outIndex,
							})
						end
						return outs
					end)(),
				}),
				Note = e(Layout.Fill, {
					direction = "row",
					layoutOrder = 4,
					children = {
						Text = e("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							FontFace = Theme.fonts.body,
							Text = note,
							TextSize = Theme.textSize.caption,
							TextColor3 = if locked or lowLevel then Theme.colors.locked else Theme.colors.textMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextWrapped = true,
						}),
					},
				}),
			},
		})
	end
	return e(Layout.Stack, {
		gap = Theme.spacing.sm,
		children = {
			Back = e(Parts.BarButton, { text = "Back", width = 100, layoutOrder = 0, onActivated = props.onBack }),
			List = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -(Theme.tapTarget + Theme.spacing.sm)),
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 1,
			}, {
				Rows = e(Layout.Stack, {
					gap = Theme.spacing.xs,
					size = UDim2.fromScale(1, 0),
					autoSize = Enum.AutomaticSize.Y,
					children = rows,
				}),
			}),
		},
	})
end

-- The upgrade modal: costs with have/need and the capacity it brings.
local function UpgradeModal(props: { uid: string, def: any, state: any, pooled: any, onClose: () -> () })
	local nextLevel = Converter.nextLevel(props.def, props.state.level)
	if nextLevel == nil then
		return nil
	end
	local chips: { [string]: any } = {}
	local short: { { itemId: string, count: number } } = {}
	for index, stack in nextLevel.upgradeCost do
		local have = format.count(props.pooled, stack.itemId)
		if have < stack.count then
			table.insert(short, { itemId = stack.itemId, count = stack.count - have })
		end
		chips[`C{index}`] = e(CostChip, { itemId = stack.itemId, have = have, need = stack.count, layoutOrder = index })
	end
	local busy = props.state.input.count > 0
	local fillUp = offers.fillUp
	local actions: { Modal.Action } = {
		{ text = "Cancel", variant = "secondary", onActivated = props.onClose },
	}
	if #short > 0 and fillUp then
		table.insert(actions, {
			text = "Buy",
			onActivated = function()
				fillUp(short)
			end,
		})
	else
		table.insert(actions, {
			text = "Upgrade",
			disabled = #short > 0 or busy,
			onActivated = function()
				Net.fire("StationUpgrade", props.uid)
				props.onClose()
			end,
		})
	end
	local current = Converter.slotCap(props.def, props.state.level)
	return e(Modal, {
		title = `Upgrade {props.def.name}`,
		height = 320,
		actions = actions,
		children = {
			Costs = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.md,
				alignX = Enum.HorizontalAlignment.Center,
				size = UDim2.new(1, 0, 0, 36),
				wraps = true,
				layoutOrder = 1,
				children = chips,
			}),
			Capacity = e(Parts.Line, {
				text = `SLOT CAPACITY {current} » {nextLevel.slotCap}`,
				tone = Theme.colors.text,
				center = true,
				layoutOrder = 2,
			}),
			Busy = busy and e(Parts.Line, {
				text = "Let it finish, or take the input out, first.",
				tone = Theme.colors.locked,
				center = true,
				layoutOrder = 3,
			}),
		},
	})
end

local function StationPane(props: Props)
	local showRecipes, setShowRecipes = React.useState(false)
	local station = props.station
	local def = Content.Stations[station.stationId]
	local ctx = context(def)
	local state = Converter.advance(station, ctx, props.now)
	local status = Converter.status(state, ctx)
	local line = status.line
	local maxed = Converter.nextLevel(def, state.level) == nil

	-- A passive station (the Rain Barrel, F-21) has no input: it fills itself up to its max.
	local passive = def.passive
	local activity: string = status.activity
	local passiveText: string? = if passive == nil
		then nil
		elseif
			activity == "working"
		then `Catching rain: {format.duration(status.batchRemaining)} for the next, room for {status.batchesLeft}`
		else `Full at {passive.max}: take the water`
	local statusText = if passiveText
		then passiveText
		elseif
			activity == "working"
		then `{format.duration(status.batchRemaining)} for the next, {status.batchesLeft} in the input`
		elseif status.activity == "noFuel" then "Add fuel to keep it burning"
		elseif status.activity == "outputFull" then "The output is full: take it"
		elseif status.activity == "short" and line then `Needs {line.inputCount} per batch`
		elseif status.ready > 0 then "Done: take the output"
		else "Drag a stack into the input"

	local header = e(Parts.Header, {
		glyph = if def.fuel then "campfire" else "craft",
		title = `{def.name} LVL {state.level}`,
		chip = true,
		right = {
			Upgrade = e(Parts.BarButton, {
				glyph = "upgrade",
				tone = "green",
				disabled = maxed,
				onActivated = props.onUpgrade,
			}),
		},
	})

	local outputs: { [string]: any } = {}
	for index, slot in state.output do
		local filled = slot.count > 0
		outputs[`O{index}`] = e(ItemSlot, {
			itemId = if filled then slot.itemId else nil,
			count = slot.count,
			size = if #state.output > 1 then Theme.panel.slot else BIG,
			slotRef = "stationOutput",
			slotIndex = index,
			layoutOrder = index,
			onActivated = function()
				Net.fire("StationTakeOutput", props.uid, index)
			end,
		})
	end

	-- Several outputs (the recycler's four) sit two by two beside the arrow, so the row
	-- stays inside the pane.
	local multi = #state.output > 1
	local gridSide = 2 * Theme.panel.slot + Theme.panel.slotGap
	local outputBlock = if multi
		then e("Frame", {
			Size = UDim2.fromOffset(gridSide, gridSide),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			Grid = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(Theme.panel.slot, Theme.panel.slot),
				CellPadding = UDim2.fromOffset(Theme.panel.slotGap, Theme.panel.slotGap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Slots = e(React.Fragment, nil, outputs),
		})
		else e(Layout.Stack, {
			direction = "row",
			gap = Theme.panel.slotGap,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.fromOffset(0, BIG),
			autoSize = Enum.AutomaticSize.X,
			layoutOrder = 3,
			children = outputs,
		})

	local converter = e(Layout.Stack, {
		gap = Theme.spacing.md,
		alignX = Enum.HorizontalAlignment.Center,
		padding = Theme.spacing.md,
		children = {
			Recipes = not passive and e(Parts.BarButton, {
				text = "All recipes",
				width = 180,
				tone = "plain",
				layoutOrder = 1,
				onActivated = function()
					setShowRecipes(true)
				end,
			}),
			Flow = e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.sm,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, math.max(BIG + HINT_HEIGHT + 6, if multi then gridSide else 0)),
				layoutOrder = 2,
				children = {
					Input = not passive and e(DropSlot, {
						target = "stationInput",
						slot = state.input,
						hint = if line then format.itemName(line.inputItemId) else "Input",
						layoutOrder = 1,
						onActivated = function()
							Net.fire("StationTakeInput", props.uid)
						end,
					}),
					Arrow = e(Flow, {
						fraction = status.progress,
						working = status.activity == "working",
						layoutOrder = 2,
					}),
					Output = outputBlock,
				},
			}),
			Status = e(Parts.Line, {
				text = statusText,
				tone = if status.activity == "working" then Theme.colors.text else Theme.colors.textMuted,
				center = true,
				layoutOrder = 3,
			}),
			Fuel = def.fuel and e(Layout.Stack, {
				direction = "row",
				gap = Theme.spacing.md,
				alignX = Enum.HorizontalAlignment.Center,
				alignY = Enum.VerticalAlignment.Center,
				size = UDim2.new(1, 0, 0, Theme.panel.slot),
				layoutOrder = 4,
				children = {
					Slot = e(ItemSlot, {
						itemId = if state.fuel.count > 0 then state.fuel.itemId else nil,
						count = state.fuel.count,
						size = Theme.panel.slot,
						slotRef = "stationFuel",
						slotIndex = 1,
						placeholder = nil,
						layoutOrder = 1,
						onActivated = function()
							Net.fire("StationTakeFuel", props.uid)
						end,
					}),
					Burn = e(Layout.Stack, {
						gap = 4,
						size = UDim2.fromOffset(200, Theme.panel.slot),
						alignY = Enum.VerticalAlignment.Center,
						layoutOrder = 2,
						children = {
							Label = e(Parts.Line, {
								text = `Fuel: {format.duration(status.fuelSeconds)}`,
								tone = Theme.colors.text,
								layoutOrder = 1,
							}),
							Track = e("Frame", {
								Size = UDim2.new(1, 0, 0, 8),
								BackgroundColor3 = Theme.colors.track,
								BorderSizePixel = 0,
								LayoutOrder = 2,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
								Fill = e("Frame", {
									Size = UDim2.fromScale(status.burnFraction, 1),
									BackgroundColor3 = Theme.colors.accentSoft,
									BorderSizePixel = 0,
								}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
							}),
						},
					}),
				},
			}),
			Capacity = e(Parts.Line, {
				text = `Each slot holds {status.capacity}`,
				center = true,
				size = Theme.textSize.caption,
				layoutOrder = 5,
			}),
		},
	})

	local body = e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.3,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.radius }),
		Content = if showRecipes
			then e(Recipes, {
				def = def,
				progress = props.progress,
				level = state.level,
				onBack = function()
					setShowRecipes(false)
				end,
			})
			else converter,
	})

	-- Speed up (MVP_LAUNCH v0.1): finish the work the station would do now for Embers, priced
	-- by the time left (Domain/Offers); one tap, the price on the button (LDoE).
	local left = if status.activity == "working" and line
		then status.batchRemaining + math.max(0, status.batchesLeft - 1) * status.batchSeconds
		else 0
	if def.fuel then
		left = math.min(left, status.fuelSeconds)
	end
	local speedPrice = Offers.speedUpPrice(left, Content.Tuning.embers :: any)
	local bar = speedPrice
		and e(Parts.Bar, {
			alignX = Enum.HorizontalAlignment.Center,
			children = {
				SpeedUp = e("TextButton", {
					Size = UDim2.fromOffset(180, Theme.tapTarget),
					BackgroundColor3 = Theme.colors.chip,
					Text = "",
					LayoutOrder = 2,
					[React.Event.Activated] = function()
						Net.fire("StationSpeedUp", props.uid)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Row = e(Layout.Stack, {
						direction = "row",
						gap = Theme.spacing.xs,
						alignX = Enum.HorizontalAlignment.Center,
						alignY = Enum.VerticalAlignment.Center,
						children = {
							Label = e("TextLabel", {
								Size = UDim2.fromOffset(0, 24),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = "SPEED UP",
								TextSize = Theme.textSize.body,
								TextColor3 = Theme.colors.text,
								LayoutOrder = 1,
							}),
							Coin = e(Glyph, { name = "coin", size = UDim2.fromOffset(22, 22), layoutOrder = 2 }),
							Price = e("TextLabel", {
								Size = UDim2.fromOffset(0, 24),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								FontFace = Theme.fonts.header,
								Text = tostring(speedPrice),
								TextSize = Theme.textSize.body,
								TextColor3 = Theme.colors.text,
								LayoutOrder = 3,
							}),
						},
					}),
				}),
			},
		})

	return e(Parts.Pane, { header = header, body = body, bar = bar })
end

return {
	Pane = StationPane,
	UpgradeModal = UpgradeModal,
	context = context,
}
