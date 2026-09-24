--[[
	Stealth Boy.

	GENERATED FILE. The roster is `_docs/tools/chems.py`; edit it
	there and run `_docs/tools/genchems.py`.
]]

ITEM.name = "Stealth Boy"
ITEM.description = "A wrist-mounted stealth field. Fragile, and the batteries do not last."
ITEM.model = "models/mosi/fnv/props/health/chems/stealthboy.mdl"

ITEM.effectSound = "rhys/fx/items/stealth/obj_stealthboy_activate_01.mp3"
ITEM.aidID = "StealthBoy"
ITEM.useEffect = "inject"

ITEM.buffs = {
	{stat = "STEALTH", value = 1, duration = 90}
}
