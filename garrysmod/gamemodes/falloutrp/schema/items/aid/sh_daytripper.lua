--[[
	Day Tripper.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Day Tripper"
ITEM.description = "Everything is fine. Everyone likes you."
ITEM.model = "models/mosi/fallout4/props/aid/daytripper.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "DayTripper"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "CHR", value = 3, duration = 180},
	{stat = "LCK", value = 2, duration = 180},
	{stat = "STR", value = -1, duration = 180}
}

ITEM.addictionName = "DayTripper"
ITEM.addictionChance = 20
