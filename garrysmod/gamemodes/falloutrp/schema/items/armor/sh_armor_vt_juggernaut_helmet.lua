ITEM.name = "Vault Tec Juggernaut Helmet"
ITEM.description = "A heavy and thick helmet, fitted with a visor."
ITEM.model = "models/fallout/apparel/vaultsecurityhelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/vaultjuggernauthelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/vaultjuggernauthelmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "VT"

ITEM.specialBonus = {}

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
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
