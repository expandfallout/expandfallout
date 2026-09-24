--[[
	The live editor, server side: storing the overrides and telling everybody.

	See `sh_live.lua` for what an override is. This is the save, the net
	handlers and the sync - and the sync matters more here than in most systems:
	a weapon's damage is read on the CLIENT for prediction and on the SERVER for
	the damage it does, so an override that reached only one of them would make
	a rifle that feels wrong and hits right.

	NOT PER MAP. What a weapon does is a decision about the schema.
]]

if (not SERVER) then return end

util.AddNetworkString("ixLiveSync")
util.AddNetworkString("ixLiveSet")
util.AddNetworkString("ixLiveOpen")
util.AddNetworkString("ixLiveCombat")
util.AddNetworkString("ixLiveTabs")

local KEY = "liveedit"
local COMBAT_KEY = "livecombat"
local TABS_KEY = "livetabs"
local loaded = false

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

function ix.live.Save()
	if (not loaded) then return end

	ix.data.Set(KEY, ix.live.overrides, false, true)
	ix.data.Set(COMBAT_KEY, ix.combat.settings, false, true)
	ix.data.Set(TABS_KEY, ix.live.tabOrder, false, true)
end

function ix.live.Load()
	if (loaded) then return end

	ix.live.overrides = ix.data.Get(KEY, {}, false, true) or {}
	ix.combat.settings = ix.data.Get(COMBAT_KEY, {}, false, true) or {}
	ix.live.tabOrder = ix.data.Get(TABS_KEY, {}, false, true) or {}
	loaded = true

	local applied = ix.live.ApplyAll()

	if (applied > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %d live edit(s) applied\n", applied))
	end
end

--[[
	LOADED LATE ON PURPOSE.

	`LoadData` runs after every item, race and faction is registered, which is
	what these overrides are written on top of - applying them at file scope
	would be writing into tables that do not exist yet. The timer is the same
	belt and braces every other store in this schema uses.
]]
hook.Add("LoadData", "ixLive", ix.live.Load)
hook.Add("PostLoadData", "ixLive", ix.live.Load)
timer.Simple(10, ix.live.Load)

hook.Add("SaveData", "ixLive", function()
	ix.live.Save()
end)

--------------------------------------------------------------------------------
-- Telling the clients
--------------------------------------------------------------------------------

--[[
	The whole store, as one table.

	`net.WriteTable` rather than a field-by-field message: the store is small -
	it holds only what somebody has CHANGED - and its shape is three levels of
	mixed types, which is exactly what that function is for.
]]
function ix.live.Sync(client)
	net.Start("ixLiveSync")
		net.WriteTable(ix.live.overrides)
		net.WriteTable(ix.combat.settings)
		net.WriteTable(ix.live.tabOrder)

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

hook.Add("PlayerLoadedCharacter", "ixLive", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.live.Sync(client) end
	end)
end)

--------------------------------------------------------------------------------
-- Changing one
--------------------------------------------------------------------------------

--[[
	`kind`, `id`, `field`, and the value as its own type.

	`net.WriteType` carries a number, a boolean, a string or a table without
	the message having to know which - and the field's own `Clean` decides
	whether what arrived is usable, on the server, before anything is stored.
]]
net.Receive("ixLiveSet", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	if (not loaded) then
		client:Notify("The live editor is still loading. Try again.")

		return
	end

	local kindID = net.ReadString()
	local id = net.ReadString()
	local key = net.ReadString()
	local reset = net.ReadBool()
	local value = net.ReadType()

	local kind = ix.live.Kind(kindID)

	if (not kind) then return end

	local field = ix.live.Field(kind, id, key)

	if (not field) then return end
	if (not kind.Target or not kind.Target(id)) then return end

	if (reset) then
		ix.live.Reset(kindID, id, key)
		ix.live.Save()
		ix.live.Sync()

		client:Notify(string.format("%s: %s put back.", id, field.name))
		ix.log.Add(client, "liveEdit", kindID, id, field.name, "reset")

		return
	end

	local clean = ix.live.Clean(field, value)

	if (clean == nil) then
		client:Notify("That is not a value that field can take.")

		return
	end

	--[[
		SETTING A FIELD TO WHAT IT ALREADY IS IS A RESET, not an override.

		Clicking the switch that is already on, or the choice that is already
		chosen, would otherwise record an override identical to the file and
		the row would then offer to RESET something nobody had changed. The
		comparison is against what the field reads RIGHT NOW with any existing
		override removed, which `Value` answers once the store entry is gone.
	]]
	local existing = ix.live.overrides[kindID]
		and ix.live.overrides[kindID][id]
		and ix.live.overrides[kindID][id][key]

	if (existing == nil) then
		local current = ix.live.Value(kindID, id, field)
		local same = current == clean

		if (istable(current) and istable(clean) and field.kind == "items") then
			--- Two sets: the same members, no more.
			same = table.Count(current) == table.Count(clean)

			for member in pairs(clean) do
				if (not current[member]) then same = false end
			end
		elseif (istable(current) and istable(clean)) then
			same = true

			for index = 1, 3 do
				if (tonumber(current[index]) ~= tonumber(clean[index])) then
					same = false
				end
			end
		end

		if (same) then return end
	end

	ix.live.overrides[kindID] = ix.live.overrides[kindID] or {}
	ix.live.overrides[kindID][id] = ix.live.overrides[kindID][id] or {}
	ix.live.overrides[kindID][id][key] = clean

	--[[
		THE EDIT IS SAVED EVEN IF APPLYING IT THROWS.

		`OnApply` is where a kind does the work that makes a change live - and
		for armour that now means taking it off somebody and putting it back
		on, which is a lot of other people's code. An error in there used to
		take the rest of this function with it: the override was in the table
		but never saved and never synced, so it survived until the next
		restart and then vanished, and the window showed a number the server
		had forgotten.

		The store is the decision; applying it is a consequence. A consequence
		that fails is worth an error in the console, not a lost decision.
	]]
	local ok, err = pcall(ix.live.Apply, kindID, id, key, clean)

	if (not ok) then
		ErrorNoHalt(string.format("[falloutrp] applying %s/%s/%s threw: %s\n",
			kindID, id, key, tostring(err)))
	end

	ix.live.Save()
	ix.live.Sync()

	local said = tostring(clean)

	if (istable(clean)) then
		said = field.kind == "items" and (table.Count(clean) .. " ticked")
			or table.concat(clean, ", ")
	end

	client:Notify(string.format("%s: %s is now %s.", id, field.name, said))

	ix.log.Add(client, "liveEdit", kindID, id, field.name, tostring(clean))
end)

