--[[
	Flare Gun frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Flare Gun Frame"
ITEM.description = "The frame of a Flare Gun. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_sml.mdl"

ITEM.width = 1
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "flare_gun"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(236, 206, 126)
