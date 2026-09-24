--[[
	Modulator base item.

	Every file in `items/modulator/` inherits this - `ix.item.LoadFromDir` gives
	items in `items/<folder>/` the base `base_<folder>`, so the folder name and
	this filename have to stay in step.

	A modulator is a THING THAT DOES NOTHING IN YOUR POCKET. It has no Use
	function on purpose: the only way to spend one is at a bench in `modulate`
	mode, standing there wearing the armour it is going into, which is Phoenix's
	shape and is what makes fitting one a decision rather than a click.

	See `sh_modulator.lua` for the rules and for how the numbers below reach the
	armour.
]]

ITEM.name = "Modulator"
ITEM.description = "An armour modulator."
ITEM.model = "models/mosi/fallout4/props/junk/modbox.mdl"
ITEM.category = "Modulators"

ITEM.width = 1
ITEM.height = 1

--- The marker `ix.modulator.Kinds` looks for. Nothing keys off the folder.
ITEM.isModulator = true

--[[
	What it is worth, in the two shapes the armour system already sums.

	`modSpecial` is keyed by the canonical attribute names - `strength`,
	`perception` and so on, the same keys `ITEM.specialBonus` uses on an armour.
	`modFields` names armour fields: `resistance`, `radResistance`,
	`fallProtection`.

	Both are added to the suit's own numbers, so a modulator is worth exactly
	what an armour with the same figure written on it would be.
]]
ITEM.modSpecial = {}
ITEM.modFields = {}

--[[
	The description, with what it does appended.

	Built from the numbers rather than written beside them - see
	`ix.modulator.Line`. Phoenix keep a hand-written `armorDesc` next to each
	bonus, and two of theirs no longer match the bonus they describe.
]]
function ITEM:GetDescription()
	local line = ix.modulator.Line(self)

	if (line == "") then return self.description end

	return string.format("%s\n\n - %s\n\n - Body armour only. Fitted at a "
		.. "modulate bench, and not recoverable afterwards.",
		self.description, line)
end
