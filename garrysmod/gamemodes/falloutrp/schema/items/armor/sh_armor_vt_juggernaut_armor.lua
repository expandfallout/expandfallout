ITEM.name = "Vault Tec Juggernaut Armor"
ITEM.description = "A heavy suit of armor, designed to absorp great kinetic energy."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/vaultjuggernaut.mdl"
ITEM.maleModel = "models/galang/fallout/player/vaultjuggernaut.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = -70
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "VT"

ITEM.specialBonus = {
	intelligence = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
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
