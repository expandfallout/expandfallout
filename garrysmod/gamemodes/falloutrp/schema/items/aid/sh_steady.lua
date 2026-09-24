--[[
	Steady.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Steady"
ITEM.description = "Your hands stop shaking entirely."
ITEM.model = "models/mosi/fnv/props/health/chems/steady.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"
ITEM.aidID = "Steady"
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "PER", value = 4, duration = 60}
}

ITEM.addictionName = "Steady"
ITEM.addictionChance = 10
