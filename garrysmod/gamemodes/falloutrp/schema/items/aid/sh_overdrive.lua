--[[
	Overdrive.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Overdrive"
ITEM.description = "You start landing hits you had no business landing."
ITEM.model = "models/mosi/fnv/props/health/chems/psycho.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.aidID = "Overdrive"
ITEM.useEffect = "inject"

--[[
	This chem shares a model with another. The marker on its
	icon is how the two are told apart in an inventory.
]]
ITEM.tint = Color(240, 190, 70)

ITEM.buffs = {
	{stat = "DMG", value = 15, duration = 180},
	{stat = "LCK", value = 2, duration = 180}
}

ITEM.addictionName = "Overdrive"
ITEM.addictionChance = 25
