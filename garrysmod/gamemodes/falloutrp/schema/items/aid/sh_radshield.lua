--[[
	Rad Shield.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Rad Shield"
ITEM.description = "A stronger Rad-X. Brotherhood chemists, mostly."
ITEM.model = "models/roadkill/fallout/clutter/aid/radx.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "RadX"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(120, 220, 140)

ITEM.buffs = {
	{stat = "RADRES", value = 60, duration = 240}
}
