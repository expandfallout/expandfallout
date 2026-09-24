-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_shouldermountedshotgun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Quad Barreled Shoulder Mounted Shotgun"
ITEM.description = "Boom."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/weapon/w_model/assault_shotgun/models/w_shotgun.mdl"
ITEM.class = "ls_shoulder_mounted_shotgun"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"
ITEM.isHeavy = true

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(58.3, 72.3, 34.7),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
