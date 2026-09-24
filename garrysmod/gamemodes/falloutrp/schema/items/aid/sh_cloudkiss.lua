--[[
	Cloud Kiss.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Cloud Kiss"
ITEM.description = "Distilled from the Cloud. It should not be breathable and it is."
ITEM.model = "models/mosi/fnv/props/health/cloudkiss.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "CloudKiss"
ITEM.radiation = 10
ITEM.useEffect = "inhale"

ITEM.buffs = {
	{stat = "PER", value = 3, duration = 150},
	{stat = "END", value = 2, duration = 150}
}

ITEM.addictionName = "CloudKiss"
ITEM.addictionChance = 35
