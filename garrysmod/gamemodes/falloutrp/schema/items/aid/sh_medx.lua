--[[
	Med-X.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Med-X"
ITEM.description = "A painkiller strong enough that you stop noticing being shot."
ITEM.model = "models/roadkill/fallout/clutter/aid/medx.mdl"

ITEM.effectSound = "phoenix/itm/ui_surgery_morphine_01.mp3"
ITEM.aidID = "MedX"
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "DR", value = 10, duration = 240}
}

ITEM.addictionName = "MedX"
ITEM.addictionChance = 20
