--[[
	The bin: making one, opening it, emptying it.

	See `sh_trash.lua` for what it is and why it is a real inventory.
]]

if (not SERVER) then return end

util.AddNetworkString("ixTrashOpen")
util.AddNetworkString("ixTrashOpened")
util.AddNetworkString("ixTrashDecide")

--[[
	`[character id] = when the offer runs out`.

	CLOSING THE BIN NO LONGER PUTS THINGS BACK BY ITSELF, and that was the
	whole bug: `OnPlayerClose` restored everything the instant the window shut,
	so by the time the confirmation appeared there was nothing left to destroy
	and it answered "the bin was empty" whichever button was pressed. The
	question was being asked after the answer had already been acted on.

	So the contents are held, and one of two things happens: the player answers,
	or this runs out and they are put back. The fallback is what keeps a crash,
	an alt-F4 or a dismissed dialog from being a way to lose things.
]]
ix.trash.pending = ix.trash.pending or {}

local HOLD = 45

--- `[character id] = inventory id`, in memory only. Never saved.
ix.trash.bins = ix.trash.bins or {}

--[[
	The bin for a character, made the first time it is asked for.

	Keyed by CHARACTER, not player: two characters on one account each get
	their own, and a bin does not follow somebody through a character switch
	holding the last one's things.
]]
function ix.trash.Get(client, callback)
	local character = client:GetCharacter()

	if (not character) then return end

	local id = character:GetID()
	local existing = ix.trash.bins[id] and ix.inventory.Get(ix.trash.bins[id])

	if (existing) then
		callback(existing)

		return
	end

	ix.inventory.New(0, ix.trash.InventoryType(), function(inventory)
		if (not IsValid(client)) then return end

		ix.trash.bins[id] = inventory:GetID()

		inventory.vars.isBag = true
		inventory.vars.isContainer = true
		inventory.vars.trash = id

		callback(inventory)
	end)
end

--[[
	Put everything back where it came from.

	The character's own inventory, and anything that will not fit goes on the
	floor rather than being destroyed - cancelling must never be a way to lose
	something, or the confirmation is not a confirmation.
]]
function ix.trash.Restore(client, inventory)
	local character = client:GetCharacter()
	local own = character and character:GetInventory()

	if (not own) then return 0 end

	local moved = 0

	for item in ix.inventory.Each(inventory) do
		--[[
			THE FIFTH ARGUMENT IS `noReplication`, AND IT WAS `true`.

			    ITEM:Transfer(invID, x, y, client, noReplication, isLogical)

			With it set, `targetInv:Add` moves the item on the server and never
			tells the client - so cancelling put everything back into an
			inventory the player could not see it in until they rejoined. It
			looked exactly like the bin emptying itself regardless of the
			answer, which made the confirmation appear to do nothing.

			Nothing here wants to suppress replication. The whole point of
			cancelling is that the player watches their things come back.
		]]
		local ok = item:Transfer(own:GetID(), nil, nil, client)

		if (ok) then
			moved = moved + 1
		else
			item:Spawn(client)
		end
	end

	return moved
end

--[[
	Destroy everything in it. Irreversible, and logged item by item.

	EACH ITEM BY NAME AND ID, not a count. "Threw away 6 items" is useless to
	anybody asking what happened to a rifle; the id is what makes an entry
	searchable against the item that went missing.
]]
function ix.trash.Empty(client, inventory)
	local destroyed = 0
	local names = {}

	for item in ix.inventory.Each(inventory) do
		local quantity = ix.stack.Get(item)

		names[#names + 1] = string.format("%s (%d)%s", item.name, item.id,
			quantity > 1 and (" x" .. quantity) or "")

		ix.log.Add(client, "trashItem", item.name, item.id, quantity,
			item.uniqueID)

		item:Remove()
		destroyed = destroyed + 1
	end

	if (destroyed > 0) then
		ix.log.Add(client, "trashEmpty", destroyed,
			table.concat(names, ", "))
	end

	return destroyed
end

--------------------------------------------------------------------------------
-- Talking to the client
--------------------------------------------------------------------------------

