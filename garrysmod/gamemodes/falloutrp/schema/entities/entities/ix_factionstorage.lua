--[[
	A faction's storage container.

	Modelled on Helix's `ix_container`, and deliberately NOT built on it: a
	container belongs to whoever is standing in front of it and can be locked
	with a password, while this belongs to a FACTION and asks a rank. Those are
	different questions and inheriting one to answer the other would mean
	overriding every part of it that matters.

	The record - which faction, what size, where, and which inventory - lives in
	`sh_factionstorage.lua`. This entity is the thing standing in the world and
	holds only the id of that record, so a storage that is stowed and redeployed
	is the same storage with the same items.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Faction Storage"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	--[[
		The record id, networked so the client can look up the name and the
		faction for the tooltip without a message of its own.
	]]
	self:NetworkVar("Int", 0, "StorageID")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		FROZEN, AND FROZEN AGAIN AFTER EVERY WAKE.

		`EnableMotion(false)` at spawn is not enough on its own: a physics
		object woken by an explosion or by another prop landing on it starts
		moving again, and a faction's storage sliding down a hill is a storage
		nobody can find. `PhysicsUpdate` is the hook that catches it.
	]]
	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		THE RECORD OWNS THE INVENTORY, SO THE RECORD IS ASKED.

		This kept a copy of the id on the entity, set by `SetInventory` after
		spawning - and anything that produced an entity without that call, or
		lost it, answered nil and told the player "this storage is still
		loading" for ever. The record already knows; a second copy on the
		entity was only ever a way for the two to disagree.

		The entity's job is to be the thing in the world that says WHICH
		storage this is. That is `GetStorageID`, and it is networked.
	]]
	function ENT:GetInventory()
		local record = ix.factionStorage.Get(self:GetStorageID())

		return record and ix.inventory.Get(record.invID)
	end

	--[[
		Kept only to tag the inventory. It no longer decides anything, so a
		spawn that misses it costs a tag rather than the whole container.
	]]
	function ENT:SetInventory(inventory)
		if (not inventory) then return end

		inventory.vars.isBag = true
		inventory.vars.isContainer = true
		inventory.vars.factionStorage = self:GetStorageID()
	end

	function ENT:Use(client)
		local record = ix.factionStorage.Get(self:GetStorageID())

		if (not record) then
			client:Notify("This storage is not registered. Tell an admin.")

			return
		end

		local ok, reason = ix.factionStorage.CanAccess(client, record)

		if (not ok) then
			client:Notify(reason)

			return
		end

		if (not record.invID or record.invID < 1) then
			client:Notify(string.format(
				"Storage %d has no inventory id. Tell an admin.", record.id))

			return
		end

		--[[
			LOADED ON DEMAND RATHER THAN REFUSED.

			This used to read the inventory straight out of memory and give up
			if it was not there - and it was not there, while
			`fo_storage_report` showed it present a moment later, which is a
			disagreement no amount of reading either side could settle.

			So it is no longer a question. `ResolveInventory` returns the
			inventory if it is in memory and restores it from the record if it
			is not, which makes the failure impossible rather than diagnosed:
			the id and the size are both written down on the record, so there
			is nothing to be missing.
		]]
		ix.factionStorage.ResolveInventory(record, function(inventory)
			if (not IsValid(client) or not IsValid(self)) then return end

			if (not inventory) then
				client:Notify(string.format(
					"Storage %d's inventory (%d) could not be loaded. Tell an "
					.. "admin.", record.id, record.invID))

				return
			end

			--[[
				Re-checked after the restore. It is asynchronous the first time
				through, and in that window the player can walk away, be
				demoted, or leave the faction.
			]]
			if (not ix.factionStorage.CanAccess(client, record)) then return end

			self:SetInventory(inventory)

			ix.storage.Open(client, inventory, {
				name = record.name or "Faction Storage",
				entity = self,
				searchTime = ix.config.Get("containerOpenTime", 0.7),

				--[[
					MORE THAN ONE PERSON AT A TIME.

					`ix.storage` defaults this to false, which is right for a
					corpse and wrong for a faction's armoury - it answered
					"someone else is using this" to the second person to walk
					up, and to the FIRST person again if their client never sent
					`ixStorageClose`, because the receiver list is what the
					check reads and only that message removes them.
				]]
				bMultipleUsers = true,

				OnPlayerClose = function(closer)
					ix.log.Add(closer, "factionStorageClose",
						record.name or "a storage")
				end
			})

			ix.log.Add(client, "factionStorageOpen", record.name or "a storage")
		end)
	end

	--[[
		The inventory is NOT destroyed with the entity.

		Stowing a storage removes the entity and keeps everything in it; that
		is the whole point of being able to pick one up. The record owns the
		inventory's lifetime, not this.

		`ix.storage.Close` is what shuts the window for anybody who had it
		open - without it they would keep a live inventory belonging to an
		entity that no longer exists.
	]]
	function ENT:OnRemove()
		local inventory = self:GetInventory()

		if (inventory and ix.storage.InUse(inventory)) then
			ix.storage.Close(inventory)
		end
	end

else
	function ENT:Draw()
		self:DrawModel()
	end

	--[[
		The tooltip names the faction, so somebody walking past a locker they
		cannot open is told whose it is rather than being refused with no
		explanation.
	]]
	function ENT:OnPopulateEntityInfo(tooltip)
		local record = ix.factionStorage.Get(self:GetStorageID())

		if (not record) then return end

		local title = tooltip:AddRow("name")

		title:SetImportant()
		title:SetText(record.name or "Faction Storage")
		title:SizeToContents()

		local faction = ix.faction.teams[record.faction]

		if (faction) then
			local owner = tooltip:AddRow("faction")

			owner:SetText(faction.name)
			owner:SetBackgroundColor(faction.color)
			owner:SizeToContents()
		end
	end
end
