-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Bellum Banner"
ITEM.description = "Bellum Banner."
ITEM.category = "Weapons"

ITEM.model = "models/mosi/fnv/props/factions/legion/flag_legion_small.mdl"
ITEM.class = "ls_bellumbanner"

ITEM.width = 2
ITEM.height = 2

ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(111.7, 121.3, 117.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
