--[[
	Radiation modulator.

	The odd one out: every other modulator moves a SPECIAL, and this moves an
	ARMOUR FIELD. Both reach the suit the same way - see `ix.modulator.Field`
	and `ix.modulator.Special` - so nothing else has to know it is different.

	15% is Phoenix's figure, and it goes into the same pool as Rad-X and the
	suit's own rating, clamped once at the total by
	`ix.armor.GetRadResistance`.
]]

ITEM.name = "Radiation Modulator"
ITEM.description = "A lead-lined lattice that lines the suit. It "
	.. "rattles, and it works."

ITEM.modFields = {radResistance = 15}
