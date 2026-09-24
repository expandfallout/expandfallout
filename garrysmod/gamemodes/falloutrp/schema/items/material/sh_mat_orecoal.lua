--[[
	Coal Ore.

	GENERATED FILE. The roster is `_docs/tools/materials.py`;
	edit it there and run `_docs/tools/genmaterials.py`.
]]

ITEM.name = "Coal Ore"
ITEM.description = "A chunk of coal ore"
ITEM.model = "models/zerochain/props_mining/zrms_resource.mdl"
ITEM.category = "Materials"

ITEM.isStackable = true

--- Corner marker; this model is shared with other items.
ITEM.tint = Color(40, 40, 44)

--[[
	Which look this one wears. The seven ores are one model
	with five bodygroups on it; `libs/sh_itembodygroup.lua`
	is what applies it, because Helix supports a skin and
	nothing else.
]]
ITEM.bodygroups = {[0] = 4}
