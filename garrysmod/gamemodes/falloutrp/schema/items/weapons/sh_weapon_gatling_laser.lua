-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_gatling_laser.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Gatling Laser"
ITEM.description = "A Common pistol chambered in 9mm. It is a reliable and cheap sidearm."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/energy/w_gatlinglaser.mdl"
ITEM.class = "ls_gatling_laser"
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
	pos = Vector(82.7, 62.1, 36.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
