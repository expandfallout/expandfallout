-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_25mm_grenade_launcher.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "25mm APW Grenade Launcher"
ITEM.description = "Grenade Launcher with a magazine?!"
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/launchers/w_25mm_grenade_apw.mdl"
ITEM.class = "ls_25mm_apwgrenade_launcher"
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
	pos = Vector(53.2, 53.7, 28.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
