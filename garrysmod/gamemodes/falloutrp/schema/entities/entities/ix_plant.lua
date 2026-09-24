--[[
	A harvestable plant.

	Press E: you get the fruit and some experience, the fruit disappears off the
	model, and it grows back on a timer. Phoenix's `nut_plant`, on this schema's
	point system - see `sh_plants.lua` for why the placement half is not
	rebuilt.

	THE PLANT STAYS AND THE FRUIT GOES. That is bodygroup 1, which every one of
	these models has: the stalk is bodygroup 0 and the thing you pick is
	bodygroup 1. It is the opposite decision to the cap stash, which is removed
	outright when looted, and for a reason - a stash IS its caps, while a picked
	bush is still a bush and still tells you where to come back to.

	THE REGROW DEADLINE IS `os.time` AND IT LIVES ON THE RECORD.

	Both halves of that are the cap stash's lessons, paid for once already:
	`CurTime` restarts at about zero on every map load, and a `timer.Simple`
	held by an entity is gone the moment the map changes - so a plant picked
	four minutes before a restart would have come back instantly, for ever.
	Written on the record, it survives, and a plant picked before a restart is
	still picked after one.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Plant"
ENT.Category = "Fallout RP"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	--[[
		Networked so the client can say "Press E to harvest" or not without
		asking. The bodygroup is networked by the engine anyway; this is the
		question the label needs, which is not quite the same thing.
	]]
	self:NetworkVar("Bool", 0, "Picked")
end

--- Which plant this is. Shared, because the client's label wants the name.
function ENT:PlantType()
	return ix.plants.Get(self:GetNetVar("plant", ""))
		or ix.plants.Get(ix.plants.fallback)
end

if (SERVER) then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		--[[
			A MODEL WITH NO COLLISION MESH GETS A BOX - the cap stash's note
			applies word for word. `PhysicsInit` silently does nothing when a
			model has no hull, the entity is then not solid, and E traces
			straight through a plant that looks perfectly ordinary.
		]]
		local physics = self:GetPhysicsObject()

		if (not IsValid(physics)) then
			self:PhysicsInitBox(Vector(-10, -10, 0), Vector(10, 10, 24))
			self:SetSolid(SOLID_BBOX)
			self:SetCollisionBounds(Vector(-10, -10, 0), Vector(10, 10, 24))

			physics = self:GetPhysicsObject()
		end

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
		The record this plant is, re-attached if it has come loose.

		`self.ixRecord and self.ixRecord.data or {}` was the whole of this, and
		that `or {}` IS A FRESH TABLE EVERY CALL: anything written through it
		went nowhere and read back as nothing a moment later. A plant with no
		record would have been picked for ever or - because the tick treated a
		missing deadline as "due" - picked and back instantly.

		So it looks the record up by id rather than giving up, and only invents
		a table when there is genuinely nothing to point at.
	]]
	function ENT:Data()
		local record = self.ixRecord

		if (not record and self.ixPointID) then
			record = ix.points.stored[self.ixPointID]
			self.ixRecord = record
		end

		if (not record) then return {} end

		record.data = record.data or {}

		return record.data
	end

	--[[
		Read the record. Called by `ix.points.Spawn` when the map loads and
		again by the tool's Reload, which is how one plant is turned into
		another without replacing it.
	]]
	function ENT:OnRestored(record)
		local data = record.data or {}
		local plant = ix.plants.Get(data.plant) or ix.plants.Get(ix.plants.fallback)

		self:SetNetVar("plant", plant.id)

		--[[
			The model follows the KIND, not the record, unless somebody typed
			one into the tool. A plant whose type was changed by Reload has to
			change what it looks like or the tool is lying.
		]]
		if (record.model ~= plant.model and not data.customModel) then
			record.model = plant.model

			self:SetModel(plant.model)
			self:PhysicsInit(SOLID_VPHYSICS)
		end

		--[[
			Phoenix's `collisions` flag, and it is the wrong way round in their
			code: `if collisions then COLLISION_GROUP_DEBRIS`. Debris is the
			group that does NOT collide with players, so their "collisions on"
			is the setting that turns them off. Ours means what it says.
		]]
		self:SetCollisionGroup(data.collisions and COLLISION_GROUP_NONE
			or COLLISION_GROUP_DEBRIS)

		local refillAt = tonumber(data.refillAt) or 0

		self:SetPicked(refillAt > os.time())
		self:SetBodygroup(1, self:GetPicked() and 1 or 0)
	end

	--[[
		Seconds before the fruit is back.

		THE NAME IS THE FIX. This was `ENT:Respawn`, and `self:Respawn()`
		returned NIL every single time - which is why nothing here worked:

		    it never grew back      the deadline was `now + nil`, so the write
		                            threw and no deadline was ever recorded
		    then it went silent     moving that write ABOVE the sound and the
		                            experience, to protect it, moved the throw
		                            above them too. The harvest lost its noise
		                            and its XP and STILL did not grow back

		One throw, three symptoms, three rounds of looking at the wrong half.

		`Respawn` is not a name a scripted entity may have. The cap stash hit
		exactly this - gotcha 12 - and was "fixed" by taking the call out of the
		arithmetic without ever asking why the call answered nil; it only worked
		because that deleted the method as well. Two entities, two identical
		failures, one name. See gotcha 17.

		Everything else on these entities works, `Yield` and `Experience`
		included, so it is not the table, the realm or the maths.
	]]
	function ENT:RegrowTime()
		local data = self:Data()
		local seconds = tonumber(data.respawn)

		if (not seconds) then
			ErrorNoHalt(string.format("[falloutrp] plant %s has no respawn "
				.. "time - using 300\n", tostring(self.ixPointID)))

			seconds = 300
		end

		return math.Clamp(seconds, 10, 86400)
	end

	--- How many of the item one harvest gives.
	function ENT:Yield()
		return math.Clamp(math.floor(tonumber(self:Data().yield) or 1), 1, 20)
	end

	--[[
		Experience for picking THIS one.

		A negative number on the record means "whatever the config says", which
		is what the tool writes unless somebody moves the slider off -1. So the
		server-wide number stays the default and a particular plant - something
		rare, something at the bottom of a cave - can be worth more without
		making every plant worth more.
	]]
	--[[
		Named `XPValue`, not `Experience`, for the reason `RegrowTime` is not
		called `Respawn`: this one has never actually been seen to work either -
		it was added in the same round as the per-plant experience and the throw
		above it meant it was never reached - and one unexplained reserved name
		on this entity is enough. `Yield` HAS been seen to work, so it keeps its
		name.
	]]
	function ENT:XPValue()
		local own = tonumber(self:Data().xp)

		if (own and own >= 0) then return math.floor(own) end

		return math.max(ix.config.Get("plantXP", 10), 0)
	end

	function ENT:Use(activator)
		if (not IsValid(activator) or not activator:IsPlayer()) then return end

		--- Holding E fires `Use` several times a second.
		if ((activator.ixNextPlant or 0) > CurTime()) then return end

		activator.ixNextPlant = CurTime() + 1

		if (self:GetPicked()) then
			activator:Notify("There is nothing left to pick.")
			activator:EmitSound("phoenix/ui/nv/menu_cancel.mp3", 50)

			return
		end

		local character = activator:GetCharacter()

		if (not character) then return end

		if (activator:IsRestricted()) then
			activator:Notify("Your hands are tied.")

			return
		end

		local inventory = character:GetInventory()
		local plant = self:PlantType()

		if (not inventory or not plant) then return end

		if (not ix.item.list[plant.item]) then
			ErrorNoHalt(string.format("[falloutrp] plant '%s' drops '%s', "
				.. "which is not an item\n", plant.id, tostring(plant.item)))

			return
		end

		--[[
			THE FIRST ONE DECIDES. If there is no room for even one, nothing is
			picked and the plant is left alone - so a full inventory costs you
			nothing rather than silently eating the harvest.
		]]
		local added = inventory:Add(plant.item)

		if (added == false or added == nil) then
			activator:Notify("You have no room for that.")

			return
		end

		local given = 1

		for _ = 2, self:Yield() do
			local more = inventory:Add(plant.item)

			if (more == false or more == nil) then break end

			given = given + 1
		end

		--[[
			THE DEADLINE IS WRITTEN BEFORE ANYTHING ELSE, and that is the fix
			for "plants grow back instantly".

			It used to be the last thing in this function, after the sound, the
			particle, the experience and two notifications - so ANY of those
			throwing (and `AddXP` can level somebody up, which is a lot of code)
			left a plant marked picked with no deadline on it. The tick then saw
			a plant that was due and put the fruit straight back.

			Everything below this point is presentation. The two lines that
			decide what the plant IS come first, with nothing between them that
			can fail: the state, then the deadline, then the noise.

			`os.time` and locals, for gotchas 11 and 12 respectively - and both
			are checked before they are added together, so if either is ever nil
			again the console says WHICH rather than the line reporting itself.
		]]
		local respawn = self:RegrowTime()
		local now = os.time()

		if (not isnumber(respawn) or not isnumber(now)) then
			ErrorNoHalt(string.format("[falloutrp] plant harvest: respawn %s, "
				.. "clock %s\n", tostring(respawn), tostring(now)))

			respawn = tonumber(respawn) or 300
			now = tonumber(now) or 0
		end

		self:SetPicked(true)
		self:SetBodygroup(1, 1)

		local record = self.ixRecord

		if (record) then
			record.data = record.data or {}
			record.data.refillAt = now + respawn

			ix.points.Save()
		else
			ErrorNoHalt("[falloutrp] a plant was harvested with no record "
				.. "attached; it cannot grow back\n")
		end

		--[[
			A SOUND THIS SERVER ACTUALLY HAS.

			This was `physics/flesh/flesh_squishy_impact_hard1-4.wav`, copied
			from Phoenix - and Phoenix run on a server with Half-Life 2 content
			mounted. `resolve_asset.py` finds none of the HL2 sound paths here,
			so every one of them played nothing at all. Checked, not assumed.
		]]
		self:EmitSound("phoenix/ui/nv/ui_items_generic_up_0"
			.. math.random(4) .. ".mp3", 65)

		--[[
			THE REST OF IT, EACH PART ON ITS OWN.

			"No sound and no experience" is what one throw anywhere in this tail
			looks like from in game: everything after the failing line is
			skipped and nothing says why, because a throw inside `ENT:Use` is
			swallowed by the engine\'s use handler.

			So each part runs in its own `pcall` and says WHICH part failed if
			it does. This is not defensive decoration - it is the difference
			between the next report being "no xp" and being one line naming the
			function that did not work.
		]]
		local function Safely(what, callback)
			local ok, err = pcall(callback)

			if (ok) then return end

			ErrorNoHalt(string.format("[falloutrp] plant harvest: %s failed: "
				.. "%s\n", what, tostring(err)))
		end

		Safely("the particle", function()
			local effect = EffectData()
			effect:SetColor(BLOOD_COLOR_ANTLION_WORKER)
			effect:SetOrigin(self:GetPos() + self:OBBCenter())
			util.Effect("BloodImpact", effect, true, true)
		end)

		Safely("experience", function()
			local experience = self:XPValue()

			if (experience > 0) then character:AddXP(experience) end
		end)

		Safely("the notification", function()
			activator:Notify(string.format("You harvest %d %s.", given,
				plant.name))
		end)

		Safely("the log", function()
			ix.log.Add(activator, "plantHarvest", plant.name, given)
		end)
	end

	--[[
		THE REGROW IS NOT HERE ANY MORE, AND THAT IS THE FIX.

		It was an `ENT:Think` that re-armed itself with `NextThink`, and it did
		not put fruit back. Rather than a fourth round of guessing which half of
		the think scheduling was not firing, the wait was moved to the place
		this codebase already keeps every other one: `ix.points.Tick`, a plain
		one-second timer over the RECORDS.

		That is the same lesson the cap stash paid for, written at the top of
		`sv_points.lua` - "ON THE RECORD, NOT ON THE ENTITY" - and it is
		strictly more robust than a think: a timer that is proven to run (it is
		the one refilling the stashes) cannot be stopped by an entity being
		asleep, moved, unparented or briefly invalid.

		`Ripen` is what the tick calls. It is on the entity because the
		bodygroup and the netvar are the entity's, and it is safe to call at any
		time - it decides for itself whether anything is due.
	]]
	function ENT:Ripen()
		if (not self:GetPicked()) then return false end

		local data = self:Data()
		local refillAt = tonumber(data.refillAt) or 0

		--[[
			NO DEADLINE IS NOT THE SAME AS A DEADLINE THAT HAS PASSED, and
			treating them as one is what "plants grow back instantly" looked
			like from here: a plant that failed to record when it should return
			answered "due" on the very next tick, for ever.

			A picked plant with nothing written on it gets a deadline now. The
			worst case is one plant taking its full time from the moment it was
			noticed rather than from the moment it was picked; the old worst
			case was every plant on the map being infinite.
		]]
		if (refillAt <= 0) then
			local respawn = self:RegrowTime()
			local now = os.time()

			data.refillAt = now + respawn

			return true
		end

		if (os.time() >= refillAt) then
			self:SetPicked(false)
			self:SetBodygroup(1, 0)

			return true
		end

		return false
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
	Helix's own tooltip rather than Phoenix's hand-drawn 3D2D text.

	`OnPopulateEntityInfo` is what the entity info panel calls, so a plant looks
	like every other thing in this game you can look at, appears after the same
	delay, and is hidden by the same options - none of which their version does.
]]
function ENT:OnPopulateEntityInfo(container)
	local plant = self:PlantType()
	local name = container:AddRow("name")

	name:SetImportant()
	name:SetText(plant and plant.name or "Plant")
	name:SizeToContents()

	local hint = container:AddRow("hint")

	if (self:GetPicked()) then
		hint:SetText("Picked. It will grow back.")
		hint:SetTextColor(Color(200, 160, 160))
	else
		hint:SetText("Press E to harvest.")
	end

	hint:SizeToContents()
end
