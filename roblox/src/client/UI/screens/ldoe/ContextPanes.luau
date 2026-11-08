--!strict
--[[
	ContextPanes: the right panes of LDoE's two-pane screen besides stations and the
	survivor (LDOE_PARITY #13, #16, #56):
	- Storage (rec2_04): the crate glyph, "TIMBER CRATE LVL 1" on the teal chip, the label
	  brush and the green upgrade arrow; the crate's slots 5 wide; TAKE ALL · sort · PUT ALL.
	  The upgrade modal shows have/need and SLOT CAPACITY 15 » 25, with CANCEL / UPGRADE (or
	  BUY, which fills the shortfall once the shop ships).
	- Inbox (checklist 4.15): every reward, purchase and overflow row with TAKE, and TAKE ALL.
	- Project (rec4_03-04): the wrecked hauler's parts checklist, have/need per part with a
	  FILL UP per row, and FINALIZE.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Content = require(ReplicatedStorage.Shared.Data)
local Project = require(ReplicatedStorage.Shared.Domain.Project)
local Net = require("../../../Net")
local Actions = require("../../../Actions")
local Theme = require("../../theme")
local format = require("../../format")
local offers = require("../../offers")
local CostChip = require("../../components/CostChip")
local ItemIcon = require("../../components/ItemIcon")
local Layout = require("../../components/Layout")
local Modal = require("../../components/Modal")
local Parts = require("./Parts")

local e = React.createElement

local ContextPanes = {}

-- Storage ----------------------------------------------------------------------------------------

-- The crate's level: its place on the upgrade chain (Timber Crate 1, Banded Crate 2).
local function crateLevel(pieceId: string): number
	local level = 1
	for _, def in Content.BuildPieces do
		if def.upgradesTo == pieceId then
			return 1 + crateLevel(def.id)
		end
	end
	return level
end

function ContextPanes.Storage(
	props: {
		storage: any, -- { uid, pieceId, slots }
		selected: { ref: string, index: number }?,
		onSelect: (ref: string, index: number) -> (),
		onSecondary: (ref: string, index: number) -> (),
		onUpgrade: () -> (),
		onLabel: () -> (),
	}
)
	local def = Content.BuildPieces[props.storage.pieceId]
	local slots = props.storage.slots or {}
	local name = if def then def.name else "Crate"
	local canUpgrade = def ~= nil and def.upgradesTo ~= nil
	local header = e(Parts.Header, {
		glyph = "storage",
		title = `{name} LVL {crateLevel(props.storage.pieceId)}`,
		chip = true,
		right = {
			Brush = e(Parts.BarButton, { glyph = "brush", tone = "teal", onActivated = props.onLabel }),
			Upgrade = e(Parts.BarButton, {
				glyph = "upgrade",
				tone = "green",
				disabled = not canUpgrade,
				onActivated = props.onUpgrade,
			}),
		},
	})
	local body = e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Grid = e(Parts.Slots, {
			ref = "storage",
			slots = slots,
			selected = props.selected,
			onSlot = function(index: number)
				props.onSelect("storage", index)
			end,
			onSecondary = function(index: number)
				props.onSecondary("storage", index)
			end,
		}),
	})
	local bar = e(Parts.Bar, {
		alignX = Enum.HorizontalAlignment.Center,
		children = {
			Take = e(Parts.BarButton, {
				text = "Take all",
				width = 150,
				tone = "teal",
				layoutOrder = 1,
				onActivated = function()
					Actions.transfer("takeAll")
				end,
			}),
			Sort = e(Parts.BarButton, {
				glyph = "sort",
				tone = "teal",
				layoutOrder = 2,
				onActivated = function()
					Net.fire("InventorySort", "storage")
				end,
			}),
			Put = e(Parts.BarButton, {
				text = "Put all",
				width = 150,
				tone = "teal",
				layoutOrder = 3,
				onActivated = function()
					Actions.transfer("putAll")
				end,
			}),
		},
	})
	return e(Parts.Pane, { header = header, body = body, bar = bar })
end

-- The storage upgrade modal (LDOE_PARITY #16).
function ContextPanes.StorageUpgrade(props: { storage: any, pooled: any, onClose: () -> () })
	local def = Content.BuildPieces[props.storage.pieceId]
	local nextDef = def and def.upgradesTo and Content.BuildPieces[def.upgradesTo]
	if def == nil or nextDef == nil then
		return nil
	end
	local chips: { [string]: any } = {}
	local short: { { itemId: string, count: number } } = {}
	for index, stack in nextDef.cost do
		local have = format.count(props.pooled, stack.itemId)
		if have < stack.count then
			table.insert(short, { itemId = stack.itemId, count = stack.count - have })
		end
		chips[`C{index}`] = e(CostChip, { itemId = stack.itemId, have = have, need = stack.count, layoutOrder = index })
	end
	local fillUp = offers.fillUp
	local actions: { Modal.Action } = { { text = "Cancel", variant = "secondary", onActivated = props.onClose } }
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
			disabled = #short > 0,
			onActivated = function()
				Net.fire("BuildUpgrade", props.storage.uid)
				props.onClose()
			end,
		})
	end
	return e(Modal, {
		title = `Upgrade to {nextDef.name}`,
		height = 300,
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
				text = `SLOT CAPACITY {def.storageSlots or 0} » {nextDef.storageSlots or 0}`,
				tone = Theme.colors.text,
				center = true,
				layoutOrder = 2,
			}),
		},
	})
