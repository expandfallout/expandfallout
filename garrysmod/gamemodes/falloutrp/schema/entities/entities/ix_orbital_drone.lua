--[[
	The cargo craft that brings an orbital drop in.

	It flies in from off to one side, releases the container over the site at
	58% of its pass, and carries on out of the map.

	PHOENIX'S `nut_orbital_drone`, with its one unportable part rebuilt.

	Theirs spawns in place on `models/roadkill/fallout/vehicle/cargobot.mdl`
	and plays a `dropoff` SEQUENCE, advancing the cycle by hand each frame and
	dropping the crate at cycle 0.58:

	    if self.Cycle >= 0.58 and SERVER then self:AmazonDelivery() end
	    if self.Cycle >= 1 and SERVER then self:Remove() end

	That model is not on this server - `resolve_asset.py` says so - and the
	nearest thing that is, `models/fallout/vertibird.mdl`, has two sequences:
	`idle` and `spin`, per `mdlseq.py`. There is no dropoff to play.

	So the cycle drives a FLIGHT PATH instead of an animation, at the same
	fraction of the same length of time. The crate is let go at 0.58 and the
	craft is gone at 1.0, exactly as theirs; what changed is that the craft
	moves through the air rather than hovering while its model animates, which
	is if anything closer to what the animation was depicting.

	THE CARRIED CRATE IS A SEPARATE PROP, which is theirs. It is parented,
	non-solid and in the debris collision group so nobody can shoot it out of
	the air or stand on it, and it is REPLACED at the moment of release by the
	real container - the thing that falls is not the thing that was carried.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Orbital Drop Craft"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

--- How high it flies, and how far out it starts and ends.
ENT.Altitude = 700
ENT.Approach = 2600

--[[
	NO NETWORK VARIABLES, deliberately.

	The craft's position is set on the server every frame and the engine
	networks that on its own, so the client needs nothing else to draw it in
	the right place. A `Target` and a `Started` var would be two more things to
	set, and the setter would have to run after `Spawn` - a network variable
	set before it is silently lost, which is what cost this project an
	afternoon on `SetBenchID`.
]]

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(ix.orbital.assets.drone)
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NOCLIP)
		self:DrawShadow(false)

		--[[
			The rotors, such as they are. `spin` is one of the model's two
			sequences and is the one that is not a static pose; if a future
			model has a proper flight sequence this is the line to change.
		]]
		local sequence = self:LookupSequence("spin")

		if (sequence and sequence > 0) then
			self:ResetSequence(sequence)
			self:SetPlaybackRate(1)
		end

		self.dropped = false

		--- Carried, and thrown away at the drop. See the header.
		self.crate = ents.Create("prop_physics")

		if (IsValid(self.crate)) then
			self.crate:SetModel(ix.orbital.assets.container)
			self.crate:SetSolid(SOLID_NONE)
			self.crate:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			self.crate:SetMoveType(MOVETYPE_NONE)
			self.crate:Spawn()
			self.crate:SetParent(self)
			self.crate:SetLocalPos(Vector(0, 0, -60))
		end
	end

	--[[
		Sent on its way. Called AFTER `Spawn`.

		The bearing is chosen here rather than in `Initialize` so two drops on
		one site do not always arrive from the same direction, and the craft is
		put at the start of its path immediately - otherwise it exists for one
		frame at the origin, which is a black speck on the horizon that
		somebody will report.
	]]
	function ENT:Launch(position)
		self.target = position
		self.started = CurTime()
		self.bearing = Angle(0, math.random(0, 359), 0):Forward()

		self:SetPos(self:PositionAt(0))
		self:SetAngles(self.bearing:Angle())
	end

	--[[
		Where it is at a given fraction of its pass.

		A straight line through the site: it comes in from one side, is exactly
		overhead at the fraction it drops, and carries on out the other.
	]]
	function ENT:PositionAt(fraction)
		local target = self.target or self:GetPos()
		local bearing = self.bearing or Vector(1, 0, 0)

		--- -1 at the start, 0 overhead at the drop, +1 at the end.
		local along = (fraction - ix.orbital.dropAt)
			/ (fraction < ix.orbital.dropAt and ix.orbital.dropAt
				or (1 - ix.orbital.dropAt))

		return target + bearing * (along * self.Approach)
			+ Vector(0, 0, self.Altitude)
	end

	function ENT:Think()
		self:NextThink(CurTime())

		if (not self.started) then return true end

		local length = math.max(ix.orbital.flightTime, 1)
		local fraction = (CurTime() - self.started) / length

		local position = self:PositionAt(math.Clamp(fraction, 0, 1))

		self:SetPos(position)
		self:SetAngles((self.bearing or Vector(1, 0, 0)):Angle())

		if (not self.dropped and fraction >= ix.orbital.dropAt) then
			self:Deliver()
		end

		if (fraction >= 1) then self:Remove() end

		return true
	end

	--[[
		Let it go.

		The carried prop is removed and the real container created in its
		place, which is theirs - `AmazonDelivery` does exactly this - and it is
		why the thing that falls has loot in it while the thing that was
		carried never did.
	]]
	function ENT:Deliver()
		if (self.dropped) then return end

		self.dropped = true

		local position = self:GetPos() - Vector(0, 0, 70)

		if (IsValid(self.crate)) then
			position = self.crate:GetPos()

			self.crate:Remove()
		end

		ix.orbital.DropContainer(position, Angle(0, self:GetAngles().y, 0))
	end

	function ENT:OnRemove()
		if (IsValid(self.crate)) then self.crate:Remove() end

		--[[
			The craft is the last thing in the event, so it is what says the
			event is over - unless it never dropped, in which case something
			removed it early and the clock still has to restart.
		]]
		if (ix.orbital.active == self) then ix.orbital.Finished() end
	end
else
	function ENT:Initialize()
		--[[
			A looping rotor, positioned on the craft each frame.

			`sound.PlayFile` with "3d" is what Phoenix use; `CreateSound` is
			the simpler equivalent here and follows the entity on its own, so
			there is nothing to move and nothing to stop by hand except at
			removal.
		]]
		self.rotor = CreateSound(self, ix.orbital.assets.rotor)

		if (self.rotor) then self.rotor:PlayEx(0.7, 100) end
	end

	function ENT:OnRemove()
		if (self.rotor) then self.rotor:Stop() end
	end

	function ENT:Draw()
		self:DrawModel()
	end
end
