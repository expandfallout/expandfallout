-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_ranger_sequoia.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Ranger Sequoia"
ITEM.description = "Against All Tyrants."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/pistol/w_rangersequoia.mdl"
ITEM.class = "ls_ranger_sequoia"
ITEM.width = 2
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
	pos = Vector(32.1, 28.2, 14.8),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
