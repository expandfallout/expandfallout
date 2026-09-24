ITEM.name = "Raider Wastehound Helmet"
ITEM.description =  "A bone helmet used by the Raiders."
ITEM.model = "models/fallout/apparel/helmetraider03.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/raider_wastehound_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/raider_wastehound_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 30
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Raider"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
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
