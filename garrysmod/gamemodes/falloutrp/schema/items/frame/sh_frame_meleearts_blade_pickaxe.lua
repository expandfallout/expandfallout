--[[
	Pickaxe frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Pickaxe Frame"
ITEM.description = "The frame of a Pickaxe. Useless on its own."
ITEM.model = "models/mosi/fallout4/props/junk/components/wood.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "meleearts_blade_pickaxe"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(164, 164, 174)
