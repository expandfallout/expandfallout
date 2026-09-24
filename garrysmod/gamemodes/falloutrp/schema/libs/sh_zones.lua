--[[
	Zones: named areas, claimable areas, radiation and out of bounds.

	BUILT ON HELIX'S AREA PLUGIN, NOT BESIDE IT.

	`helix/plugins/area` already stores named axis-aligned boxes, saves them per
	map, syncs them to every client compressed, and gives each one a table of
	typed properties. Writing a second box system would have meant a second
	store, a second sync and a second editor - so a zone here IS an area, and
	all four kinds differ only in their `type` and what reads them.

	    area          a named place; its name appears when you walk in
	    claim         the same, and a faction lead can take it
	    radiation     adds rads for as long as you stand in it
	    outofbounds   kills you after a few seconds

	WHAT IS NOT REUSED IS HELIX'S IDEA OF "THE AREA YOU ARE IN".

	`PLUGIN:AreaThink` picks `overlappingBoxes[1]` - whichever the hash table
	happened to yield first - and remembers exactly one. That is wrong twice
	over for this schema: a radiation zone drawn inside a town would take the
	name banner away from the town half the time, and a player standing in both
	needs both to act on them, not one.

	So membership is worked out from `ix.area.stored` at each end for itself:
	the client picks the smallest displayable box it is inside, and the server
	walks every radiation and out-of-bounds box separately. Neither uses
	`client:GetArea()`. `ix.area.stored` is a complete copy on both realms, so
	this costs nothing extra.
]]

ix.zones = ix.zones or {}

--------------------------------------------------------------------------------
-- The kinds of zone
--------------------------------------------------------------------------------

--[[
	`display` marks the two kinds that put a name on your screen. It is what
	makes a radiation zone inside a town invisible as a *place* while still
	being very much there.
]]
ix.zones.types = {
	{
		id = "area",
		name = "Area",
		description = "A named place. The name shows when you walk in.",
		color = Color(120, 190, 255),
		display = true
	},
	{
		id = "claim",
		name = "Claimable Area",
		description = "A place a faction lead can take with /claimarea.",
		color = Color(255, 200, 100),
		display = true,
		claimable = true
	},
	{
		id = "radiation",
		name = "Radiation Zone",
		description = "Adds rads for as long as somebody stands in it.",
		color = Color(120, 230, 120)
	},
	{
		id = "outofbounds",
		name = "Out of Bounds",
		description = "Kills anybody who stays in it.",
		color = Color(230, 80, 80)
	}
}

ix.zones.byID = {}

for _, zoneType in ipairs(ix.zones.types) do
	ix.zones.byID[zoneType.id] = zoneType
end

--[[
	Told to Helix twice, deliberately.

	At file scope because `helix/plugins` is loaded before the schema - see
	`ix.plugin.Initialize`, which does `LoadFromDir("helix/plugins")` and only
	then `Load("schema", ...)` - so `ix.area` is already there. And again from
	`SetupAreaProperties`, which is the plugin's own extension point and the
	only one that runs on a `lua_refresh`.

	Both are plain table writes, so doing it twice costs a few assignments and
	means neither has to be the one that works.
]]
local function Register()
	if (not ix.area or not ix.area.AddType) then return end

	for _, zoneType in ipairs(ix.zones.types) do
		ix.area.AddType(zoneType.id, zoneType.name)
	end

	--[[
		Properties are per AREA, not per type - that is Helix's model, and the
		editor draws every registered one on every area. `radiation` on a town
		simply stays zero.
	]]
	ix.area.AddProperty("radiation", ix.type.number, 0,
		{min = 0, max = 25, decimals = 0})

	--[[
		How often those rads land.

		Rads-per-second alone could not express "one rad every ten seconds",
		which is what a lightly contaminated area is - the smallest step it
		could take was one per second, and 60 rads a minute is a death sentence
		rather than a hazard. A rate and an interval can say either.
	]]
	ix.area.AddProperty("radInterval", ix.type.number, 1,
		{min = 1, max = 120, decimals = 0})

	ix.area.AddProperty("killTime", ix.type.number, 5,
		{min = 1, max = 120, decimals = 0})

	--- How long a faction has to stand in a claimable area to take it.
	ix.area.AddProperty("captureTime", ix.type.number, 30,
		{min = 1, max = 900, decimals = 0})

	--[[
		Who holds a claimable area. Empty means nobody.

		A STRING, holding either `faction:<uniqueID>` or `character:<id>` - the
		same two-shapes-in-one-field as `ix.bench.CaptureFor`, for the same
		reason: a Wastelander taking a place cannot take it for "everybody who
		has not picked a side".

		One string rather than two properties because Helix networks and
		sanitises properties one at a time, and two fields that must agree is
		two fields that can disagree.
	]]
	ix.area.AddProperty("owner", ix.type.string, "")
