--[[
	Perception modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Perception Modulator"
ITEM.description = "A sensor package wired into the suit's collar. "
	.. "Things in the dark stop being surprises."

ITEM.modSpecial = {perception = 3}
