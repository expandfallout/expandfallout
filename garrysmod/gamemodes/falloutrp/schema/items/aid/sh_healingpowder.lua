--[[
	Healing Powder.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Healing Powder"
ITEM.description = "Ground broc flower and xander root. Tribal medicine, and it works."
ITEM.model = "models/roadkill/fallout/clutter/aid/healingpowder.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.heal = 25
ITEM.healTime = 6
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "PER", value = -1, duration = 90}
}
