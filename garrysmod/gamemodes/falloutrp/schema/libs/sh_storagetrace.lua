--[[
	Tracing a storage that will not open.

	`ix_container:Use` and the client's `ixStorageOpen` receiver both refuse
	SILENTLY - `if (inventory and ...)` on one side, `if (IsValid(entity) and
	inventory and inventory.slots)` on the other, neither with an else. So a
	container that does not open produces no message anywhere, and the two
	realms cannot be told apart by looking at either one.

	`fo_container_report` covers the server's half and reports it healthy. This
	covers the two things it cannot see:

	    did the server actually SEND the open
	    did the client REFUSE it, and on which of the three conditions

	A CONCOMMAND, NOT A REPLICATED CONVAR. The first version was
	`CreateConVar(..., FCVAR_REPLICATED)` created on the server, which a player
	cannot set from their own console - it answers "Unknown command", because a
	replicated convar is the server's to change and the client only reads it.
	A command runs where it is typed and can turn the flag on in both realms,
	which is the whole point of a trace that spans them.
]]

ix.storageTrace = ix.storageTrace or false

if (SERVER) then
	util.AddNetworkString("ixStorageTrace")

	--[[
		Wrapped, not replaced. `ix.storage.Sync` is the last thing the server
		does before the client is expected to draw a window, so a line here and
		silence on the client narrows it to the message or to the receiver.
	]]
	--[[
		`Open` as well as `Sync`, because everything between them is where this
		can go quiet: `Open` refuses outright when somebody is already in a
		single-user storage, and otherwise hands off to a STARED ACTION that
		only calls `Sync` if the player keeps looking at the entity for
		`searchTime`. A trace with only `Sync` in it cannot tell "never opened"
		from "opened and the stare never finished".
	]]
	local Open = ix.storage.Open

	function ix.storage.Open(client, inventory, info)
		if (ix.storageTrace and IsValid(client)) then
			local existing = inventory and inventory.storageInfo

			client:ChatPrint(string.format(
				"[storage] OPEN inv=%s  searchTime=%s  inUse=%s  multi=%s",
				inventory and tostring(inventory:GetID()) or "nil",
				tostring((info and info.searchTime)
					or (existing and existing.searchTime) or 0),
				tostring(inventory and ix.storage.InUse(inventory)),
				tostring((info and info.bMultipleUsers)
					or (existing and existing.bMultipleUsers) or false)))

			--[[
				A context that already exists is NOT replaced by `Open`, so a
				stale one - left by a receiver that never sent its close -
				keeps the entity it was made with. That entity is what the
				stared action watches, and an invalid one can never complete.
			]]
			if (existing) then
				client:ChatPrint(string.format(
					"[storage] OPEN reusing context, entity=%s",
					IsValid(existing.entity)
						and existing.entity:GetClass() or "INVALID"))
			end
		end

		return Open(client, inventory, info)
	end

	local Sync = ix.storage.Sync

	function ix.storage.Sync(client, inventory)
		if (ix.storageTrace) then
			local info = inventory and inventory.storageInfo

			MsgC(Color(255, 200, 100), string.format(
				"[storage] sync -> %s  inv=%s  entity=%s  slots=%s\n",
				IsValid(client) and client:Name() or "?",
				inventory and tostring(inventory:GetID()) or "nil",
				info and IsValid(info.entity)
					and info.entity:GetClass() or "INVALID",
				inventory and inventory.slots and "yes" or "NO"))

			if (IsValid(client)) then
				client:ChatPrint(string.format(
					"[storage] SERVER sent the open. inv=%s entity=%s slots=%s",
					inventory and tostring(inventory:GetID()) or "nil",
					info and IsValid(info.entity)
						and info.entity:GetClass() or "INVALID",
					inventory and inventory.slots and "yes" or "NO"))
			end
		end

		return Sync(client, inventory)
	end

	--[[
		`ix_container:Use` itself, condition by condition.

		This is the last dark stretch: `USE` fires and `OPEN` never does, so
		the entity's own `Use` is bailing - and it bails on four separate
		things with no else on any of them. Wrapping the SENT's stored table is
		how to see inside a method that belongs to somebody else's plugin
		without replacing it.

		`scripted_ents.GetStored` hands back the registered table; `t` is the
		ENT the class was built from, and every spawned container looks its
		methods up through it, so wrapping here covers the ones already in the
		world as well as the ones spawned later.
	]]
	timer.Simple(0, function()
		local stored = scripted_ents.GetStored("ix_container")

		if (not stored or not stored.t or not stored.t.Use) then
			MsgC(Color(255, 160, 160),
				"[storage] could not wrap ix_container:Use - not registered\n")

			return
		end

		local original = stored.t.Use

		stored.t.Use = function(self, activator, ...)
			if (ix.storageTrace and IsValid(activator)) then
				--[[
					BOTH SIDES OF THE ONE EXPRESSION THAT DISAGREES.

					`PlayerUse` sees `ix.inventory.Get(entity:GetID())` resolve
					and `ENT:GetInventory()` - which is
					`ix.item.inventories[self:GetID()]` - return nil, on the
					same entity in the same tick. Only two things can differ:
					the ID each call reads, or the TABLE each call reads it
					from. So both are printed, with their types.
				]]
				local id = self:GetID()
				local direct = ix.item.inventories[id]
				local viaGet = ix.inventory.Get(id)
				local viaMethod = self:GetInventory()

				activator:ChatPrint(string.format(
					"[storage] ENT:Use ent=%d  id=%s(%s)  direct=%s  get=%s  "
					.. "method=%s  table=%d",
					self:EntIndex(), tostring(id), type(id),
					direct and "yes" or "NO",
					viaGet and "yes" or "NO",
					viaMethod and "yes" or "NO",
					table.Count(ix.item.inventories or {})))

				--[[
					WHICH FILE DEFINES THE METHOD, ASKED OF LUA ITSELF.

					`direct` and `get` both resolve and `method` does not, so
					`ENT:GetInventory` is not the function it is meant to be -
					it is not `ix.item.inventories[self:GetID()]`, because that
					expression is right there returning a value.

					Guessing which file replaced it is what the last four
					rounds were. `debug.getinfo` answers it: `short_src` names
					the file and `linedefined` the line, so whatever is
					overriding it identifies itself.
				]]
				local where = debug.getinfo(self.GetInventory, "S")
				local whereID = debug.getinfo(self.GetID, "S")

				activator:ChatPrint(string.format(
					"[storage] GetInventory defined at %s:%d",
					where and where.short_src or "?",
					where and where.linedefined or -1))

				--[[
					`GetStorageID` belongs to `ix_factionstorage` and to
					nothing else. If a CONTAINER has it, the two entity classes
					are sharing one table - which would also explain the
					`GetInventory` above, because mine reads a storage record
					by that id and a container's would be 0, giving no record
					and a clean nil.

					One boolean either confirms that or kills it.
				]]
				activator:ChatPrint(string.format(
					"[storage] container has GetStorageID=%s  storageID=%s  "
					.. "class=%s",
					tostring(isfunction(self.GetStorageID)),
					isfunction(self.GetStorageID)
						and tostring(self:GetStorageID()) or "-",
					self:GetClass()))

				activator:ChatPrint(string.format(
					"[storage] GetID defined at %s:%d",
					whereID and whereID.short_src or "?",
					whereID and whereID.linedefined or -1))

				local nextOpen = activator.ixNextOpen or 0

				activator:ChatPrint(string.format(
					"[storage] ENT:Use  nextOpen=%.1f (now %.1f, ok=%s)  "
					.. "character=%s  locked=%s",
					nextOpen, CurTime(), tostring(nextOpen < CurTime()),
					activator:GetCharacter() and "yes" or "NO",
					tostring(self:GetLocked())))
			end

			return original(self, activator, ...)
		end

		MsgC(Color(255, 200, 100), "[storage] wrapped ix_container:Use\n")
	end)

	concommand.Add("fo_storage_trace", function(client, _, arguments)
		if (IsValid(client) and not client:IsSuperAdmin()) then return end

		local on = arguments[1] ~= "0"

		ix.storageTrace = on

		--[[
			Turned on in BOTH realms from one command. The client half is what
			says whether the message arrived, and asking somebody to enable it
			twice is asking for a trace with one half missing.
		]]
		net.Start("ixStorageTrace")
			net.WriteBool(on)

		if (IsValid(client)) then
			net.Send(client)

			client:ChatPrint("[storage] trace " .. (on and "on" or "off"))
		else
			net.Broadcast()
		end

		MsgC(Color(255, 200, 100),
			"[storage] trace " .. (on and "on" or "off") .. "\n")
	end)

	return
