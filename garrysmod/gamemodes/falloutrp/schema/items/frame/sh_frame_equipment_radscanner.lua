--[[
	Mutation Scanner frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Mutation Scanner Frame"
ITEM.description = "The frame of a Mutation Scanner. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_sml.mdl"

ITEM.width = 1
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "equipment_radscanner"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(218, 188, 108)