--[[
	The per-weapon combat settings, which are their own store rather than a
	kind: they are not a field on any table, they are a decision the damage
	hook reads. See `sh_livecombat.lua`.
]]
net.Receive("ixLiveCombat", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	if (not loaded) then return end

	local uniqueID = net.ReadString()
	local settings = net.ReadTable()

	if (not ix.item.list[uniqueID]) then return end

	local function Clean(pair)
		if (not istable(pair)) then return nil end

		local out = {}

		for _, group in ipairs(ix.combat.groups) do
			local value = tonumber(pair[group])

			if (value) then out[group] = math.Clamp(value, 0, 20) end
		end

		return next(out) and out or nil
	end

	--- The per-tier ladder, checked against the tiers that exist.
	local function CleanRarity(pairs_)
		if (not istable(pairs_)) then return nil end

		local out = {}

		for _, entry in ipairs(ix.rarity.tiers) do
			local value = tonumber(pairs_[entry.id])

			if (value) then out[entry.id] = math.Clamp(value, 0, 10) end
		end

		return next(out) and out or nil
	end

	local cleaned = {
		scaled = Clean(settings.scaled),
		static = Clean(settings.static),
		rarity = CleanRarity(settings.rarity),
		cap = math.Clamp(tonumber(settings.cap) or 0, 0, 10)
	}

	--- An entry that says nothing is removed rather than stored as empty.
	if (not cleaned.scaled and not cleaned.static and not cleaned.rarity
	and cleaned.cap <= 0) then
		ix.combat.settings[uniqueID] = nil
	else
		ix.combat.settings[uniqueID] = cleaned
	end

	ix.live.Save()
	ix.live.Sync()

	client:Notify(string.format("%s: hit multipliers saved.",
		ix.item.list[uniqueID].name or uniqueID))

	ix.log.Add(client, "liveCombat", uniqueID)
end)

--[[
	The F1 tab order - a list of names, in the order they should appear.

	Sent whole rather than as a move, because "put the inventory second" is not
	a thing that can be expressed as one number without the rest of the list
	agreeing about what the others are.
]]
net.Receive("ixLiveTabs", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	if (not loaded) then return end

	local count = math.min(net.ReadUInt(8), 32)
	local order = {}

	for index = 1, count do
		local name = net.ReadString()

		--- Positions from 1, so an unknown tab's 100 still sorts after them.
		if (name ~= "") then order[name] = index end
	end

	ix.live.tabOrder = order

	ix.live.Save()
	ix.live.Sync()

	client:Notify("Menu tab order saved. Reopen the menu to see it.")
	ix.log.Add(client, "liveEdit", "menu", "tabs", "order",
		table.concat(table.GetKeys(order), ", "))
end)

--[[
	Opening it. The window is the client's; this is the permission.

	Same shape as every other configurer in this schema - see `/MiningConfig`.
]]
ix.command.Add("LiveEdit", {
	description = "Open the live editor: weapons, armour, chems, races, "
		.. "factions.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "dev.terminal")
	end,

	OnRun = function(self, client)
		ix.live.Sync(client)

		net.Start("ixLiveOpen")
		net.Send(client)
	end
})

ix.log.AddType("liveEdit", function(client, kind, id, field, value)
	return string.format("%s set %s %s - %s to %s.", client:Name(), kind, id,
		field, value)
end, FLAG_DANGER)

ix.log.AddType("liveCombat", function(client, uniqueID)
	return string.format("%s changed the hit multipliers on %s.",
		client:Name(), uniqueID)
end, FLAG_DANGER)
