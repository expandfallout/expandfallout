--[[
	A stash box.

	Press E and your own storage opens - see `sh_stash.lua` for why the box does
	not own what is in it, and `sv_stash.lua` for how the inventory is found.

	Placed with the `fo_point` tool and kept by `sv_points.lua`, like a cap
	stash and a plant. It holds no state of its own at all: there is nothing on
	this entity worth saving, because everything a stash means lives on the
	character who opened it.

	THE MODEL IS PHOENIX'S, and it needed installing.
	`models/galang/fallout/furniture/stashboxcontainer.mdl` lives in
	`phoenix_contributor_content` (workshop 3504308895), which was not mounted
	here - so that pack is now junctioned like every other content pack, and the
	MODEL IS ONLY ON THIS MACHINE UNTIL 3504308895 IS IN THE COLLECTION. See
	`_docs/02-server-setup.md`; a client without it sees an ERROR box that still
	works perfectly, which is the kind of fault nobody notices until a
	screenshot.

	`models/roadkill/fallout/containers/footlocker.mdl` is the fallback if that
	pack is ever dropped - type it into the point tool's model field, which
	overrides the default for that one box.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Stash"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		--[[
			A MODEL WITH NO COLLISION MESH GETS A BOX - the same guard every
			other point entity carries. `PhysicsInit` silently does nothing when
			the model has no hull, and an entity that is not solid is one the
			use trace goes straight through.
		]]
		if (not IsValid(physics)) then
			self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 20))
			self:SetSolid(SOLID_BBOX)
			self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 20))
		else
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		A short cooldown per player rather than per entity.

		E is held rather than tapped by most people, and `SIMPLE_USE` still
		fires more than once. Per player, because two people at one box are two
		separate opens and one should not eat the other's.
	]]
	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		activator.ixNextStash = activator.ixNextStash or 0

		if (activator.ixNextStash > CurTime()) then return end

		activator.ixNextStash = CurTime() + 1

		self:EmitSound("phoenix/ui/nv/itm_bottle_up_01.mp3", 60, 100, 0.5)

		ix.stash.Open(activator, self)
	end
else
	--- Far enough to read the label walking past, not far enough to clutter.
	local RANGE = 400

	ENT.RenderGroup = RENDERGROUP_BOTH

	function ENT:Draw()
		self:DrawModel()
	end

	--[[
		The label, in `DrawTranslucent` rather than `Draw`.

		WITHOUT `RENDERGROUP_BOTH` ABOVE THIS NEVER RUNS AT ALL - an opaque
		entity is only ever asked to draw once, in the opaque pass, and the
		translucent call simply does not happen. It has cost this project the
		farm bars and the ore node label; see gotcha 18.
	]]
	function ENT:DrawTranslucent()
		local client = LocalPlayer()

		if (not IsValid(client)) then return end
		if (client:GetPos():DistToSqr(self:GetPos()) > RANGE * RANGE) then
			return
		end

		if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
			return
		end

		local position = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z))
			+ Vector(0, 0, 12)

		cam.Start3D2D(position, Angle(0, client:EyeAngles().y - 90, 90), 0.15)
			draw.SimpleText("STASH", "ixZoneNote", 0, 0,
				Color(150, 220, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText("your own storage", "ixZoneNote", 0, 18,
				Color(150, 220, 200, 150), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