net.Receive("ixTrashOpen", function(length, client)
	if (not client:GetCharacter()) then return end

	--[[
		Rate limited, because opening one makes an inventory the first time and
		a held key would make a great many of them.
	]]
	if ((client.ixNextTrash or 0) > RealTime()) then return end

	client.ixNextTrash = RealTime() + 0.5

	ix.trash.Get(client, function(inventory)
		if (not IsValid(client)) then return end

		--[[
			THE PLAYER IS THE ANCHOR, AND THE CAPS PANEL IS TURNED OFF AT THE
			OTHER END.

			`ix.storage` needs a valid entity to hang an inventory off, and it
			has to be one the CLIENT can also see - the open message is a
			`net.WriteEntity`, and the receiver refuses to build the window at
			all if that comes back NULL:

			    if (IsValid(entity) and inventory and inventory.slots) then

			An invisible anchor prop below the map fails exactly there: it is
			outside every client's PVS, so it is never sent, so the window
			never opens. The world entity is a coin toss on the same question.
			The player is the one entity that is always valid at both ends.

			The cost is that `ix.storage.Sync` then offers to move their money:

			    elseif (info.entity:IsPlayer() and info.entity:GetCharacter()) then
			        info.data.money = info.entity:GetCharacter():GetMoney()

			which is where the caps panel came from. That is turned off in
			`cl_trash.lua`, which knows which inventory is the bin because of
			the message sent just below.
		]]
		net.Start("ixTrashOpened")
			net.WriteUInt(inventory:GetID(), 32)
		net.Send(client)

		ix.storage.Open(client, inventory, {
			name = "Trash",
			entity = client,
			searchTime = 0,
			bMultipleUsers = false,

			--[[
				CLOSING IS NOT EMPTYING. The window shutting - by the close
				button, by walking away, by disconnecting - restores
				everything. Only `ixTrashEmpty` destroys, and that only arrives
				when somebody has answered the question.
			]]
			--[[
				CLOSING ASKS. IT DOES NOT DECIDE.

				The client puts the question up as the window goes; whichever
				button is pressed sends `ixTrashDecide`. Nothing is destroyed
				and nothing is put back until then, which is the only order in
				which a confirmation means anything.

				An unanswered offer is put back by the timer below, so the
				default is always "keep it".
			]]
			OnPlayerClose = function(closer)
				if (not IsValid(closer)) then return end

				local character = closer:GetCharacter()

				if (not character) then return end

				if (table.IsEmpty(inventory:GetItems() or {})) then return end

				ix.trash.pending[character:GetID()] = CurTime() + HOLD
			end
		})
	end)
end)

--[[
	The answer.

	One message with a boolean rather than two messages, so there is exactly
	one place that clears the pending offer - two would eventually be one that
	forgot.
]]
net.Receive("ixTrashDecide", function(length, client)
	local destroy = net.ReadBool()
	local character = client:GetCharacter()

	if (not character) then return end

	local inventory = ix.inventory.Get(ix.trash.bins[character:GetID()] or 0)

	if (not inventory) then return end

	ix.trash.pending[character:GetID()] = nil

	if (not destroy) then
		local restored = ix.trash.Restore(client, inventory)

		if (restored > 0) then
			client:Notify(string.format(
				"%d item(s) put back - nothing was thrown away.", restored))
		end

		return
	end

	local destroyed = ix.trash.Empty(client, inventory)

	if (ix.storage.InUse(inventory)) then
		ix.storage.Close(inventory)
	end

	client:Notify(destroyed > 0
		and string.format("Threw away %d item(s). They are gone.", destroyed)
		or "The bin was empty.")
end)

--[[
	An offer nobody answered.

	Checked on a slow timer rather than one timer per offer: a bin is opened
	rarely, and a named timer per character is a name to get wrong and a timer
	to leave running after a disconnect.
]]
timer.Create("ixTrashExpire", 5, 0, function()
	for id, deadline in pairs(ix.trash.pending) do
		if (CurTime() < deadline) then continue end

		ix.trash.pending[id] = nil

		local inventory = ix.inventory.Get(ix.trash.bins[id] or 0)

		if (not inventory) then continue end

		--[[
			The owner may be gone, in which case `Restore` has nowhere to put
			things and the disconnect handler has already dealt with it.
		]]
		local character = ix.char.loaded[id]
		local owner = character and character:GetPlayer()

		if (not IsValid(owner)) then continue end

		local restored = ix.trash.Restore(owner, inventory)

		if (restored > 0) then
			owner:Notify(string.format(
				"%d item(s) put back - you never said.", restored))
		end
	end
end)

--[[
	A character leaving takes its bin with it.

	Anything still in there goes back to them if they are here to take it, and
	the inventory is dropped from memory either way - a bin is not a thing to
	hold open across a disconnect.
]]
hook.Add("PlayerDisconnected", "ixTrash", function(client)
	local character = client:GetCharacter()

	if (not character) then return end

	local id = character:GetID()
	local inventory = ix.trash.bins[id] and ix.inventory.Get(ix.trash.bins[id])

	if (inventory) then
		ix.trash.Restore(client, inventory)
	end

	ix.trash.bins[id] = nil
end)

ix.log.AddType("trashItem", function(client, name, id, quantity, uniqueID)
	return string.format("%s destroyed %s (item %d, %s)%s in the bin.",
		client:Name(), name, id, uniqueID,
		quantity > 1 and (" x" .. quantity) or "")
end, FLAG_WARNING)

ix.log.AddType("trashEmpty", function(client, count, names)
	return string.format("%s emptied the bin - %d item(s): %s", client:Name(),
		count, names)
end, FLAG_WARNING)
