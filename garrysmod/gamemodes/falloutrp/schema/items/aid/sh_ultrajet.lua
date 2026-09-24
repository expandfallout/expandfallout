--[[
	Ultrajet.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Ultrajet"
ITEM.description = "Jet, refined. Faster, longer, and it wants more of you."
ITEM.model = "models/mosi/fnv/props/health/chems/jet.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_jet.mp3"
ITEM.aidID = "Jet"
ITEM.useEffect = "inhale"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 190, 235)

ITEM.buffs = {
	{stat = "SPD", value = 45, duration = 90}
}

ITEM.addictionName = "Jet"
ITEM.addictionChance = 35
