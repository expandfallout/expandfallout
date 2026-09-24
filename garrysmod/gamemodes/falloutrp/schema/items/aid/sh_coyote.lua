--[[
	Coyote Tobacco Chew.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Coyote Tobacco Chew"
ITEM.description = "A tribal chew. Steadies you and dulls the edges."
ITEM.model = "models/roadkill/fallout/clutter/aid/healingpowder.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "Coyote"
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(150, 110, 60)

ITEM.buffs = {
	{stat = "PER", value = 2, duration = 240},
	{stat = "INT", value = -1, duration = 240}
}

ITEM.addictionName = "Coyote"
ITEM.addictionChance = 15
