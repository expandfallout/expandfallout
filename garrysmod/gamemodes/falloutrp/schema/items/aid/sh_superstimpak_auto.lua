--[[
	Auto-Inject Super Stimpak.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Auto-Inject Super Stimpak"
ITEM.description = "A super stimpak that fires itself. Goes through most things."
ITEM.model = "models/mosi/fnv/props/health/superstimpak_auto.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"
ITEM.heal = 100
ITEM.healTime = 4
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "END", value = -1, duration = 60}
}
