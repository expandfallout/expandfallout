--[[
	A lootable container.

	Placed by an admin through the loot configurer, persisted per map, and
	filled from a named loot table the first time somebody opens it.

	NOT A HELIX INVENTORY. The contents are a plain list of `{uniqueID, count}`
	held on the entity, and a real item is created only when something is taken
	out. A hundred crates on a map should not mean a hundred inventories of
	database rows nobody has looked at - Phoenix reached the same conclusion
	with their `FakeInventory`.

	The loot table is a networked STRING rather than an id, so the client can
	show which table a container uses without needing the table list.
]]

ENT.Type = "anim"
ENT.PrintName = "Lootable"
ENT.Category = "Fallout RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true

ENT.PopulateEntityInfo = true

--[[
	THE LOCK IS TWO VALUES, not one.

	`LockLevel` is the difficulty it was placed with and does not change;
	`Locked` is whether it is shut right now. Picking a lock clears the second
	and leaves the first, so the container relocks at the difficulty it has
	always had rather than needing an admin to set it again - see
	`sh_lockpick.lua`.

	Both are networked because the tooltip says what you are looking at before
	you press anything.
]]
function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "LootTable")
	self:NetworkVar("Int", 0, "LockLevel")
	self:NetworkVar("Bool", 0, "Locked")
end

if (SERVER) then
	function ENT:Initialize()
		--[[
			The model is set by the placer BEFORE Spawn, so it is only
			defaulted here when something created this entity directly - the Q
			menu, or a map that already had one.
		]]
		if (self:GetModel() == nil or self:GetModel() == "") then
			self:SetModel("models/props_junk/wood_crate001a.mdl")
		end

		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self.ixViewers = {}
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		--[[
			A LOCKED CONTAINER SHOWS THE LOCK, not its contents. `Begin`
			answers false when there is nothing to pick with, and it has
			already told the player why.
		]]
		if (self:GetLocked() and (self:GetLockLevel() or 0) > 0) then
			ix.lockpick.Begin(activator, self)

			return
		end

		if (self:GetLootTable() == "") then
			if (activator:IsAdmin()) then
				activator:Notify("This lootable has no table set. Use the loot configurer.")
			end

			return
		end

		ix.loot.Open(activator, self)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_lootable")

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		--[[
			Recorded so a Q-menu spawn persists like a placed one. Without this
			it would vanish on restart and look like the save was broken.
		]]
		entity.ixLootData = {
			position = entity:GetPos(),
			angles = entity:GetAngles(),
			model = entity:GetModel(),
			lootTable = "",
			respawn = ix.config.Get("lootRespawnTime", 600)
		}

		ix.loot.placed[#ix.loot.placed + 1] = entity.ixLootData
		entity.ixLootData.entity = entity

		ix.loot.SavePlaced()

		return entity
	end

	--[[
		REMOVAL DOES NOT ERASE THE RECORD, deliberately.

		This used to save the list whenever a container was removed, which
		meant a sandbox cleanup - or any mass removal - deleted every container
		permanently. A lootable is world content: it should survive anything
		short of somebody deciding to delete it.

		Deliberate deletion goes through `ix.loot.RemovePlaced`, which is the
		only path that shrinks the list.
	]]
	function ENT:OnRemove()
	end
else
	function ENT:Initialize()
	end

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name")

		title:SetImportant()
		title:SetText(self.PrintName)
		title:SizeToContents()

		local description = tooltip:AddRow("description")

		description:SetText(self:GetLocked() and "Locked. Press E to pick."
			or "Press E to search.")
		description:SizeToContents()

		--[[
			The difficulty is worth knowing BEFORE spending pins on it, which
			is how the game itself does it: a Very Hard lock is a decision
			about whether you have enough bobby pins, not a surprise.
		]]
		if (self:GetLocked() and (self:GetLockLevel() or 0) > 0) then
			local lock = tooltip:AddRow("lock")

			lock:SetText("Lock: " .. ix.lockpick.Name(self:GetLockLevel()))
			lock:SetBackgroundColor(ix.config.Get("color"))
			lock:SizeToContents()
		end

		--[[
			Admins see which table it draws from. Everyone else should not -
			knowing a crate is `Looter_RareCrap` tells a player whether it is
			worth walking to.
		]]
		if (LocalPlayer():IsAdmin()) then
			local name = self:GetLootTable()
			local row = tooltip:AddRow("loottable")

			row:SetText("Table: " .. (name ~= "" and name or "none set"))
			row:SizeToContents()
		end
	end
end
