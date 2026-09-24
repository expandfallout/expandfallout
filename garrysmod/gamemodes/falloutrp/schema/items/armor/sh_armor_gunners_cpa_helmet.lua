ITEM.name = "Gunners Combat Power Armor Helmet"
ITEM.description = "A set of Combat Power Armor worn by the Gunners Lead. | LEAD"
ITEM.model = "models/fallout/apparel/t60pahelmetgo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnersflhelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnersflhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 80
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = true

ITEM.faction = "Gunners"
ITEM.factionClass = "LEAD"

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
