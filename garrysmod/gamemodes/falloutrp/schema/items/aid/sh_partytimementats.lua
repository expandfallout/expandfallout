--[[
	Party Time Mentats.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Party Time Mentats"
ITEM.description = "The whole tin. You are the most charming person in the room."
ITEM.model = "models/mosi/fnv/props/health/chems/mentats.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Mentats"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(235, 90, 160)

ITEM.buffs = {
	{stat = "CHR", value = 6, duration = 180},
	{stat = "INT", value = -1, duration = 180}
}

ITEM.addictionName = "Mentats"
ITEM.addictionChance = 25
