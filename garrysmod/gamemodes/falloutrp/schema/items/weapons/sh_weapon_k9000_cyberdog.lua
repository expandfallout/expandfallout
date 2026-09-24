-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_k9000_cyberdog.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "K9000 Cyberdog Gun"
ITEM.description = "Woof woof motherfucker."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/heavy/w_k9000.mdl"
ITEM.class = "ls_k9000cyberdoggun"
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
	pos = Vector(74.4, 55.9, 33.9),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
