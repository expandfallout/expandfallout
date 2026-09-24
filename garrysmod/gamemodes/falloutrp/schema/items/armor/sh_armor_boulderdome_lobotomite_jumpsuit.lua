ITEM.name = "Lobotomite Jumpsuit"
ITEM.description = "A jumpsuit worn by the LOBOTOMITES!"
ITEM.model = "models/fallout/apparel/leatherarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/lobotomitejumpsuit.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/lobotomitejumpsuit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 65
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Boulder Dome"

ITEM.specialBonus = {
	strength = 15,
	intelligence = -15
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
