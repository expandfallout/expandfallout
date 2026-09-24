--[[
	Jet.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Jet"
ITEM.description = "A brahmin-dung inhaler out of Redding. Everything gets faster."
ITEM.model = "models/mosi/fnv/props/health/chems/jet.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_jet.mp3"
ITEM.aidID = "Jet"
ITEM.useEffect = "inhale"

ITEM.buffs = {
	{stat = "SPD", value = 30, duration = 60}
}

ITEM.addictionName = "Jet"
ITEM.addictionChance = 25
