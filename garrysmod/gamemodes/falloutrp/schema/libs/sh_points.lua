--[[
	Points: the things a map-maker places one of at a time.

	    capstash     a cache of caps that refills on a timer
	    captureflag  ground a faction takes by standing on it
	    orbital      a marked landing site, for a system that does not exist yet
	    stash        a box that opens the storage belonging to whoever pressed E

	A POINT IS AN ENTITY, A ZONE IS A VOLUME. That is the whole of the split,
	and it is why these are not `sh_zones.lua` types: an area is a box you are
	inside and has no surface, while these are objects you walk up to, look at
	and press E on. Trying to make one mechanism do both would mean a box that
	sometimes has a model.

	THE RECORD IS AUTHORITATIVE, NOT THE ENTITY - the same rule
	`sv_permaprop.lua` states and for the same reason. A map cleanup removes
	every entity on the map; if the list were rebuilt by walking entities, the
	next save would write an empty one and every cap stash on the server would
	be gone for good.

	THE ORBITAL SITE DOES NOTHING ON PURPOSE. It is a marker with a name and a
	position, placed now so the map work can happen before the drop system
	exists. It is listed, saved and drawn, and that is all it claims to do.
]]

ix.points = ix.points or {}

--[[
	Models are the ones this server actually has - checked with
	`_docs/tools/resolve_asset.py` rather than guessed, because a missing model
	is an error-textured box that still spawns, still saves and still works,
	which is a fault nobody notices until a screenshot.
]]
ix.points.types = {
	{
		id = "capstash",
		name = "Cap Stash",
		class = "ix_capstash",
		description = "A cache of caps. Vanishes when looted, back on a timer.",
		model = "models/mosi/fallout4/props/junk/bottlecaptin.mdl",
		color = Color(255, 210, 120),
		defaults = {caps = 250, respawn = 900}
	},
	{
		id = "captureflag",
		name = "Capture Point",
		class = "ix_captureflag",
		description = "Ground a faction takes by standing on it.",
		model = "models/mosi/fnv/props/factions/flagpole_small.mdl",
		color = Color(140, 200, 255),
		defaults = {captureTime = 45, radius = 160}
	},
	{
		id = "plant",
		name = "Plant",
		class = "ix_plant",
		description = "Wasteland flora. Press E for the fruit and some XP.",

		--[[
			The default only. Every plant record carries its own model, taken
			from the KIND chosen on the tool - see `ix_plant:OnRestored`.
		]]
		model = "models/roadkill/fallout/clutter/plants/xanderroot.mdl",
		color = Color(150, 220, 150),
		defaults = {plant = "xanderroot", respawn = 300, yield = 1,
			xp = -1, collisions = false}
	},
	{
		--[[
			A stash box. Everything about what it holds is on the CHARACTER who
			opens it - see `sh_stash.lua` - so the record here is a position and
			nothing else, and removing the box takes nobody's things with it.
		]]
		id = "stash",
		name = "Stash",
		class = "ix_stash",
		description = "Personal storage. Everybody who opens it gets their own.",
		model = "models/galang/fallout/furniture/stashboxcontainer.mdl",
		color = Color(150, 220, 200),
		defaults = {}
	},
	{
		id = "orbital",
		name = "Orbital Drop Site",
		class = "ix_orbitalpad",
		description = "A named landing site. Nothing lands on it yet.",
		model = "models/roadkill/fallout/clutter/junk/marker_radiation.mdl",
		color = Color(200, 160, 255),
		defaults = {}
	}
}

ix.points.byID = {}
ix.points.byClass = {}

for _, pointType in ipairs(ix.points.types) do
	ix.points.byID[pointType.id] = pointType
	ix.points.byClass[pointType.class] = pointType
end

function ix.points.TypeOf(entity)
	if (not IsValid(entity)) then return end

	return ix.points.byClass[entity:GetClass()]
end

--[[
	Caps, written the way this schema writes them everywhere else.

	`1000c`, not "1000 caps" and not "$1000". One function so the day somebody
	decides it should be "1,000c" it is one edit.
]]
function ix.points.FormatCaps(amount)
	return string.format("%dc", math.floor(tonumber(amount) or 0))
end

--------------------------------------------------------------------------------
-- Who may place them
--------------------------------------------------------------------------------

--[[
	Registered SHARED. A permission the client does not know about is a tickbox
	missing from the rank editor - see `sh_sandbox.lua`.
]]
if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("point.edit",
		"Place and remove cap stashes, capture points and drop sites", "World")
end
