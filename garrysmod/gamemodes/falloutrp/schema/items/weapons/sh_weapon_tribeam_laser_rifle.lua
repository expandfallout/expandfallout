-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_tribeam_laser_rifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Tri-Beam Laser Rifle"
ITEM.description = "A shotgun-like variant of the Laser Rifle."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/energy/w_tribeamlaserrifle.mdl"
ITEM.class = "ls_tribeam_laser_rifle"
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
	pos = Vector(48.6, 51.1, 26.9),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
