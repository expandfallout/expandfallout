--[[
	Doors: several factions on one, and doors that are teleports.

	WHY THIS IS A LAYER AND NOT AN EDIT TO HELIX'S DOOR PLUGIN.

	`helix/plugins/doors` saves a fixed list of net vars:

	    local variables = {"disabled", "name", "price", "ownable", "faction",
	        "class", "visible"}

	It is a LOCAL. A `factions` net var added from here would work perfectly
	until the next map change and then be gone, because `SaveDoorData` only
	writes what is in that table and nothing outside the plugin can add to it.

	So the extra rules are kept here, keyed by `MapCreationID`, saved with
	`ix.data` per map, and applied through `CanPlayerAccessDoor` - the hook the
	plugin already asks. Helix's single-faction door still works exactly as it
	did; this only ever grants access on top.

	    ix.doors.factions[mapID]  = {"bos", "ncr"}
	    ix.doors.links[mapID]     = {position = , angles = , name = }

	A TELEPORT IS A DOOR WITH A DESTINATION, NOT A NEW ENTITY. That is what
	makes "lock the teleport with keys like a door" free: the lock is the
	door's own lock, `ix_keys` is Helix's own keys, and who may turn it is the
	faction list below - which is the same list that says who may walk through.

	`MapCreationID` IS THE KEY because it is the only id a map entity keeps
	across a restart. An entity index is assigned at spawn and a position is a
	float; both would silently attach a teleport to the wrong door one day.
]]

ix.doors = ix.doors or {}

--- `[mapID] = {factionUniqueID, ...}`. Synced whole; there are never many.
ix.doors.factions = ix.doors.factions or {}

--- `[mapID] = {position = Vector, angles = Angle, name = string}`.
ix.doors.links = ix.doors.links or {}

--[[
	Teleports on things the map did not make.

	    ix.doors.propLinks[n] = {model, origin, position, angles, name,
	                             factions}

	A SPAWNED PROP HAS NO `MapCreationID`, so it cannot be keyed the way a map
	door is - the id it would have is -1 for every prop on the server. It is
	keyed by a number of our own instead, and the record remembers WHERE THE
	PROP WAS and WHAT MODEL IT WAS, which is how it finds it again after a
	restart.

	THAT IS ALSO THE PERSISTENCE RULE, and it falls out for free: a prop that
	was made permanent comes back at exactly its saved position, so the link
	finds it. One that was not is simply not there any more, and the link is
	dropped on load - "the tp is deleted on server start up like items on the
	floor", which is what was asked for and what an impermanent thing should
	do.
]]
ix.doors.propLinks = ix.doors.propLinks or {}

--- How close a prop has to be to its saved position to be the same prop.
ix.doors.propTolerance = 8

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

--[[
	The key for an entity, or nil.

	`MapCreationID` answers -1 for anything spawned at runtime, which is every
	prop and every scripted entity - so this is also the test for "is this a
	thing the map shipped with", and nothing else needs to ask.
]]
function ix.doors.MapID(entity)
	if (not IsValid(entity)) then return end

	local id = entity:MapCreationID()

	if (not id or id < 0) then return end

	return id
end

--[[
	The faction uniqueIDs allowed on a door, as they are stored.

	A prop teleport keeps its own list INSIDE its link record rather than in
	`ix.doors.factions`, because that table is keyed by `MapCreationID` and a
	prop has none. One lookup either way, and the two never collide.
]]
function ix.doors.FactionIDs(entity)
	local prop = ix.doors.PropLink(entity)

	if (prop) then return prop.factions or {} end

	local id = ix.doors.MapID(entity)

	return (id and ix.doors.factions[id]) or {}
end

