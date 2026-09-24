--[[
	Developer terminal.

	A Q-menu spawnable entity, like Helix's own vendor, but it is NOT a vendor:
	no prices, no stock, no money, no buy/sell modes. Those exist to make trade
	a game mechanic, and none of that helps when the thing you actually want is
	"put one of every gun in my inventory and let me test them".

	So it is a separate entity rather than a configured `ix_vendor`. Bolting a
	dev mode onto the vendor would mean threading "this one is free and infinite
	and admin-only" through its trading, stock and networking - and every one of
	those paths is a place to accidentally hand players free items.

	ADMIN ONLY, ENFORCED SERVER-SIDE. The `AdminOnly` flag below only hides it
	from the spawn menu; the give handler in `sv_devmenu.lua` is what actually
	stops a non-admin sending the net message by hand.
]]

ENT.Type = "anim"
ENT.PrintName = "Developer Terminal"
ENT.Category = "Fallout RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true

-- Helix shows this when you look at the entity.
ENT.PopulateEntityInfo = true

function ENT:SetupDataTables()
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/catmop/fallout/furniture/institute/insterminal.mdl")
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
		Opening is gated here as well as in the give handler.

		Two checks rather than one because they answer different questions: this
		is "should you see the menu", the other is "may you actually take that
		item". A client can skip this one entirely by sending the net message
		itself, which is exactly why the second exists.
	]]
	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		if (not activator:IsAdmin()) then
			activator:NotifyLocalized("devTerminalDenied")
			return
		end

		net.Start("ixFODevOpen")
		net.Send(activator)
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_devvendor")

		entity:SetPos(trace.HitPos + trace.HitNormal * 16)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end
else
	function ENT:Initialize()
	end

	function ENT:Draw()
		self:DrawModel()
	end

	--[[
		The label Helix draws when you look at it. Says plainly that it is a
		developer tool, so nobody mistakes one left on a live map for a shop.
	]]
	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name")

		title:SetImportant()
		title:SetText(self.PrintName)
		title:SizeToContents()

		local description = tooltip:AddRow("description")

		description:SetText("Admin only. Gives items straight to your inventory.")
		description:SizeToContents()
	end
end
