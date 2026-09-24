--[[
	Backpacks - the server's one job: the old packs become the new ones.

	The first backpacks were three ARMOUR items, `armor_backpack_small`,
	`_medium` and `_large`, and they were made and filled in testing before
	the redesign replaced them with the bags in `items/bags/`. An item row
	whose id no longer exists is logged as unknown on every load and
	skipped, forever. Rather than leave those rows dead - or delete them,
	with what was in them - they are RENAMED, once, to the ids of the bags
	that took their place. A pack carries its inventory's id in its data,
	and the bag base reads the same field, so the contents come with it.

	Once, and remembered in `ix.data`, so a server that has done it never
	looks again.
]]

if (not SERVER) then return end

local RENAMES = {
	armor_backpack_small = "backpack_small",
	armor_backpack_medium = "backpack_medium",
	armor_backpack_large = "backpack_large"
}

local function Migrate()
	if (ix.data.Get("backpackMigrated", false, false, true)) then return end

	for old, new in pairs(RENAMES) do
		local query = mysql:Update("ix_items")
			query:Update("unique_id", new)
			query:Where("unique_id", old)
		query:Execute()
	end

	ix.data.Set("backpackMigrated", true, false, true)

	MsgC(Color(120, 200, 120), "[falloutrp] old armour backpacks renamed to the bag items\n")
end

hook.Add("PostLoadData", "ixBackpackMigrate", function()
	timer.Simple(2, Migrate)
end)
