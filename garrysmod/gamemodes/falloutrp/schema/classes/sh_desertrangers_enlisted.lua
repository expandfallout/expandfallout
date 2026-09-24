--[[
	Desert Rangers - Enlisted.

	GENERATED FILE. The roster is `_docs/tools/classes.py`; edit
	it there and run `_docs/tools/genclasses.py`.
]]

CLASS.name = "Desert Rangers - Enlisted"
CLASS.description = "The rank and file of the Desert Rangers."
CLASS.faction = FACTION_DESERTRANGERS
CLASS.isDefault = true

--[[
	The rung. 1 enlisted, 2 NCO, 3 officer, 4 lead.

	Phoenix carry this as four booleans set on about half their
	classes; one ordered number says the same thing and can be
	compared, which is what `sh_classrank.lua` needs to gate the
	top of a ladder behind a grant.
]]
CLASS.rank = 1

CLASS_DESERTRANGERS_ENLISTED = CLASS.index
