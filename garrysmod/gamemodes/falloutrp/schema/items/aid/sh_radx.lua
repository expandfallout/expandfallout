--[[
	Rad-X.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Rad-X"
ITEM.description = "Take it before you go in, not after."
ITEM.model = "models/roadkill/fallout/clutter/aid/radx.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "RadX"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "RADRES", value = 25, duration = 300}
}
