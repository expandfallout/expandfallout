--[[
	Diluted RadAway.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Diluted RadAway"
ITEM.description = "Cut with water. Gentler, and it takes less out."
ITEM.model = "models/roadkill/fallout/clutter/aid/radaway.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radaway.mp3"
ITEM.radiation = -25
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(160, 200, 220)

ITEM.addictionName = "RadAway"
ITEM.addictionChance = 5
