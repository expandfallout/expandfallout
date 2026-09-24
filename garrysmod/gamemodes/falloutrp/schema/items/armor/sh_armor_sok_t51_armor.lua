ITEM.name = "Tribal T-51b Power Armor"
ITEM.description = "An tribal T-51b power armor"
ITEM.model = "models/fallout/apparel/adpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/kagat51.mdl"
ITEM.maleModel = "models/galang/fallout/player/kagat51.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 78
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "SOK"

ITEM.specialBonus = {
	intelligence = 3
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
