--[[
	Berserk.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Berserk"
ITEM.description = "Raider chem. You will not feel a thing, and you will not stop."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Berserk"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(90, 30, 30)

ITEM.buffs = {
	{stat = "DMG", value = 35, duration = 60},
	{stat = "DR", value = -10, duration = 60},
	{stat = "STR", value = 3, duration = 60}
}

ITEM.addictionName = "Berserk"
ITEM.addictionChance = 50
