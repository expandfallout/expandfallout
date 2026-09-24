-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Cryolator"
ITEM.description = "Cryolator."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/energy_rifle/w_cryolator.mdl"
ITEM.class = "ls_cryolator"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(57.0, 53.9, 29.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
