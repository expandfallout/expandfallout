--[[
	Fusion core.

	What Power Armour runs on. Ported from their `schema/items/junk/`, with the
	stacking fields dropped - this schema has no item stacking yet, so
	`isStackable = false` / `maxQuantity = 1` describe the only behaviour
	available and would be noise.

	In `items/` root rather than a folder, deliberately. `ix.item.LoadFromDir`
	gives anything in `items/<folder>/` the base `base_<folder>`, so putting
	this in `items/junk/` would demand a `base_junk` that does not exist.
]]

ITEM.name = "Fusion Core"
ITEM.description = "Used to power fusion generators and power armour."
ITEM.model = "models/mosi/fallout4/props/fusion_core.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1
ITEM.price = 10

--[[
	The marker `ix.armor.EquipFusionCore` searches the inventory for.

	Keyed off a flag rather than the uniqueID so a variant core - a bigger one,
	a faction one - works without editing the armour code.
]]
ITEM.isFusionCore = true

--[[
	How much charge this puts into a suit, as a percentage.

	A full core fills a suit exactly once. Partial cores are possible by
	setting `charge` data on an instance; the armour takes whatever is there.
]]
ITEM.charge = 100

function ITEM:GetDescription()
	local charge = self:GetData("charge", self.charge or 100)

	return string.format("%s\n\n - Charge: %d%%", self.description, charge)
end
