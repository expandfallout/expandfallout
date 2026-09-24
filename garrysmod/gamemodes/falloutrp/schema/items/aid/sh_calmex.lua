--[[
	Calmex.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Calmex"
ITEM.description = "A sedative from the Sierra Madre. Steady hands, soft footsteps."
ITEM.model = "models/mosi/fnv/props/health/chems/mentats.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Calmex"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(80, 190, 190)

ITEM.buffs = {
	{stat = "PER", value = 3, duration = 180},
	{stat = "DMG", value = 10, duration = 180}
}

ITEM.addictionName = "Calmex"
ITEM.addictionChance = 20
