--[[
	The bin button, in the top right corner of the inventory page.

	IT IS A CHILD OF THE MENU'S INVENTORY PAGE, not of the inventory panel.

	The first version wrapped `ixInventory:Init` and hung the button inside
	that panel, which was wrong twice over. `ixInventory` sizes itself to the
	grid EXACTLY - `SetGridSize` is `w * iconSize + 8` wide - so there is no
	corner inside it that is not a slot, and the slots are built later than
	`Init`, so they are drawn over anything added there. The button existed,
	took no clicks, and was invisible under the top right slot. Nothing errored.

	`MenuSubpanelCreated` fires with the page each time the menu is built, so
	the button lives exactly as long as the page does, appears only on the
	inventory tab, and never turns up on a crate, a corpse or a workbench -
	which the old version needed a `ix.gui.inv1 == self` test to avoid.
]]

if (not CLIENT) then return end

local function Scaled(value)
	return math.Round(value * ix.fallout.GetFontScale())
end

--[[
	Which inventory is the bin, told to us as it opens.

	The window has no other way to know: it is an ordinary storage window, and
	the only thing that makes it a bin is what the server does with it.
]]
ix.trash = ix.trash or {}
ix.trash.invID = ix.trash.invID or 0

net.Receive("ixTrashOpened", function()
	ix.trash.invID = net.ReadUInt(32)
end)

--[[
	BOTH ANSWERS ARE SENT. Neither is the absence of a message.

	The first version sent nothing for "keep it", because closing the window
	already restored everything - which was the bug: the restore happened
	before the question was asked, so by the time either button was pressed
	there was nothing left and the answer changed nothing. The server now holds
	the contents until it is told, and the fallback if it never is, is to keep
	them.
]]
local function Confirm()
	Derma_Query("Everything in the bin will be destroyed. This cannot be "
		.. "undone.", "Trash", "Throw it away", function()
			net.Start("ixTrashDecide")
				net.WriteBool(true)
			net.SendToServer()
		end, "Keep it", function()
			net.Start("ixTrashDecide")
				net.WriteBool(false)
			net.SendToServer()
		end)
end

--[[
	The caps panel, off - for the bin and for nothing else.

	`ix.storage.Sync` puts the owner's money into any storage whose anchor is a
	player, and the bin's anchor has to be the player who opened it: the open
	message is a `net.WriteEntity` and the window refuses to build if that
	comes back NULL, which is what an invisible prop below the map does. See
	the long note in `sv_trash.lua`.

	So the money is stopped at the panel instead. Wrapped rather than replaced,
	and only ever a no-op for the one inventory the server named - every other
	container keeps its money row.
]]
local function WrapMoney()
	local PANEL = vgui.GetControlTable("ixStorageView")

	if (not PANEL) then return false end
	if (PANEL.ixTrashMoney) then return true end

	PANEL.ixTrashMoney = true

	for _, name in ipairs({"SetLocalMoney", "SetStorageMoney"}) do
		local original = PANEL[name]

		if (not original) then continue end

		PANEL[name] = function(self, ...)
			if (self.GetStorageID and self:GetStorageID() == ix.trash.invID
			and ix.trash.invID > 0) then
				return
			end

			return original(self, ...)
		end
	end

	return true
end

if (not WrapMoney()) then
	--- Same retry as the bin button below; there is no "derma is ready" hook.
	timer.Create("ixTrashMoneyWrap", 1, 10, function()
		if (WrapMoney()) then timer.Remove("ixTrashMoneyWrap") end
	end)
end

--[[
	Ask the question when the bin window CLOSES, not when it opens.

	A short poll waits for the storage view to exist and then hangs the question
	off its removal. Asking at the click would be asking before anything had
	been put in.
]]
local function WatchForClose()
	local deadline = CurTime() + 3

	timer.Create("ixTrashWatch", 0.1, 0, function()
		if (CurTime() > deadline) then
			timer.Remove("ixTrashWatch")

			return
		end

		local view = ix.gui.openedStorage

		if (not IsValid(view)) then return end

		timer.Remove("ixTrashWatch")

		local remove = view.OnRemove

		view.OnRemove = function(pnl)
			if (remove) then remove(pnl) end

			--[[
				Only ask when there is something to ask about. A bin opened and
				closed untouched should say nothing at all - and the server
				only holds the contents when there are some, so asking anyway
				would produce a question with no answer behind it.
			]]
			local inventory = view.storageInventory
				and ix.item.inventories[view.storageInventory.invID or 0]

			if (inventory and not table.IsEmpty(inventory:GetItems() or {}))
			then
				Confirm()
			end

			ix.trash.invID = 0
		end
	end)
end

--[[
	What happened last time, for `fo_trash_report`.

	Kept as PLAIN VALUES, not just the panel. The first report printed
	`IsValid(lastButton)` and nothing else, so running it after closing the
	menu - which is the only time you can type in the console - said "button
	exists false" whether the button had been made or not. A record that is
	only true while you cannot read it is not a record.
]]
local record = {made = 0, lastMade = "never", x = 0, y = 0, parent = "none"}
local lastButton

