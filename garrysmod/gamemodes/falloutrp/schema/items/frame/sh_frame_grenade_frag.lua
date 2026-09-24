--[[
	Frag Grenade frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Frag Grenade Frame"
ITEM.description = "The frame of a Frag Grenade. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_lrg.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "grenade_frag"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(172, 112, 62)
