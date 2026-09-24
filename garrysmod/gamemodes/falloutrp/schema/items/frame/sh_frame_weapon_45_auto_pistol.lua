--[[
	.45 Auto Pistol frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = ".45 Auto Pistol Frame"
ITEM.description = "The frame of a .45 Auto Pistol. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_sml.mdl"

ITEM.width = 1
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "weapon_45_auto_pistol"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(218, 188, 108)
