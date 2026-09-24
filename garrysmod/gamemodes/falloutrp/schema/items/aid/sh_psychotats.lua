--[[
	Psychotats.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Psychotats"
ITEM.description = "Psycho and Mentats. Sharp, and looking for a fight."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Psychotats"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(180, 80, 200)

ITEM.buffs = {
	{stat = "DMG", value = 20, duration = 150},
	{stat = "PER", value = 3, duration = 150}
}

ITEM.addictionName = "Psychotats"
ITEM.addictionChance = 40
