-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_plasma_pistol.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Plasma Pistol"
ITEM.description = "Small gun, big presence."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/plasma/w_pistol.mdl"
ITEM.class = "ls_plasma_pistol"
ITEM.width = 3
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
	pos = Vector(31.1, 27.2, 14.9),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
