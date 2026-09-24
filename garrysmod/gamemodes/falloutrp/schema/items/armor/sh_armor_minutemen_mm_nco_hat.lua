ITEM.name = "Minutemen NCO Sheriff Hat"
ITEM.description = "A hat well known in the Western states for law and order."
ITEM.model = "models/galang/fallout/player/minutemenofficerhatgo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/sherrifs_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/sherrifs_hat.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Minutemen"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
