-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_imi_galil.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "IMI Galil"
ITEM.description = "An Automatic Rifle developed by ISRAEL."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/rifle/w_imi_galil.mdl"
ITEM.class = "ls_imi_galil"
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
	pos = Vector(70.1, 65.3, 36.9),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
