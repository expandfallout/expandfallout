-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Vances 9mm SMG"
ITEM.description = "Vances 9mm SMG."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/pistols/vances_9mm_smg.mdl"
ITEM.class = "ls_unique_vances9mmsmg"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(30.4, 26.5, 14.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
