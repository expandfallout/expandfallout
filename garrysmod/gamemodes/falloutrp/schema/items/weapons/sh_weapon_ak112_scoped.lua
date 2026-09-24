-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_ak112_scoped.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Scoped AK112"
ITEM.description = "A reliable rifle known for its durability and ease of use."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/rifle/w_ak_112.mdl"
ITEM.class = "ls_ak112_scoped"
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
	pos = Vector(64.5, 59.1, 33.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
