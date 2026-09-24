--[[
	The trade-up bench, server side.

	See `sh_tradeup.lua` for the rules. This is the half that is allowed to
	believe nothing the client says: the window sends a uniqueID and a quality,
	and everything else - that the bench exists, that it is a trade-up bench,
	that you are standing at it, that you may use it, and that you really do
	have five of them - is worked out here against the real inventory.
]]

if (not SERVER) then return end

util.AddNetworkString("ixTradeUp")

ix.tradeup = ix.tradeup or {}

--[[
	The items a trade would consume, or nil and a reason.

	COLLECTED AS A LIST FIRST, and nothing is removed until the list is
	complete. Removing as they are found would leave a partial trade behind if
	the fifth one turned out not to be there - which is exactly the failure that
	loses somebody four rifles.
]]
function ix.tradeup.Collect(inventory, uniqueID, rarity)
	local amount = ix.tradeup.Amount()
	local found = {}

	for item in ix.inventory.Each(inventory) do
		if (item.uniqueID ~= uniqueID) then continue end
		if (not ix.tradeup.Eligible(item)) then continue end
		if (ix.rarity.Get(item) ~= rarity) then continue end

		found[#found + 1] = item

		if (#found >= amount) then break end
	end

	if (#found < amount) then
		return nil, string.format("You need %d of those, unequipped. You have "
			.. "%d.", amount, #found)
	end

	return found
end

--[[
	One trade.

	The order is deliberate: the new weapon is made FIRST and the five are
	removed only once it exists. `Inventory:Add` can fail - there may be no
	room, since the five being consumed are still in the way - and a failure
	after the removal would be five weapons gone and nothing to show for it.

	Room is the one thing this asks the player to sort out: the new weapon has
	to fit alongside the old ones for a moment.
]]
function ix.tradeup.Run(client, uniqueID, rarity)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false, "You have no inventory." end

	local nextTier = ix.tradeup.NextTier(rarity)

	if (not nextTier) then
		return false, string.format("%s is as far as this bench goes.",
			ix.tradeup.Cap().name)
	end

	local items, reason = ix.tradeup.Collect(inventory, uniqueID, rarity)

	if (not items) then return false, reason end

	local itemTable = ix.item.list[uniqueID]
	local name = itemTable and itemTable.name or uniqueID

	--[[
		`Inventory:Add` answers `x, y, invID` when it fits and `false, reason`
		when it does not - so the first return is a grid column, not the item.
		The item itself is made asynchronously inside it and is not needed here.
	]]
	local placed = inventory:Add(uniqueID, 1, {rarity = nextTier.id})

	if (not placed) then
		return false, "No room for it. Clear a space first."
	end

	for _, item in ipairs(items) do
		item:Remove()
	end

	ix.log.Add(client, "tradeUp", name, ix.rarity.Tier(rarity).name,
		nextTier.name)

	return true, string.format("%s %s.", nextTier.name, name)
end

net.Receive("ixTradeUp", function(length, client)
	local entity = net.ReadEntity()
	local uniqueID = net.ReadString()
	local rarity = net.ReadString()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 200) then return end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record) then return end

	local ok, reason = ix.bench.CanUse(client, record)

	if (not ok) then
		client:Notify(reason)

		return
	end

	--[[
		THE BENCH HAS TO BE A TRADE-UP BENCH.

		The window only ever opens on one, but the message is a message and
		anybody can send it - without this, a chem bench would trade up.
	]]
	local definition = ix.bench.TypeOf(record)

	if (not definition or definition.mode ~= "tradeup") then return end

	local traded, result = ix.tradeup.Run(client, uniqueID, rarity)

	client:Notify(result)

	if (not traded) then return end

	if (IsValid(record.entity)) then
		record.entity:EmitSound("phoenix/ui/nv/itm_bottle_up_02.mp3", 65, 100,
			0.6)
	end

	--- So the window redraws with the five gone and the new one in.
	ix.bench.Refresh(record)
end)

ix.log.AddType("tradeUp", function(client, name, from, to)
	return string.format("%s traded %d %s %s up to %s.", client:Name(),
		ix.tradeup.Amount(), from, name, to)
end)
