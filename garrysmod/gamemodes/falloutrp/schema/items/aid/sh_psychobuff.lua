--[[
	Psychobuff.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Psychobuff"
ITEM.description = "Psycho and Buffout. Everything hurts less and hits harder."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Psychobuff"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(200, 130, 60)

ITEM.buffs = {
	{stat = "DMG", value = 20, duration = 150},
	{stat = "HP", value = 20, duration = 150},
	{stat = "STR", value = 2, duration = 150}
}

ITEM.addictionName = "Psychobuff"
ITEM.addictionChance = 45
