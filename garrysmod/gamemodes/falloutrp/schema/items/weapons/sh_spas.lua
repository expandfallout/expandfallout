-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "SPAS-12"
ITEM.description = "SPAS-12."
ITEM.category = "Weapons"

ITEM.model = "models/rhys/fallout/weapons/world/spas/spas.mdl"
ITEM.class = "ls_spas"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(69.4, 61.9, 33.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
