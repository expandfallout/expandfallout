--[[
	Rad-X (Brotherhood).

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Rad-X (Brotherhood)"
ITEM.description = "Brotherhood issue. The same compound, twice the dose."
ITEM.model = "models/mosi/fallout4/props/aid/radxbos.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "RadX"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "RADRES", value = 45, duration = 300}
}
