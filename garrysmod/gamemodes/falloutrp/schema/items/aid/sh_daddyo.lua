--[[
	Daddy-O.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Daddy-O"
ITEM.description = "Beatnik chem. Clears the head and dulls the tongue."
ITEM.model = "models/mosi/fallout4/props/aid/daddyo.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "DaddyO"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "INT", value = 3, duration = 180},
	{stat = "PER", value = 2, duration = 180},
	{stat = "CHR", value = -1, duration = 180}
}

ITEM.addictionName = "DaddyO"
ITEM.addictionChance = 20
