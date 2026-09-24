--[[
	Grape Mentats.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Grape Mentats"
ITEM.description = "Grape flavoured. You have never been so persuasive."
ITEM.model = "models/mosi/fnv/props/health/chems/mentats.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Mentats"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(90, 70, 200)

ITEM.buffs = {
	{stat = "CHR", value = 4, duration = 180}
}

ITEM.addictionName = "Mentats"
ITEM.addictionChance = 15
