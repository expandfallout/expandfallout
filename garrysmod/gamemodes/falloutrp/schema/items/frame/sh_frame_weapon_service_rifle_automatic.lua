--[[
	MK2 Auto Service frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "MK2 Auto Service Frame"
ITEM.description = "The frame of a MK2 Auto Service. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_lrg.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "weapon_service_rifle_automatic"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(186, 196, 226)
