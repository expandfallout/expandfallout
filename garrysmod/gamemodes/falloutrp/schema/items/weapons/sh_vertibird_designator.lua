-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Vertibird Designator"
ITEM.description = "Vertibird Designator."
ITEM.category = "Equipment"

ITEM.model = "models/catmop/fallout/weapons/world/melee/w_binoculars.mdl"
ITEM.class = "ls_vertibird_designator"

ITEM.width = 2
ITEM.height = 1

ITEM.weaponCategory = "equipment2"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(20.9, 16.7, 11.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
