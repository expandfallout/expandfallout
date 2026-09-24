--[[
	CIT Access Pad.

	GENERATED FILE. The roster is `_docs/tools/materials.py`;
	edit it there and run `_docs/tools/genmaterials.py`.
]]

ITEM.name = "CIT Access Pad"
ITEM.description = "A CIT access pad. Clean, unlabelled, and it knows who is holding it."
ITEM.model = "models/mosi/fallout4/props/junk/keycard.mdl"
ITEM.category = "Access"

--[[
	ONE OF A KIND. Not a quantity of a substance - a specific
	object, and two of them sharing a slot would be a lie
	about what is in the room.
]]
ITEM.isStackable = false

--- Corner marker; this model is shared with other items.
ITEM.tint = Color(220, 220, 230)
