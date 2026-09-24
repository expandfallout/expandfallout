--[[
	Dropping one item onto another runs `combine`.

	Helix already has the whole mechanism and it does not fire. `fo_stack_report`
	settled where the fault is, in one run:

	    functions: combine=true Split=true (4 total)
	    instances: target=true source=true
	    CanMerge = 1
	    OnCanRun -> true

	Every part the item owns answers yes, so nothing about the item is wrong and
	the fault is entirely in how the DRAG decides what you dropped on. There
	turned out to be two faults, one behind the other.

	ONE: IT ASKS VGUI WHERE THE CURSOR IS. `PaintDragPreview` works out the
	combine target with `vgui.GetHoveredPanel()`, and the icon being dragged
	called `self:MouseCapture(true)` when it was pressed. A panel holding mouse
	capture IS the hovered panel as far as vgui is concerned, whatever the
	cursor is over - so `hoveredPanel != itemPanel` is false, `combineItem` is
	never set, and the drop lands in a branch that does nothing. Nothing errors;
	the item springs back.

	TWO: THE DROP CELL IS NOT THE CELL YOU AIMED AT. Helix computes it from the
	dragged panel's own corner:

	    dropX = math.ceil((x - 4 - (panel.gridW - 1) * 32) / self.iconSize)

	`x` is where the panel's top-left landed, and that is offset from the
	cursor by wherever you happened to grab the icon. Dragging left-to-right
	and right-to-left therefore round into DIFFERENT cells for the same
	apparent drop, which is exactly the reported symptom: it refuses one way
	and works if you immediately drag the other way. For ordinary moves this is
	invisible, because any empty cell will do.

	SO THE TARGET COMES FROM THE CURSOR, and the combine is sent from here
	rather than by handing `combineItem` back to Helix. Going through their
	handler would put this behind their `IsAllEmpty` test again - which is the
	branch that eats the drop when the rounding disagrees - and the whole point
	is to stop depending on that arithmetic.

	What is NOT reimplemented: whether two items may merge at all. That is the
	item's own `combine.OnCanRun`, and the server checks it again when the
	message arrives, along with inventory access. This decides only WHICH item
	you dropped on.
]]

if (not CLIENT) then return end

--[[
	The grid cell under the cursor, in an inventory panel.

	The same arithmetic Helix uses, against the cursor instead of the dragged
	panel's corner. `4` and `GetPadding(2)` are their grid's own offsets; taken
	from the panel rather than copied so a skin that changes them cannot make
	this silently aim one cell out.
]]
local function CellUnderCursor(panel)
	if (not IsValid(panel) or not panel.iconSize) then return end

	local mouseX, mouseY = input.GetCursorPos()
	local localX, localY = panel:ScreenToLocal(mouseX, mouseY)
	local padding = panel.GetPadding and panel:GetPadding(2) or 0

	return math.ceil((localX - 4) / panel.iconSize),
		math.ceil((localY - padding) / panel.iconSize)
end

--- Would dropping `item` on `target` merge them?
local function Mergeable(target, item)
	if (not target or not item or target == item) then return false end
	if (not target.functions) then return false end

	local info = target.functions.combine

	if (not info or not info.OnCanRun) then return false end

	return info.OnCanRun(target, {item.id}) ~= false
end

local function Wrap()
	local PANEL = vgui.GetControlTable("ixItemIcon")

	if (not PANEL) then return false end
	if (PANEL.ixStackDrag) then return true end

	--- Marked so a `lua_refresh` cannot wrap the wrapper around itself.
	PANEL.ixStackDrag = true

	local original = PANEL.OnDrop

	function PANEL:OnDrop(bDragging, inventoryPanel, inventory, gridX, gridY)
		local item = self.itemTable

		if (not bDragging or not item or not IsValid(inventoryPanel)
		or not inventory or not inventory.GetItemAt) then
			return original(self, bDragging, inventoryPanel, inventory, gridX,
				gridY)
		end

		--[[
			The cursor first, then the cell Helix worked out. Two chances at
			the same question, and the second one is what makes this no worse
			than the old behaviour if the cursor is somehow outside the grid.
		]]
		local cursorX, cursorY = CellUnderCursor(inventoryPanel)
		local target

		if (cursorX) then
			local candidate = inventory:GetItemAt(cursorX, cursorY)

			if (Mergeable(candidate, item)) then target = candidate end
		end

		if (not target and gridX) then
			local candidate = inventory:GetItemAt(gridX, gridY)

			if (Mergeable(candidate, item)) then target = candidate end
		end

		if (not target) then
			return original(self, bDragging, inventoryPanel, inventory, gridX,
				gridY)
		end

		--[[
			Sent from here, and the original is NOT called - it would take the
			combine as a move into an occupied cell and do nothing, or move the
			item somewhere nobody asked for.

			This is the same message Helix's own combine branch sends; the
			server re-checks the item, the inventory access and `OnCanRun`
			before anything merges.
		]]
		local info = target.functions.combine

		if (info.sound) then
			surface.PlaySound(info.sound)
		end

		net.Start("ixInventoryAction")
			net.WriteString("combine")
			net.WriteUInt(target.id, 32)
			net.WriteUInt(target.invID or inventoryPanel.invID or 0, 32)
			net.WriteTable({item.id})
		net.SendToServer()
	end

	return true
end

if (not Wrap()) then
	--[[
		A retry rather than a hook: there is no hook that reliably means
		"Helix's derma is registered" on the client, and `InitPostEntity` does
		not fire in this schema at all. Helix registers `ixItemIcon` in its
		core, which loads before the schema, so this normally never runs.
	]]
	local attempts = 0

	timer.Create("ixStackDragWrap", 1, 10, function()
		attempts = attempts + 1

		if (Wrap()) then
			timer.Remove("ixStackDragWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] ixItemIcon never appeared - dragging "
				.. "items together to stack them is not active\n")
		end
	end)
end
