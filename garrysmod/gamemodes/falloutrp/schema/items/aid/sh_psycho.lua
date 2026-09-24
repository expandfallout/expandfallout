--[[
	Psycho.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Psycho"
ITEM.description = "Military issue, discontinued for obvious reasons. You hit much harder."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Psycho"
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "DMG", value = 25, duration = 120},
	{stat = "STR", value = 2, duration = 120}
}

ITEM.addictionName = "Psycho"
ITEM.addictionChance = 30
