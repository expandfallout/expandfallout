--[[
	Elastic Restraints.

	The item is only the carrying half. The SWEP is `weapon_cuff_elastic` from
	the `cuffs` addon - the same one Phoenix use, licensed and installed at
	`addons/cuffs` - and everything a restraint DOES is its: the cuffing, the
	struggling, the gag, the blindfold and the rope you drag somebody by.
	`sh_cuffs.lua` is where this schema meets it.

	It lives in `items/weapons/` so that Helix's own `base_weapons` handles the
	equipping, the loadout and the holstering, exactly as it does for a rifle.

	IN ITS OWN WEAPON CATEGORY, deliberately. Helix keeps one weapon per
	`weaponCategory` - that is what stops two rifles being equipped at once -
	and putting restraints in "melee" would mean choosing between carrying a
	knife and being able to tie anybody up. They are a tool, so the category is
	`tool`, and they cost you nothing but a slot on the wheel.
]]

ITEM.name = "Elastic Restraints"
ITEM.description = "A pair of elastic restraints. Equip them and click on "
	.. "somebody to tie their hands. This item has rules of use."
ITEM.model = "models/mosi/fallout4/props/junk/handcuffs.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

ITEM.class = "weapon_cuff_elastic"
ITEM.weaponCategory = "tool"
