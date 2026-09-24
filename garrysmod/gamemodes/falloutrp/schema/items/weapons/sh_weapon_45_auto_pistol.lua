-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_45_auto_pistol.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = ".45 Auto Pistol"
ITEM.description = "A pistol to bring justice to those who are deserved."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_45mm.mdl"
ITEM.class = "ls_45_auto_pistol"
ITEM.width = 2
ITEM.height = 2
ITEM.isMelee = false
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(29.6, 25.2, 13.7),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
