-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Drone Cannon"
ITEM.description = "Drone Cannon."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/drone_cannon.mdl"
ITEM.class = "ls_drone_cannon"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(94.8, 72.3, 44.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
