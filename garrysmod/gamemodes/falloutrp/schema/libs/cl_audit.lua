--[[
	The audit, client side: the window, and the two inventories.

	See `sv_audit.lua` for where the data comes from and
	`derma/cl_audit.lua` for the window itself.
]]

ix.audit = ix.audit or {}

if (not CLIENT) then return end

net.Receive("ixAuditOpen", function()
	local steamID64 = net.ReadString()
	local characters = net.ReadTable()

	local panel = ix.gui.audit

	--- Refreshed in place if it is already open - see `PANEL:Setup`.
	if (not IsValid(panel)) then
		panel = vgui.Create("ixFOAudit")
	end

	if (not IsValid(panel)) then return end

	panel:Setup(steamID64, characters)
end)

--[[
	SOMEBODY ELSE'S STORAGE, NEXT TO YOUR OWN.

	Helix's inventory panel is `inventory:Show()`, and both of these are real
	inventory panels - so dragging an item from one to the other is Helix's own
	transfer, with its own rules, and nothing here has to know what moving an
	item means.

	The audited one is put on the left and the auditor's own to the right of
	it, which is the arrangement every container in this game already uses.
]]
net.Receive("ixAuditShow", function()
	local id = net.ReadUInt(32)
	local bStash = net.ReadBool()
	local who = net.ReadString()

	local inventory = ix.inventory.Get(id)

	if (not inventory) then return end

	local character = LocalPlayer():GetCharacter()
	local mine = character and character:GetInventory()

	if (not mine) then return end

	--- One at a time. Opening a second closes the first.
	if (IsValid(ix.gui.auditInventory)) then
		ix.gui.auditInventory:Remove()
	end

	if (IsValid(ix.gui.auditOwn)) then
		ix.gui.auditOwn:Remove()
	end

	--[[
		`ixInventory` IS THE PANEL, and it is the one Helix's own bags create -
		`SetInventory` and nothing else. Two of them side by side is what makes
		an audit useful: dragging an item from one to the other is Helix's own
		transfer, with Helix's own rules, and nothing here has to know what
		moving an item means.
	]]
	local theirs = vgui.Create("ixInventory")

	if (not IsValid(theirs)) then return end

	theirs:SetInventory(inventory)
	theirs:ShowCloseButton(true)
	theirs:SetTitle(string.format("%s - %s", who,
		bStash and "STASH" or "INVENTORY"))
	theirs:Center()
	theirs:MakePopup()

	local ours = vgui.Create("ixInventory")

	if (IsValid(ours)) then
		ours:SetInventory(mine)
		ours:ShowCloseButton(true)
		ours:SetTitle("YOURS")
		ours:MakePopup()
	end

	--[[
		POSITIONED A FRAME LATER, because an `ixInventory` does not know how big
		it is yet.

		`SetInventory` builds the grid in its own layout pass, so `GetTall()`
		read on this frame is the panel's default height and the arithmetic put
		both windows somewhere near the top of the screen. One frame is all it
		takes for the size to be real.
	]]
	timer.Simple(0, function()
		if (not IsValid(theirs)) then return end

		local width = theirs:GetWide()
		local height = theirs:GetTall()

		--- Theirs on the left, yours to the right of it, as every container is.
		theirs:SetPos(ScrW() * 0.5 - width - 8, ScrH() * 0.5 - height * 0.5)

		if (IsValid(ours)) then
			ours:MoveRightOf(theirs, 8)
			ours:SetY(ScrH() * 0.5 - ours:GetTall() * 0.5)
		end
	end)

	ix.gui.auditInventory = theirs
	ix.gui.auditOwn = ours

	--[[
		TELLING THE SERVER TO LET GO, which is what stops an auditor receiving
		every change to a stash on the other side of the map for the rest of
		the session - and what lets the inventory fall out of memory again.
	]]
	theirs.OnRemove = function()
		if (IsValid(ours)) then ours:Remove() end

		net.Start("ixAuditShow")
			net.WriteUInt(id, 32)
		net.SendToServer()

		if (ix.gui.auditInventory == theirs) then
			ix.gui.auditInventory = nil
		end
	end
end)