hook.Add("MenuSubpanelCreated", "ixTrash", function(id, container)
	if (id ~= "inv" or not IsValid(container)) then return end

	local size = Scaled(26)
	local margin = Scaled(6)

	local button = container:Add("DButton")

	button:SetText("")
	button:SetSize(size, size)
	button:SetTooltip("Trash - drag things in, then close the window")
	button.ixTrashButton = true

	--[[
		RAISED WITH ZPos, NOT `MoveToFront` IN `PerformLayout`.

		The inventory canvas is docked FILL underneath and was added first, so
		it is drawn over anything added after it unless the order is changed.
		`MoveToFront` reorders the parent's children and invalidates its layout,
		which from inside `PerformLayout` is a loop; a z position is read by the
		same sort without touching the layout.
	]]
	button:SetZPos(32767)

	lastButton = button

	record.made = record.made + 1
	record.lastMade = os.date("%H:%M:%S")

	button.Paint = function(pnl, width, height)
		local colour = pnl:IsHovered() and Color(220, 90, 80)
			or Color(190, 190, 190)
		local unit = math.max(math.floor(width / 11), 1)

		surface.SetDrawColor(colour)

		--- A handle, a lid and a body, drawn rather than shipped as a material.
		surface.DrawRect(width * 0.5 - unit * 1.5, unit, unit * 3, unit)
		surface.DrawRect(unit * 1.5, unit * 2, width - unit * 3, unit)
		surface.DrawOutlinedRect(unit * 2, unit * 4, width - unit * 4,
			height - unit * 5, 1)

		for offset = 0, 2 do
			surface.DrawRect(unit * 3.5 + offset * unit * 2, unit * 6, 1,
				height - unit * 9)
		end
	end

	button.DoClick = function()
		--[[
			THE MENU IS CLOSED FIRST, and it has to be.

			`ixStorageView` is a fullscreen panel, and Helix only half-supports
			opening one while the character menu is up:

			    function PANEL:SetLocalInventory(inventory)
			        if (IsValid(ix.gui.inv1) and !IsValid(ix.gui.menu)) then

			So with the menu open the storage window IS created - it simply
			never gets your own inventory put in it, and it is drawn underneath
			the menu popup anyway. From the outside the button does nothing at
			all, which is exactly what it looked like.

			Worse, `ixStorageView:Init` reassigns `ix.gui.inv1` to its own
			panel, so the menu's inventory would be left pointing at a window
			that is about to be removed.

			Every other container is opened from the world with no menu up.
			Closing it here puts the bin in the same state as all of them.
		]]
		if (IsValid(ix.gui.menu)) then
			ix.gui.menu:Remove()
		end

		net.Start("ixTrashOpen")
		net.SendToServer()

		WatchForClose()
	end

	--[[
		Positioned from the PAGE's corner, in the page's own layout.

		Not docked: `container` is dock-padded by `cl_panels.lua` to centre the
		grid, and a docked button would be pushed inside that padding and would
		move every time the grid was resized.

		Wrapped rather than replaced - `container` is built by the menu and may
		grow a layout of its own later.
	]]
	local layout = container.PerformLayout

	container.PerformLayout = function(pnl, width, height)
		if (layout) then layout(pnl, width, height) end

		if (not IsValid(button)) then return end

		button:SetPos(width - size - margin, margin)

		record.x, record.y = button:GetPos()
		record.parent = string.format("%dx%d", width, height)
	end

	container:InvalidateLayout(true)
end)

--[[
	What the button actually is, when it is not where it should be.

	The first version of this failed silently in three different ways at once,
	and none of them could be seen from the screen - so the state that decides
	whether it is visible is printable.
]]
concommand.Add("fo_trash_report", function()
	local accent, plain = Color(255, 200, 100), Color(200, 200, 200)

	MsgC(accent, "\n-- bin button ------------------------------------------\n")

	MsgC(plain, string.format("  %-22s %s\n", "menu open now",
		tostring(IsValid(ix.gui.menu))))
	MsgC(plain, string.format("  %-22s %s\n", "button alive now",
		tostring(IsValid(lastButton))))
	MsgC(plain, string.format("  %-22s %d\n", "times made", record.made))
	MsgC(plain, string.format("  %-22s %s\n", "last made at",
		record.lastMade))
	MsgC(plain, string.format("  %-22s %d, %d\n", "last position",
		record.x, record.y))
	MsgC(plain, string.format("  %-22s %s\n", "last page size",
		record.parent))
	MsgC(plain, string.format("  %-22s %s\n", "storage open",
		tostring(IsValid(ix.gui.openedStorage))))

	MsgC(accent, "\n")
end)

--[[
	`/admin` opens the menu.

	Sent as a message rather than opened by the command directly, for the
	reason `/shopconfig` taught: a command runs on the SERVER, and a window
	opens on the client.
]]
net.Receive("ixAdminOpen", function()
	vgui.Create("ixFOAdminMenu")
end)
