--[[
	The bin. A trash icon in the corner of your inventory.

	Click it, drag what you want gone into the panel, close it, confirm. The
	items are destroyed and every one of them is logged with its name, its id
	and who threw it away.

	A REAL INVENTORY, NOT A LIST. The bin is a Helix inventory like any other,
	so dragging into it is the same gesture as dragging into a crate and needs
	no new UI mechanics at all - and, more usefully, an item in the bin is
	still a real item until the moment you confirm. Closing without confirming
	puts everything back, because a bin you cannot change your mind about is a
	bin nobody will risk using.

	ONE PER CHARACTER, MADE ON DEMAND. It is not saved: the whole point is that
	it is empty by the time anybody could look at it again, and a persistent
	bin would be a free extra bag that happens to be called "trash".

	THE CONFIRMATION IS THE POINT. Deleting things is the one action here with
	no undo, so it asks, it says how many, and it names what it is about to
	destroy in the log before it does it.
]]

ix.trash = ix.trash or {}

--- How big the bin is. Generous, because emptying a bag should take one trip.
ix.trash.width = 6
ix.trash.height = 5

--[[
	The inventory type, registered on demand.

	Same trick as the benches and the faction storages: Helix takes sizes from
	a registered type rather than from arguments.
]]
function ix.trash.InventoryType()
	local invType = string.format("trash:%dx%d", ix.trash.width,
		ix.trash.height)

	if (not ix.item.inventoryTypes[invType]) then
		ix.inventory.Register(invType, ix.trash.width, ix.trash.height, true)
	end

	return invType
end
