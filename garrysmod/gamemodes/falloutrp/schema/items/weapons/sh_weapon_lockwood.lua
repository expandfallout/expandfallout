-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_lockwood.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Lockwood"
ITEM.description = "A reliable gun favored for its power."
ITEM.category = "Weapons"
ITEM.model = "models/rhys/fallout/weapons/world/lockwood/w_lockwoodmk2.mdl"
ITEM.class = "ls_lockwood"
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
	pos = Vector(61.5, 59.1, 32.1),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
