--[[
	Dropped items do not survive a restart.

	Helix's `saveitems` plugin writes every `ix_item` on the map to its data
	file and spawns them all back on the next boot. On a server where people
	drop things constantly - testing, dying, making room in a pack - the map
	accumulates rubbish that nobody put there on purpose and nobody will ever
	tidy up.

	THIS USES THE LEVER THE PLUGIN ALREADY HAS, rather than replacing it:

	    if (hook.Run("ShouldDeleteSavedItems") == true) then
	        -- don't spawn saved item and just delete them.
	        local query = mysql:Delete("ix_items")
	            query:WhereIn("item_id", idRange)
	        query:Execute()
	                            -- helix/plugins/saveitems.lua:34

	so the rows go with the entities and the database does not fill up with
	items that no longer exist anywhere. Returning true is the whole change;
	everything about how and when is Helix's.

	Note the comparison is `== true`, not truthiness - a listener returning
	anything else, including a string, leaves the items alone. That is why this
	returns the boolean rather than the config value directly.

	WHAT IS NOT AFFECTED. Items inside a character's inventory, inside a
	storage container, or inside a bag are not `ix_item` entities in the world
	and are not touched by any of this. Neither are lootable containers, which
	hold a plain list and create real items only when something is taken out.
]]

if (not SERVER) then return end

ix.config.Add("clearDroppedItems", true,
	"Whether items dropped on the ground are deleted on restart.", nil, {
	category = "Server"
})

hook.Add("ShouldDeleteSavedItems", "ixDropCleanup", function()
	return ix.config.Get("clearDroppedItems", true) == true
end)

--[[
	Said out loud when it happens.

	`saveitems` prints its own line when it deletes, but only on the boot where
	there was something to delete - and a server that quietly stops persisting
	dropped items is a thing somebody will otherwise notice weeks later and
	report as lost inventory.
]]
hook.Add("PostLoadData", "ixDropCleanup", function()
	if (not ix.config.Get("clearDroppedItems", true)) then return end

	MsgC(Color(255, 200, 100),
		"[falloutrp] dropped items are cleared on restart (clearDroppedItems)\n")
end)
