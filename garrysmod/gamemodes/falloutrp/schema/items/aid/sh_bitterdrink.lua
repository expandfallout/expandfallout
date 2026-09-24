--[[
	Bitter Drink.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Bitter Drink"
ITEM.description = "A tribal brew, bitter enough that you know it is doing something."
ITEM.model = "models/roadkill/fallout/clutter/aid/healingpowder.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.heal = 55
ITEM.healTime = 6
ITEM.useEffect = "swallow"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 90, 50)

ITEM.buffs = {
	{stat = "PER", value = -2, duration = 120}
}
