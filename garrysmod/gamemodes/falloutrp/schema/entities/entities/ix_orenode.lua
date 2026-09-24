--[[
	An ore node.

	Hit it with a pickaxe and kilogrammes come off; every `miningKgPerOre` that
	comes off is one ore in your bag. Empty it and it is gone until its timer
	brings it back. Phoenix's `nut_mining_rock`, with the soft spot made real -
	theirs sends one to the client to draw and the server half that used it is
	not in the scrape, so what a hit on it is WORTH is ours.

	THE SOFT SPOT IS A POSITION ON THE MODEL, networked, redrawn as a glow by
	`cl_mining.lua`. Hitting within `miningSoftRadius` of it is worth
	`miningSoftMultiplier` ordinary hits and moves it somewhere else. Mining
	without looking still works; mining well is three times faster.

	THE METHOD NAMES ARE DELIBERATELY ODD - `ApplyRecord`, `ApplyShape`,
	`MineFor`, `OreData` rather than `Configure`, `Reshape`, `Mine`, `Ore`.
	Gotcha 17: a method called `Respawn` on a scripted entity in this build
	answers nil however it is written, nobody found out why, and it cost three
	rounds of debugging on the plants. The farming entities are named the same
	careful way.

	IT IS NOT A POINT, though it looks like one. `sh_points.lua` calls a point
	"a thing a map-maker places one of at a time", which fits - but a point is
	placed by `fo_point` and carries a handful of fixed properties, and a node
	needs its own tool, its own list, its own respawn and an ore registry that
	is edited in game. Sharing the table would have meant teaching the point
	system about all of it.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Ore Node"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true
--[[
	RENDERGROUP_BOTH, AND WITHOUT IT NOTHING BELOW IS EVER DRAWN.

	`ENT:DrawTranslucent` is only called for entities in a translucent render
	group, and an anim entity with an opaque model is not in one - so the bars
	were written, were correct, and never ran. The two entities in this schema
	whose translucent drawing does work (`ix_breachcharge`'s glow and the
	orbital beacon's dome) both set this and that is the whole difference.
]]
ENT.RenderGroup = RENDERGROUP_BOTH


function ENT:SetupDataTables()
	--- Which ore, so the client can name and colour it.
	self:NetworkVar("String", 0, "OreType")

	--- Kilogrammes left, and what a full one holds.
	self:NetworkVar("Float", 0, "Amount")
	self:NetworkVar("Float", 1, "MaxAmount")

	--[[
		WHERE THE SOFT SPOT IS, in world space.

		A netvar rather than Phoenix's net message: it is state rather than an
		event, so somebody who walks up after it moved should see where it is
		now rather than nothing at all.
	]]
	self:NetworkVar("Vector", 0, "SoftSpot")
end

--- How full it is, 0 to 1.
function ENT:FillFraction()
	local max = self:GetMaxAmount()

	if (max <= 0) then return 0 end

	return math.Clamp(self:GetAmount() / max, 0, 1)
end

function ENT:OreData()
	return ix.mining.Get(self:GetOreType()) or ix.mining.Fallback()
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(ix.mining.model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--- Frozen again after every wake; see `ix_factionstorage.lua`.
	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		Set it up from its record. Called when one is placed, when the map
		loads, and when the tool is used on an existing node.
	]]
	function ENT:ApplyRecord(record)
		local ore = ix.mining.Get(record.ore) or ix.mining.Fallback()

		self:SetOreType(ore and ore.id or "iron")
		self:SetSkin(ore and tonumber(ore.skin) or 0)

		self:SetMaxAmount(math.max(tonumber(record.amount) or 25, 1))
		self:SetAmount(math.max(tonumber(record.remaining)
			or self:GetMaxAmount(), 0))

		self:ApplyShape()
		self:MoveSoftSpot()
	end

	--[[
		The model shrinks as it empties. Phoenix's five stages.

		AND THE SOFT SPOT MOVES WITH IT. The spot sits on the surface of the
		shape the node is CURRENTLY showing, so a rock that has just shrunk
		leaves its spot hanging in the air where the rock used to be. Only when
		the bodygroup actually changes - four times in the life of a node, not
		once per swing.
	]]
	function ENT:ApplyShape()
		local wanted = ix.mining.Bodygroup(self:FillFraction())

		if (self:GetBodygroup(0) == wanted) then return end

		self:SetBodygroup(0, wanted)
		self:MoveSoftSpot()
	end

	--[[
		Somewhere new on the rock to aim at - ON THE SURFACE OF IT.

		The first version picked a point inside the bounding box, and a
		bounding box is not a rock: the spot floated out in the air beside the
		node as often as not, and when it did land on the model it could land
		INSIDE it, where nothing can hit it. Both were reported, and both are
		the same mistake - guessing at a shape instead of asking for it.

		So it traces. A random direction, from outside the box, back towards the
		middle, with a filter that ignores everything except this node - the
		first thing it can possibly hit is this rock's own surface. The spot
		sits two units off that, which is far enough to see and near enough that
		a swing landing on the spot also lands on the rock.

		Ten tries, because a trace that starts inside a concave part of the
		model can miss; after that the middle of the node will do, which is
		always hittable even if it is not interesting.
	]]
	function ENT:MoveSoftSpot()
		local centre = self:LocalToWorld(self:OBBCenter())
		local radius = self:BoundingRadius() + 8

		local function only(entity) return entity == self end

		for _ = 1, 10 do
			local direction = VectorRand()

			direction:Normalize()

			--- Biased upwards: the bottom of one of these is in the floor.
			direction.z = math.abs(direction.z) * 0.8 + 0.2

			direction:Normalize()

			local trace = util.TraceLine({
				start = centre + direction * radius,
				endpos = centre,
				filter = only,
				mask = MASK_SOLID
			})

			if (trace.Hit and trace.Entity == self) then
				self:SetSoftSpot(trace.HitPos + trace.HitNormal * 2)

				return
			end
		end

		self:SetSoftSpot(centre)
	end

	--[[
		A swing landed.

		`position` is where the damage hit, which is what decides whether this
		was the soft spot - so a wild swing that happens to clip the rock is
		worth an ordinary hit and a deliberate one is worth several.
	]]
	function ENT:MineFor(client, position)
		if (self:GetAmount() <= 0) then return end

		local character = client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (not inventory) then return end

		local ore = self:OreData()

		if (not ore) then return end

		--- Ordinary hit, the ore's own hardness, then the server-wide dial.
		local kg = ix.config.Get("miningKgPerHit", 1.5)
			* (tonumber(ore.strength) or 1)
			* ix.config.Get("miningStrength", 1)

		local soft = false

		if (position and position:Distance(self:GetSoftSpot())
		<= ix.config.Get("miningSoftRadius", 12)) then
			soft = true
			kg = kg * ix.mining.SoftMultiplier(ore)

			self:MoveSoftSpot()
		end

		kg = math.min(kg, self:GetAmount())

		self:SetAmount(self:GetAmount() - kg)
		self:ApplyShape()

		--[[
			THE PROGRESS IS ON THE NODE, not on the person.

			Two people working the same rock are digging the same hole - their
			swings add up, and whoever lands the hit that crosses the threshold
			gets the ore. That is how Phoenix's reads and it is the only version
			that does not reward standing back and letting somebody else soften
			it up.
		]]
		local perOre = math.max(ix.config.Get("miningKgPerOre", 5), 0.1)

		self.ixProgress = (self.ixProgress or 0) + kg

		local given = 0
		local each = ix.mining.Yield(ore)

		while (self.ixProgress >= perOre) do
			self.ixProgress = self.ixProgress - perOre

			--[[
				ONE MILESTONE, `each` ORE. A milestone that cannot be paid in
				full puts itself back rather than paying half - see below.
			]]
			local room = true

			for _ = 1, each do
				local one = inventory:Add(ore.item)

				if (one == false or one == nil) then
					room = false

					break
				end

				given = given + 1
			end

			if (not room) then
				--[[
					No room. The kilogrammes are already off the rock, so the
					progress is put back rather than lost - come back with an
					empty bag and the next hit finishes it.
				]]
				self.ixProgress = self.ixProgress + perOre

				client:Notify("You have no room for the ore.")

				break
			end
		end

		if (given > 0) then
			local experience = ix.config.Get("miningXP", 2) * given

			if (experience > 0) then character:AddXP(experience) end

			client:EmitSound("phoenix/ui/nv/ui_items_generic_up_0"
				.. math.random(4) .. ".mp3", 65)

			ix.log.Add(client, "mine", ore.name, given)
		end

		ix.mining.EffectAt(self, position or self:GetPos(), soft)

		--- Emptied. The record keeps the clock; see `ix.mining.Tick`.
		if (self:GetAmount() <= 0) then ix.mining.Deplete(self) end
	end

	--[[
		Damage is the only way in.

		Phoenix check the inflictor is their pickaxe; this checks the config,
		which defaults to the same pickaxe and can be blanked to allow anything.
	]]
	function ENT:OnTakeDamage(damage)
		local client = damage:GetAttacker()

		if (not IsValid(client) or not client:IsPlayer()) then return end
		if (not client:Alive() or client:IsRestricted()) then return end

		local wanted = ix.config.Get("miningTool", "meleearts_blade_pickaxe")

		if (wanted and wanted ~= "") then
			local weapon = client:GetActiveWeapon()

			if (not IsValid(weapon) or weapon:GetClass() ~= wanted) then
				return
			end
		end

		--- Holding the swing button on a fast weapon is still one hit a swing.
		if ((client.ixNextMine or 0) > CurTime()) then return end

		client.ixNextMine = CurTime() + 0.2

		self:MineFor(client, damage:GetDamagePosition())
	end

	--- Nothing. A node is hit, not used.
	function ENT:Use()
	end

	return
end

--------------------------------------------------------------------------------
-- What it looks like
--------------------------------------------------------------------------------

function ENT:Draw()
	self:DrawModel()
end

--[[
	The name and what is left in it, over the node.

	Only close up, and only when you are looking at it - a number over every
	rock on the map at all times is a minimap nobody asked for.
]]
function ENT:DrawTranslucent()
	local client = LocalPlayer()

	if (not IsValid(client)) then return end
	if (client:GetEyeTrace().Entity ~= self) then return end
	if (client:GetPos():DistToSqr(self:GetPos()) > 250000) then return end

	if (not ix.fallout.LoadMenuFonts or not ix.fallout.LoadMenuFonts()) then
		return
	end

	local ore = self:OreData()

	if (not ore) then return end

	local angles = EyeAngles()

	angles.p = 0
	angles.y = angles.y - 90
	angles.r = 90

	local colour = ix.mining.Colour(ore)

	cam.Start3D2D(self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z))
		+ Vector(0, 0, 20), angles, 0.05)
		draw.SimpleText(ore.name, "ixZoneName", 2, 2, color_black,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(ore.name, "ixZoneName", 0, 0, colour,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(ix.mining.FormatAmount(self:GetAmount()),
			"ixLootHeader", 2, 42, color_black, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(ix.mining.FormatAmount(self:GetAmount()),
			"ixLootHeader", 0, 40, color_white, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
