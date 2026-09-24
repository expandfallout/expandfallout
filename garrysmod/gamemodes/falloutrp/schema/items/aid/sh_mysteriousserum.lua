--[[
	Mysterious Serum.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Mysterious Serum"
ITEM.description = "Nobody will say where it comes from. It works better than anything else."
ITEM.model = "models/mosi/fallout4/props/aid/mysteriousserum.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"
ITEM.aidID = "Serum"
ITEM.heal = 80
ITEM.healTime = 6
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "DR", value = 25, duration = 300},
	{stat = "RADRES", value = 50, duration = 300}
}
