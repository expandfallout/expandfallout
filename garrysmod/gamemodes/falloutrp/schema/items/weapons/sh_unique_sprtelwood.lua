-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Sprtel-Wood 9700"
ITEM.description = "Sprtel-Wood 9700."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/w_sprtel_wood_9700.mdl"
ITEM.class = "ls_unique_sprtelwood"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(74.2, 56.8, 32.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
