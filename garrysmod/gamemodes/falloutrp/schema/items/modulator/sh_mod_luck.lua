--[[
	Luck modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Luck Modulator"
ITEM.description = "Nobody can say what this one does. It is measurably "
	.. "better to be wearing it than not."

ITEM.modSpecial = {luck = 3}
