ITEM.name = "Tactical Power Armor"
ITEM.description = "A standard issue power armor worn by the MEF | OFFICER ARMOR"
ITEM.model = "models/fallout/apparel/mwpa.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mef/mwpa.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/mwpa.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 78
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
