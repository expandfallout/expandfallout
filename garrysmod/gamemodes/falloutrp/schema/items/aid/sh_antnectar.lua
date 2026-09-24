--[[
	Ant Nectar.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Ant Nectar"
ITEM.description = "Thick and sweet, straight from the nest. Enormously strong for a while."
ITEM.model = "models/mosi/fnv/props/health/chems/jet.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "AntNectar"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(220, 170, 50)

ITEM.buffs = {
	{stat = "STR", value = 4, duration = 120},
	{stat = "PER", value = -2, duration = 120}
}

ITEM.addictionName = "AntNectar"
ITEM.addictionChance = 30
