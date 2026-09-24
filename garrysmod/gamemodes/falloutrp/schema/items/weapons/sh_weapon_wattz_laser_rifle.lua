-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_wattz_laser_rifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Wattz Laser Rifle"
ITEM.description = "Having a very long range and acute accuracy, this laser rifle can be effectively used in long distance combat."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/fallout/weapons/world/wattz/w_wattz.mdl"
ITEM.class = "ls_wattz_sniper"
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
	pos = Vector(80.1, 73.8, 39.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
