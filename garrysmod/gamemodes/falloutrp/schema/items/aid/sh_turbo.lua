--[[
	Turbo.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Turbo"
ITEM.description = "The world slows down. You do not."
ITEM.model = "models/mosi/fnv/props/health/chems/turbo.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_jet.mp3"
ITEM.aidID = "Turbo"
ITEM.useEffect = "inhale"

ITEM.buffs = {
	{stat = "SPD", value = 60, duration = 20},
	{stat = "AGL", value = 2, duration = 20}
}

ITEM.addictionName = "Turbo"
ITEM.addictionChance = 30
