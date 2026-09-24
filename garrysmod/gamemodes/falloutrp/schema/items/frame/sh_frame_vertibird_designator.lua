--[[
	Vertibird Designator frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Vertibird Designator Frame"
ITEM.description = "The frame of a Vertibird Designator. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_med.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "vertibird_designator"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(196, 196, 196)
