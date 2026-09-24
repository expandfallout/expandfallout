--[[
	Stealth Boy Mk II.

	The chem version (`items/aid/sh_stealthboy.lua`) is a ninety-second field
	that runs itself. This is the same device with a rebuilt cell, worn: it
	takes the body-accessory slot, draws nothing on the body, and while it is
	on the stealth key works the way it does in a stealth suit - `hasStealth`
	is the same flag the courser suit carries, and `ix.armor.GiveStealth` /
	`SetStealth` are the same calls.

	Every field the armour base reads is present, even the zeros, because the
	base reads them without defaults - see any suit in this folder.
]]

ITEM.name = "Stealth Boy Mk II"
ITEM.description = "A wrist-mounted stealth field with a rebuilt cell: it "
	.. "runs for as long as it is worn. Strap it on and use your stealth key."
ITEM.model = "models/mosi/fnv/props/health/chems/stealthboy.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Armor"
ITEM.price = 1200
ITEM.playerHeight = false

ITEM.hasStealth = true
ITEM.bodyType = "bodyAccessory"

--- Nothing is drawn on the body; the field is the whole of the look.
ITEM.femaleModel = ""
ITEM.maleModel = ""
ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0
ITEM.isPA = false
ITEM.noCore = false
ITEM.specialBonus = {}

--- A wrist is a wrist; anything with arms wears it.
ITEM.wearer = "any"

ITEM.takesType = {
	hat = false,
	mask = false,
	eyes = false,
	helmet = false,
	body = false
}

ITEM.takesBody = {
	hair = false,
	beard = false,
	head = false
}

ITEM.OnEquip = function(item, client)
	ix.armor.GiveStealth(client)

	return true
end

ITEM.OnUnequip = function(item, client)
	ix.armor.SetStealth(client, false)

	return true
end
