--[[
	Rebar Club frame.

	GENERATED FILE. The roster is read from the installed weapons by
	`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.
]]

ITEM.name = "Rebar Club Frame"
ITEM.description = "The frame of a Rebar Club. Useless on its own."
ITEM.model = "models/mosi/fallout4/props/junk/components/wood.mdl"

ITEM.width = 2
ITEM.height = 1

--- Which weapon this builds; read by `ix.blueprint`.
ITEM.weapon = "meleearts_blunt_rebarclub"

--- Shared model, so the BORDER says which kind this is.
ITEM.tint = Color(188, 148, 108)
