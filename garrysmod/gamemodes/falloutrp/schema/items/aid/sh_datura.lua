--[[
	Datura Hide.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Datura Hide"
ITEM.description = "Ground datura root. Numbs everything, including the parts you need."
ITEM.model = "models/roadkill/fallout/clutter/aid/healingpowder.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Datura"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 80, 160)

ITEM.buffs = {
	{stat = "DR", value = 8, duration = 180},
	{stat = "PER", value = -2, duration = 180}
}

ITEM.addictionName = "Datura"
ITEM.addictionChance = 20
