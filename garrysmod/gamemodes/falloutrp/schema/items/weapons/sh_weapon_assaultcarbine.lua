-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_assaultcarbine.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Assault Carbine"
ITEM.description = "A High Rate of Fire Carbine, chambered in 5mm."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/rifles/w_assaultcarbine.mdl"
ITEM.class = "ls_assault_carbine"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"

-- {"ang":"{100.9236 179.7848 0}","pos":"[-126.5284 4.8409 651.6857]","mdl_ang":"{0 0 0}","fov":3.807255211466015}
ITEM.iconCam = {
    pos = Vector(-120.5284, -28, 640),
    ang = Angle(100.9236, 190, 180),
    fov = 3.807255211466015,
}

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(60.5, 55.2, 30.4),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
