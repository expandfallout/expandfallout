-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_varmintrifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Varmint Rifle"
ITEM.description = "A lightweight rifle designed for small game hunting."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/rifles/w_varmint.mdl"
ITEM.class = "ls_varmint_rifle"
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
	pos = Vector(69.0, 65.0, 35.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
