-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_equipment_radscanner.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Mutation Scanner"
ITEM.description = "A handheld device used to scan individuals for genetic mutations."
ITEM.category = "Equipment"

ITEM.model = "models/mosi/fallout4/props/junk/biometricscanner.mdl"
ITEM.class = "ls_radiation_scanner"

ITEM.width = 2
ITEM.height = 2

ITEM.rarity = 1
ITEM.rollRarity = false

ITEM.weaponCategory = "equipment"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(24.5, 26.9, 22.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
