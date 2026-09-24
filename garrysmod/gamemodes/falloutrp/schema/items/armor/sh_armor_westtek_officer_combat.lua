ITEM.name = "West-Tek Private Security Combat Armor"
ITEM.description = "Combat armor associated with the pre-war government and it's contractors."
ITEM.model = "models/fallout/apparel/combatranger.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/enclavemarineoutfit.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/enclavemarineoutfit.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 73
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "West-Tek"
ITEM.factionClass = "Officer - West-Tek"

ITEM.specialBonus = {
	charisma = 2,
	intelligence = 2
}

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