end

-- Inbox ---------------------------------------------------------------------------------------------

function ContextPanes.Inbox(props: { rows: { any } })
	local list: { [string]: any } = {}
	for index, row in props.rows do
		local def = Content.Items[row.itemId]
		list[row.id] = e(Layout.Stack, {
			direction = "row",
			gap = Theme.spacing.sm,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.new(1, -8, 0, 56),
			layoutOrder = index,
			children = {
				Icon = e("Frame", {
					Size = UDim2.fromOffset(48, 48),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}, { Icon = e(ItemIcon, { itemId = row.itemId }) }),
				Text = e(Layout.Fill, {
					direction = "row",
					layoutOrder = 2,
					children = {
						Column = e(Layout.Stack, {
							gap = 0,
							alignY = Enum.VerticalAlignment.Center,
							children = {
								Name = e(Parts.Line, {
									text = `{if def then def.name else row.itemId}  x{row.count}`,
									tone = Theme.colors.text,
									layoutOrder = 1,
								}),
								Source = e(Parts.Line, {
									text = row.source,
									size = Theme.textSize.caption,
									layoutOrder = 2,
								}),
							},
						}),
					},
				}),
				Take = e(Parts.BarButton, {
					text = "Take",
					width = 90,
					tone = "teal",
					layoutOrder = 3,
					onActivated = function()
						Net.fire("InboxTake", row.id)
					end,
				}),
			},
		})
	end
	local body = if #props.rows == 0
		then e(Parts.Line, { text = "Nothing waiting. Rewards and purchases land here.", center = true })
		else e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Rows = e(Layout.Stack, {
				gap = Theme.spacing.xs,
				size = UDim2.fromScale(1, 0),
				autoSize = Enum.AutomaticSize.Y,
				children = list,
			}),
		})
	local bar = e(Parts.Bar, {
		alignX = Enum.HorizontalAlignment.Center,
		children = {
			All = e(Parts.BarButton, {
				text = "Take all",
				width = 150,
				tone = "teal",
				disabled = #props.rows == 0,
				onActivated = function()
					Net.fire("InboxTakeAll")
				end,
			}),
		},
	})
	return e(Parts.Pane, {
		header = e(Parts.Header, { glyph = "inbox", title = "Inbox" }),
		body = body,
		bar = bar,
	})
end

-- Project: the parts checklist ------------------------------------------------------------------------

function ContextPanes.Project(props: { projectId: string, state: any, pooled: any })
	local def = Content.Projects[props.projectId]
	local state: Project.State = props.state or Project.new()
	local rows: { [string]: any } = {}
	for index, row in Project.rows(def, state) do
		local have = format.count(props.pooled, row.itemId)
		rows[`P{index}`] = e(Layout.Stack, {
			direction = "row",
			gap = Theme.spacing.sm,
			alignY = Enum.VerticalAlignment.Center,
			size = UDim2.new(1, 0, 0, 52),
			layoutOrder = index,
			children = {
				Part = e(CostChip, {
					itemId = row.itemId,
					have = row.delivered,
					need = row.need,
					size = 44,
					layoutOrder = 1,
				}),
				Name = e(Layout.Fill, {
					direction = "row",
					layoutOrder = 2,
					children = {
						Text = e(Parts.Line, {
							text = `{format.itemName(row.itemId)} (you have {have})`,
							tone = Theme.colors.text,
						}),
					},
				}),
				Fill = e(Parts.BarButton, {
					text = if row.done then "Done" else "Fill up",
					width = 110,
					tone = if row.done then "plain" else "teal",
					disabled = row.done or have <= 0 or state.finishedAt > 0,
					layoutOrder = 3,
					onActivated = function()
						Net.fire("ProjectDeliver", props.projectId, row.itemId)
					end,
				}),
			},
		})
	end
	local ready = Project.isReady(def, state)
	local body = e(Layout.Stack, {
		gap = Theme.spacing.sm,
		children = {
			Description = e(Parts.Line, { text = def.description, layoutOrder = 0 }),
			Rows = e(Layout.Stack, {
				gap = Theme.spacing.xs,
				size = UDim2.new(1, 0, 0, #def.parts * 56),
				layoutOrder = 1,
				children = rows,
			}),
		},
	})
	local bar = e(Parts.Bar, {
		alignX = Enum.HorizontalAlignment.Center,
		children = {
			Finalize = e(Parts.BarButton, {
				text = if state.finishedAt > 0 then "Restored" else "Finalize",
				width = 180,
				tone = "green",
				disabled = not ready,
				onActivated = function()
					Net.fire("ProjectFinalize", props.projectId)
				end,
			}),
		},
	})
	return e(Parts.Pane, {
		header = e(Parts.Header, { glyph = "vehicle", title = def.name, chip = true }),
		body = body,
		bar = bar,
	})
end

return ContextPanes
