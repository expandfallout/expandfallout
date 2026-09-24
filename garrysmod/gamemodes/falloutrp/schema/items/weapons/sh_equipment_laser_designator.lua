-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_equipment_laser_designator.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Laser Designator"
ITEM.description = "A targeting device that calls in an orbital laser strike. Single use."
ITEM.category = "Equipment"

ITEM.model = "models/catmop/fallout/weapons/world/melee/w_binoculars.mdl"
ITEM.class = "ls_laser_designator"

ITEM.width  = 2
ITEM.height = 1

ITEM.rarity     = 5
ITEM.rollRarity = false

ITEM.weaponCategory = "equipment2"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(20.9, 16.7, 11.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
