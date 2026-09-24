-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Silenced Machine Gun"
ITEM.description = "Silenced Machine Gun."
ITEM.category = "Weapons"

ITEM.model = "models/rhys/fallout/weapons/world/smmg/w_smachinegun.mdl"
ITEM.class = "ls_smmg"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(54.6, 66.4, 32.7),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
