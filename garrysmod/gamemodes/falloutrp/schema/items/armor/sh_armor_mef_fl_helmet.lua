ITEM.name = "Purity Tesla Power Armor Helmet"
ITEM.description = "A set of Power Armor from a far-away land, it's pristine in condition. Nobody quite knows what it's user is up to."
ITEM.model = "models/fallout/apparel/amwpahelmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/mef/mwteslahelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/mef/mwteslahelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = false

ITEM.specialBonus = {
	perception = 2
}

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
