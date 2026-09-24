--[[
	Fitting a modulator, server side.

	See `sh_modulator.lua` for the rules. The window sends which modulator to
	fit and nothing else: which armour it goes into is worked out HERE, from
	what the character is actually wearing, so there is no armour id in the
	message that could name somebody else's suit.
]]

if (not SERVER) then return end

util.AddNetworkString("ixModulate")

ix.modulator = ix.modulator or {}

--[[
	The body armour a character is wearing, or nil.

	`ix.armor.GetEquipped` is keyed by slot, so this is one lookup rather than a
	search - and it is the same table the resistance sums read, so the suit
	being modulated is by definition the suit doing the work.
]]
function ix.modulator.WornBody(character)
	return ix.armor.GetEquipped(character).body
end

--[[
	Find one unfitted modulator of a kind in an inventory.

	Returns the item, or nil. The FIRST one found: they are identical, carry no
	instance data of their own, and any of them will do.
]]
local function FindModulator(inventory, uniqueID)
	for item in ix.inventory.Each(inventory) do
		if (item.uniqueID == uniqueID) then return item end
	end
end

--[[
	Fit one. Returns `true, message` or `false, reason`.

	THE ARMOUR IS WRITTEN BEFORE THE MODULATOR IS REMOVED, and the order
	matters for the reason it always does: a failure between the two should
	leave the player with the modulator rather than without it. Writing item
	data cannot fail, so in practice nothing lands in between - but the order
	is free and the alternative is somebody losing one.
]]
function ix.modulator.Fit(client, uniqueID)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false, "You have no inventory." end

	local itemTable = ix.item.list[uniqueID]
	local armor = ix.modulator.WornBody(character)

	if (not armor) then
		return false, "Put the armour on first. A modulator goes into the "
			.. "suit you are wearing."
	end

	local ok, reason = ix.modulator.CanFit(itemTable, armor)

	if (not ok) then return false, reason end

	local modulator = FindModulator(inventory, uniqueID)

	if (not modulator) then
		return false, string.format("You have no %s.",
			itemTable.name or uniqueID)
	end

	--[[
		READ, CHANGED AND WRITTEN BACK WHOLE.

		`item:GetData` hands back the stored table itself rather than a copy, so
		writing into it directly would change the suit without ever telling the
		item it had changed - and `SetData` is what networks it to the owner and
		writes the row. The copy also means a failure above leaves nothing
		half-written.
	]]
	local mods = table.Copy(armor:GetData("mods", {}) or {})

	mods[uniqueID] = true

	armor:SetData("mods", mods)
	modulator:Remove()

	--[[
		The suit's numbers have changed, so whatever the server networked about
		this character's armour is now out of date. `ix.armor.Refresh` is what
		equipping one calls, and fitting a modulator changes exactly the same
		sums.
	]]
	if (ix.armor.Refresh) then
		ix.armor.Refresh(client)
	end

	ix.log.Add(client, "modulatorFit", itemTable.name or uniqueID,
		armor.name or armor.uniqueID)

	return true, string.format("%s fitted to %s.",
		itemTable.name or uniqueID, armor.name or "your armour")
end

net.Receive("ixModulate", function(length, client)
	local entity = net.ReadEntity()
	local uniqueID = net.ReadString()

	if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 200) then return end

	local record = ix.bench.Get(entity:GetBenchID())

	if (not record) then return end

	local allowed, why = ix.bench.CanUse(client, record)

	if (not allowed) then
		client:Notify(why)

		return
	end

	--- The bench has to be a modulate bench; the message is only a message.
	local definition = ix.bench.TypeOf(record)

	if (not definition or definition.mode ~= "modulate") then return end

	local fitted, result = ix.modulator.Fit(client, uniqueID)

	client:Notify(result)

	if (not fitted) then return end

	if (IsValid(record.entity)) then
		record.entity:EmitSound("phoenix/ui/nv/itm_bottle_up_02.mp3", 65, 90,
			0.6)
	end
end)

ix.log.AddType("modulatorFit", function(client, name, armor)
	return string.format("%s fitted a %s to their %s.", client:Name(), name,
		armor)
end)
