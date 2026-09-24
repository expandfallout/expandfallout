-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_equipment_binoculars.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Binoculars"
ITEM.description = "A set of binoculars used to observe from far away."
ITEM.category = "Equipment"

ITEM.model = "models/catmop/fallout/weapons/world/melee/w_binoculars.mdl"
ITEM.class = "ls_binoculars"

ITEM.width = 3
ITEM.height = 2

ITEM.rarity = 1
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
