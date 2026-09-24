-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Laser Detonator"
ITEM.description = "Laser Detonator."
ITEM.category = "Equipment"

ITEM.model = "models/catmop/fallout/weapons/world/pistols/laserdetonator.mdl"
ITEM.class = "ls_laser_detonator"

ITEM.width = 2
ITEM.height = 1

ITEM.weaponCategory = "equipment2"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(20.4, 21.5, 11.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
