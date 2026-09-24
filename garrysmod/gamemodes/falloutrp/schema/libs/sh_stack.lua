--[[
	Item stacks.

	Helix has no quantity at all - an item is one thing, and five pieces of
	steel are five items in five slots. Phoenix add `isStackable` and
	`maxQuantity` to theirs, and this is the same idea written against Helix.

	THE COUNT LIVES IN ITEM DATA, not in a new column. `item:GetData` is the
	`data` field on `ix_items`, so a stack survives being dropped, put in a
	container, and a restart, and nothing had to be added to the schema of the
	database to make that true.

	STACKING IS A GESTURE, NOT AN AUTOMATIC. Dragging one onto another merges
	them, and Helix already has the mechanism for that: `ITEM.functions.combine`
	is called on the item being dragged ONTO, with the id of the one being
	dragged. Merging silently on pickup would take the choice away, and an
	inventory that rearranges itself while you are looking at it is worse than
	one that does what you told it.

	    MAX FIVE, by default. `ITEM.maxQuantity` overrides it per item, and
	    `ITEM.isStackable = false` means it never stacks at all - an Enclave
	    access pad is one specific object, and two of them in one slot would be
	    a lie about what is in the room.
]]

ix.stack = ix.stack or {}

--- The default ceiling. An item may name a smaller or larger one.
ix.stack.max = 5

function ix.stack.Get(item)
	--[[
		`GetData` as well as the item, because this is called on the item TABLE
		as well as on instances - the shop tooltip and the loot preview both
		hand over `ix.item.list[uniqueID]`, which has no data of its own. Helix
		makes that safe (`self.data = self.data or {}`) but a plain table with
		no item metatable at all would not be.
	]]
	if (not item or not item.GetData) then return 1 end

	return math.max(math.floor(item:GetData("quantity", 1)), 1)
end

function ix.stack.GetMax(item)
	if (not item or not item.isStackable) then return 1 end

	return math.max(math.floor(item.maxQuantity or ix.stack.max), 1)
end

--[[
	Can these two merge, and by how much?

	Returns the number that would move. 0 means no - a different item, a full
	target, or either of them not stackable - so callers can ask one question
	instead of four.
]]
function ix.stack.CanMerge(target, source)
	if (not target or not source or target == source) then return 0 end
	if (not target.isStackable) then return 0 end
	if (target.uniqueID ~= source.uniqueID) then return 0 end

	local room = ix.stack.GetMax(target) - ix.stack.Get(target)

	if (room < 1) then return 0 end

	return math.min(room, ix.stack.Get(source))
end

if (SERVER) then
	--[[
		Set the count, and remove the item when it reaches zero.

		One function so "took the last one" is handled the same way everywhere.
		`SetData` networks to whoever can see the item, which is what redraws
		the number on the icon.
	]]
	function ix.stack.Set(item, quantity)
		quantity = math.floor(quantity or 0)

		if (quantity < 1) then
			item:Remove()

			return 0
		end

		item:SetData("quantity", quantity)

		return quantity
	end

	--[[
		Move as much as will fit from one stack into another.

		Returns how much moved. The source is removed when it is emptied, and
		kept with the remainder when it is not - which is what makes merging a
		part-stack into a nearly-full one leave you holding the difference
		rather than losing it.
	]]
	function ix.stack.Merge(target, source)
		local moving = ix.stack.CanMerge(target, source)

		if (moving < 1) then return 0 end

		ix.stack.Set(target, ix.stack.Get(target) + moving)
		ix.stack.Set(source, ix.stack.Get(source) - moving)

		return moving
	end

	--[[
		Take `quantity` out of a stack into a new item beside it.

		The new one is created first and only then is the original reduced: an
		inventory with no room leaves the stack exactly as it was, rather than
		destroying part of it and failing to place the rest.
	]]
	function ix.stack.Split(item, quantity, callback)
		local have = ix.stack.Get(item)

		quantity = math.Clamp(math.floor(quantity or 0), 1, have - 1)

		if (have < 2 or quantity < 1) then
			if (callback) then callback(false, "notEnough") end

			return
		end

		local inventory = ix.item.inventories[item.invID]

		if (not inventory) then
			if (callback) then callback(false, "noInventory") end

			return
		end

		local added, reason = inventory:Add(item.uniqueID, 1,
			{quantity = quantity})

		if (added == false or added == nil) then
			if (callback) then callback(false, reason or "noFit") end

			return
		end

		ix.stack.Set(item, have - quantity)

		if (callback) then callback(true) end
	end
