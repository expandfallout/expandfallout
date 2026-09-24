--[[
	Walking an inventory ONCE PER ITEM.

	`Inventory:Iter()` walks the SLOT GRID, not the items:

	    item = self.slots[x] and self.slots[x][y]
	    x = x + 1

	and `Inventory:Add` writes the item into every slot of its footprint:

	    for x2 = 0, item.width - 1 do
	        for y2 = 0, item.height - 1 do
	            targetInv.slots[index][y + y2] = item

	So a three-by-two rifle is yielded SIX TIMES. Every loop over `Iter()` is
	really a loop over occupied squares, and for a schema full of two- and
	three-square guns that is not the same list at all.

	WHAT IT ACTUALLY COST, before this existed:

	    "[Helix] Cannot give weapon - ls_ak47 does not exist!" five times on
	    every spawn. `GM:PostPlayerLoadout` calls `OnLoadout` once per yield;
	    the first `Give` succeeded and the other five failed because the player
	    already held it. Five failures for a six-square weapon.

	    A de-duplication pass that read those six yields as six items, kept the
	    "first" and unequipped the other five - which were the same item. It
	    unequipped the only rifle the character had, on every single join, and
	    then found six again next time because there had only ever been one.

	    An hour of reading `ITEM:Transfer` looking for why.

	COUNTING IS THE DANGEROUS ONE. Anything that answers "how many of these do
	I have" or "take three of them" against `Iter()` is answering in squares.
	`ix.stack.Count` decides whether a recipe can be crafted.

	This yields each item once, in slot order, and is otherwise the same
	iterator. Where the position matters, `Iter()` is still the right call and
	the duplication is the point - `cl_quickmove.lua` wants squares.
]]

ix.inventory = ix.inventory or {}

--[[
	`for item in ix.inventory.Each(inventory) do`

	Returns an empty iterator for a nil inventory rather than erroring, because
	the alternative is a nil check at all twenty call sites and one of them
	forgetting.
]]
function ix.inventory.Each(inventory)
	if (not inventory or not inventory.Iter) then
		return function() return nil end
	end

	local iterator = inventory:Iter()
	local seen = {}

	return function()
		while (true) do
			local item, x, y = iterator()

			if (not item) then return nil end

			--[[
				Keyed by item id rather than by the table, so an inventory
				holding two SEPARATE items that happen to share a uniqueID
				still yields both - which is the whole point of the id.
			]]
			local id = item.id or item

			if (not seen[id]) then
				seen[id] = true

				return item, x, y
			end
		end
	end
end

--[[
	How many separate items an inventory holds.

	`Inventory:GetItemCount` is Helix's and counts by uniqueID; this counts
	everything, and neither of them counts squares.
]]
function ix.inventory.Count(inventory)
	local count = 0

	for _ in ix.inventory.Each(inventory) do
		count = count + 1
	end

	return count
end
