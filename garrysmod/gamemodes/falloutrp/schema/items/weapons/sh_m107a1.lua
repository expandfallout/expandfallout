-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "M107A1"
ITEM.description = "M107A1."
ITEM.category = "Weapons"

ITEM.model = "models/roadkill/fallout/weapons/world/sniper/w_m107a1.mdl"
ITEM.class = "ls_m107a1"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(95.4, 87.3, 46.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
