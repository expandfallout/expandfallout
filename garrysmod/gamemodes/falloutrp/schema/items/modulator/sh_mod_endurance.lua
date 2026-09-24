--[[
	Endurance modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Endurance Modulator"
ITEM.description = "A regulator that keeps the wearer's blood chemistry "
	.. "where it ought to be, whatever the day has been "
	.. "like."

ITEM.modSpecial = {endurance = 3}
