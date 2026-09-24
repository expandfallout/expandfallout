--[[
	Boulder Dome.

	GENERATED FILE. The roster is `_docs/tools/factions.py`; edit it
	there and run `_docs/tools/genfactions.py`.
]]

FACTION.name = "Boulder Dome"
FACTION.description = "Scientists shut in beneath Boulder, and what the New Plague made of them."
FACTION.color = Color(100, 0, 255)
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

--[[
	The icon, from `phoenix_faction_icons`.

	Their file names do not match our faction ids - the pack has
	`creature`, `outcast` and `gk` where we have `creatures`,
	`outcasts` and `greatkhans` - so the generator maps the ones
	that differ. A faction with nothing suitable in the pack gets
	one of their numbered defaults rather than naming a material
	that does not exist, which draws as a purple checkerboard.
]]
FACTION.icon = "phoenix/faction_icons/boulderdome.png"

FACTION_BOULDERDOME = FACTION.index
