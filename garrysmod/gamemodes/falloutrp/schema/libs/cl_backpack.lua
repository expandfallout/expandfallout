--[[
	A backpack's window, and the click that opens it.

	WHERE THE WINDOW GOES. Helix makes a bag's window inside the menu's tile
	canvas, and this schema's F1 menu pads that canvas down to the main
	grid's exact size to centre it - so the window was laid out where
	nothing is drawn. A pack's window is a CHILD OF THE MENU instead (of
	the storage view, in a storage), painted like any other panel: on top
	of the menu, beside the main grid, packs stacking below each other, on
	the left when the right of the screen is too narrow. It goes when the
	menu goes. It was a popup of its own for a round, and two popups take
	turns being on top - the first click back on the menu buried it.

	THE CLICK. Helix opens a bag from the right-click menu, or all of them
	when the menu opens (the `openBags` option). Phoenix's packs opened on
	a click, and so do these: a left click on a pack's icon that does not
	turn into a drag opens its window, and a second one closes it. The
	icon panel's `OnMouseReleased` is wrapped rather than replaced - Helix's
	release is what ends a drag and drops an item into the world, and it
	has to run first. A click is told from a drag by the cursor not having
	moved since `OnMousePressed` recorded it.
]]

if (not CLIENT) then return end

ix.backpack = ix.backpack or {}

local function Scaled(value)
	return math.Round(value * (ix.fallout and ix.fallout.GetFontScale
		and ix.fallout.GetFontScale() or 1))
end

--- Every pack window open, in the order they were opened.
ix.backpack.windows = ix.backpack.windows or {}

