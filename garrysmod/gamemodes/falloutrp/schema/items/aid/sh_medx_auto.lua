--[[
	Auto-Inject Med-X.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Auto-Inject Med-X"
ITEM.description = "Med-X with a pressure trigger. Goes through armour."
ITEM.model = "models/roadkill/fallout/clutter/aid/medx.mdl"

ITEM.effectSound = "phoenix/itm/ui_surgery_morphine_01.mp3"
ITEM.aidID = "MedX"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(90, 160, 230)

ITEM.buffs = {
	{stat = "DR", value = 12, duration = 240}
}

ITEM.addictionName = "MedX"
ITEM.addictionChance = 20
