--[[
	Cleaver frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Cleaver Frame"
ITEM.description = "The frame of a Cleaver. Useless on its own."
ITEM.model = "models/mosi/fallout4/props/junk/components/wood.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "meleearts_blade_cleaver"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(236, 236, 246)
