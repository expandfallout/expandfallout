--[[
	MEF - Officer.

	GENERATED FILE. The roster is `_docs/tools/classes.py`; edit
	it there and run `_docs/tools/genclasses.py`.
]]

CLASS.name = "MEF - Officer"
CLASS.description = "Senior enough in the Midwestern Expeditionary Force for an order to carry."
CLASS.faction = FACTION_MEF
CLASS.isDefault = false

--[[
	The rung. 1 enlisted, 2 NCO, 3 officer, 4 lead.

	Phoenix carry this as four booleans set on about half their
	classes; one ordered number says the same thing and can be
	compared, which is what `sh_classrank.lua` needs to gate the
	top of a ladder behind a grant.
]]
CLASS.rank = 3

CLASS_MEF_OFFICER = CLASS.index
