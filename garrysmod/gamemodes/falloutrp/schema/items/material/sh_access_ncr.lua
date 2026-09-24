--[[
	NCR Requisition Pad.

	GENERATED FILE. The roster is `_docs/tools/materials.py`;
	edit it there and run `_docs/tools/genmaterials.py`.
]]

ITEM.name = "NCR Requisition Pad"
ITEM.description = "An NCR requisition pad. Signed, countersigned and probably forged."
ITEM.model = "models/mosi/fallout4/props/junk/keycard.mdl"
ITEM.category = "Access"

--[[
	ONE OF A KIND. Not a quantity of a substance - a specific
	object, and two of them sharing a slot would be a lie
	about what is in the room.
]]
ITEM.isStackable = false

--- Corner marker; this model is shared with other items.
ITEM.tint = Color(180, 140, 60)
