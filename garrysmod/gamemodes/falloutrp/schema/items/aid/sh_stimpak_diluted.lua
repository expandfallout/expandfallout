--[[
	Diluted Stimpak.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Diluted Stimpak"
ITEM.description = "Stretched with clean water. Half as good, twice as many."
ITEM.model = "models/mosi/fnv/props/health/stimpak_clean.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"
ITEM.heal = 20
ITEM.healTime = 4
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(160, 200, 220)
