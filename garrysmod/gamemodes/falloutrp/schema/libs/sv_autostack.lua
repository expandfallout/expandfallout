--[[
	Stacking on the way in.

	`ix.stack` has always been able to merge two stacks - you drag one onto the
	other - and nothing ever did it for you. So forty ore out of one node was
	forty separate stacks of one, in forty slots, and the stacking system might
	as well not have existed for anything picked up rather than tidied by hand.

	THE HOOK IS `InventoryItemAdded`, which is Helix's own and fires on BOTH
	paths through `Inventory:Add` - the one that creates an item (mining,
	harvesting, loot) and the one that moves an existing instance (picking a
	dropped item up, taking one out of a container). One hook, every way in.

	TWO THINGS ARE DELIBERATELY LEFT ALONE:

	    a move inside one inventory   dragging a stack to a different slot in
	                                  your own bag is not "putting it away",
	                                  and silently welding it to the stack it
	                                  landed next to is the sort of help that
	                                  loses somebody the split they just made
	    a split                       `ix.stack.Split` adds a new item to the
	                                  same inventory ON PURPOSE, and without a
	                                  guard this would merge it straight back
	                                  and make splitting a no-op
]]

if (not SERVER) then return end

--[[
	Fill up whatever is already there.

	Merges into every partial stack in turn rather than only the first, because
	somebody carrying two half stacks and picking up a third should end with
	one - which is the whole point of doing this automatically.
]]
local function Absorb(inventory, item)
	local absorbed = 0

	for other in ix.inventory.Each(inventory) do
		if (other == item or other.uniqueID ~= item.uniqueID) then continue end
		if (ix.stack.Get(item) < 1) then break end

		local moved = ix.stack.Merge(other, item)

		absorbed = absorbed + moved

		--- `Merge` removes the source when it empties it.
		if (not ix.item.instances[item.id]) then break end
	end

	return absorbed
end

--[[
	TOPPING UP BEFORE ANYTHING IS CREATED.

	The hook below is the general answer and it is a tick late, which is fine
	for something picked up off the floor and wrong for something MADE: forty
	ore out of a node is forty calls to `Add`, and each one needs a free slot
	for the moment before the merge catches up. An inventory with one slot left
	and a half stack of iron in it would refuse the second swing.

	So `Add` itself tries the stacks first. If the whole amount fits into what
	is already there, no item is created at all and no slot is needed.

	WRAPPED ON THE META TABLE, which is how every inventory in the game gets it
	- `ix.meta.inventory` is what `ix.inventory.Create` builds them from.

	It only ever intervenes for the plainest case: a uniqueID, no data, no
	position asked for, and an item type that stacks. Anything with data on it
	(a weapon with ammo, a collar with a deadline) or aimed at a particular
	slot goes through Helix's own path untouched.
]]
local function WrapAdd()
	local meta = ix.meta.inventory

	if (not meta or not meta.Add) then return false end
	if (meta.ixAutoStack) then return true end

	meta.ixAutoStack = true

	local original = meta.Add

	function meta:Add(uniqueID, quantity, data, x, y, noReplication)
		local plain = isstring(uniqueID) and not data and not x and not y
			and not ix.stack.splitting

		if (not plain) then
			return original(self, uniqueID, quantity, data, x, y, noReplication)
		end

		local itemTable = ix.item.list[uniqueID]

		if (not itemTable or not itemTable.isStackable) then
			return original(self, uniqueID, quantity, data, x, y, noReplication)
		end

		local wanted = math.max(math.floor(tonumber(quantity) or 1), 1)
		local remaining = wanted

		for item in ix.inventory.Each(self) do
			if (item.uniqueID ~= uniqueID) then continue end

			local room = ix.stack.GetMax(item) - ix.stack.Get(item)

			if (room < 1) then continue end

			local moving = math.min(room, remaining)

			ix.stack.Set(item, ix.stack.Get(item) + moving)

			remaining = remaining - moving

			--[[
				ALL OF IT WENT INTO STACKS. `true` is what Helix's own
				multiple-quantity path returns, so every caller that checks
				`added == false or added == nil` reads this the same way.
			]]
			if (remaining < 1) then return true end
		end

		return original(self, uniqueID, remaining, data, x, y, noReplication)
	end

	return true
end

if (not WrapAdd()) then
	timer.Create("ixAutoStackAdd", 1, 10, function()
		if (WrapAdd()) then timer.Remove("ixAutoStackAdd") end
	end)
end

--[[
	And the general case: anything that ARRIVES rather than being made.

	A dropped item picked up, or one taken out of a container, is an existing
	instance being moved - `Add` above never sees a uniqueID for it - so it is
	merged after the fact instead.
]]
hook.Add("InventoryItemAdded", "ixAutoStack", function(oldInventory,
	inventory, item)
	if (not item or not item.isStackable) then return end
	if (not inventory or not inventory.GetID) then return end

	--- A split is putting one there on purpose. See the header.
	if (ix.stack.splitting) then return end

	--- Shuffling something around your own bag is not an arrival.
	if (oldInventory and oldInventory.GetID
	and oldInventory:GetID() == inventory:GetID()) then
		return
	end

	--[[
		NEXT TICK, not now.

		Helix is in the middle of `Add` - the slots have been written and the
		item's own callback has not necessarily run yet - and removing the item
		from inside that leaves the inventory half updated. A tick later the
		add is finished and merging is an ordinary edit.
	]]
	local id = item.id
	local invID = inventory:GetID()

	timer.Simple(0, function()
		local instance = ix.item.instances[id]
		local target = ix.item.inventories[invID]

		if (not instance or not target or not target.GetID) then return end
		if (instance.invID ~= invID) then return end

		Absorb(target, instance)
	end)
end)

--[[
	The guard around splitting, wrapped rather than written into `ix.stack`.

	`Split` is shared code that predates this file and has no reason to know
	about it; the flag lives here, with the hook that reads it.
]]
local function Wrap()
	if (ix.stack.wrappedSplit) then return true end
	if (not ix.stack.Split) then return false end

	ix.stack.wrappedSplit = true

	local original = ix.stack.Split

	function ix.stack.Split(item, quantity, callback)
		ix.stack.splitting = true

		local ok, err = pcall(original, item, quantity, callback)

		ix.stack.splitting = nil

		if (not ok) then
			ErrorNoHalt("[falloutrp] stack split failed: "
				.. tostring(err) .. "\n")
		end
	end

	return true
end

if (not Wrap()) then
	timer.Create("ixAutoStackWrap", 1, 10, function()
		if (Wrap()) then timer.Remove("ixAutoStackWrap") end
	end)
end
