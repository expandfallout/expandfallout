-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_44magnum.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "44. Magnum"
ITEM.description = "Bigger iron."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_44.mdl"
ITEM.class = "ls_44_magnum_revolver"
ITEM.width = 2
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "secondary"

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(24.0, 23.3, 11.7),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
