--[[
	An item is in one place, and the world is not one of them.

	A dropped item is an `ix_item` entity standing on the ground and an item
	whose `invID` is 0 - the world. Picking it up moves the item into a real
	inventory and Helix removes the entity, in `ix.item.PerformInventoryAction`:

	    if (result != false) then
	        if (IsValid(entity)) then
	            entity.ixIsSafe = true
	            entity:Remove()

	WHEN THAT DOES NOT HAPPEN THE ITEM IS IN TWO PLACES, and everything after
	it is wrong in a way that reads as three separate bugs:

	    press E again   the take transfers it to the inventory it is already
	                    in, and `ITEM:Transfer` answers "same inv"
	    drop it         `Transfer(nil)` wants to move it to inventory 0, which
	                    is where it still thinks it is - "same inv" again, and
	                    nothing appears on the ground

	Both are one number, `item.invID`, disagreeing with where the item actually
	is. This is the sweep that makes them agree: whenever an item lands in a
	real inventory, any entity still holding it goes.

	IT IS A SAFETY NET, NOT A FIX. Helix's own removal runs first and this
	finds nothing to do in every ordinary case. It is here because the failure
	is silent, produces three unrelated-looking symptoms, and leaves an item
	that can be duplicated by whoever notices - which is not something to leave
	resting on one `if` in somebody else's file.
]]

if (not SERVER) then return end

--[[
	`OnItemTransferred` fires at the end of every successful move, with the
	item already carrying its new `invID` - so this is the moment the answer to
	"where is it" is known and the entity can be checked against it.

	Deferred by a frame. Helix removes the entity AFTER `OnRun` returns, and
	`OnItemTransferred` is fired inside `Transfer`, which is inside `OnRun` -
	so running immediately would find an entity that is about to be removed
	anyway and remove it a moment early. Harmless, but it would mean this
	always looked like the thing doing the work.
]]
hook.Add("OnItemTransferred", "ixItemEntity", function(item)
	if (not item or not item.id) then return end

	local id = item.id

	timer.Simple(0, function()
		local instance = ix.item.instances[id]

		if (not instance) then return end

		--- Still in the world: the entity is where it should be.
		if ((instance.invID or 0) <= 0) then return end

		for _, entity in ipairs(ents.FindByClass("ix_item")) do
			if (entity.ixItemID ~= id) then continue end

			--[[
				`ixIsSafe` is Helix's flag for "this entity is going because
				the item moved, not because the item was destroyed" - without
				it `ix_item:OnRemove` treats the removal as the item being
				lost and deletes it out from under the inventory it just
				arrived in.
			]]
			entity.ixIsSafe = true

			entity:Remove()

			--[[
				AND THE ITEM'S REFERENCE TO IT.

				`item.entity` is set by `PerformInventoryAction` and cleared
				at the end of it - so an action that died in the middle leaves
				it pointing at an entity that is then removed, which in Lua is
				a NULL entity and still TRUTHY:

				    if (item.entity) then
				        if (client:GetShootPos():DistToSqr(item.entity:GetPos())

				That is `sh_item.lua:628`, and it is why dropping the item
				afterwards did nothing at all - it threw on the way in, before
				it reached the drop.
			]]
			instance.entity = nil

			ErrorNoHalt(string.format("[falloutrp] item %d was in inventory "
				.. "%s and still had an entity on the ground - removed it\n",
				id, tostring(instance.invID)))
		end
	end)
end)
