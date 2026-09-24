--[[
	Turpentine.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Turpentine"
ITEM.description = "Not meant to be drunk. People drink it anyway."
ITEM.model = "models/roadkill/fallout/clutter/aid/healingpowder.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.radiation = 5
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(200, 200, 120)

ITEM.buffs = {
	{stat = "STR", value = 2, duration = 120},
	{stat = "INT", value = -2, duration = 120},
	{stat = "PER", value = -2, duration = 120}
}

ITEM.addictionName = "Turpentine"
ITEM.addictionChance = 35
