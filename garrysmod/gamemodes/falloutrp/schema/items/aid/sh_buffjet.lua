--[[
	Buffjet.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Buffjet"
ITEM.description = "Buffout cut into a Jet inhaler. Tougher and quicker."
ITEM.model = "models/mosi/fnv/props/health/chems/jet.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_jet.mp3"
ITEM.aidID = "Buffjet"
ITEM.useEffect = "inhale"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 200, 120)

ITEM.buffs = {
	{stat = "HP", value = 20, duration = 90},
	{stat = "SPD", value = 25, duration = 90}
}

ITEM.addictionName = "Buffjet"
ITEM.addictionChance = 40
