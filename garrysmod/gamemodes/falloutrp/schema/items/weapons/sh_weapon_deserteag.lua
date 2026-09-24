-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_deserteag.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = ".44 Desert Eagle"
ITEM.description = ""
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_bigo.mdl"
ITEM.class = "ls_deserteagle"
ITEM.width = 2
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(24.8, 23.2, 12.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
