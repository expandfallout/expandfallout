-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_marksmancarbine.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Marksman Carbine"
ITEM.description = "A semi-automatic rifle favored by marksmen for its accuracy."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/rifles/w_marksmancarbine.mdl"
ITEM.class = "ls_marksman_carbine"
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
	pos = Vector(45.6, 45.3, 24.5),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
