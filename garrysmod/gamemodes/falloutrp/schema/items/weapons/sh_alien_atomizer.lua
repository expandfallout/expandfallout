-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Alien Atomizer"
ITEM.description = "Alien Atomizer."
ITEM.category = "Weapons"

ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_alien_atomizer.mdl"
ITEM.class = "ls_alien_atomizer"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(28.7, 25.9, 13.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
