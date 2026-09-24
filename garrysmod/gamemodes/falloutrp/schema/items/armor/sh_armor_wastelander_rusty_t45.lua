ITEM.name = "Rusty T-45 Power Armor"
ITEM.description = "A set if Pre-War power armor, model T-45, heavily rusted and in need of repairs."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/t45rusted.mdl"
ITEM.maleModel = "models/galang/fallout/player/t45rusted.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.specialBonus = {}

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
