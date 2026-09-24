-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_tesla_rcw.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Tesla RCW"
ITEM.description = "Someone is about to have a bad day."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/energy_rifle/w_teslarcw.mdl"
ITEM.class = "ls_tesla_rcw"
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
	pos = Vector(51.3, 51.6, 29.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
