--[[
	Orbital drops - deciding when and where.

	See `sh_orbital.lua` for what one is and what came from Phoenix.

	THE EVENT HALF IS RECONSTRUCTED, NOT PORTED. glua-steal never retrieves
	server files, so `plugins/orbital_drops/sv_plugin.lua` is not in the
	scrape - what exists of theirs is the two entities and the config list. The
	entities name what the missing half must have done: pick a point, spawn a
	beacon on it, and do that every `Orbital Event Timer` seconds when enough
	people are on. That is what this is.

	ONE AT A TIME. Two beacons counting down at once would split whoever turned
	up, and the interval is measured from the last one ENDING rather than from
	the last one starting - a drop that took five minutes to play out should
	not be followed immediately by the next.
]]

if (not SERVER) then return end

ix.orbital = ix.orbital or {}

--- The beacon or the craft currently in play, if any.
ix.orbital.active = ix.orbital.active or nil

--- When the next one may happen.
ix.orbital.nextEvent = 0

--------------------------------------------------------------------------------
-- Where
--------------------------------------------------------------------------------

--[[
	Every placed drop site, as `{id, record}`.

	Read straight out of `ix.points.stored` rather than kept as a second list,
	for the reason the whole point system gives: the record is authoritative
	and a copy is a thing that goes stale.
]]
function ix.orbital.Sites()
	local out = {}

	for id, record in pairs(ix.points.stored or {}) do
		if (record.type ~= "orbital") then continue end

		out[#out + 1] = {id = id, record = record}
	end

	return out
end

--[[
	Pick one, avoiding the last.

	A site chosen at random will pick the same one twice often enough to look
	broken on a map with three of them. Excluding the previous choice is one
	comparison and makes it feel deliberate.
]]
function ix.orbital.PickSite()
	local sites = ix.orbital.Sites()

	if (#sites == 0) then return end
	if (#sites == 1) then return sites[1] end

	for _ = 1, 8 do
		local pick = sites[math.random(#sites)]

		if (pick.id ~= ix.orbital.lastSite) then return pick end
	end

	return sites[math.random(#sites)]
end

--------------------------------------------------------------------------------
-- Starting one
--------------------------------------------------------------------------------

--[[
	Put a beacon on a site. Returns the beacon, or `false, reason`.

	The beacon is spawned slightly above the marker so it sits on the ground
	rather than inside it, and the marker itself is left alone - a drop site is
	a permanent thing that drops happen AT, not a thing that is consumed.
]]
function ix.orbital.Start(site, client)
	if (IsValid(ix.orbital.active)) then
		return false, "There is already one happening."
	end

	site = site or ix.orbital.PickSite()

	if (not site) then
		return false, "There are no drop sites on this map. Place some with "
			.. "the point tool."
	end

	local beacon = ents.Create("ix_orbital_beacon")

	if (not IsValid(beacon)) then return false, "It would not spawn." end

	beacon:SetPos(site.record.position + Vector(0, 0, 8))
	beacon:SetAngles(angle_zero)
	beacon:Spawn()

	beacon.ixSiteName = site.record.data and site.record.data.name
		or "an unmarked site"

	ix.orbital.active = beacon
	ix.orbital.lastSite = site.id

	ix.log.Add(client, "orbitalStart", beacon.ixSiteName)

	if (ix.config.Get("orbitalAnnounce", true)) then
		for _, other in ipairs(player.GetAll()) do
			other:ChatPrint(string.format(
				"[Orbital] A drop beacon has landed at %s.",
				beacon.ixSiteName))
		end
	end

	return beacon
end

--[[
	Called by the beacon and the craft when they are finished with.

	The interval starts HERE rather than at the beacon landing, so the gap
	between drops is a gap between drops rather than a gap that the beacon's
	own five minutes eats most of.
]]
function ix.orbital.Finished()
	ix.orbital.active = nil
	ix.orbital.nextEvent = CurTime()
		+ math.max(ix.config.Get("orbitalInterval", 3600), 60)
end

--------------------------------------------------------------------------------
-- The clock
--------------------------------------------------------------------------------

timer.Create("ixOrbital", 30, 0, function()
	if (not ix.config.Get("orbitalEnabled", true)) then return end
	if (IsValid(ix.orbital.active)) then return end
	if (not ix.points or not ix.points.loaded) then return end

	--[[
		The first interval is counted from the server starting rather than
		fired immediately, so a restart is not a drop.
	]]
	if (ix.orbital.nextEvent <= 0) then
		ix.orbital.nextEvent = CurTime()
			+ math.max(ix.config.Get("orbitalInterval", 3600), 60)

		return
	end

	if (CurTime() < ix.orbital.nextEvent) then return end

	if (#player.GetAll() < ix.config.Get("orbitalMinPlayers", 30)) then
		--[[
			Not enough people. The clock is NOT reset - so the drop happens as
			soon as the server is busy enough rather than an hour after it
			becomes busy enough.
		]]
		return
	end

	ix.orbital.Start()
end)

--------------------------------------------------------------------------------
-- The container
--------------------------------------------------------------------------------

--[[
	Drop the loot container at a position.

	Called by the craft. Built through `ix.loot.Spawn` with `bNoSave` set, so
	it is a real lootable with a real table and is NOT written into the placed
	list - a container that self destructs in five minutes has no business
	being restored on the next map load.
]]
function ix.orbital.DropContainer(position, angles)
	local name = ix.config.Get("orbitalLootTable", "Orbital")

	if (not ix.loot.Get(name)) then
		ErrorNoHalt(string.format("[falloutrp] orbital loot table '%s' does "
			.. "not exist - the container will be empty. Make it in the loot "
			.. "configurer or set `orbitalLootTable`.\n", tostring(name)))
	end

	local entity = ix.loot.Spawn({
		position = position,
		angles = angles or angle_zero,
		model = ix.orbital.assets.container,
		lootTable = name
	}, true)

	if (not IsValid(entity)) then return end

	--[[
		Dropped rather than placed. A placed lootable is frozen on purpose -
		see `ix_lootable:Initialize` - and this one has just been let go of
		twelve metres up, so it is given its physics back for the fall.
	]]
	entity:PhysicsInit(SOLID_VPHYSICS)
	entity:SetMoveType(MOVETYPE_VPHYSICS)
	entity:SetSolid(SOLID_VPHYSICS)

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(true)
		physics:Wake()
	end

	entity:EmitSound(ix.orbital.assets.opened, 80)

	--[[
		Self destruct. Phoenix's `timer.Simple(300, ...)` with their config
		name - it is what stops a map filling with old containers, and it is
		why the drop is worth going to when it happens rather than whenever.
	]]
	local despawn = math.max(ix.config.Get("orbitalDespawn", 300), 10)

	timer.Simple(despawn, function()
		if (not IsValid(entity)) then return end

		ix.loot.RemovePlaced(entity)

		entity:Remove()
	end)

	ix.log.Add(nil, "orbitalDrop", name, despawn)

	return entity
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("orbitalStart", function(client, where)
	return string.format("%s an orbital drop at %s.",
		client and (client:Name() .. " called") or "The server started",
		where)
end, FLAG_WARNING)

ix.log.AddType("orbitalCancel", function(client)
	return string.format("%s called off the orbital drop.", client:Name())
end, FLAG_WARNING)

ix.log.AddType("orbitalDrop", function(client, lootTable, despawn)
	return string.format("An orbital container landed - table '%s', gone in "
		.. "%d second(s).", lootTable, despawn)
end)
