--[[
	The black market terminal.

	Phoenix's `nut_blackmarket`: a ship's computer console with a wall
	monitor rendered above it, that opens the market when used. The same
	models, the same shape. Spawned by staff from the entities tab, and
	`gmod_tool permaprop` keeps it across restarts like any other prop.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Black Market Terminal"
ENT.Category = "Fallout RP"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Model = "models/galang/fallout/furniture/classicshipcomputerconsole.mdl"
ENT.Monitor = "models/galang/fallout/furniture/classicwallmonitor.mdl"

function ENT:Initialize()
	if (SERVER) then
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:EnableMotion(false)
		end
	end
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		if (not trace.Hit) then return end

		local entity = ents.Create("ix_blackmarket")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end
		if ((self.ixNextUse or 0) > CurTime()) then return end

		self.ixNextUse = CurTime() + 0.5

		ix.blackmarket.Open(activator, self)
	end

	return
end

--[[
	THE SCREENS HAVE NO TEXTURE. The wall monitor's third material,
	`vcontrolpanelsscreen01`, is in neither of the folders its model names
	and in no content pack this server mounts - so the three screens drew as
	pink and black checks. The monitor is a clientside model of ours, with
	that one material replaced by a plain dark green screen.

	`$color2`, NOT `$color`. On a model the engine writes the entity's own
	render colour into `$color` every frame - white - which is why the
	first version of this drew three pitch white screens. `$color2` is the
	tint the model renderer leaves alone. (Gotcha 30.)
]]
local SCREEN = CreateMaterial("ixMarketScreen", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$color2"] = "[0.06 0.30 0.14]",
	["$nocull"] = "1"
})

function ENT:Draw()
	self:DrawModel()

	if (not IsValid(self.monitor)) then
		self.monitor = ClientsideModel(self.Monitor, RENDERGROUP_OPAQUE)

		if (not IsValid(self.monitor)) then return end

		self.monitor:SetNoDraw(true)
		self.monitor:SetSubMaterial(2, "!ixMarketScreen")
	end

	local angles = self:GetAngles()

	angles:RotateAroundAxis(angles:Up(), -90)

	self.monitor:SetPos(self:GetPos() + angles:Up() * 80
		+ angles:Forward() * -10)
	self.monitor:SetAngles(angles)
	self.monitor:DrawModel()
end

function ENT:OnRemove()
	if (IsValid(self.monitor)) then self.monitor:Remove() end
end

--- Keeps the material referenced so it is never collected.
ENT.ScreenMaterial = SCREEN

hook.Add("PopulateEntityInfo", "ixBlackMarket", function(entity, container)
	if (entity:GetClass() ~= "ix_blackmarket") then return end

	local title = container:AddRow("name")

	title:SetImportant()
	title:SetText("Black Market Terminal")
	title:SizeToContents()

	local row = container:AddRow("blackmarket")

	row:SetText("Buy and sell, no questions asked. Press E.")
	row:SizeToContents()
end)
