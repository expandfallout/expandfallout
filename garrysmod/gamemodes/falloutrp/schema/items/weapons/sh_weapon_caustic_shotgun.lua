-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_caustic_shotgun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Caustic Shotgun"
ITEM.description = "Long range drug delivery!"
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/shotgun/w_caustic_shotgun.mdl"
ITEM.class = "ls_caustic_shotgun"
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
	pos = Vector(68.4, 62.5, 34.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
