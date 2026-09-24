-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_chinese_pistol.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Chinese Pistol"
ITEM.description = "黑猫"
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/pistols/w_mauser_c96.mdl"
ITEM.class = "ls_chinese_pistol"
ITEM.width = 2
ITEM.height = 2
ITEM.isWeapon = true
ITEM.isMelee = false
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(26.5, 22.1, 12.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
