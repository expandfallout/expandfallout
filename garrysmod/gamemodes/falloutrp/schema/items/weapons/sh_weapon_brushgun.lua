-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_brushgun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Brush Gun"
ITEM.description = "A reliable gun favored for its power."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/rifles/w_brushgun.mdl"
ITEM.class = "ls_brush_gun"
ITEM.width = 3
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
	pos = Vector(57.9, 54.5, 30.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
