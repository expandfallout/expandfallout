-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_teslacaster.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Tesla Caster"
ITEM.description = "I cast tesla at thee."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/fallout/weapons/world/tesla_caster/models/w_tesla_caster.mdl"
ITEM.class = "ls_tesla_caster"
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
	pos = Vector(113.7, 91.3, 52.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
