-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_m72gaussrifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "M72 Gauss Rifle"
ITEM.description = "Warning, may explode due to prototype status."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/fallout/weapons/world/m72/w_m72gaussrifle.mdl"
ITEM.class = "ls_m72_gauss_rifle"
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
	pos = Vector(74.3, 68.7, 37.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
