-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_junk_jet.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Junk Jet"
ITEM.description = "A makeshift weapon that fires various junk items as projectiles. It is a unique and unconventional weapon, often found in the hands of scavengers and tinkerers in the wasteland. The Junk Jet is known for its versatility and creativity, allowing users to utilize whatever scrap they can find to create devastating ammunition."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/heavy_weapon/rock_it_launcher.mdl"
ITEM.class = "ls_junk_jet"
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
	pos = Vector(55.6, 44.8, 26.0),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
