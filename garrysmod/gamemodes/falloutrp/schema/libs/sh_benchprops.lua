--[[
	Right-clicking a workbench with the C menu open.

	    Configure   opens `/benchconfig` on that bench's type
	    Open        opens it without the faction, rank or level check
	    Remove      takes it and everything in it away

	SHARED, like `sh_factionmgmt.lua`: `properties.Add` needs `Filter` on the
	client to decide whether the option is drawn and `Receive` on the server to
	act, and they are one registration.

	EVERY ONE OF THESE CHECKS ADMIN TWICE, and the second check is the real
	one. Sandbox's `OpenEntityMenu` only ever calls `Filter` - Helix's
	admin-only `GM:CanProperty` is for a property to call on ITSELF and does
	not gate custom properties at all - so a `Filter` that returns false hides
	the menu entry and stops nothing. The `Receive` is reachable by anybody who
	can send a netstring.
]]

local function IsBench(entity)
	return IsValid(entity) and entity:GetClass() == "ix_workbench"
end

--- The entity a `Receive` was sent about, or nil if it was not a real one.
local function ReadBench(client, bAdmin)
	local entity = net.ReadEntity()

	if (not IsBench(entity)) then return nil end
	if (bAdmin and not client:IsAdmin()) then return nil end

	--[[
		Range checked on the server too. The C menu will not draw an option for
		something out of sight, but the message does not carry where the player
		was standing when they clicked it.
	]]
	if (client:GetPos():Distance(entity:GetPos()) > 400) then return nil end

	return entity
end

properties.Add("ixBenchConfigure", {
	MenuLabel = "[ADMIN] Configure this bench",
	MenuIcon = "icon16/wrench.png",
	Order = 8100,
	PrependSpacer = true,

	Filter = function(self, entity)
		return IsBench(entity) and LocalPlayer():IsAdmin()
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = ReadBench(client, true)

		if (not entity) then return end

		--[[
			The whole list is sent, not just this bench's type, because the
			configurer is the same window either way and it needs the rest to
			draw its left column. Which one to open is the client's business
			once it has them.
		]]
		ix.bench.SendAll(client, true)
	end
})

properties.Add("ixBenchOpen", {
	MenuLabel = "[ADMIN] Open this bench",
	MenuIcon = "icon16/box.png",
	Order = 8101,

	Filter = function(self, entity)
		return IsBench(entity) and LocalPlayer():IsAdmin()
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = ReadBench(client, true)

		if (not entity) then return end

		local record = ix.bench.Get(entity:GetBenchID())

		if (not record) then
			client:Notify("That bench has no record.")

			return
		end

		--[[
			Straight to `Open` rather than to `Use`. They do the same thing
			today, and this is the one that will not start doing something else
			if benches ever grow a lock or an animation on being opened by
			hand - the same reason the faction storages have an admin route
			that does not go through the entity.
		]]
		ix.bench.Open(client, record)
	end
})

properties.Add("ixBenchRemove", {
	MenuLabel = "[ADMIN] Remove this bench",
	MenuIcon = "icon16/cancel.png",
	Order = 8102,

	Filter = function(self, entity)
		return IsBench(entity) and LocalPlayer():IsAdmin()
	end,

	Action = function(self, entity)
		--[[
			Asked on the CLIENT, before the message is sent.

			Phoenix ask on the server through a request/response pair of their
			own, which means the server holds a callback waiting on somebody
			who can disconnect while the box is up. Nothing needs to be held
			here: if they say no, no message is sent.
		]]
		Derma_Query("Remove this bench and everything in it? This cannot be "
			.. "undone.", "Workbenches", "Remove", function()
				self:MsgStart()
					net.WriteEntity(entity)
				self:MsgEnd()
			end, "Cancel", function() end)
	end,

	Receive = function(self, length, client)
		local entity = ReadBench(client, true)

		if (not entity) then return end

		local record = ix.bench.Get(entity:GetBenchID())

		if (not record) then
			entity:Remove()
			client:Notify("That bench had no record. Removed the prop.")

			return
		end

		local definition = ix.bench.TypeOf(record)

		ix.bench.Destroy(record)

		client:Notify(string.format("Removed bench %d (%s).", record.id,
			definition and definition.name or record.bench))

		ix.log.Add(client, "benchRemove", record.bench)
	end
})

if (SERVER) then
	ix.log.AddType("benchRemove", function(client, uniqueID)
		return string.format("%s removed a '%s' bench.", client:Name(),
			uniqueID)
	end)
end
