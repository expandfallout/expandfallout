--[[
	Buffout.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Buffout"
ITEM.description = "Bodybuilder pills from before the war. You can take more of a beating."
ITEM.model = "models/mosi/fnv/props/health/chems/buffout.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Buffout"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "HP", value = 25, duration = 120},
	{stat = "STR", value = 2, duration = 120},
	{stat = "END", value = 2, duration = 120}
}

ITEM.addictionName = "Buffout"
ITEM.addictionChance = 14