local function Windows()
	local out = {}

	for _, panel in ipairs(ix.backpack.windows) do
		if (IsValid(panel)) then out[#out + 1] = panel end
	end

	ix.backpack.windows = out

	return out
end

--[[
	Beside the main inventory, below the packs already there, in screen
	space. Called for a short while after the window is made, because the
	main grid is sized and centred a frame after the menu builds it.
]]
local function Place(panel)
	local main = ix.gui.inv1

	if (not IsValid(main)) then
		panel:Center()

		return
	end

	local sx, sy = main:LocalToScreen(0, 0)
	local gap = Scaled(12)
	local y = sy

	for _, other in ipairs(Windows()) do
		if (other == panel) then break end

		y = y + other:GetTall() + gap
	end

	local x = sx + main:GetWide() + gap

	if (x + panel:GetWide() > ScrW()) then
		x = sx - gap - panel:GetWide()
	end

	if (y + panel:GetTall() > ScrH()) then y = sy end

	panel:SetPos(math.max(x, 0), math.max(y, 0))
end

--- Open one pack's window; the pack has to be loaded on this client.
function ix.backpack.Open(item)
	local index = item:GetData("id")

	--- Said out loud, because "nothing shows up" has had three causes so far.
	print(string.format("[falloutrp] backpack open: item %s inventory id %s loaded %s menu %s storage %s",
		tostring(item.uniqueID), tostring(index),
		tostring(index ~= nil and ix.item.inventories[index] ~= nil
			and ix.item.inventories[index].slots ~= nil),
		tostring(IsValid(ix.gui.menu)), tostring(IsValid(ix.gui.openedStorage))))

	if (not index) then
		LocalPlayer():Notify("This pack has no storage yet; put it down and pick it up again.")

		return
	end

	local inventory = ix.item.inventories[index]

	if (not inventory or not inventory.slots) then
		LocalPlayer():Notify("This pack's storage is not loaded on your side yet.")
		ErrorNoHalt("[falloutrp] backpack inventory '" .. tostring(index)
			.. "' is not loaded on this client\n")

		return
	end

	local old = ix.gui["inv" .. index]

	if (IsValid(old)) then old:Remove() end

	local panel = vgui.Create("ixInventory")

	panel:SetInventory(inventory)

	--[[
		NOT PAINTED BY THE MENU. While the main grid exists, Helix's
		`ixInventory:SetInventory` marks every window for another inventory
		"painted manually" and adds it to the grid's `childPanels`, because
		Helix's own menu paints those windows itself inside its page. This
		schema's menu does not, so the window was made, sized, filled, on
		top - and never drawn: "loaded true menu true" and nothing on the
		screen. Painted like any other panel, and out of that list.
	]]
	panel:SetPaintedManually(false)

	if (IsValid(ix.gui.inv1) and istable(ix.gui.inv1.childPanels)) then
		table.RemoveByValue(ix.gui.inv1.childPanels, panel)
	end

	panel:ShowCloseButton(true)
	panel:SetTitle(item.GetName and item:GetName() or L(item.name))

	--[[
		A CHILD OF THE MENU, NOT A POPUP BESIDE IT. Two popups take turns:
		whichever was clicked last is on top, so the first click back on the
		menu - to drag an item over - put the menu over the pack ("stuck
		behind the F1 menu unless I click it"). A child is drawn after its
		parent and moves with it, and both the menu and the storage view
		cover the whole screen, so screen positions still hold.
	]]
	local host = IsValid(ix.gui.openedStorage) and ix.gui.openedStorage or ix.gui.menu

	if (IsValid(host)) then panel:SetParent(host) end

	panel:SetVisible(true)
	panel:SetMouseInputEnabled(true)
	panel:MoveToFront()

	--- The menu keeps the keyboard; this only wants the mouse.
	panel:SetKeyboardInputEnabled(false)

	ix.gui["inv" .. index] = panel

	--- In a storage: Helix's own place for it, the middle.
	if (IsValid(ix.gui.openedStorage)) then
		panel:Center()

		return panel
	end

	ix.backpack.windows[#ix.backpack.windows + 1] = panel

	Place(panel)

	local until_ = SysTime() + 0.75
	local think = panel.Think

	panel.Think = function(this)
		if (think) then think(this) end

		if (SysTime() < until_) then Place(this) end

		--- Goes with the menu.
		if (not IsValid(ix.gui.menu) and not IsValid(ix.gui.openedStorage)) then
			this:Remove()
		end
	end

	return panel
end

--------------------------------------------------------------------------------
-- The click
--------------------------------------------------------------------------------

local icon = vgui.GetControlTable("ixItemIcon")

if (icon and not icon.ixBackpackClick) then
	icon.ixBackpackClick = true

	local released = icon.OnMouseReleased

	icon.OnMouseReleased = function(self, code)
		local item = self.itemTable
		local x, y = input.GetCursorPos()
		local still = code == MOUSE_LEFT and self.clickX ~= nil
			and not dragndrop.IsDragging()
			and math.abs(x - self.clickX) < 4 and math.abs(y - self.clickY) < 4

		if (released) then released(self, code) end

		if (not still or not item or not item.backpack) then return end
		if (IsValid(item.entity)) then return end

		local index = item:GetData("id")

		if (not index) then return end

		local panel = ix.gui["inv" .. index]

		--- Open: close it. Closed: open it.
		if (IsValid(panel)) then
			print("[falloutrp] backpack click: closing the open window")
			panel:Remove()

			return
		end

		item.player = LocalPlayer()
		ix.backpack.Open(item)
		item.player = nil
	end
end

--------------------------------------------------------------------------------
-- Dropping onto a pack
--------------------------------------------------------------------------------

--[[
	WHICH ITEM COVERS A SQUARE. The client is told each item once, at its
	top-left square (`ixInventorySync`), and every other square it covers
	is empty as far as `GetItemAt` knows - the server fills them all, the
	client does not. Walked by footprint instead.
]]
function ix.backpack.Covering(inventory, x, y)
	for sx, column in pairs(inventory and inventory.slots or {}) do
		for sy, item in pairs(column) do
			if (istable(item) and item.id and x >= sx and y >= sy
			and x < sx + (item.width or 1) and y < sy + (item.height or 1)) then
				return item
			end
		end
	end
end

--[[
	ANY SQUARE OF THE PACK, and none of Helix's chain is trusted to say so.

	Helix decides a drop three ways, and all three answer only on a pack's
	top-left square. `vgui.GetHoveredPanel` picks the combine target during
	the drag; `IsAllEmpty` then gets first refusal and reads the panel's own
	slot table; and the drop cell itself is computed as
	`(x - 4 - (gridW - 1) * 32) / iconSize`, where the 32 is half of an
	icon size this schema does not use, so the cell is wrong by up to a
	square before anything else happens.

	So this takes the drop before Helix sees it: the square under the
	CURSOR, the item whose footprint covers that square, and - if that item
	will take one - the combine sent straight to the server, which is all
	Helix's own path does at the end of it.
]]
local invPanel = vgui.GetControlTable("ixInventory")

if (invPanel and not invPanel.ixBackpackDrop) then
	invPanel.ixBackpackDrop = true

	local receive = invPanel.ReceiveDrop

	local function Combine(self, panels)
		local dragged = panels and panels[1]
		local item = IsValid(dragged) and dragged.GetItemTable and dragged:GetItemTable()
		local inventory = item and ix.item.inventories[self.invID]

		if (not inventory) then return false end

		local size = self:GetIconSize()

		if (not size or size <= 0) then return false end

		local x, y = self:ScreenToLocal(input.GetCursorPos())
		local target = ix.backpack.Covering(inventory,
			math.floor((x - self:GetPadding(1)) / size) + 1,
			math.floor((y - self:GetPadding(2)) / size) + 1)

		if (not target or target == item or target.id == item.id) then return false end

		local info = target.functions and target.functions.combine

		if (not info) then return false end

		item.player = LocalPlayer()
		local allowed = not info.OnCanRun or info.OnCanRun(target, {item.id}) ~= false
		item.player = nil

		if (not allowed) then return false end

		if (info.sound) then surface.PlaySound(info.sound) end

		net.Start("ixInventoryAction")
			net.WriteString("combine")
			net.WriteUInt(target.id, 32)
			net.WriteUInt(target.invID or inventory:GetID(), 32)
			net.WriteTable({item.id})
		net.SendToServer()

		return true
	end

	invPanel.ReceiveDrop = function(self, panels, bDropped, menuIndex, x, y)
		if (bDropped and Combine(self, panels)) then
			self.previewPanel = nil

			return
		end

		if (receive) then return receive(self, panels, bDropped, menuIndex, x, y) end
	end
end
