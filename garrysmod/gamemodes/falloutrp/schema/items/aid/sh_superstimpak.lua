--[[
	Super Stimpak.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Super Stimpak"
ITEM.description = "A stronger stimpak. Mends more, and takes something out of you doing it."
ITEM.model = "models/mosi/fnv/props/health/superstimpak.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_stimpak.mp3"
ITEM.heal = 100
ITEM.healTime = 5
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "END", value = -1, duration = 60}
}
