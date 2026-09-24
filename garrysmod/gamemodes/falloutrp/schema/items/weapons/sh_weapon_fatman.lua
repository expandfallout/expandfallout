-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_fatman.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Fatman"
ITEM.description = "You've won."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/explosive/w_fatman.mdl"
ITEM.class = "ls_fatman"
ITEM.width = 3
ITEM.height = 2
ITEM.isMelee = false
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"
ITEM.isHeavy = true

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(62.2, 72.2, 33.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
