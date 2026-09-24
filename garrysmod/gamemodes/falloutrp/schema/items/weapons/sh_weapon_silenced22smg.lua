-- Ported from Phoenix's own weapon items - their inventory model and
-- slot category. Size normalised to their convention for this weapon
-- type; see _docs/03-weapons.md.
-- "gamemodes\\fallout\\schema\\items\\weapons\\sh_weapon_silenced22smg.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
ITEM.name = "Silenced .22 SMG"
ITEM.description = "A silenced submachine gun chambered in .22 caliber."
ITEM.category = "Weapons"
ITEM.model = "models/roadkill/fallout/weapons/world/smgs/w_s22mm.mdl"
ITEM.class = "ls_22_smg"
ITEM.width = 3
ITEM.height = 2
ITEM.isWeapon = true
ITEM.rarity = 1
ITEM.rollRarity = true
ITEM.weaponCategory = "primary"
ITEM.tooHeavyForBag = false

-- Override for rarity dmg multipliers, stops specific weapons from being too powerful.
ITEM.rarityMult = {
	[1] = 1, -- None
	[2] = 1.05, -- Common
	[3] = 1.1, -- UnCommon
	[4] = 1.15, -- Rare
	[5] = 1.2, -- Superior
	[6] = 1.25, -- Legendary
	[7] = 1.3, -- Pearlescent
	[8] = 1 -- Unique
}

--[[
	Icon camera, measured from this model's VERTICES - the MDL hull lies
	about the geometry on several of these packs. See _docs/19-items.md.
]]
ITEM.iconCam = {
	pos = Vector(44.7, 39.1, 21.2),
	ang = Angle(22.4, -132.4, 0),
	fov = 40
}
