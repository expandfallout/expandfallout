--[[
	Strength modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Strength Modulator"
ITEM.description = "A sealed module that trims a suit's servos until the "
	.. "wearer carries and hits harder than they should."

ITEM.modSpecial = {strength = 3}
