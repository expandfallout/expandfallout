--[[
	Bufftats.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Bufftats"
ITEM.description = "Buffout and Mentats pressed together. Stronger and sharper."
ITEM.model = "models/mosi/fnv/props/health/chems/buffout.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Bufftats"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 140, 220)

ITEM.buffs = {
	{stat = "HP", value = 20, duration = 150},
	{stat = "STR", value = 2, duration = 150},
	{stat = "INT", value = 2, duration = 150}
}

ITEM.addictionName = "Bufftats"
ITEM.addictionChance = 35
