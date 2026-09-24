ITEM.name = "Vault-Tec Power Armor"
ITEM.description = "A set of power armor specially designed for the Vault Tec corporation."
ITEM.model = "odels/galang/fallout/player/VaultTecPAGo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/VaultTecPA.mdl"
ITEM.maleModel = "models/galang/fallout/player/VaultTecPA.mdl"

ITEM.skin = 0

ITEM.resistance = 70
ITEM.speedBoost = -70
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

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
