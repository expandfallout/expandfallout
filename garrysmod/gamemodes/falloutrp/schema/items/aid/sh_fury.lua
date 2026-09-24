--[[
	Fury.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Fury"
ITEM.description = "Super mutant chem. Enormous strength and no judgement at all."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Fury"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(150, 40, 40)

ITEM.buffs = {
	{stat = "DMG", value = 40, duration = 90},
	{stat = "STR", value = 4, duration = 90},
	{stat = "INT", value = -3, duration = 90}
}

ITEM.addictionName = "Fury"
ITEM.addictionChance = 55
