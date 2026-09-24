--[[
	The faction log's client half: the window, and the magnifier that opens
	it on an open faction storage. The shop's magnifier is in
	`derma/cl_shop.lua`, where the shop's tab bar is built.

	`ix.factionlog` IS DECLARED HERE TOO: `cl_` files load before `sh_` ones
	(gotcha 26).
]]

if (not CLIENT) then return end

ix.factionlog = ix.factionlog or {}

function ix.factionlog.Open(kind)
	if (IsValid(ix.gui.factionLogs)) then ix.gui.factionLogs:Remove() end

	ix.gui.factionLogs = vgui.Create("ixFOFactionLogs")
	ix.gui.factionLogs:SetKind(kind or "")
end

function ix.factionlog.Ask(kind, search, page)
	net.Start("ixFactionLogAsk")
		net.WriteString(kind or "")
		net.WriteString(search or "")
		net.WriteUInt(math.Clamp(math.floor(tonumber(page) or 0), 0, 255), 8)
	net.SendToServer()
end

net.Receive("ixFactionLog", function()
	local kind = net.ReadString()
	local rows = net.ReadTable()
	local more = net.ReadBool()
	local page = net.ReadUInt(8)
	local total = net.ReadUInt(32)

	if (IsValid(ix.gui.factionLogs)) then
		ix.gui.factionLogs:Receive(kind, rows, more, page, total)
	end
end)

--[[
	A MAGNIFIER ON AN OPEN FACTION STORAGE. Helix builds the storage window
	in its `ixStorageOpen` receiver and offers no hook after it, so the
	receiver is wrapped: Helix's runs, then a frame later the window - if it
	is a faction storage's, which its inventory says - gets the button.
]]
local original = net.Receivers["ixstorageopen"]

if (original) then
	net.Receive("ixStorageOpen", function(length, ...)
		original(length, ...)

		timer.Simple(0, function() ix.factionlog.Decorate() end)
	end)
end

function ix.factionlog.Decorate()
	local panel = ix.gui.openedStorage

	if (not IsValid(panel) or IsValid(panel.ixFactionLogButton)) then return end

	local id = panel.storageID or panel.GetStorageID and panel:GetStorageID()
	local inventory = id and ix.item.inventories[id]

	if (not inventory or not inventory.vars
	or not inventory.vars.factionStorage) then
		return
	end

	local button = panel:Add("DImageButton")

	button:SetImage("icon16/magnifier.png")
	button:SetStretchToFit(false)
	button:SetSize(24, 24)
	button:SetPos(panel:GetWide() - 64, 4)
	button:SetTooltip("Your faction's storage log")
	button.DoClick = function() ix.factionlog.Open("storage") end

	panel.ixFactionLogButton = button
end
