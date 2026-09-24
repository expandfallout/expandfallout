ITEM.name = "Hellfire Powered Helmet"
ITEM.description = "The helmet to the infamous hellfire power armor. | NCO ARMOR"
ITEM.model = "models/fallout/apparel/hellfirehelm.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/hellfire_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/hellfire_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	perception = 3
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
