--[[
	The Kings - The King.

	GENERATED FILE. The roster is `_docs/tools/classes.py`; edit
	it there and run `_docs/tools/genclasses.py`.
]]

CLASS.name = "The Kings - The King"
CLASS.description = "There is one King, and he is it."
CLASS.faction = FACTION_KINGS
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

CLASS_KINGS_KING = CLASS.index
