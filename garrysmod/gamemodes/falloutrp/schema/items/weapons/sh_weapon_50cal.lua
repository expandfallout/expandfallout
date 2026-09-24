-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_50cal.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Browning .50 Cal"
ITEM.description = "It's a machine gun!"
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/m2hb_browning.mdl"
ITEM.class = "ls_50browning"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"
ITEM.isHeavy = true

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(100.6, 78.7, 48.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
