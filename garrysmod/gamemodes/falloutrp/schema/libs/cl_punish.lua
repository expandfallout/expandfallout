--[[
	Bans and warnings, client side.

	The BANS tab draws from these, and the player list shows a warning count
	beside each name - so the menu needs the tables rather than a query per
	row. They are only sent to somebody who may see them; see
	`ix.punish.SendAll`.
]]

if (not CLIENT) then return end

ix.punish = ix.punish or {}
ix.punish.bans = ix.punish.bans or {}
ix.punish.warnings = ix.punish.warnings or {}

net.Receive("ixPunishSync", function()
	ix.punish.bans = net.ReadTable() or {}
	ix.punish.warnings = net.ReadTable() or {}

	if (IsValid(ix.gui.adminMenu)) then
		ix.gui.adminMenu:Populate()
	end
end)

--- How many warnings an account has, for the player list.
function ix.punish.Count(steamID64)
	local list = ix.punish.warnings[tostring(steamID64)]

	return list and #list or 0
end
