-- Written from the weapon: Phoenix never itemised this one.
-- Size follows the convention their own items establish - see _docs/03-weapons.md.

ITEM.name = "Elijah's Jury-Rigged Tesla Cannon"
ITEM.description = "Elijah's Jury-Rigged Tesla Cannon."
ITEM.category = "Weapons"

ITEM.model = "models/rhys/fallout/weapons/world/tesla_caster/models/w_tesla_caster.mdl"
ITEM.class = "ls_unique_elijasjurryriggedteslacannon"

ITEM.width = 3
ITEM.height = 2

ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(113.7, 91.3, 52.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
