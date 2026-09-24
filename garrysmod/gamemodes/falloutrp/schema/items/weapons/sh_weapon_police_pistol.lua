-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_police_pistol.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Police Pistol"
ITEM.description = "A standard issue pistol used by the police forces of the Sierra Madre. It is a reliable and cheap sidearm."
ITEM.category = "Weapons"
ITEM.model = "models/catmop/fallout/weapons/world/pistols/w_policepistol.mdl"
ITEM.class = "ls_police_pistol"
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
	pos = Vector(19.2, 18.2, 9.6),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