end

net.Receive("ixStorageTrace", function()
	ix.storageTrace = net.ReadBool()
end)

--[[
	The panel Helix creates when the message passes its three conditions.

	A net message has one receiver and Helix owns it, so this cannot hook
	`ixStorageOpen` itself. It hooks the consequence instead: a SERVER line with
	no CLIENT line means the receiver refused, and `fo_storage_client` says
	which of the three conditions it refused on.

	Deferred, because `ix.fallout.WrapPanel` lives in `fallout_ui/`, which is
	included after `libs/` - the same load-order trap `cl_buff.lua` sits in.
]]
timer.Simple(0, function()
	if (not ix.fallout or not ix.fallout.WrapPanel) then return end

	ix.fallout.WrapPanel("ixStorageView", "Init", function()
		if (not ix.storageTrace) then return end

		chat.AddText(Color(255, 200, 100),
			"[storage] CLIENT opened the view - it arrived and passed")
	end)
end)

concommand.Add("fo_storage_client", function()
	local keys = {}

	for id, inventory in pairs(ix.item.inventories or {}) do
		keys[#keys + 1] = string.format("%s%s", tostring(id),
			inventory.slots and "" or "(NO SLOTS)")
	end

	table.sort(keys)

	--[[
		`ix.gui.menu` is the FIRST thing the receiver checks, and it closes the
		storage outright when the F1 menu is open - so a menu panel left valid
		because it was hidden rather than removed would refuse every container
		on the server, silently, for ever.
	]]
	chat.AddText(Color(255, 200, 100), string.format(
		"[storage] menu open=%s  storage open=%s  %d inventor(y/ies) known",
		tostring(IsValid(ix.gui.menu)),
		tostring(IsValid(ix.gui.openedStorage)),
		table.Count(ix.item.inventories or {})))

	chat.AddText(Color(200, 200, 200),
		"[storage] client inventories: "
		.. (#keys > 0 and table.concat(keys, " ") or "none"))
end)
