-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_r700_sup.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Suppressed R-700"
ITEM.description = "A heavy sniper used by marksmen in the wasteland."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/rifle/w_r700.mdl"
ITEM.class = "ls_r700_sup"
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
	pos = Vector(90.7, 80.4, 44.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