--- The same, as faction tables, skipping any that no longer exist.
function ix.doors.Factions(entity)
	local out = {}

	for _, uniqueID in ipairs(ix.doors.FactionIDs(entity)) do
		local faction = ix.faction.teams[uniqueID]

		if (faction) then out[#out + 1] = faction end
	end

	return out
end

--- The prop teleport hung on an entity, if it has one.
function ix.doors.PropLink(entity)
	if (not IsValid(entity)) then return end

	local id = entity.ixTeleportLink

	return id and ix.doors.propLinks[id]
end

--[[
	Find the prop each saved link belongs to, and tag it.

	Run on both realms - the server needs it to teleport people, the client
	needs it to draw the sign and the line - and run repeatedly, because a
	permanent prop is restored some time after the map loads and a client
	receives it some time after that. Tagging an entity twice costs one
	assignment.

	MATCHED ON MODEL AND POSITION, in that order. Position alone would attach a
	teleport to whatever else happened to be standing there; the model is what
	makes "the same prop" mean something.
]]
function ix.doors.AttachPropLinks()
	local tolerance = ix.doors.propTolerance * ix.doors.propTolerance
	local found = {}

	for id, link in pairs(ix.doors.propLinks) do
		if (not isvector(link.origin)) then
			link.origin = Vector(link.origin)
		end

		for _, entity in ipairs(ents.FindInSphere(link.origin,
		ix.doors.propTolerance)) do
			if (not IsValid(entity)) then continue end
			if (entity:GetModel() ~= link.model) then continue end
			if (entity:GetPos():DistToSqr(link.origin) > tolerance) then
				continue
			end

			entity.ixTeleportLink = id
			found[id] = entity

			break
		end
	end

	return found
end

function ix.doors.Link(entity)
	local prop = ix.doors.PropLink(entity)

	if (prop) then return prop end

	local id = ix.doors.MapID(entity)

	return id and ix.doors.links[id]
end

--[[
	May this character use this door - walk through it, and lock it?

	ONE ANSWER FOR BOTH. A teleport somebody may use but not lock is a teleport
	the other side props open, and a lock somebody may turn on a door they
	cannot use is a way to shut a faction out of its own building. Helix asks
	the same question for both through `CanPlayerAccessDoor`, and this agrees
	with it.

	An EMPTY list is "no extra rule", not "nobody" - the door falls back to
	whatever Helix already decided.
]]
function ix.doors.Allowed(client, entity)
	if (not IsValid(client)) then return false end

	local character = client:GetCharacter()

	if (not character) then return false end

	--[[
		A BOUGHT TELEPORT BELONGS TO THE PERSON WHO BOUGHT IT.

		Checked before the faction list and answering for both: whoever owns it
		is allowed, and the list still adds whoever else was named. An owned
		door that also names a faction is a faction's door with a keyholder,
		which is a reasonable thing to want and costs nothing to support.
	]]
	if (ix.doors.Owns(client, entity)) then return true end

	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction) then return false end

	for _, uniqueID in ipairs(ix.doors.FactionIDs(entity)) do
		if (uniqueID == faction.uniqueID) then return true end
	end

	return false
end

--[[
	Is this door locked right now?

	`m_bLocked` is the engine's own field on a `prop_door_rotating` or a
	`func_door`, read through `GetInternalVariable` because there is no
	accessor for it and Helix does not keep a copy. Reading the engine's answer
	means a door locked by `ix_keys`, by the map, or by an admin all count -
	one source of truth rather than a second flag that can disagree with the
	door people can see is shut.
]]
function ix.doors.Locked(entity)
	if (not IsValid(entity)) then return false end

	--[[
		A PROP HAS NO ENGINE LOCK, so a teleport on one keeps its own flag.

		`ix_keys` only works on `IsDoor()` entities and `m_bLocked` only exists
		on the door classes, so there is nothing to read on a crate - the flag
		in the link record is the whole state, and it is set through
		`ix.doors.SetLocked` from the wrapped keys and from `/tplock`.
	]]
	local prop = ix.doors.PropLink(entity)

	if (prop) then return prop.locked == true end

	return entity:GetInternalVariable("m_bLocked") == true
end

--------------------------------------------------------------------------------
-- Two-way pairs
--------------------------------------------------------------------------------

--[[
	A key that survives a restart, for either kind of thing.

	    map:412    a door the map made, by `MapCreationID`
	    prop:3     a teleport on a prop, by its link id

	One string rather than two fields, for the reason the zone owner is one
	string: two fields that have to agree are two fields that can disagree.
]]
function ix.doors.KeyOf(entity)
	local prop = ix.doors.PropLink(entity)

	if (prop) then return "prop:" .. tostring(prop.id) end

	local id = ix.doors.MapID(entity)

	return id and ("map:" .. id)
end

--- The entity a key names, if it is here.
function ix.doors.FromKey(key)
	if (not key) then return end

	local kind, id = string.match(tostring(key), "^(%a+):(%d+)$")

	if (not kind) then return end

	id = tonumber(id)

	if (kind == "map") then return ents.GetMapCreatedEntity(id) end

	local link = ix.doors.propLinks[id]

	if (not link) then return end

	--[[
		Found by walking the tagged entities rather than kept as a reference:
		the tag is rebuilt every few seconds by `AttachPropLinks` and a stored
		entity would go stale the moment the prop was removed and restored.
	]]
	for _, entity in ipairs(ents.FindInSphere(link.origin,
	ix.doors.propTolerance)) do
		if (IsValid(entity) and entity.ixTeleportLink == id) then
			return entity
		end
	end
end

--- The far end of a two-way teleport, or nil for a one-way one.
function ix.doors.Partner(entity)
	local link = ix.doors.Link(entity)

	return link and link.pair and ix.doors.FromKey(link.pair)
end

