-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = ".50 SMG"
ITEM.description = ".50 SMG."
ITEM.category = "Weapons"

ITEM.model = "models/rhys/fallout/weapons/world/50_smg/models/w_50smg.mdl"
ITEM.class = "ls_50_smg"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(49.2, 47.0, 27.3),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
