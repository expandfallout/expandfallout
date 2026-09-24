ITEM.name = "Vault-Tec Power Armor Helmet"
ITEM.description = "A power armor helmet belonging to the Vault-Tec PA set."
ITEM.model = "odels/galang/fallout/player/VaultTecPAHelmetGo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/VaultTecPA.mdl"
ITEM.maleModel = "models/galang/fallout/player/VaultTecPA.mdl"

ITEM.skin = 0

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
