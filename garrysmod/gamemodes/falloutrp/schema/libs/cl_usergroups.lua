--[[
	The rank definitions, client side.

	Ranks are DATA now rather than a table in a shared file - they are made in
	the menu and stored in `ix.data` - so the client has to be told what they
	are before it can draw anybody's rank name, colour, or the permission grid.

	`ix.admin.ranks` starts as the defaults so the very first frame after a
	join has something sensible to read, and is replaced wholesale when the
	server's copy arrives.
]]

if (not CLIENT) then return end

ix.admin = ix.admin or {}

--[[
	The defaults are NOT seeded here, and cannot be: `libs/` loads
	alphabetically, so this file runs long before `sh_usergroups.lua` defines
	`DefaultRanks`. The shared file does its own seeding at the end of itself -
	see the note there.
]]

net.Receive("ixRankSync", function()
	local ranks = net.ReadTable()

	if (not istable(ranks) or table.IsEmpty(ranks)) then return end

	ix.admin.ranks = ranks

	--[[
		A menu that is open is rebuilt rather than left showing the old ladder.
		Editing a rank is exactly when somebody is looking at this.
	]]
	if (IsValid(ix.gui.adminMenu)) then
		ix.gui.adminMenu:Populate()
	end
end)
