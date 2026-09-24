-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_cit_laser_rifle.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "C.I.T Laser Rifle"
ITEM.description = "I really have to write a description for ALL of these?"
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/energy_rifle/w_c.i.t_rifle.mdl"
ITEM.class = "ls_cit_laser_rifle"
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
	pos = Vector(59.0, 58.2, 32.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