end

--------------------------------------------------------------------------------
-- Whole inventories
--------------------------------------------------------------------------------

--[[
	How many of something an inventory holds, counting stacks.

	`inventory:GetItemCount` exists in Helix and counts ITEMS, not quantities -
	so one stack of five steel answers 1 there and 5 here. Crafting needs the
	second answer, and getting the first is how a recipe wanting five steel
	refuses somebody who is holding five steel.
]]
function ix.stack.Count(inventory, uniqueID)
	if (not inventory) then return 0 end

	local total = 0

	for item in ix.inventory.Each(inventory) do
		if (item.uniqueID == uniqueID) then
			total = total + ix.stack.Get(item)
		end
	end

	return total
end

if (SERVER) then
	--[[
		Take a number of something out, across as many stacks as it takes.

		Returns true only if the whole amount was taken. It COUNTS FIRST and
		removes second: a recipe that consumed four of the five steel it needed
		and then failed would be a recipe that eats your materials.

		Smallest stacks first, so a part-stack is cleared before a full one is
		broken into. That leaves an inventory tidier than taking whatever comes
		first, and it costs one sort.
	]]
	function ix.stack.Take(inventory, uniqueID, count)
		count = math.floor(count or 0)

		if (count < 1) then return true end
		if (ix.stack.Count(inventory, uniqueID) < count) then return false end

		local found = {}

		for item in ix.inventory.Each(inventory) do
			if (item.uniqueID == uniqueID) then
				found[#found + 1] = item
			end
		end

		table.sort(found, function(a, b)
			return ix.stack.Get(a) < ix.stack.Get(b)
		end)

		for _, item in ipairs(found) do
			if (count < 1) then break end

			local have = ix.stack.Get(item)
			local taking = math.min(have, count)

			count = count - taking

			ix.stack.Set(item, have - taking)
		end

		return true
	end

	--[[
		Put a number of something in, filling part-stacks before making new
		ones.

		Returns how many actually went in. A full inventory takes what fits and
		says so, rather than silently dropping the rest - the caller decides
		whether to put the remainder on the floor.

		`data` is stamped on everything created, COPIED per item rather than
		shared: two stacks handed the same table would be two items pointing at
		one set of values, and writing to one would silently write to both.
		The workbenches use it to mark experience owed on a finished craft.
	]]
	function ix.stack.Give(inventory, uniqueID, count, data)
		count = math.floor(count or 0)

		if (not inventory or count < 1) then return 0 end

		local itemTable = ix.item.list[uniqueID]

		if (not itemTable) then return 0 end

		local given = 0

		if (itemTable.isStackable) then
			local maximum = math.max(
				math.floor(itemTable.maxQuantity or ix.stack.max), 1)

			for item in ix.inventory.Each(inventory) do
				if (count < 1) then break end
				if (item.uniqueID ~= uniqueID) then continue end

				local room = maximum - ix.stack.Get(item)

				if (room < 1) then continue end

				local adding = math.min(room, count)

				ix.stack.Set(item, ix.stack.Get(item) + adding)

				count = count - adding
				given = given + adding
			end

			--[[
				Whole stacks for the remainder, so twelve steel is three items
				rather than twelve.
			]]
			while (count > 0) do
				local batch = math.min(maximum, count)
				local values = data and table.Copy(data) or {}

				values.quantity = batch

				local added = inventory:Add(uniqueID, 1, values)

				if (added == false or added == nil) then break end

				count = count - batch
				given = given + batch
			end

			return given
		end

		for _ = 1, count do
			local added = inventory:Add(uniqueID, 1,
				data and table.Copy(data) or nil)

			if (added == false or added == nil) then break end

			given = given + 1
		end

		return given
	end
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

if (CLIENT) then
	--[[
		`fo_stack_report` - why did dragging that onto that not merge them?

		It walks the SAME path the drag does, in order, and prints what each
		step answered:

		    1. is `combine` on the instance at all (it lives on the base, and
		       Helix's base merge is a `table.Merge` that could have lost it)
		    2. what `OnCanRun(target, {source.id})` returns - this is the exact
		       call `PaintDragPreview` makes to decide whether to light the
		       target up and set `combineItem`
		    3. what `CanMerge` saw, field by field

		If step 2 says true, nothing here is wrong and the fault is in the drag
		itself - which is a different file and a different fix. Splitting those
		two apart is the whole point; see `07-gotchas.md` principle 1.
	]]
	local function Line(text)
		MsgC(Color(255, 200, 100), "[stack] " .. text .. "\n")

		if (IsValid(LocalPlayer())) then
			LocalPlayer():ChatPrint("[stack] " .. text)
		end
	end

	concommand.Add("fo_stack_report", function()
		local character = LocalPlayer():GetCharacter()
		local inventory = character and character:GetInventory()

		if (not inventory) then
			Line("no inventory")

			return
		end

		--- Grouped by uniqueID, so a pair to test is whatever has two.
		local groups = {}

		for item in ix.inventory.Each(inventory) do
			groups[item.uniqueID] = groups[item.uniqueID] or {}

			local list = groups[item.uniqueID]

			list[#list + 1] = item
		end

		local tested = 0

		for uniqueID, list in SortedPairs(groups) do
			if (#list < 2) then continue end

			tested = tested + 1

			local target, source = list[1], list[2]
			local itemTable = ix.item.list[uniqueID]

			Line(string.format("%s - %d of them, ids %d and %d", uniqueID,
				#list, target.id, source.id))

			Line(string.format("   table: isStackable=%s maxQuantity=%s",
				tostring(itemTable and itemTable.isStackable),
				tostring(itemTable and itemTable.maxQuantity)))

			Line(string.format("   instance: isStackable=%s quantity=%d "
				.. "max=%d", tostring(target.isStackable),
				ix.stack.Get(target), ix.stack.GetMax(target)))

			local functions = target.functions or {}

			Line(string.format("   functions: combine=%s Split=%s (%d total)",
				tostring(functions.combine ~= nil),
				tostring(functions.Split ~= nil), table.Count(functions)))

			--[[
				`ix.item.instances` is what `OnCanRun` dereferences, and a
				client that does not have the SOURCE instance would make the
				whole thing answer false for a reason nothing else would show.
			]]
			Line(string.format("   instances: target=%s source=%s",
				tostring(ix.item.instances[target.id] ~= nil),
				tostring(ix.item.instances[source.id] ~= nil)))

			Line(string.format("   CanMerge = %d",
				ix.stack.CanMerge(target, source)))

			if (functions.combine and functions.combine.OnCanRun) then
				local ok, result = pcall(functions.combine.OnCanRun, target,
					{source.id})

				Line(string.format("   OnCanRun -> %s%s", tostring(result),
					ok and "" or "  (ERRORED: " .. tostring(result) .. ")"))
			else
				Line("   OnCanRun -> NO COMBINE FUNCTION ON THE INSTANCE")
			end

			if (tested >= 3) then break end
		end

		if (tested == 0) then
			Line("nothing in your inventory has two of it - pick up a second "
				.. "of something stackable and run this again")
		end
	end)

	--[[
		`fo_stack_try` - fire the merge the drag would have fired.

		Takes the two ids `fo_stack_report` printed and sends the same
		`ixInventoryAction` the drop handler sends. If the report says
		OnCanRun is true and this merges them, the fault is in the DRAG, not in
		the item; if this does nothing either, it is the server half.
	]]
	concommand.Add("fo_stack_try", function(_, _, arguments)
		local target = tonumber(arguments[1])
		local source = tonumber(arguments[2])

		if (not target or not source) then
			Line("usage: fo_stack_try <target id> <source id>")

			return
		end

		local item = ix.item.instances[target]

		if (not item) then
			Line("no instance " .. target .. " on this client")

			return
		end

		net.Start("ixInventoryAction")
			net.WriteString("combine")
			net.WriteUInt(target, 32)
			net.WriteUInt(item.invID or 0, 32)
			net.WriteTable({source})
		net.SendToServer()

		Line(string.format("sent combine %d <- %d in inventory %d", target,
			source, item.invID or 0))
	end)
end
