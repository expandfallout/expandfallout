ITEM.name = "West-Tek Combat Helmet"
ITEM.description = "Combat helmet worn by pre-war military personnel as-well as it's contractors."
ITEM.model = "models/thespireroleplay/items/clothes/group053_helmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/enclavemarinehelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/enclavemarinehelmet.mdl"

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
ITEM.factionClass = "Officer - West Tek"

ITEM.specialBonus = {
	charisma = 2,
	intelligence = 2
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
