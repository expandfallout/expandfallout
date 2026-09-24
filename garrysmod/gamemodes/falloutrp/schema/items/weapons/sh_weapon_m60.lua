-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_m60.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "M60, The Pig"
ITEM.description = "Oink."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/m60.mdl"
ITEM.class = "ls_m60"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"
ITEM.tooHeavyForBag = true

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(75.5, 72.6, 35.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
