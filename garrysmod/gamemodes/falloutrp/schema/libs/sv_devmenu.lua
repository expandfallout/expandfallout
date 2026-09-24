--[[
	Developer terminal - the server half.

	The entity decides who gets to SEE the menu. This decides who gets to take
	something out of it, and it is the one that matters: a net message can be
	sent by any client at any time, from anywhere, without ever touching the
	entity. Anything that only checked `ENT:Use` would be handing every player
	an item spawner.

	So every request is re-checked here from scratch:

	    is the sender an admin?
	    is the uniqueID a real registered item?
	    do they have a character with an inventory?
	    will it actually fit?

	None of those are assumptions the client is allowed to make on our behalf.
]]

if (not SERVER) then return end

util.AddNetworkString("ixFODevOpen")
util.AddNetworkString("ixFODevGive")

--[[
	Rate limit.

	Not a security control - the admin check above it is - but a stuck mouse
	button on a "give" row should not enqueue two hundred inventory writes and
	the database traffic that follows.
]]
local nextGive = {}

net.Receive("ixFODevGive", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")
		return
	end

	if ((nextGive[client] or 0) > RealTime()) then return end

	nextGive[client] = RealTime() + 0.1

	local uniqueID = net.ReadString()
	local amount = math.Clamp(net.ReadUInt(8), 1, 20)

	--[[
		The quality to stamp on it, or blank for none.

		CHECKED AGAINST THE TIER LIST AND AGAINST THE ITEM, not trusted: a
		rarity on something that is not a weapon is a number nothing reads,
		and an unknown tier id would be stored and then answer as Common for
		ever - `ix.rarity.Get` refuses to return an id it does not know, so the
		weapon would simply look like it had lost its quality.
	]]
	local rarity = net.ReadString()

	if (rarity ~= "" and (not ix.rarity.byID[rarity]
	or not ix.rarity.Applies(uniqueID))) then
		rarity = ""
	end

	local itemTable = ix.item.list[uniqueID]

	if (not itemTable) then
		client:NotifyLocalized("devTerminalNoItem", uniqueID)
		return
	end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	--[[
		Added one at a time rather than as a stack.

		Helix has no item stacking (see 08-open-items.md), so `Add(id, count)`
		would create `count` separate instances anyway - doing it in a loop just
		makes the failure visible: the moment one does not fit, we stop and say
		how many made it, instead of silently dropping the rest.
	]]
	local given = 0
	local data = rarity ~= "" and {rarity = rarity} or nil

	for _ = 1, amount do
		if (not inventory:Add(uniqueID, 1, data)) then break end

		given = given + 1
	end

	if (given < 1) then
		client:NotifyLocalized("devTerminalNoRoom", itemTable.name)
		return
	end

	client:NotifyLocalized("devTerminalGave", given,
		rarity ~= "" and (ix.rarity.Tier(rarity).name .. " " .. itemTable.name)
			or itemTable.name)

	ix.log.Add(client, "devTerminalGive", uniqueID, given,
		rarity ~= "" and rarity or nil)
end)

hook.Add("PlayerDisconnected", "ixFODevMenu", function(client)
	nextGive[client] = nil
end)

--[[
	Logged, because an admin handing themselves gear is exactly the sort of
	thing that should be in the record rather than only in someone's memory.
]]
ix.log.AddType("devTerminalGive", function(client, uniqueID, amount, rarity)
	return string.format("%s took %dx %s%s from the developer terminal.",
		client:Name(), amount, uniqueID,
		rarity and (" at " .. ix.rarity.Tier(rarity).name) or "")
end, FLAG_DANGER)

ix.log.AddType("devTerminalDenied", function(client)
	return string.format("%s tried to use the developer terminal without access.",
		IsValid(client) and client:Name() or "unknown")
end, FLAG_DANGER)

--[[
	Opening it without the entity.

	The terminal started as a spawnable prop because that is how Helix's own
	vendors work, but a dev tool you have to place in the world before you can
	use it is a dev tool you stop using. The entity still works; this is the
	direct route.

	Admin is checked HERE rather than trusting a client to only ask when
	allowed - and it is checked again in the give and bot handlers, because
	having the menu open is not permission to take anything out of it.
]]
util.AddNetworkString("ixFODevRequest")

net.Receive("ixFODevRequest", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")
		return
	end

	net.Start("ixFODevOpen")
	net.Send(client)
end)

--[[
	A Helix command as well as the console one, so it is discoverable: this
	shows up in the `/help` list, where a concommand nobody was told about does
	not.
]]

--[[
	QUICK ACTIONS.

	One net message with an action name rather than a message per button. The
	set is a closed table, so an unknown action does nothing at all - a client
	cannot invent one, and adding a button here does not mean adding another
	net string to the registry.

	Anything that ALREADY has an admin command is not duplicated here. The
	terminal runs `/charsetrads` and friends instead, so there is one
	implementation of each rule, already validated and already logged.
]]
util.AddNetworkString("ixFODevAction")

