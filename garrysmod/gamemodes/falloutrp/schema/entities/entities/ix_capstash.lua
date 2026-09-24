--[[
	A cap stash.

	Press E and it is gone - the caps go to you and the stash itself is REMOVED
	until its timer brings it back. Placed with the `fo_point` tool; the record
	that keeps it across a restart lives in `sv_points.lua`, and so does the
	timer that puts it back.

	IT IS REMOVED, NOT HIDDEN, and that is the second attempt at this.

	The first hid it: `SetNoDraw`, `SetNotSolid`, and then a networked `Hidden`
	flag that `ENT:Draw` read. None of it worked in game - the model stayed
	exactly where it was - and rather than find out which of the three was not
	arriving, the state is now one the client cannot disagree about. An entity
	either exists or it does not.

	That also took the refill timer off this entity, which is the better place
	for it anyway: a stash waiting to come back has no entity to run a `Think`,
	so the wait belongs to the record. See `ix.points.Tick`.

	THE CAPS ARE NOT AN ITEM AND NOT AN INVENTORY. A stash is a number that goes
	to zero and comes back, so it is a number - making it an inventory would
	mean a container to open, items to drag and a way to put things IN one, none
	of which a cap stash is for.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Cap Stash"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	--- Networked so the client can draw the amount without asking.
	self:NetworkVar("Int", 0, "Caps")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		--[[
			A MODEL WITH NO COLLISION MESH GETS A BOX.

			`PhysicsInit(SOLID_VPHYSICS)` silently does nothing when the model
			has no physics hull - a lot of small prop models do not - and the
			entity is then not solid, which means the use trace goes straight
			through it and E does nothing at all. A bounding box is a worse
			shape and infinitely better than an entity nobody can touch.
		]]
		if (not IsValid(physics)) then
			self:PhysicsInitBox(Vector(-8, -8, 0), Vector(8, 8, 12))
			self:SetSolid(SOLID_BBOX)
			self:SetCollisionBounds(Vector(-8, -8, 0), Vector(8, 8, 12))

			physics = self:GetPhysicsObject()
		end

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetCaps(0)
	end

	--- Frozen again after every wake; see `ix_factionstorage.lua`.
	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	--[[
		Called by `ix.points.Spawn` once the record is attached.

		A stash only exists while it has something in it - `ix.points.Tick` is
		what decides that - so this is the amount, and nothing else.
	]]
	function ENT:OnRestored(record)
		local data = record.data or {}

		self:SetCaps(math.max(tonumber(data.remaining)
			or tonumber(data.caps) or 0, 0))
	end

	function ENT:Data()
		return self.ixRecord and self.ixRecord.data or {}
	end

	--- How much a full stash holds. The refill time is read in `Use`.
	function ENT:Capacity()
		return math.max(tonumber(self:Data().caps) or 250, 0)
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		local character = activator:GetCharacter()

		if (not character) then return end

		--[[
			Rate limited per player. Holding E fires `Use` several times a
			second, and the entity is not gone until the end of this function.
		]]
		if ((activator.ixNextStash or 0) > CurTime()) then return end

		activator.ixNextStash = CurTime() + 1

		local caps = self:GetCaps()

		if (caps <= 0) then
			activator:EmitSound("phoenix/ui/nv/menu_cancel.mp3", 50)

			return
		end

		--[[
			THE PAYOUT HAPPENS FIRST, before the bookkeeping.

			Everything after this is saving and removing, and any of it that
			went wrong used to take the payout down with it - the stash emptied
			and the caps went nowhere. The one thing the player is here for
			goes first.
		]]
		character:SetMoney(character:GetMoney() + caps)

		activator:Notify(string.format("You take %s.",
			ix.points.FormatCaps(caps)))

		activator:EmitSound("phoenix/ui/nv/itm_bottle_up_01.mp3", 65)

		ix.log.Add(activator, "pointLoot", ix.points.FormatCaps(caps))

		local data = self:Data()
		local record = self.ixRecord

		data.remaining = 0

		--[[
			NO METHOD CALL INSIDE THE ARITHMETIC, and that is not style.

			This line was

			    data.refillAt = os.time() + self:Respawn()

			and it threw "attempt to perform arithmetic on a nil value" every
			single time - which left `refillAt` at 0, so the tick saw a stash
			that was empty with no timer on it and put it straight back. That
			is why they were infinite: the error was the refill.

			WHICH OF THE TWO WAS NIL IS NOW KNOWN, and it was `self:Respawn()`.
			`Respawn` is not a name a scripted entity may have - it answers nil
			whatever the method body says. This was "fixed" by taking the call
			out of the arithmetic, which worked only because doing so deleted
			the method as well; the plant then hit the identical wall with the
			identical name. See gotcha 17.

			The number is read from the record in the open either way, where a
			nil is visible and reported rather than thrown three lines later.

			A WALL CLOCK, because `CurTime` restarts at about zero on every map
			load and a refill saved in it means nothing after a restart.
		]]
		local respawn = tonumber(data.respawn)

		if (not respawn) then
			respawn = 900

			ErrorNoHalt(string.format("[falloutrp] cap stash %s has no "
				.. "respawn time - using %d\n",
				tostring(record and record.id), respawn))
		end

		local now = os.time()

		if (not isnumber(now)) then
			--- Cannot happen, and the last three things that could not.
			ErrorNoHalt("[falloutrp] os.time() is not a number\n")

			now = 0
		end

		data.refillAt = now + math.max(respawn, 10)

		--- The record has to forget the entity, because it is about to go.
		if (record) then record.entity = nil end

		ix.points.Save()

		self:Remove()
	end
else
	--[[
		Drawn only when you are close enough to press E on it.

		A number floating over every stash on the map would turn the map into a
		minimap. 200 units is a little beyond `Use` range, so the label appears
		just before it becomes useful.

		There is no "empty" state to draw: an empty stash is not there.
	]]
	local RANGE = 200

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

		local caps = self:GetCaps()

		if (caps <= 0) then return end

		local position = self:GetPos() + self:OBBCenter()
			+ self:GetUp() * (self:OBBMaxs().z * 0.6 + 8)

		cam.Start3D2D(position, Angle(0, client:EyeAngles().y - 90, 90), 0.15)
			draw.SimpleText(ix.points.FormatCaps(caps), "ixZoneNote", 0, 0,
				Color(255, 210, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
