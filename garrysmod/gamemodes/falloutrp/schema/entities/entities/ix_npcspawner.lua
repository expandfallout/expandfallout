--[[
	An NPC spawner pod: the entity that stands for a spawner record.

	Invisible and not solid; the record in `ix.npc.spawners` is the truth
	and this is what thinks for it, once a second, in `ix.npc.Tick`. Staff
	with the NPC Spawner tool out see it drawn by `cl_npc.lua`. See
	`libs/sh_npc.lua`.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "NPC Spawner"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:Initialize()
	if (SERVER) then
		self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetNoDraw(true)
		self:DrawShadow(false)

		self.ixNPCs = {}
		self.ixQueue = {}
		self.ixAwake = false

		self:NextThink(CurTime() + 1)
	end
end

if (SERVER) then
	function ENT:Think()
		if (self.ixRecord and ix.npc and ix.npc.Tick) then
			ix.npc.Tick(self)
		end

		self:NextThink(CurTime() + 1)

		return true
	end

	function ENT:OnRemove()
		for _, npc in ipairs(self.ixNPCs or {}) do
			if (IsValid(npc)) then npc:Remove() end
		end

		if (ix.npc and ix.npc.pods and self.ixRecord
		and ix.npc.pods[self.ixRecord] == self) then
			ix.npc.pods[self.ixRecord] = nil
		end
	end

	--- Never by hand: the tool makes them from records.
	function ENT:SpawnFunction() end
else
	function ENT:Draw() end
end
