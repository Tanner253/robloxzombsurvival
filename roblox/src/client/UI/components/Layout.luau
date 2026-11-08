--!strict
--[[
	Layout: the layout objects every screen is built from (checklist 4.19: siblings are
	placed by UIListLayout / UIGridLayout / UIPadding and size constraints, never by hand
	so they can't drift onto each other).

	- Stack: children in a row or column with a gap (UIListLayout), optional padding,
	  alignment and automatic size. Children order by `layoutOrder`.
	- Grid: fixed-size cells in rows (UIGridLayout), e.g. inventory slots.
	- Fill: a child that takes the rest of a Stack's length (UIFlexItem).
	- pad: a UIPadding from Theme spacing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local Layout = {}

export type StackProps = {
	direction: ("row" | "column")?,
	gap: number?,
	padding: number?,
	alignX: Enum.HorizontalAlignment?,
	alignY: Enum.VerticalAlignment?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	autoSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
	name: string?,
	wraps: boolean?,
	children: any?,
}

function Layout.pad(all: number, sides: { top: number?, bottom: number?, left: number?, right: number? }?): any
	local s: { top: number?, bottom: number?, left: number?, right: number? } = sides or {}
	return e("UIPadding", {
		PaddingTop = UDim.new(0, s.top or all),
		PaddingBottom = UDim.new(0, s.bottom or all),
		PaddingLeft = UDim.new(0, s.left or all),
		PaddingRight = UDim.new(0, s.right or all),
	})
end

function Layout.Stack(props: StackProps)
	local children: { [string]: any } = table.clone(props.children or {})
	children.Layout = e("UIListLayout", {
		FillDirection = if props.direction == "row" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, props.gap or 0),
		HorizontalAlignment = props.alignX or Enum.HorizontalAlignment.Left,
		VerticalAlignment = props.alignY or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Wraps = props.wraps == true,
	})
	if props.padding then
		children.Padding = Layout.pad(props.padding)
	end
	return e("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.autoSize,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end

export type GridProps = {
	cell: Vector2,
	gap: number?,
	columns: number?, -- caps the cells per row (UIGridLayout FillDirectionMaxCells)
	size: UDim2?,
	position: UDim2?,
	autoSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	alignX: Enum.HorizontalAlignment?,
	children: any?,
}

function Layout.Grid(props: GridProps)
	local children: { [string]: any } = table.clone(props.children or {})
	children.Grid = e("UIGridLayout", {
		CellSize = UDim2.fromOffset(props.cell.X, props.cell.Y),
		CellPadding = UDim2.fromOffset(props.gap or 0, props.gap or 0),
		FillDirectionMaxCells = props.columns or 0,
		HorizontalAlignment = props.alignX or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return e("Frame", {
		Size = props.size or UDim2.fromScale(1, 0),
		Position = props.position,
		AutomaticSize = props.autoSize or Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, children)
end

-- The pixel size a grid of `count` cells takes in `columns` columns.
function Layout.gridSize(count: number, columns: number, cell: Vector2, gap: number): Vector2
	local rows = math.max(1, math.ceil(count / columns))
	local cols = math.min(count, columns)
	return Vector2.new(cols * cell.X + (cols - 1) * gap, rows * cell.Y + (rows - 1) * gap)
end

-- A Stack child that grows to fill the remaining length (UIFlexItem).
function Layout.Fill(props: { layoutOrder: number?, children: any?, crossSize: UDim?, direction: ("row" | "column")? })
	local children: { [string]: any } = table.clone(props.children or {})
	children.Flex = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill })
	local cross = props.crossSize or UDim.new(1, 0)
	return e("Frame", {
		Size = if props.direction == "row" then UDim2.new(UDim.new(0, 0), cross) else UDim2.new(cross, UDim.new(0, 0)),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, children)
end

return Layout
