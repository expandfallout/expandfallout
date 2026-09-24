-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "That Gun"
ITEM.description = "That Gun."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/pistols/w_thatgun.mdl"
ITEM.class = "ls_unique_thatgun"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(21.8, 20.2, 10.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
