-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_mp5.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "MP5"
ITEM.description = ""
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/rifle/w_mp5.mdl"
ITEM.class = "ls_mp5_ncr"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(347.5, 272.2, 151.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
