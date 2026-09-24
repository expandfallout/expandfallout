--[[
	Charisma modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Charisma Modulator"
ITEM.description = "A voice conditioner and a set of very deliberate "
	.. "lights. People listen a moment longer."

ITEM.modSpecial = {charisma = 3}
