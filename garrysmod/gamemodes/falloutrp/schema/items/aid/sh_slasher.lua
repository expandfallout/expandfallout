--[[
	Slasher.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Slasher"
ITEM.description = "Psycho cut with Med-X. Hits harder and hurts less."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Psycho"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(200, 60, 60)

ITEM.buffs = {
	{stat = "DMG", value = 15, duration = 150},
	{stat = "DR", value = 10, duration = 150}
}

ITEM.addictionName = "Psycho"
ITEM.addictionChance = 40
