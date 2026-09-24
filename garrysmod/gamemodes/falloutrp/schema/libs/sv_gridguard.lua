--[[
	Nothing may be put down on top of something else.

	`Inventory:Add` DOES NOT CHECK THE SLOTS when it is told where to put
	something. Helix's own code, the branch that moves an existing item:

	    if (x and y) then
	        targetInv.slots[x] = targetInv.slots[x] or {}
	        targetInv.slots[x][y] = true
	        ...
	        targetInv.slots[index][y + y2] = item

	It writes into whatever is there. `CanItemFit` is asked on the path that
	moves an item WITHIN one inventory, and on no other path at all - so
	`ITEM:Transfer(invID, x, y)`, which is what every drag and every shift-click
	between two inventories ends in, will happily stack two rifles into the same
	squares. The grid then holds two items claiming the same slots: they draw on
	top of each other, and the one underneath is unreachable until something
	moves the other away.

	THAT IS WHAT THE THREE PISTOLS IN ONE SQUARE WERE. Shift-clicking several
	things quickly is the easy way to it - each click asks the CLIENT's copy of
	the destination for a free slot, and that copy does not change until the
	server answers, so the second and third clicks are both told the same square
	is free - but it is not the only way. A stale container view does it, and so
	does any code that passes coordinates it worked out earlier.

	So the check happens HERE, on the way in, for every caller at once. A
	position that is not free is not refused outright: the item goes to the
	first square that IS free, because "put this in the box" should not fail
	over an argument about which square, and only a genuinely full inventory
	answers `noFit`.

	`libs/cl_quickmove.lua` reserves squares locally as well, so shift-clicking
	twenty things puts them in twenty different squares rather than sending
	twenty moves that this has to redirect one at a time. This is the guarantee;
	that is the manners.
]]

if (not SERVER) then return end

ix.gridguard = ix.gridguard or {}

--[[
	Wrapped on the meta table, which is how every inventory in the game gets it
	- `ix.meta.inventory` is what `ix.inventory.Create` builds them from. The
	same trick, and the same reason, as `sv_autostack.lua`.

	`libs/` loads alphabetically, so this wraps the auto-stacking `Add` rather
	than the other way round. Either order works: the two intervene on
	completely different arguments - auto-stacking only ever handles a call with
	NO position, and this one only ever handles a call WITH one.
]]
local function WrapAdd()
	local meta = ix.meta.inventory

	if (not meta or not meta.Add) then return false end
	if (meta.ixGridGuard) then return true end

	meta.ixGridGuard = true

	local original = meta.Add

	function meta:Add(uniqueID, quantity, data, x, y, noReplication)
		if (not x or not y) then
			return original(self, uniqueID, quantity, data, x, y,
				noReplication)
		end

		--[[
			A number is an existing item instance and a string is an item type
			about to be made. Both have a size, and both are being placed
			somewhere specific, so both are checked.
		]]
		local item = isnumber(uniqueID) and ix.item.instances[uniqueID]
			or ix.item.list[uniqueID]

		if (not item) then
			return original(self, uniqueID, quantity, data, x, y,
				noReplication)
		end

		local width = item.width or 1
		local height = item.height or 1

		--[[
			ITSELF IS NOT IN THE WAY. An item being moved a square to the left
			overlaps where it currently is, and `CanItemFit`'s last argument is
			exactly for that - without it, nudging something would always be
			refused and then "corrected" to the far side of the bag.

			Only for an instance: an item that does not exist yet cannot be
			standing in its own way.
		]]
		local existing = isnumber(uniqueID) and item or nil

		--[[
			`CanItemFit` checks the right-hand edge and NOT the bottom one -
			`(x + x2) > self.w` and nothing about `self.h` - so a tall item
			placed near the bottom passes its test and then writes into rows
			that do not exist. Those slots are outside the grid, which means
			nothing draws them and nothing can ever pick the item up again.
		]]
		local fits = self:CanItemFit(x, y, width, height, existing)
			and (y + height - 1) <= self.h

		if (fits) then
			return original(self, uniqueID, quantity, data, x, y,
				noReplication)
		end

		--[[
			Somewhere else, then. `FindEmptySlot` may answer with a BAG, and
			its coordinates are that bag's rather than this inventory's - so
			when it does, the position is dropped entirely and Helix's own
			search runs again inside `Add`, which knows how to put something
			into a bag.
		]]
		local freeX, freeY, bag = self:FindEmptySlot(width, height)

		if (bag) then
			return original(self, uniqueID, quantity, data, nil, nil,
				noReplication)
		end

		if (not freeX) then return false, "noFit" end

		return original(self, uniqueID, quantity, data, freeX, freeY,
			noReplication)
	end

	return true
