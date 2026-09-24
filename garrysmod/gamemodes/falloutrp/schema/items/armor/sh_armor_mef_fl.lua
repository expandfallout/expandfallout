ITEM.name = "Purity Tesla Power Armor"
ITEM.description = "A set of Power Armor from a far-away land, it's pristine in condition. Nobody quite knows what it's user is up to."
ITEM.model = "models/fallout/apparel/amwpa.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/mef/mwteslapa.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/mwteslapa.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = -40
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = false

ITEM.specialBonus = {
	perception = 4
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
