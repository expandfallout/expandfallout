--[[
	A head on a pike.

	Phoenix's `nut_playerhead`, which is a head item that has been PLANTED: you
	deploy one in front of you, it names whoever it belonged to, and anybody
	who does not like the message can shoot it down.

	IT IS NOT THE ITEM. The item is `items/sh_playerhead.lua` and it is what a
	head is while somebody is carrying it; this is what one is once it is in
	the ground outside a settlement. Deploying spends the item, and shooting
	the spike destroys it - a warning you can put back in your bag is not a
	warning.

	THE ANGLE IS THE PLANTER'S, flattened. A pike leaning at whatever pitch
	somebody was looking at is a pike that has fallen over, and the yaw is the
	only part of "which way am I facing" that a stake in the ground has.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Head on a Spike"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.PopulateEntityInfo = true

--- Named after nobody until it is told. Networked so the client can draw it.
function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "HeadOwner")
end

if (SERVER) then
	--[[
		Three models, picked at random, so a row of them along a road is not
		obviously three copies of one prop. They are Phoenix's own Fort pikes -
		`_docs/tools/resolve_asset.py` confirms all three ship with the player
		content pack.
	]]
	local MODELS = {
		"models/roadkill_fallout/fallout/architecture/thefort/"
			.. "nv_headpikemale01.mdl",
		"models/roadkill_fallout/fallout/architecture/thefort/"
			.. "nv_headpikemale02.mdl",
		"models/roadkill_fallout/fallout/architecture/thefort/"
			.. "nv_headpikemale03.mdl"
	}

	function ENT:Initialize()
		self:SetModel(table.Random(MODELS))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		--[[
			IT DOES NOT MOVE once it is planted, which is what makes it a
			landmark rather than a prop somebody can push into a doorway. It
			still takes damage; it just does not roll away when it does.
		]]
		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		self.health = 50
	end

	--[[
		Fifty points of anything and it is gone.

		Deliberately not `SetHealth` and the engine's own damage handling: a
		`prop_physics`-style health would let a stray shotgun pellet from
		across the street count the same as a deliberate burst, and this is
		meant to take a moment of somebody's attention to remove.
	]]
	function ENT:OnTakeDamage(damageInfo)
		self.health = self.health - damageInfo:GetDamage()

		if (self.health > 0 or self.removing) then return end

		self.removing = true

		local effect = EffectData()

		effect:SetOrigin(self:LocalToWorld(self:OBBCenter()))
		effect:SetMagnitude(6)
		effect:SetScale(2)

		util.Effect("bloodspray", effect)

		self:Remove()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name")

		title:SetImportant()
		title:SetText(self.PrintName)
		title:SizeToContents()

		local owner = self:GetHeadOwner()

		local description = tooltip:AddRow("description")

		--[[
			WHATEVER THE HEAD SAID IT WAS, verbatim. It is "NCR - Trooper" for
			one cut off a body and "Vault Dweller" for one taken from a permanent
			kill, so the possessive belongs only to the second - "NCR -
			Trooper's head" reads as a person called Trooper.
		]]
		description:SetText(owner ~= "" and ("The head of a " .. owner .. ".")
			or "Somebody's head.")
		description:SizeToContents()
	end
end
