--[[
	A capture point.

	A square of ground marked in red. Stand in it and it starts going to your
	faction; walk out and it stops where it is. Somebody from another faction
	standing in it makes it CONTESTED, which stops it for everybody - taking
	ground means clearing it first.

	Whoever holds it is paid, in caps, every few minutes, to every member of
	the faction who is online. That is the point of holding one.

	A SQUARE, NOT A SPHERE. `ents.FindInBox` is what the red outline actually
	describes, and a sphere drawn as a box is a point that captures from
	corners you were told were outside it. The outline and the test are the
	same shape.

	LEAVING PAUSES, IT DOES NOT RESET. "It stops when you leave" is what was
	asked for, and stopping is not the same as undoing: a point worn down over
	an evening is a thing two factions can fight over across a session, while
	one that empties the moment you step off is a test of who can stand still
	longest without being shot.

	THE OWNER STRING IS THE SAME ONE THE ZONES USE - `faction:<uniqueID>`,
	encoded by `ix.zones.ClaimFor` and read by `ix.zones.Owner`. Two systems
	that both mean "which faction holds this" should not have two answers.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Capture Point"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

--- How tall the capture box is. Two storeys, so a roof does not hide you.
ENT.CaptureHeight = 192

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Progress")
	self:NetworkVar("Bool", 0, "Contested")
	self:NetworkVar("String", 0, "PointName")
	self:NetworkVar("String", 1, "HolderName")

	--[[
		The holder's colour, packed into an integer because `NetworkVar` has no
		colour type. Networked rather than looked up because a point held by
		one faction has a colour the client could find, and the "unclaimed"
		grey is not any faction's - one field answers both.
	]]
	self:NetworkVar("Int", 0, "HolderColour")

	--- Networked so the client can draw the outline the server tests against.
	self:NetworkVar("Int", 1, "Radius")
end

--- Unpacked from the integer the server packs. Shared: both ends draw with it.
function ENT:HolderColour()
	local packed = self:GetHolderColour()

	if (packed <= 0) then return Color(190, 190, 190) end

	return Color(bit.band(bit.rshift(packed, 16), 255),
		bit.band(bit.rshift(packed, 8), 255), bit.band(packed, 255))
end

--- The corners of the capture box, in world space.
function ENT:CaptureBounds()
	local radius = math.max(self:GetRadius(), 32)
	local origin = self:GetPos()

	return origin + Vector(-radius, -radius, -16),
		origin + Vector(radius, radius, self.CaptureHeight)
end

function ENT:IsInside(position)
	local mins, maxs = self:CaptureBounds()

	return position:WithinAABox(mins, maxs)
end

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (not IsValid(physics)) then
			self:PhysicsInitBox(Vector(-8, -8, 0), Vector(8, 8, 64))
			self:SetSolid(SOLID_BBOX)

			physics = self:GetPhysicsObject()
		end

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		self:SetProgress(0)
		self:SetRadius(160)
		self:SetPointName("Capture Point")
		self:SetHolderName("")
	end

	function ENT:PhysicsUpdate(physics)
		if (physics:IsMotionEnabled()) then
			physics:EnableMotion(false)
			physics:Sleep()
		end
	end

	function ENT:Data()
		return self.ixRecord and self.ixRecord.data or {}
	end

	function ENT:OnRestored(record)
		local data = record.data or {}

		self:SetPointName(tostring(data.name or "Capture Point"))
		self:SetRadius(math.Clamp(tonumber(data.radius) or 160, 32, 2048))
		self:Announce()

		self.nextPayout = CurTime() + self:PayoutInterval()
	end

	function ENT:CaptureTime()
		return math.max(tonumber(self:Data().captureTime) or 45, 5)
	end

	function ENT:Payout()
		return math.max(tonumber(self:Data().payout) or 0, 0)
	end

	--- Minutes on the record, seconds everywhere it is used.
	function ENT:PayoutInterval()
		return math.max(tonumber(self:Data().payoutInterval) or 5, 1) * 60
	end

	--[[
		Which factions may take this. An empty list means any real one.

		"Any real one" and not "anybody": a default faction holds nothing, the
		same rule `ix.zones.ClaimFor` states, so Wastelanders cannot take a
		point whatever the list says.
	]]
	function ENT:AllowedFactions()
		return self:Data().factions or {}
	end

	function ENT:Allows(faction)
		if (not faction or faction.isDefault) then return false end

		local list = self:AllowedFactions()

		if (#list == 0) then return true end

		for _, uniqueID in ipairs(list) do
			if (uniqueID == faction.uniqueID) then return true end
		end

		return false
	end

	--- Push the current holder out to everybody looking at it.
	--- What a side claim is called, and in whose colour. Nil for a faction one.
	local SIDE_NAMES = {
		["side:attackers"] = "Attackers",
		["side:defenders"] = "Defenders",
		["side:skirmishers"] = "Skirmishers"
	}

	function ENT:Announce()
		--[[
			A SIDE HOLDS A WAR POINT, not a faction - so the name is the side's
			and the colour is the principal faction's, which is the one people
			picture when they hear "the attackers".
		]]
		local claim = self:Data().owner
		local sideName = claim and SIDE_NAMES[claim]

		if (sideName) then
			local raid = ix.raid and ix.raid.current
			local principal = raid and (claim == "side:attackers"
				and raid.attacker or raid.defender)
			local data = principal and ix.faction.indices[principal]
			local colour = data and data.color or Color(190, 190, 190)

			self:SetHolderName(sideName)
			self:SetHolderColour(bit.bor(bit.lshift(colour.r, 16),
				bit.lshift(colour.g, 8), colour.b))

			return
		end

		local owner = ix.zones.Owner({properties = {owner = self:Data().owner}})

		self:SetHolderName(owner and owner.name or "")

		local colour = owner and owner.color or Color(190, 190, 190)

		self:SetHolderColour(bit.bor(bit.lshift(colour.r, 16),
			bit.lshift(colour.g, 8), colour.b))
	end

	--[[
		WHAT ONE CHARACTER'S CLAIM ON THIS POINT IS.

		Normally their faction's, through `ix.zones.ClaimFor` - the same string
		the zones use, so two systems that both mean "who holds this" have one
		answer.

		A WAR POINT GROUPS BY SIDE INSTEAD. Everybody who came to attack is one
		claim and everybody defending is another, so a faction that turned up
		to assist can take the enemy's ground and cannot contest its own -
		which is what assisting means and what standing next to your allies
		should feel like.
	]]
	function ENT:ClaimOf(character)
		if (self.ixWarPoint and ix.raid and ix.raid.Side) then
			local side = ix.raid.Side(character:GetFaction())

			if (side) then return "side:" .. side end
		end

		return ix.zones.ClaimFor(character)
	end

	--[[
		Everybody standing in the box, grouped by the claim they would make.

		Grouping by claim string rather than by faction index is what makes two
		members of the SAME faction not contest each other while a third from
		another faction does, without this having to know anything about
		factions.
	]]
	function ENT:Occupants()
		local mins, maxs = self:CaptureBounds()
		local claims, blocked = {}, false

		for _, client in ipairs(ents.FindInBox(mins, maxs)) do
			if (not IsValid(client) or not client:IsPlayer()) then continue end
			if (not client:Alive()) then continue end

			local character = client:GetCharacter()

			if (not character) then continue end

			local faction = ix.faction.indices[character:GetFaction()]

			--[[
				Somebody who may not take it still CONTESTS it. Standing on a
				point you cannot capture to stop somebody else capturing it is
				a real thing to do, and the alternative - a Wastelander being
				invisible to the point - would make them the ideal escort.
			]]
			if (not self:Allows(faction)) then
				blocked = true

				continue
			end

			local claim = self:ClaimOf(character)

			if (not claim) then continue end

			claims[claim] = claims[claim] or {}
			claims[claim][#claims[claim] + 1] = client
		end

		return claims, blocked
	end

	--- Pay everybody in the holding faction, wherever they are standing.
	function ENT:Pay()
		local owner = ix.zones.Owner({properties = {owner = self:Data().owner}})
		local amount = self:Payout()

		if (not owner or not owner.faction or amount <= 0) then return end

		local paid = 0

		for _, client in ipairs(player.GetAll()) do
			local character = client:GetCharacter()

			if (not character) then continue end

			local faction = ix.faction.indices[character:GetFaction()]

			if (not faction or faction.uniqueID ~= owner.faction) then
				continue
			end

			character:SetMoney(character:GetMoney() + amount)

			--[[
				A notice, not a chat line. Caps arriving is the same kind of
				event as picking something up - it belongs in the corner with
				the rest of them rather than in the middle of whatever people
				are saying to each other.
			]]
			client:Notify(string.format("%s from %s.",
				ix.points.FormatCaps(amount), self:GetPointName()))

			client:EmitSound("phoenix/ui/nv/itm_bottle_up_01.mp3", 55)

			paid = paid + 1
		end

		if (paid > 0) then
			ix.log.Add(nil, "pointPayout", self:GetPointName(), owner.name,
				ix.points.FormatCaps(amount), paid)
		end
	end

	--[[
		SAY IT ONCE, in chat, to everybody.

		A war is decided on these now, so the whole server has a stake in what
		is happening on one - "they are taking the point" is the moment people
		drop what they are doing and run. Guarded by the last thing said so a
		point being stood on for two minutes is one line rather than two
		hundred and forty.
	]]
	function ENT:AnnounceState(text)
		if (self.ixLastSaid == text) then return end

		--[[
			The last line said, so a state that lasts a while is one message -
			and a state that comes back after a different one is a new event
			and is said again. "Being taken", "contested", "being taken" is
			three things happening, not one repeated.
		]]
		self.ixLastSaid = text

		--[[
			THROUGH THE CONFLICT ANNOUNCER, not a channel of its own. It is a
			line about the fight everybody is in, it should read like the rest
			of them, and `ix.raid.Announce` already reaches every client with
			the right colour - see `sv_raid.lua`.
		]]
		if (ix.raid and ix.raid.Announce) then
			ix.raid.Announce(text)
		end
	end

	--[[
		How many people a side needs standing here before it counts.

		ONE, unless multicap is on - which is a war setting, because a war is
		the only thing decided on these and "one man walks in while everybody
		fights elsewhere" is the thing it exists to stop.
	]]
	function ENT:RequiredPeople()
		if (not self.ixWarPoint) then return 1 end
		if (not ix.config.Get("warMultiCap", false)) then return 1 end

		return math.max(ix.config.Get("warCapPlayers", 2), 1)
	end

	function ENT:Think()
		self:NextThink(CurTime() + 0.5)

		local data = self:Data()

		--- The wage, whether or not anybody is standing on it.
		if (self.nextPayout and CurTime() >= self.nextPayout) then
			self.nextPayout = CurTime() + self:PayoutInterval()

			self:Pay()
		end

		local claims, blocked = self:Occupants()
		local distinct = table.Count(claims)

		if (distinct == 0) then
			--- Nobody who counts is here. Progress stays where it is.
			self:SetContested(blocked)

			--[[
				STOPPING LOSES THE PROGRESS. Walking off a point you were
				taking is giving it up - the only thing that HOLDS progress is
				somebody standing there contesting it, which is the one case
				where both sides are still fighting over it.
			]]
			if (self.ixWarPoint and self:GetProgress() > 0) then
				self:SetProgress(0)
				self:AnnounceState(string.format(
					"%s is no longer being taken.", self:GetPointName()))
			end

			return true
		end

		if (distinct > 1 or blocked) then
			self:SetContested(true)

			if (self.ixWarPoint) then
				self:AnnounceState(string.format("%s is CONTESTED.",
					self:GetPointName()))
			end

			return true
		end

		self:SetContested(false)

		local claim, here = next(claims)

		if (claim == data.owner) then
			--- Already theirs. Standing on your own ground does nothing.
			self:SetProgress(0)

			return true
		end

		--[[
			ENOUGH OF THEM, for a war point with multicap on. Fewer than that
			is treated as nobody: the point neither moves nor resets, which is
			the same thing standing off it does.
		]]
		if (#here < self:RequiredPeople()) then
			if (self.ixWarPoint) then
				self:AnnounceState(string.format(
					"%s needs %d people on it to be taken.", self:GetPointName(),
					self:RequiredPeople()))
			end

			return true
		end

		--[[
			SAID WHEN IT STARTS, and then not again.

			The percentage was a line every half second for two minutes. What
			people need is the moment somebody walks onto the point - after
			that they can watch the bar like everybody else.

			`GetProgress() <= 0` is the test rather than a flag, because it is
			already the thing that means "this is new": progress is cleared by
			walking off it, and holding it never starts from zero.
		]]
		if (self.ixWarPoint and self:GetProgress() <= 0) then
			self:AnnounceState(string.format("%s is being taken!",
				self:GetPointName()))
		end

		self:SetProgress(math.min(
			self:GetProgress() + 0.5 / self:CaptureTime(), 1))

		if (self:GetProgress() < 1) then return true end

		self:SetProgress(0)

		data.owner = claim

		self:Announce()

		--- A war point is not map furniture and has no record to write to.
		if (self.ixPointID) then
			ix.points.Update(self)
		end

		local holder = self:GetHolderName()
		local taker = here and here[1]

		if (IsValid(taker)) then
			ix.log.Add(taker, "pointCapture", self:GetPointName(), holder)
		end

		for _, client in ipairs(player.GetAll()) do
			client:ChatPrint(string.format("[Capture] %s has been taken by %s.",
				self:GetPointName(), holder))

			client:EmitSound("phoenix/ui/76/ui_discover_region_01.mp3", 60)
		end

		--[[
			A WAR IS DECIDED HERE, not by the clock. Taking the enemy's ground
			is the win condition, so the war library is told and it ends the
			thing - see `ix.war.PointTaken`.
		]]
		if (self.ixWarPoint and ix.war and ix.war.PointTaken) then
			ix.war.PointTaken(self, claim)
		end

		return true
	end

	--- E says who holds it, for anybody who cannot read the bar from where
	--- they are standing.
	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		local holder = self:GetHolderName()

		activator:Notify(string.format("%s - %s.", self:GetPointName(),
			holder ~= "" and ("held by " .. holder) or "held by nobody"))
	end
else
	local RANGE = 2400

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

		--[[
			THE RED SQUARE, drawn from `Draw` rather than from a hook.

			`Draw` already runs once per visible entity per frame with the
			right render state, and drawing the outline here means it appears
			and disappears with the pole rather than needing its own list of
			which points exist.
		]]
		local mins, maxs = self:CaptureBounds()
		local centre = (mins + maxs) * 0.5
		local half = (maxs - mins) * 0.5

		render.DrawWireframeBox(centre, angle_zero, -half, half,
			Color(220, 60, 50, 255), true)

		local position = self:GetPos() + self:GetUp() * (self:OBBMaxs().z + 12)

		--[[
			The scale, not the font. Everything inside a `cam.Start3D2D` is in
			its own units, so tripling the scale triples the text and the gap
			between the two lines together - changing the font would have
			needed the offsets changing to match.
		]]
		cam.Start3D2D(position, Angle(0, client:EyeAngles().y - 90, 90), 0.6)
			local holder = self:GetHolderName()

			draw.SimpleText(self:GetPointName(), "ixZoneNote", 0, -18,
				self:HolderColour(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText(holder ~= "" and holder or "unclaimed",
				"ixZoneNote", 0, 0, ColorAlpha(self:HolderColour(), 190),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
