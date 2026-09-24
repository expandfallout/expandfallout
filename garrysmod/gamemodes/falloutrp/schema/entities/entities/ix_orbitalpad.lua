--[[
	An orbital drop site.

	A NAMED POSITION AND NOTHING ELSE, ON PURPOSE.

	The drop system does not exist yet. This is here so the map work can happen
	first - somebody can walk the map now, place the sites, name them and have
	them survive a restart, and whatever lands on them later reads a list that
	is already correct.

	It claims nothing it does not do. `E` says its name, it draws its name to
	anybody standing near it, and `/droppoints` lists them. There is no timer,
	no beacon and no reward, because pretending otherwise would mean somebody
	testing the drop system against a marker that had already half-implemented
	it.

	WHAT THE DROP SYSTEM WILL WANT is here already: a stable id
	(`entity.ixPointID`), a position, a name, and a record in `ix.points.stored`
	that survives a map change - so it can pick a site, spawn something on it,
	and put it back where it was on the next restart.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Orbital Drop Site"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "PointName")
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

		self:SetPointName("Drop Site")
	end

	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:OnRestored(record)
		local data = record.data or {}

		self:SetPointName(tostring(data.name or "Drop Site"))
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		activator:Notify(string.format("%s. Nothing is scheduled to land here.",
			self:GetPointName()))
	end
else
	local RANGE = 700

	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (not IsValid(client)) then return end
		if (client:GetPos():DistToSqr(self:GetPos()) > RANGE * RANGE) then
			return
		end

		if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
			return
		end

		local position = self:GetPos() + self:GetUp() * (self:OBBMaxs().z + 10)

		cam.Start3D2D(position, Angle(0, client:EyeAngles().y - 90, 90), 0.18)
			draw.SimpleText(self:GetPointName(), "ixZoneNote", 0, 0,
				Color(200, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText("drop site", "ixZoneNote", 0, 18,
				Color(200, 160, 255, 150), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