--[[
	A faction from whatever somebody typed.

	`ix.faction.Get` is index-or-uniqueID only:

	    return ix.faction.indices[identifier] or ix.faction.teams[identifier]

	so it answers nil for "Brotherhood of Steel", which is the only name a
	player has ever seen. This tries the uniqueID first - exact, and what the
	tool panel prints - then the display name, then a unique prefix of it.

	A PREFIX THAT MATCHES TWO FACTIONS IS NO MATCH. Guessing between them would
	one day put the wrong faction on somebody's front door, and the fix for an
	ambiguous prefix is to type more of it.
]]
function ix.doors.FindFaction(text)
	text = string.lower(string.Trim(tostring(text or "")))

	if (text == "") then return end
	if (ix.faction.teams[text]) then return ix.faction.teams[text] end

	local partial, count

	for _, faction in pairs(ix.faction.teams) do
		local name = string.lower(faction.name or "")

		if (name == text) then return faction end

		if (string.find(name, text, 1, true)) then
			partial = faction
			count = (count or 0) + 1
		end
	end

	if (count == 1) then return partial end
end

--[[
	What counts as a world teleport.

	`trigger_teleport` is the one everybody means. The others are here because
	a map that wants you somewhere else uses whichever of them the mapper
	reached for, and a tool that only removed one kind would look broken on
	half the maps.

	`trigger_changelevel` is INCLUDED and matters most: on a persistent server
	it is the entity that throws everybody at a map that does not exist.
]]
ix.doors.worldClasses = {
	trigger_teleport = true,
	point_teleport = true,
	trigger_changelevel = true,
	trigger_teleport_relative = true
}

--------------------------------------------------------------------------------
-- Owning one
--------------------------------------------------------------------------------

--[[
	Who bought this teleport, if anybody.

	The SAME OWNER STRING the zones and the capture points use, read by
	`ix.zones.Owner` - `character:<id>|<name>` here, because a door is bought
	by a person rather than taken by a faction. One format for "who holds this"
	across the schema means one parser and one set of edge cases.
]]
--[[
	What colour a teleport's name is written in.

	Stored on the link as three plain numbers rather than a `Color`, because
	the links go to the client as JSON - `ix.data` and `ixDoorSync` both - and
	a colour comes back from that as a table with no metatable, which every
	drawing function in the game refuses.

	Nothing set falls back to the pair this sign has always used: red when it
	is locked, pale blue when it is not. A colour that IS set wins in both
	cases - the word LOCKED is on the line underneath either way, so the state
	is not being hidden by somebody choosing red for their own door.
]]
function ix.doors.Colour(entity)
	local link = ix.doors.Link(entity)
	local colour = link and link.colour

	if (istable(colour) and colour[1]) then
		return Color(tonumber(colour[1]) or 255, tonumber(colour[2]) or 255,
			tonumber(colour[3]) or 255)
	end

	if (ix.doors.Locked(entity)) then return Color(235, 90, 80) end

	return Color(150, 220, 255)
end

function ix.doors.Owner(entity)
	local link = ix.doors.Link(entity)

	if (not link or not link.owner or link.owner == "") then return end

	return ix.zones.Owner({properties = {owner = link.owner}})
end

--- What it costs, or 0 for one that is not for sale.
function ix.doors.Price(entity)
	local link = ix.doors.Link(entity)

	return math.max(tonumber(link and link.price) or 0, 0)
end

--- Does this character own it?
function ix.doors.Owns(client, entity)
	local owner = ix.doors.Owner(entity)
	local character = IsValid(client) and client:GetCharacter()

	if (not owner or not character or not owner.character) then return false end

	return character:GetID() == owner.character
end

--------------------------------------------------------------------------------
-- Timing
--------------------------------------------------------------------------------

--[[
	How long turning a lock takes.

	NOT INSTANT, and the reason is the same one Helix has for `doorLockTime`:
	somebody standing over a lock for three seconds can be interrupted, and a
	lock that closes the instant it is clicked is one nobody can be caught
	doing. Helix's own default is one second, which is not long enough to
	matter; the schema raises both to three so keys and `/tplock` agree.
]]
ix.config.Add("teleportLockTime", 3,
	"Seconds spent turning the lock on a teleport.", nil, {
	data = {min = 0, max = 30},
	category = "Doors"
})

--[[
	Helix's own door timing, raised to match.

	`ix.config.Add` keeps whatever an admin has set - it only replaces the
	DEFAULT - so this changes the number on a server that has never touched it
	and leaves a deliberate choice alone. Written as a re-Add rather than a
	poke at `ix.config.stored`, because that is the supported way to say it and
	it keeps the description and the slider bounds correct.
]]
if (ix.config.stored and ix.config.stored.doorLockTime) then
	ix.config.Add("doorLockTime", 3,
		"How long it takes to (un)lock a door.", nil, {
		data = {min = 0, max = 10.0, decimals = 1},
		category = "dConfigName"
	})
end

--------------------------------------------------------------------------------
-- Permissions
--------------------------------------------------------------------------------

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("door.edit",
		"Set door factions and make teleport doors", "World")
	ix.admin.RegisterPermission("door.worldtp",
		"Permanently delete the map's own teleports", "World")
end
