-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_navyrevolver.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Navy Revolver"
ITEM.description = "Bang Bang."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/fallout/weapons/world/revolver/models/revolver.mdl"
ITEM.class = "ls_navy_revolver"
ITEM.width = 2
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(31.1, 27.2, 14.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
