-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Smoke Grenade"
ITEM.description = "Smoke Grenade."
ITEM.category = "Weapons"

ITEM.model = "models/roadkill/fallout/weapons/world/grenade/w_incin.mdl"
ITEM.class = "ls_grenade_smoke"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(9.5, 10.8, 5.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