end

Register()

hook.Add("SetupAreaProperties", "ixZones", Register)

--------------------------------------------------------------------------------
-- Reading them
--------------------------------------------------------------------------------

function ix.zones.Get(id)
	return ix.area and ix.area.stored and ix.area.stored[id]
end

function ix.zones.TypeOf(area)
	return ix.zones.byID[area and area.type or ""]
end

--- Everything an area carries, with the defaults filled in.
function ix.zones.Properties(area)
	return (area and area.properties) or {}
end

--[[
	How big a box is.

	Used to pick between nested areas: the smallest one you are inside is the
	one you are in. A shop inside a town should say "shop".
]]
function ix.zones.Volume(area)
	if (not area) then return math.huge end

	local size = area.endPosition - area.startPosition

	return math.abs(size.x * size.y * size.z)
end

function ix.zones.Contains(area, position)
	if (not area) then return false end

	return position:WithinAABox(area.startPosition, area.endPosition)
end

--[[
	Every zone containing a position, optionally of one type.

	Returns an array of `{id = , area = }`. An array rather than the first
	match, because overlapping is the normal case here and every caller that
	only wants one has its own idea of which.
]]
function ix.zones.At(position, typeID)
	local out = {}

	if (not ix.area or not ix.area.stored) then return out end

	for id, area in pairs(ix.area.stored) do
		if (typeID and area.type ~= typeID) then continue end

		if (ix.zones.Contains(area, position)) then
			out[#out + 1] = {id = id, area = area}
		end
	end

	return out
end

--- The zone whose name should be on screen, or nil. Smallest wins.
function ix.zones.Displayed(position)
	local best, bestID, bestVolume

	for _, entry in ipairs(ix.zones.At(position)) do
		local zoneType = ix.zones.TypeOf(entry.area)

		if (not zoneType or not zoneType.display) then continue end
		if (entry.area.properties
		and entry.area.properties.display == false) then continue end

		local volume = ix.zones.Volume(entry.area)

		if (not bestVolume or volume < bestVolume) then
			best, bestID, bestVolume = entry.area, entry.id, volume
		end
	end

	return bestID, best
end

--------------------------------------------------------------------------------
-- Who holds one
--------------------------------------------------------------------------------

--[[
	The owner string, unpacked. Returns nil, or a table:

	    {faction = uniqueID, name = ...}
	    {character = id, name = ...}

	The name is looked up rather than stored, so a faction renamed in its own
	file is renamed everywhere it is written on a wall. A character's name is
	the one exception - there is nothing to look it up from once they are
	offline - so that half carries its own.
]]
function ix.zones.Owner(area)
	local owner = ix.zones.Properties(area).owner

	if (not owner or owner == "") then return end

	local kind, value = string.match(owner, "^(%a+):(.+)$")

	if (not kind) then return end

	if (kind == "faction") then
		local faction = ix.faction.teams[value]

		if (not faction) then return end

		return {faction = value, name = faction.name, color = faction.color}
	end

	if (kind == "character") then
		local id, name = string.match(value, "^(%d+)|(.*)$")

		if (not id) then return end

		return {character = tonumber(id), name = name}
	end
end

--[[
	What claiming this would write, for a given character. Nil if they cannot.

	A DEFAULT FACTION HOLDS NOTHING. `isDefault` marks the faction nobody joins
	deliberately - Wastelanders here - and "everybody who has not picked a
	side" is not an organisation that can hold a town: taking one as a
	Wastelander would hand it to every unaffiliated character on the server at
	once, which is the opposite of what claiming it meant.

	An earlier version let them hold it PERSONALLY, mirroring
	`ix.bench.CaptureFor`. That is right for a workbench, which one person can
	stand at and use, and wrong for a town: personal ownership of ground is not
	a thing this schema has, and it would put one name in the faction slot of
	every sign on the map.
]]
function ix.zones.ClaimFor(character)
	if (not character) then return end

	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction or faction.isDefault) then return end

	return "faction:" .. faction.uniqueID
