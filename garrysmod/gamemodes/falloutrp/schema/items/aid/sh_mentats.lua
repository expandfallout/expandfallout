--[[
	Mentats.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Mentats"
ITEM.description = "Sharpens the mind. Wears off sharper still."
ITEM.model = "models/mosi/fnv/props/health/chems/mentats.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Mentats"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "INT", value = 2, duration = 180},
	{stat = "PER", value = 2, duration = 180}
}

ITEM.addictionName = "Mentats"
ITEM.addictionChance = 15
