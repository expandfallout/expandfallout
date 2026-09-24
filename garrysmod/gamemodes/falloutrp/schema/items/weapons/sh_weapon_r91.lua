-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_r91.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "R91"
ITEM.description = "An average assault rifle."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/rifle/w_g3assaultrifle.mdl"
ITEM.class = "ls_r91"
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
	pos = Vector(59.5, 56.9, 30.7),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
