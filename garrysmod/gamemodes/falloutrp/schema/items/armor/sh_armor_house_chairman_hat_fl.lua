ITEM.name = "Chairmen Boss Fedora"
ITEM.description = "Ring a ding ding baby. A hat for the coolest cat in the wastes."
ITEM.model = "models/fallout/apparel/tophat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/faction/chairmenleadhat.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/chairmenleadhat.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "House"

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
