-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "C4 Plastic Explosive"
ITEM.description = "C4 Plastic Explosive."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/mine/c4_plastic_explosive.mdl"
ITEM.class = "ls_mine_c4"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(22.9, 21.8, 11.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
