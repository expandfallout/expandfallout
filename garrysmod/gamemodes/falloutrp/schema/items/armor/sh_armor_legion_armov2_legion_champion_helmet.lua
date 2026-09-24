ITEM.name = "Legion Champion Power Helmet"
ITEM.description = "A set of Power Armor worn by Champions in Caesar's Legion."
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/powerarmor_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false
ITEM.isSalvagedPA = false

ITEM.faction = "Legion"
ITEM.factionClass = "Officer"

ITEM.specialBonus = {
	perception = 4
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
