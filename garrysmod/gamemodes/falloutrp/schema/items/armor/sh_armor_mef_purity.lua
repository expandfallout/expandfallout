ITEM.name = "Purity Power Armor"
ITEM.description = "An advanced power armor worn by officers of the MEF | HIGH COMMAND ARMOR"
ITEM.model = "models/fallout/apparel/amwpa.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mef/amwpa.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/amwpa.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "MEF"

ITEM.specialBonus = {
	perception = 2
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
