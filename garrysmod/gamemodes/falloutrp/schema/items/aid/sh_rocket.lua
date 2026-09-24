--[[
	Rocket.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Rocket"
ITEM.description = "Nuka-Cola and Jet. Crude, and it moves."
ITEM.model = "models/mosi/fnv/props/health/chems/jet.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_jet.mp3"
ITEM.aidID = "Jet"
ITEM.useEffect = "inhale"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(200, 60, 90)

ITEM.buffs = {
	{stat = "SPD", value = 40, duration = 60},
	{stat = "AGL", value = 1, duration = 60}
}

ITEM.addictionName = "Jet"
ITEM.addictionChance = 30
