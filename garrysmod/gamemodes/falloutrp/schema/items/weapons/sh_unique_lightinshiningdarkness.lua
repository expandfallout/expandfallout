-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "A Light in Shining Darkness"
ITEM.description = "A Light in Shining Darkness."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/pistols/w_a_light_shining_in_darkness.mdl"
ITEM.class = "ls_unique_lightinshiningdarkness"

ITEM.width = 2
ITEM.height = 2

ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(15.3, 14.9, 7.9),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
