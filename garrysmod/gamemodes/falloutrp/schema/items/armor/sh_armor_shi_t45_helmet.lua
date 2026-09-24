ITEM.name = "Shi T-45 Helmet"
ITEM.description = "A T-45 power armor helmet used by the Shi"
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/t-45.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/t-45.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "shi"

ITEM.textureReplace = {
    ["roadkill/fallout/player/male/armor/t-45/powerarmorhelmet"] = "galang/fallout/player/t45/shi/shit45helm",
}

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
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
