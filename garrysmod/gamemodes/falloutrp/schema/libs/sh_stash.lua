--[[
	The stash: one box of storage that belongs to you and follows you.

	Phoenix's `stash` plugin. Theirs is an admin-spawned box you press E on that
	opens YOUR OWN inventory - every stash on the map is the same storage for a
	given player, so one on each side of the wasteland is a way of getting your
	things back rather than a place to hide them.

	THE ENTITY IS A POINT, not a deployable and not a bench.

	It is placed with the `fo_point` tool, saved in `ix.points.stored`, listed
	by `/points` and removed by `/pointdelete` - the same as a cap stash and a
	plant, because it is the same KIND of thing: one an admin puts down while
	building the map and nobody moves afterwards. Making it its own placeable
	would have meant a second copy of the placing, the saving, the listing and
	the deleting, all of which already exist and are already debugged.

	THE STORAGE BELONGS TO THE CHARACTER, NOT TO THE BOX. The inventory id
	lives in character data, so:

	    every stash on the map opens the same one
	    a second player at the same box opens THEIRS, at the same moment
	    deleting the box does not delete anybody's things

	That last one is the reason the id is not kept on the record: a stash an
	admin removes while rearranging a town should not take a hundred players'
	belongings with it.
]]

ix.stash = ix.stash or {}

--[[
	How big it is.

	Phoenix's is a fixed 6x6. Configurable here because "how much can a player
	stockpile" is an economy decision rather than a technical one, and it is
	exactly the sort of number that wants changing after a month of play.

	CHANGING IT IS SAFE IN ONE DIRECTION. Helix stores an item's slot inside
	the inventory, so making the stash BIGGER simply adds room. Making it
	SMALLER leaves anything already outside the new bounds where it is - the
	items are not deleted, they are just in a part of the grid that no longer
	draws - so shrink it only when you mean to, and put it back if things go
	missing.
]]
ix.config.Add("stashWidth", 6,
	"How many columns of storage a personal stash has.", nil, {
	data = {min = 1, max = 20},
	category = "Stash"
})

ix.config.Add("stashHeight", 6,
	"How many rows of storage a personal stash has.", nil, {
	data = {min = 1, max = 20},
	category = "Stash"
})

--[[
	How long the box takes to open.

	Phoenix's is a quarter of a second of standing still, which is long enough
	to read as opening something and short enough not to be a wait. Zero makes
	it instant.
]]
ix.config.Add("stashOpenTime", 0.25,
	"Seconds spent opening a stash.", nil, {
	data = {min = 0, max = 10, decimals = 2},
	category = "Stash"
})

--[[
	The inventory type for a size, registered on demand.

	The same trick, and the same reason, as `ix.factionStorage.InventoryType`
	and `ix.bench.InventoryType`: Helix takes a size from a REGISTERED TYPE
	rather than from arguments, so a 6x6 stash needs a `stash:6x6` type to
	exist before one can be made.
]]
function ix.stash.InventoryType(width, height)
	width = math.Clamp(math.floor(width or 6), 1, 20)
	height = math.Clamp(math.floor(height or 6), 1, 20)

	local invType = string.format("stash:%dx%d", width, height)

	if (not ix.item.inventoryTypes[invType]) then
		ix.inventory.Register(invType, width, height, true)
	end

	return invType, width, height
end

--- The configured size, as two numbers.
function ix.stash.Size()
	return math.Clamp(math.floor(ix.config.Get("stashWidth", 6)), 1, 20),
		math.Clamp(math.floor(ix.config.Get("stashHeight", 6)), 1, 20)
end
