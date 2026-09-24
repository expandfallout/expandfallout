--[[
	Intelligence modulator.

	One of the eight. The numbers are here rather than in a registry because
	this file is what somebody opens when they want to change one - see
	`sh_modulator.lua`, which reads them straight off the item.
]]

ITEM.name = "Intelligence Modulator"
ITEM.description = "A pre-war teaching aid, repurposed. It answers "
	.. "questions you had not finished asking."

ITEM.modSpecial = {intelligence = 3}
