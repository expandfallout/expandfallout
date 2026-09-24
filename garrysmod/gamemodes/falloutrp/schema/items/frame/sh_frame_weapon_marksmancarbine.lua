--[[
	Marksman Carbine frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Marksman Carbine Frame"
ITEM.description = "The frame of a Marksman Carbine. Useless on its own."
ITEM.model = "models/roadkill/fallout/clutter/junk/modkit_lrg.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "weapon_marksmancarbine"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(132, 142, 172)
