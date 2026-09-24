--[[
	The per-command rank overrides, client side.

	The COMMANDS tab draws each one's requirement beside it, and the picker
	sets it - so the client needs the table. It is not secret: knowing that
	`/charsetmoney` needs superadmin tells you nothing you could not learn by
	trying it.
]]

if (not CLIENT) then return end

ix.admin = ix.admin or {}
ix.admin.commandRanks = ix.admin.commandRanks or {}

ix.admin.commandExcludes = ix.admin.commandExcludes or {}

net.Receive("ixCommandRankSync", function()
	ix.admin.commandRanks = net.ReadTable() or {}
	ix.admin.commandExcludes = net.ReadTable() or {}

	if (IsValid(ix.gui.adminMenu)
	and ix.gui.adminMenu.section == "commands") then
		ix.gui.adminMenu:Populate()
	end
end)
