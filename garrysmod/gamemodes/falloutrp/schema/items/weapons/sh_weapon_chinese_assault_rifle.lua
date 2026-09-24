-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_chinese_assault_rifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Chinese Assault Rifle"
ITEM.description = "A rifle made by the Chinese."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/rifles/w_chineseassaultrifle.mdl"
ITEM.class = "ls_chinese_assault_rifle"
ITEM.width = 3
ITEM.height = 2
ITEM.isMelee = false
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(85.2, 75.9, 42.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
