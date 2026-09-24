--[[
	Railroad - Escaped Gen 2.

	GENERATED FILE. The roster is `_docs/tools/classes.py`; edit
	it there and run `_docs/tools/genclasses.py`.
]]

CLASS.name = "Railroad - Escaped Gen 2"
CLASS.description = "A Gen 2 that got out, and is trying to stay out."
CLASS.faction = FACTION_RAILROAD
CLASS.isDefault = false

--[[
	The rung. 1 enlisted, 2 NCO, 3 officer, 4 lead.

	Phoenix carry this as four booleans set on about half their
	classes; one ordered number says the same thing and can be
	compared, which is what `sh_classrank.lua` needs to gate the
	top of a ladder behind a grant.
]]
CLASS.rank = 1

--[[
	Race-locked. This is not a rank somebody is promoted into,
	it is a different creature, so a character of any other
	race is refused by `sh_classrank.lua`.
]]
CLASS.races = {
	"citgen2"
}

CLASS_RAILROAD_SYNTH_GEN2 = CLASS.index
