--[[
	C.I.T..

	GENERATED FILE. The roster is `_docs/tools/factions.py`; edit it
	there and run `_docs/tools/genfactions.py`.
]]

FACTION.name = "C.I.T."
FACTION.description = "Once a university. Now a hub of scientific advancement, and less forthcoming about what it advances."
FACTION.color = Color(255, 255, 255)
FACTION.isDefault = false

--[[
	THE ARRAY FORM MATTERS. Phoenix write this as a keyed table:

	    FACTION.models = { ["models/..."] = true }

	and Helix's `ix.faction.LoadFromDir` iterates with `pairs` and
	precaches the VALUE. Fed `true` it silently skips precaching and
	character creation breaks with no error at all.
]]
FACTION.models = {
	"models/phoenix/humans/animations.mdl"
}

--- Which races may join. Anything unlisted is human only.
FACTION.races = {
	"human",
	"citgen1",
	"citgen2"
}

--[[
	The icon, from `phoenix_faction_icons`.

	Their file names do not match our faction ids - the pack has
	`creature`, `outcast` and `gk` where we have `creatures`,
	`outcasts` and `greatkhans` - so the generator maps the ones
	that differ. A faction with nothing suitable in the pack gets
	one of their numbered defaults rather than naming a material
	that does not exist, which draws as a purple checkerboard.
]]
FACTION.icon = "phoenix/faction_icons/institute.png"

FACTION_CIT = FACTION.index