end

--- Does this character hold this area?
function ix.zones.Holds(client, area)
	local owner = ix.zones.Owner(area)
	local character = IsValid(client) and client:GetCharacter()

	if (not owner or not character) then return false end

	if (owner.character) then return character:GetID() == owner.character end

	if (owner.faction) then
		local faction = ix.faction.indices[character:GetFaction()]

		return faction ~= nil and faction.uniqueID == owner.faction
	end

	return false
end

--------------------------------------------------------------------------------
-- How one is written on the screen
--------------------------------------------------------------------------------

--[[
	The name, with the holder appended.

	    Springvale
	    Springvale [Brotherhood of Steel]

	The suffix is built here rather than stored in the id, because the id is
	the key `ix.area.stored` is indexed by - putting the faction in it would
	mean renaming the area every time it changed hands, and every reference to
	it going stale at the same moment.
]]
function ix.zones.DisplayName(id, area)
	local owner = ix.zones.Owner(area)

	if (not owner) then return id end

	return string.format("%s [%s]", id, owner.name)
end

--[[
	The colour it is drawn in: the holder's, or the area's own.

	A claimed place is the faction's colour because that is the fact worth
	reading at a glance - whose ground you just walked onto.
]]
function ix.zones.Color(area)
	local owner = ix.zones.Owner(area)

	if (owner and owner.color) then return owner.color end

	local properties = ix.zones.Properties(area)

	if (properties.color) then return properties.color end

	local zoneType = ix.zones.TypeOf(area)

	return zoneType and zoneType.color or Color(255, 255, 255)
end

--------------------------------------------------------------------------------
-- Who may do what
--------------------------------------------------------------------------------

--[[
	Registered SHARED, like every other permission - the rank editor runs on
	the client and a server-only registration is an invisible tickbox. See
	`sh_sandbox.lua`, which learned that the hard way.
]]
if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("zone.edit", "Create and delete zones", "World")
	ix.admin.RegisterPermission("zone.claim.force",
		"Claim or release an area regardless of faction", "World")
end

--[[
	The rank a faction lead has to be to claim ground.

	Rank 3 is the same bar `ix.factionmgmt.CanKick` uses. Somebody trusted to
	throw people out of the faction is trusted to say where it stands.
]]
ix.zones.claimRank = 3

function ix.zones.CanClaim(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then return false, "You have no character." end

	--[[
		THE FACTION CHECK COMES BEFORE THE ADMIN OVERRIDE.

		`zone.claim.force` lets somebody take ground off whoever holds it; it
		does not turn a Wastelander into a faction. An admin with no faction
		claiming a town would write an owner nobody can be a member of, and
		nothing would ever be able to release it.
	]]
	local faction = ix.faction.indices[character:GetFaction()]

	if (not faction or faction.isDefault) then
		return false, "You have no faction to claim it for."
	end

	if (ix.admin and ix.admin.Can(client, "zone.claim.force")) then
		return true
	end

	if (ix.factionmgmt.GetRank(client) < ix.zones.claimRank) then
		return false, "Only a faction lead can claim ground."
	end

	return true
end

--- How long taking this one takes, in seconds.
function ix.zones.CaptureTime(area)
	return math.max(tonumber(ix.zones.Properties(area).captureTime) or 30, 1)
end
