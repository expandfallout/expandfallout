-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_plasmagatling.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Plasma Gatling"
ITEM.description = "I cast plasma at thee."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/w_gatlingplasma.mdl"
ITEM.class = "ls_plasma_gatling"
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
	pos = Vector(72.7, 60.7, 35.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
