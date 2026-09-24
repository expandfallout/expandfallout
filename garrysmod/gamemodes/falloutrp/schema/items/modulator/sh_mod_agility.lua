--[[
	Agility modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Agility Modulator"
ITEM.description = "Balance gyros and a lighter step. The suit stops "
	.. "arguing with the person inside it."

ITEM.modSpecial = {agility = 3}
