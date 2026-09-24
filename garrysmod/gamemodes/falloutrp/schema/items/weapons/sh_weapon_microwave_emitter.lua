-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_microwave_emitter.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Microwave Emitter"
ITEM.description = "Heats food, also a deadly weapon."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/pistols/w_mesmetron.mdl"
ITEM.class = "ls_microwave_emitter"
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
	pos = Vector(36.2, 31.9, 17.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
