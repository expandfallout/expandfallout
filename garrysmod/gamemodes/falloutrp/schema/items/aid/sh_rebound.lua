--[[
	Rebound.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Rebound"
ITEM.description = "A stimulant that puts the spring back in your legs."
ITEM.model = "models/mosi/fnv/props/health/chems/rebound.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Rebound"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "AGL", value = 2, duration = 120},
	{stat = "SPD", value = 10, duration = 120}
}

ITEM.addictionName = "Rebound"
ITEM.addictionChance = 15
