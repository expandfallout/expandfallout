ITEM.name = "Gunners T-60 Armor Helmet"
ITEM.description = "A set of T-60 power armor worn by the Gunners. | OFFICER"
ITEM.model = "models/fallout/apparel/t60pahelmetgo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnert60helmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnert60helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Gunners"
ITEM.factionClass = "OFFICER"

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
