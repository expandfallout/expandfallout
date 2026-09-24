-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "The Prototype"
ITEM.description = "The Prototype."
ITEM.category = "Weapons"

ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_transportalponder.mdl"
ITEM.class = "ls_syringe_pistol"

ITEM.width = 2
ITEM.height = 2

ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(32.4, 34.0, 21.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