local ACTIONS = {
	heal = function(client)
		client:SetHealth(client:GetMaxHealth())

		local character = client:GetCharacter()

		--[[
			Radiation caps max health, so a heal that ignored it would push the
			player above their own ceiling and read as a bug.
		]]
		if (character and character.ApplyBodyState) then
			character:ApplyBodyState()
		end

		return "Healed."
	end,

	refill = function(client)
		local character = client:GetCharacter()

		if (not character) then return end

		if (character.SetHunger) then
			character:SetHunger(100)
			character:SetThirst(100)
		end

		if (character.SetRadiation) then
			character:SetRadiation(0)
			character:ApplyBodyState()
		end

		client:SetHealth(client:GetMaxHealth())

		return "Health, hunger, thirst and rads reset."
	end,

	--[[
		Empties the inventory. The single most useful thing when testing item
		code, and the single most destructive - hence the confirmation on the
		client and the danger flag on the log.
	]]
	stripitems = function(client)
		local character = client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (not inventory) then return end

		local removed = 0

		for item in ix.inventory.Each(inventory) do
			item:Remove()
			removed = removed + 1
		end

		return string.format("Removed %d item(s).", removed)
	end,

	--[[
		Dropped items pile up fast while testing and each is a real entity with
		a real inventory row behind it.
	]]
	clearground = function(client)
		local removed = 0

		for _, entity in ipairs(ents.FindByClass("ix_item")) do
			entity:Remove()
			removed = removed + 1
		end

		return string.format("Removed %d dropped item(s).", removed)
	end,

	--[[
		Deletes the records too, through `RemovePlaced`. Plain `Remove` would
		clear the map and leave every container to come back on restart, which
		is the opposite of what a button called CLEAR means.
	]]
	clearlootables = function(client)
		local removed = 0

		for _, entity in ipairs(ents.FindByClass("ix_lootable")) do
			if (ix.loot.RemovePlaced(entity)) then removed = removed + 1 end
		end

		return string.format("Removed %d lootable(s).", removed)
	end,

	--[[
		Forces every placed container to re-roll on next open, without touching
		what they are or where they are. The fastest way to test a loot table
		change against containers already in the world.
	]]
	resetlootables = function(client)
		local reset = 0

		for _, entity in ipairs(ents.FindByClass("ix_lootable")) do
			entity.ixContents = nil
			entity.ixNextFill = nil
			reset = reset + 1
		end

		return string.format("Reset %d container(s).", reset)
	end,

	savelootables = function(client)
		return string.format("Saved %d lootable(s).", ix.loot.SavePlaced())
	end
}

--[[
	CONFIGURATION FROM THE TERMINAL.

	A closed list, like the actions above and for the same reason: the key
	arrives from the client, so anything not named here cannot be written. That
	matters more for a config than for an action - `ix.config.Set` will happily
	write any key in the registry, including Helix's own, and the terminal is
	not a general config editor.

	The TYPE is taken from what is already stored rather than from the message.
	A number field that arrived as a string would be saved as a string and read
	back by `math.max` as an error some minutes later, in a different file.

	THE LIST ITSELF IS IN `sh_devmenu.lua`, so the window can be built from the
	same table this enforces - see the note there.
]]
util.AddNetworkString("ixFODevConfig")


net.Receive("ixFODevConfig", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	local key = net.ReadString()
	local value = net.ReadType()

	if (not ix.devmenu.configurable[key]) then return end

	local config = ix.config.stored[key]

	if (not config) then return end

	local wanted = type(config.default)

	if (wanted == "number") then
		value = tonumber(value)

		if (not value) then return end

		--- The slider bounds the config declared, honoured off the slider too.
		local data = config.data or {}

		value = math.Clamp(value, data.min or -math.huge,
			data.max or math.huge)

		if (not data.decimals or data.decimals == 0) then
			value = math.Round(value)
		end
	elseif (wanted == "boolean") then
		value = tobool(value)
	else
		value = tostring(value)
	end

	local before = ix.config.Get(key)

	ix.config.Set(key, value)

	client:Notify(string.format("%s: %s", key, tostring(value)))

	ix.log.Add(client, "devTerminalConfig", key, tostring(before),
		tostring(value))
end)

ix.log.AddType("devTerminalConfig", function(client, key, before, after)
	return string.format("%s set %s from %s to %s.", client:Name(), key,
		before, after)
end, FLAG_DANGER)

net.Receive("ixFODevAction", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")
		return
	end

	local action = ACTIONS[net.ReadString()]

	if (not action) then return end

	local result = action(client)

	if (result) then
		client:Notify(result)
	end

	ix.log.Add(client, "devTerminalAction", result or "?")
end)

ix.log.AddType("devTerminalAction", function(client, what)
	return string.format("%s used a developer terminal action: %s",
		client:Name(), what)
end, FLAG_DANGER)

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