end

if (not WrapAdd()) then
	--[[
		A retry rather than a hook. `ix.meta.inventory` is built by Helix's core
		before the schema loads, so at file scope it is normally already there
		and this never runs - but a failure here is items landing on top of each
		other, so it says so rather than going quiet.
	]]
	local attempts = 0

	timer.Create("ixGridGuardWrap", 1, 10, function()
		attempts = attempts + 1

		if (WrapAdd()) then
			timer.Remove("ixGridGuardWrap")
		elseif (attempts >= 10) then
			ErrorNoHalt("[falloutrp] ix.meta.inventory never appeared - items "
				.. "can be placed on top of each other\n")
		end
	end)
end

--------------------------------------------------------------------------------
-- Cleaning up what got through before the guard existed
--------------------------------------------------------------------------------

--[[
	Find items sharing squares, and move the later one somewhere free.

	The guard above stops new overlaps; it cannot undo the ones already written
	to the database, and those are invisible until somebody notices two icons
	drawn on top of each other. `/GridRepair` walks every loaded inventory and
	puts them right.

	THE FIRST CLAIMANT KEEPS THE SQUARE, which is arbitrary and is the point:
	both items are equally real, so the rule only has to be consistent. The
	other one is moved, and moved WITHIN its own inventory - somebody's rifle
	must not appear in a different container because the grid was tidied.

	Returns how many were moved and how many could not be.
]]
function ix.gridguard.Repair()
	local moved, stuck = 0, 0

	for _, inventory in pairs(ix.item.inventories) do
		if (not inventory or not inventory.slots or not inventory.GetSize) then
			continue
		end

		local claimed = {}
		local overlapping = {}

		for item in ix.inventory.Each(inventory) do
			local x, y = item.gridX, item.gridY

			if (not x or not y) then continue end

			local clash = false

			for x2 = 0, (item.width or 1) - 1 do
				for y2 = 0, (item.height or 1) - 1 do
					local key = (x + x2) .. "," .. (y + y2)

					if (claimed[key] and claimed[key] ~= item) then
						clash = true
					end

					claimed[key] = claimed[key] or item
				end
			end

			if (clash) then overlapping[#overlapping + 1] = item end
		end

		for _, item in ipairs(overlapping) do
			--[[
				CLEARED FIRST, so the search does not find the very squares
				this item is sitting in occupied by itself - `FindEmptySlot`
				has no "ignore this one" argument, unlike `CanItemFit`.
			]]
			for x2 = 0, (item.width or 1) - 1 do
				for y2 = 0, (item.height or 1) - 1 do
					local column = inventory.slots[item.gridX + x2]

					if (column and column[item.gridY + y2] == item) then
						column[item.gridY + y2] = nil
					end
				end
			end

			local x, y, bag = inventory:FindEmptySlot(item.width or 1,
				item.height or 1)

			if (not x or bag) then
				--[[
					Put back exactly where it was. An inventory with no room is
					left overlapping rather than having an item quietly moved
					somewhere else or destroyed - the report says so, and an
					admin can make room and run it again.
				]]
				for x2 = 0, (item.width or 1) - 1 do
					for y2 = 0, (item.height or 1) - 1 do
						local column = item.gridX + x2

						inventory.slots[column] = inventory.slots[column] or {}
						inventory.slots[column][item.gridY + y2] = item
					end
				end

				stuck = stuck + 1

				continue
			end

			item.gridX = x
			item.gridY = y

			for x2 = 0, (item.width or 1) - 1 do
				for y2 = 0, (item.height or 1) - 1 do
					inventory.slots[x + x2] = inventory.slots[x + x2] or {}
					inventory.slots[x + x2][y + y2] = item
				end
			end

			--- The database row, so the repair survives a restart.
			local query = mysql:Update("ix_items")
				query:Update("x", x)
				query:Update("y", y)
				query:Where("item_id", item.id)
			query:Execute()

			--[[
				Everybody looking at this inventory is told, because their copy
				still has the item in the old square. `SendSlot` is Helix's own
				and is what a move normally uses.
			]]
			if (inventory.SendSlot) then
				inventory:SendSlot(x, y, item)
			end

			moved = moved + 1
		end
	end

	return moved, stuck
end
