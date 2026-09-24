--[[
	Addictol.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Addictol"
ITEM.description = "An inhaler that does in one breath what Fixer does in an hour."
ITEM.model = "models/mosi/fnv/props/health/chems/fixer.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.cures = true
ITEM.useEffect = "inhale"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(90, 200, 230)
