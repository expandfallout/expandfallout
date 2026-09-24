--[[
	Power Armor Framework.

	GENERATED FILE. The roster is `_docs/tools/materials.py`;
	edit it there and run `_docs/tools/genmaterials.py`.
]]

ITEM.name = "Power Armor Framework"
ITEM.description = "A crate full of parts and exo-skeleton needed to research power armor."
ITEM.model = "models/models/bos/militarycrate.mdl"
ITEM.category = "Schematics"

--[[
	ONE OF A KIND. Not a quantity of a substance - a specific
	object, and two of them sharing a slot would be a lie
	about what is in the room.
]]
ITEM.isStackable = false

--- Corner marker; this model is shared with other items.
ITEM.tint = Color(80, 160, 220)
