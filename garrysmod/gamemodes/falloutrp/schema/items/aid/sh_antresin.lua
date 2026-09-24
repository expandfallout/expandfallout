--[[
	Anti-Resin.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Anti-Resin"
ITEM.description = "Counteracts the resin. Whatever the resin was."
ITEM.model = "models/mosi/fnv/props/health/chems/antresin.mdl"

ITEM.effectSound = "phoenix/itm/npc_human_using_radx_01.mp3"
ITEM.aidID = "AntiResin"
ITEM.useEffect = "swallow"

ITEM.buffs = {
	{stat = "RADRES", value = 30, duration = 240}
}
