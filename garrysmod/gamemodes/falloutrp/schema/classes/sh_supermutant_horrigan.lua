--[[
	Frank Horrigan.

	GENERATED FILE. The roster is `_docs/tools/classes.py`; edit
	it there and run `_docs/tools/genclasses.py`.
]]

CLASS.name = "Frank Horrigan"
CLASS.description = "The Enclave's finest work, and the last thing a great many people saw."
CLASS.faction = FACTION_SUPERMUTANT
CLASS.isDefault = false

--[[
	The rung. 1 enlisted, 2 NCO, 3 officer, 4 lead.

	Phoenix carry this as four booleans set on about half their
	classes; one ordered number says the same thing and can be
	compared, which is what `sh_classrank.lua` needs to gate the
	top of a ladder behind a grant.
]]
CLASS.rank = 4

--- One at a time. There is only one of these in the world.
CLASS.limit = 1

--[[
	Race-locked. This is not a rank somebody is promoted into,
	it is a different creature, so a character of any other
	race is refused by `sh_classrank.lua`.
]]
CLASS.races = {
	"frankhorrigan"
}

CLASS_SUPERMUTANT_HORRIGAN = CLASS.index
