--[[
	The breaching charge.

	Phoenix's `nut_dbuster`, rebuilt: a box stuck to a door that beeps faster
	and faster for five seconds and then blows every door within reach open.

	WHAT IS THE SAME: the model, the beep that accelerates, the red glow sprite
	that shrinks with it, the dynamic light, the screen flash for everybody
	within 900 units, and the explosion sound.

	WHAT IS NOT: the countdown is a networked float rather than a client-side
	guess. Theirs sets `lifetime = CurTime() + burstTime` separately on each
	end and hopes they agree; a client that joined mid-beep, or whose clock had
	drifted, saw a charge beeping at a completely different rate from the one
	that was about to go off. One number, sent once, is the same number
	everywhere.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Breaching Charge"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model = "models/props_c17/consolebox05a.mdl"

function ENT:SetupDataTables()
	--[[
		WHEN, not how long left. A duration would have to be re-sent to stay
		true; a moment on the clock is true for as long as the clock runs, and
		both ends share `CurTime`.
	]]
	self:NetworkVar("Float", 0, "ExplodeAt")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)

		self:SetExplodeAt(CurTime() + ix.config.Get("breachTime", 5))
		self:EmitSound("weapons/mine/wpn_mine_arm.wav", 65)

		--[[
			Half size, as Phoenix's is. A full-size console box on a door looks
			like a crate somebody left on a shelf.
		]]
		self:ManipulateBoneScale(0, Vector(1, 1, 1) * 0.5)
	end

	--- Who planted it and what it is stuck to, both remembered for the log.
	function ENT:SetBreachTarget(entity, client)
		self.door = entity
		self.planter = client
	end

	--[[
		Blowing the door.

		The charge is parented to what it was stuck to, so that door is always
		a candidate - `FindInSphere` alone would miss a wide door whose ORIGIN
		is metres away from the charge, which is most double doors.
	]]
	function ENT:Explode()
		local position = self:GetPos()
		local client = IsValid(self.planter) and self.planter or nil
		local radius = ix.config.Get("breachRadius", 48)
		local restore = ix.config.Get("breachDoorRestore", 30)

		local targets = ents.FindInSphere(position, radius)

		if (IsValid(self.door)) then targets[#targets + 1] = self.door end

		local done = {}

		for _, entity in ipairs(targets) do
			if (not IsValid(entity) or done[entity]) then continue end
			if (not ix.breach.CanBreach(client, entity)) then continue end

			done[entity] = true

			--[[
				A TELEPORT LOSES ITS LOCK AND ITS OWNER. That is what a breach
				means in this schema - see `ix.doors.Breach`, which was written
				for this and until now had nothing calling it.
			]]
			if (ix.doors.Link(entity)) then
				if (client) then
					ix.doors.Breach(client, entity)
				else
					ix.doors.Release(nil, entity)
				end
			end

			if (entity:IsDoor()) then
				entity:Fire("unlock")
				entity:Fire("open")

				--[[
					Away from the charge, not `VectorRand`. A door that flies
					towards the person who blew it is funny once.
				]]
				local direction = (entity:GetPos() - position)

				if (direction:IsZero()) then direction = self:GetForward() end

				entity:BlastDoor(direction:GetNormalized() * 400, restore)
			end

			if (client) then
				ix.log.Add(client, "breachDoor", entity:GetClass())
			end
		end

		local effect = EffectData()
		effect:SetOrigin(position)
		util.Effect("Explosion", effect)

		--[[
			AND IT HURTS. The first version blew the door off its hinges and
			left everybody stood next to it untouched, which reads as a bug the
			moment anybody watches it happen - a breaching charge that is safe
			to stand in front of is a door key with a countdown, and standing
			clear of one should be worth doing.

			`util.BlastDamage` falls off with distance and respects walls, so
			being on the far side of the door you are blowing is the protection
			it ought to be. The planter is the attacker when they are still
			about, so it lands in the logs and the kill feed as theirs.
		]]
		local damage = ix.config.Get("breachDamage", 80)
		local blastRadius = ix.config.Get("breachDamageRadius", 220)

		if (damage > 0 and blastRadius > 0) then
			util.BlastDamage(self, client or self, position, blastRadius,
				damage)
		end

		self:EmitSound("weapons/explosion/fx_explosion_grenade_frag_high_0"
			.. math.random(3) .. ".mp3", 120, 200)

		--[[
			The flash reaches much further than the blast does, deliberately -
			it is the thing that tells a room full of people that a door has
			just gone, and none of them are meant to be looking at it.
		]]
		for _, other in ipairs(ents.FindInSphere(position, 900)) do
			if (other:IsPlayer() and other:Alive()) then
				other:ScreenFade(SCREENFADE.IN, Color(255, 225, 225, 75),
					0.5, 0)
			end
		end
	end

	function ENT:Think()
		if (self:GetExplodeAt() > CurTime()) then
			self:NextThink(CurTime() + 0.1)

			return true
		end

		self:Explode()
		self:Remove()

		return false
	end

	--- Nothing. A planted charge is not a thing you can pick up again.
	function ENT:Use()
	end

	return
end

local GLOW = Material("sprites/glow04_noz.vmt")

function ENT:Initialize()
	self.beep = 255
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:BeepLight()
	local light = DynamicLight(self:EntIndex())

	if (not light) then return end

	light.Pos = self:GetPos() + self:GetUp() * 5
	light.r = 255
	light.g = 0
	light.b = 0
	light.Brightness = 2
	light.Size = 64
	light.Decay = 512
	light.DieTime = CurTime() + 0.5
end

--[[
	The beep, and why it accelerates.

	`beep` falls from 255 towards zero and restarts; how fast it falls is
	scaled by how much of the countdown has been used, so the last second is a
	continuous tone and the first is a slow tick. That is Phoenix's, and it is
	the entire warning anybody gets.
]]
function ENT:Think()
	local remaining = self:GetExplodeAt() - CurTime()
	local total = math.max(ix.config.Get("breachTime", 5), 1)
	local elapsed = math.Clamp(total - remaining, 0, total)

	if (remaining <= 0) then
		self.beep = 0

		return
	end

	self.beep = self.beep - FrameTime() * 450 * (1 + elapsed)

	if (self.beep <= 0) then
		self.beep = 255

		self:EmitSound("phoenix/ui/nv/menu_beep.mp3", 75, 150)
		self:BeepLight()
	end
end

function ENT:DrawTranslucent()
	if (self:GetExplodeAt() <= CurTime()) then return end

	local size = math.Clamp(self.beep / 10, 0, 40)

	render.SetMaterial(GLOW)
	render.DrawSprite(self:GetPos() - self:GetUp() * 2, size, size,
		Color(255, 0, 0))
end
