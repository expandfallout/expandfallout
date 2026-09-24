-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_gauss_musket.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Gauss Musket"
ITEM.description = "Magnets might be real."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/energy_rifle/w_gauss_musket.mdl"
ITEM.class = "ls_gauss_musket"
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
	pos = Vector(67.7, 66.2, 35.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
