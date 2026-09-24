-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_combat_shotgun.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Combat Shotgun"
ITEM.description = "A powerful shotgun that fires multiple pellets in a wide spread. It is a common sight in the wasteland, and is known for its devastating close-range damage."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/shotgun/w_combatshotgun.mdl"
ITEM.class = "ls_combat_shotgun"
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
	pos = Vector(59.8, 55.0, 30.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
