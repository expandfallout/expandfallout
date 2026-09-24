-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "C.I.T V3-N Biorifle"
ITEM.description = "C.I.T V3-N Biorifle."
ITEM.category = "Weapons"

ITEM.model = "models/catmop/fallout/weapons/world/energy_rifle/v3-n_biorifle.mdl"
ITEM.class = "ls_cit_v3n_biorifle"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(47.9, 48.4, 24.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
